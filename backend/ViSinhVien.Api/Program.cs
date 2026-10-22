using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using ViSinhVien.Api.Data;
using ViSinhVien.Api.Models;
using ViSinhVien.Api.Endpoints;

var builder = WebApplication.CreateBuilder(args);
var connection = builder.Configuration.GetConnectionString("Finance")
    ?? throw new InvalidOperationException("Thiếu ConnectionStrings__Finance. Xem scripts/run-api.sh.");
builder.Services.AddDbContext<FinanceDbContext>(o => o.UseNpgsql(connection));
builder.Services.Configure<RouteHandlerOptions>(o => o.ThrowOnBadRequest = true);
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .SetIsOriginAllowed(origin => Uri.TryCreate(origin, UriKind.Absolute, out var uri) && uri.IsLoopback)
    .AllowAnyHeader().AllowAnyMethod()));
var app = builder.Build();
app.UseCors();
app.Use(async (context, next) =>
{
    try { await next(context); }
    catch (BadHttpRequestException)
    {
        context.Response.StatusCode = 400;
        await context.Response.WriteAsJsonAsync(new { message = "Dữ liệu gửi lên không hợp lệ. Số tiền phải là số nguyên và ngày phải có dạng yyyy-MM-dd." });
    }
    catch (DbUpdateException ex) when (ex.InnerException is Npgsql.PostgresException pg && pg.SqlState.StartsWith("23"))
    {
        context.Response.StatusCode = 409;
        await context.Response.WriteAsJsonAsync(new { message = "Dữ liệu bị trùng hoặc không còn hợp lệ. Hãy tải lại và thử lại." });
    }
    catch (Exception ex) when (IsDatabaseError(ex))
    {
        context.Response.StatusCode = 503;
        await context.Response.WriteAsJsonAsync(new { message = "Không kết nối được PostgreSQL. Hãy kiểm tra database và thử lại." });
    }
});

app.MapGet("/api/health", async (FinanceDbContext db) =>
    await db.Database.CanConnectAsync()
        ? Results.Ok(new { status = "ok", database = db.Database.GetDbConnection().Database })
        : Results.Json(new { message = "PostgreSQL chưa sẵn sàng." }, statusCode: 503));

app.MapGet("/api/categories", async (FinanceDbContext db) =>
    Results.Ok(await db.Categories.AsNoTracking().OrderBy(x => x.Type).ThenBy(x => x.Name).ToListAsync()));

app.MapPost("/api/categories", async (CategoryInput input, FinanceDbContext db) =>
{
    var name = (input.Name?.Trim() ?? "").Normalize(NormalizationForm.FormC);
    if (name.Length is < 1 or > 100 || input.Type is not ("income" or "expense"))
        return Error("Tên danh mục phải có 1–100 ký tự; loại phải là income hoặc expense.");
    await using var change = await db.Database.BeginTransactionAsync();
    var nameKey = input.Type + ":" + name.ToUpperInvariant();
    await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({nameKey}, 0))");
    var names = await db.Categories.Where(x => x.Type == input.Type).Select(x => x.Name).ToListAsync();
    if (names.Any(existing => string.Equals(existing, name, StringComparison.OrdinalIgnoreCase)))
        return Error("Danh mục cùng tên và loại đã tồn tại.");
    var item = new Category { Name = name, Type = input.Type };
    db.Categories.Add(item);
    await db.SaveChangesAsync();
    await change.CommitAsync();
    return Results.Created($"/api/categories/{item.Id}", item);
});

app.MapPut("/api/categories/{id:long}", async (long id, CategoryEdit input, FinanceDbContext db) =>
{
    var item = await db.Categories.FindAsync(id);
    if (item is null) return Results.NotFound();
    var name = (input.Name?.Trim() ?? "").Normalize(NormalizationForm.FormC);
    if (name.Length is < 1 or > 100) return Error("Tên danh mục phải có 1–100 ký tự.");
    await using var change = await db.Database.BeginTransactionAsync();
    var nameKey = item.Type + ":" + name.ToUpperInvariant();
    await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({nameKey}, 0))");
    var names = await db.Categories.Where(x => x.Id != id && x.Type == item.Type).Select(x => x.Name).ToListAsync();
    if (names.Any(existing => string.Equals(existing, name, StringComparison.OrdinalIgnoreCase)))
        return Error("Danh mục cùng tên và loại đã tồn tại.");
    item.Name = name;
    item.IsArchived = input.IsArchived;
    await db.SaveChangesAsync();
    await change.CommitAsync();
    return Results.Ok(item);
});

app.MapGet("/api/transactions", async (FinanceDbContext db, string? month, string? type,
    long? categoryId, string? search, int page = 1, int pageSize = 20) =>
{
    if (page < 1 || page > 1000000 || pageSize is < 1 or > 100) return Error("Phân trang không hợp lệ.");
    if (categoryId is <= 0) return Error("Danh mục không hợp lệ.");
    if (search?.Length > 500) return Error("Từ khóa tìm kiếm tối đa 500 ký tự.");
    var query = db.Transactions.AsNoTracking().AsQueryable();
    if (month is not null)
    {
        if (!TryMonth(month, out var start)) return Error("Tháng phải có dạng yyyy-MM.");
        var end = start.AddMonths(1);
        query = query.Where(x => x.TransactionDate >= start && x.TransactionDate < end);
    }
    if (type is not null)
    {
        if (type is not ("income" or "expense")) return Error("Loại không hợp lệ.");
        query = query.Where(x => x.Category.Type == type);
    }
    if (categoryId is not null) query = query.Where(x => x.CategoryId == categoryId);
    if (!string.IsNullOrWhiteSpace(search))
    {
        var text = search.Trim();
        // PostgreSQL installed with locale C cannot case-fold Vietnamese accented
        // capitals. Compare candidate text consistently across Windows/Linux.
        var candidates = await query.Select(x => new { x.Id, x.Note, CategoryName = x.Category.Name }).ToListAsync();
        var matchingIds = candidates.Where(x => x.Note.Contains(text, StringComparison.OrdinalIgnoreCase)
            || x.CategoryName.Contains(text, StringComparison.OrdinalIgnoreCase)).Select(x => x.Id).ToArray();
        query = query.Where(x => matchingIds.Contains(x.Id));
    }
    var total = await query.CountAsync();
    var items = await query.OrderByDescending(x => x.TransactionDate).ThenByDescending(x => x.Id)
        .Skip((page - 1) * pageSize).Take(pageSize).Select(x => new
        {
            x.Id, x.CategoryId, categoryName = x.Category.Name, type = x.Category.Type,
            x.AmountVnd, x.TransactionDate, x.Note, x.CreatedAt
        }).ToListAsync();
    return Results.Ok(new { items, total, page, pageSize });
});

app.MapGet("/api/transactions/{id:long}", async (long id, FinanceDbContext db) =>
{
    var item = await db.Transactions.AsNoTracking().Where(x => x.Id == id).Select(x => new
    {
        x.Id, x.CategoryId, categoryName = x.Category.Name, type = x.Category.Type,
        x.AmountVnd, x.TransactionDate, x.Note, x.CreatedAt
    }).SingleOrDefaultAsync();
    return item is null ? Results.NotFound() : Results.Ok(item);
});

app.MapPost("/api/transactions", async (TransactionInput input, FinanceDbContext db) =>
{
    var error = await ValidateTransaction(input, db);
    if (error is not null) return Error(error);
    var item = new FinanceTransaction
    {
        CategoryId = input.CategoryId, AmountVnd = input.AmountVnd,
        TransactionDate = input.TransactionDate, Note = input.Note?.Trim() ?? ""
    };
    db.Transactions.Add(item);
    await db.SaveChangesAsync();
    return Results.Created($"/api/transactions/{item.Id}", new { item.Id, item.CategoryId, item.AmountVnd, item.TransactionDate, item.Note, item.CreatedAt });
});

app.MapPut("/api/transactions/{id:long}", async (long id, TransactionInput input, FinanceDbContext db) =>
{
    var item = await db.Transactions.FindAsync(id);
    if (item is null) return Results.NotFound();
    var error = await ValidateTransaction(input, db, item.CategoryId);
    if (error is not null) return Error(error);
    item.CategoryId = input.CategoryId;
    item.AmountVnd = input.AmountVnd;
    item.TransactionDate = input.TransactionDate;
    item.Note = input.Note?.Trim() ?? "";
    await db.SaveChangesAsync();
    return Results.Ok(new { item.Id, item.CategoryId, item.AmountVnd, item.TransactionDate, item.Note, item.CreatedAt });
});

app.MapDelete("/api/transactions/{id:long}", async (long id, FinanceDbContext db) =>
{
    var item = await db.Transactions.FindAsync(id);
    if (item is null) return Results.NotFound();
    db.Transactions.Remove(item);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.MapGet("/api/reports/monthly", async (string month, FinanceDbContext db) =>
{
    if (!TryMonth(month, out var start)) return Error("Tháng phải có dạng yyyy-MM.");
    var end = start.AddMonths(1);
    var grouped = await db.Transactions.AsNoTracking()
        .Where(x => x.TransactionDate >= start && x.TransactionDate < end)
        .GroupBy(x => new { x.CategoryId, x.Category.Name, x.Category.Type })
        .Select(g => new { categoryId = g.Key.CategoryId, categoryName = g.Key.Name, type = g.Key.Type,
            amountVnd = g.Sum(x => (decimal)x.AmountVnd) }).ToListAsync();
    var income = grouped.Where(x => x.type == "income").Sum(x => x.amountVnd);
    var expense = grouped.Where(x => x.type == "expense").Sum(x => x.amountVnd);
    var budget = await db.MonthlyBudgets.AsNoTracking().SingleOrDefaultAsync(x => x.BudgetMonth == start);
    decimal? percent = budget is null ? null : Math.Round(expense * 100 / budget.LimitVnd, 2);
    var status = budget is null ? "unset" : expense > budget.LimitVnd ? "exceeded"
        : expense == budget.LimitVnd ? "reached" : expense >= budget.LimitVnd * 0.8m ? "warning" : "normal";
    return Results.Ok(new { month, incomeVnd = income, expenseVnd = expense, balanceVnd = income - expense,
        budgetLimitVnd = budget?.LimitVnd, budgetPercent = percent, budgetStatus = status,
        expenseByCategory = grouped.Where(x => x.type == "expense").OrderByDescending(x => x.amountVnd) });
});

app.MapFinanceExtensions();

// Removing the monthly cap never removes recorded transactions or category caps.
// The mobile UI offers this as "Gỡ hạn mức" to return to the "Chưa thiết lập" state.
app.MapDelete("/api/budgets/{month}", async (string month, FinanceDbContext db) =>
{
    if (!TryMonth(month, out var start)) return Error("Tháng phải có dạng yyyy-MM.");
    var count = await db.MonthlyBudgets.Where(x => x.BudgetMonth == start).ExecuteDeleteAsync();
    return count == 0
        ? Results.NotFound(new { message = "Tháng này chưa thiết lập ngân sách." })
        : Results.NoContent();
});

app.MapPut("/api/budgets/{month}", async (string month, BudgetInput input, FinanceDbContext db) =>
{
    if (!TryMonth(month, out var start)) return Error("Tháng phải có dạng yyyy-MM.");
    if (input.LimitVnd is <= 0 or > 1000000000000) return Error("Ngân sách phải từ 1 đến 1.000.000.000.000 đồng.");
    // Upsert giữ đúng một dòng mỗi tháng khi có yêu cầu đồng thời.
    await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO monthly_budgets (budget_month, limit_vnd) VALUES ({start}, {input.LimitVnd}) ON CONFLICT (budget_month) DO UPDATE SET limit_vnd = EXCLUDED.limit_vnd");
    return Results.Ok(new { month, input.LimitVnd });
});

app.Run();

static IResult Error(string message) => Results.BadRequest(new { message });
static bool IsDatabaseError(Exception error)
{
    // EF Core có thể bọc lỗi mất kết nối trong InvalidOperationException.
    for (Exception? current = error; current is not null; current = current.InnerException)
        if (current is Npgsql.NpgsqlException) return true;
    return false;
}
static bool TryMonth(string month, out DateOnly date) =>
    DateOnly.TryParseExact(month + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out date)
    && date.Year is >= 1900 and <= 2100;
static async Task<string?> ValidateTransaction(TransactionInput input, FinanceDbContext db, long? oldCategoryId = null)
{
    if (input.AmountVnd is <= 0 or > 1000000000000) return "Số tiền phải từ 1 đến 1.000.000.000.000 đồng.";
    if (input.TransactionDate.Year is < 1900 or > 2100) return "Ngày giao dịch phải nằm trong năm 1900–2100.";
    var vietnamToday = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTime.UtcNow, "Asia/Ho_Chi_Minh"));
    if (input.TransactionDate > vietnamToday) return "Ngày giao dịch không được ở tương lai.";
    if ((input.Note?.Length ?? 0) > 500) return "Ghi chú tối đa 500 ký tự.";
    var category = await db.Categories.FindAsync(input.CategoryId);
    if (category is null) return "Danh mục không tồn tại.";
    if (category.IsArchived && oldCategoryId != category.Id) return "Danh mục đã lưu trữ không nhận giao dịch mới.";
    return null;
}

record CategoryInput(string? Name, string Type);
record CategoryEdit(string? Name, bool IsArchived);
record TransactionInput(long CategoryId, long AmountVnd, DateOnly TransactionDate, string? Note);
record BudgetInput(long LimitVnd);
