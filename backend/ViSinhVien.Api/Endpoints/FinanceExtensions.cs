using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using ViSinhVien.Api.Data;

namespace ViSinhVien.Api.Endpoints;

public static class FinanceExtensions
{
    public static void MapFinanceExtensions(this WebApplication app)
    {
        app.MapGet("/api/reports/summary", async (string period, string date, FinanceDbContext db) =>
        {
            if (!TryRange(period, date, out var start, out var end))
                return Error("Kỳ phải là week, month hoặc year; ngày phải có dạng yyyy-MM-dd (1900–2100).");
            var groups = await db.Transactions.AsNoTracking()
                .Where(x => x.TransactionDate >= start && x.TransactionDate < end)
                .GroupBy(x => new { x.CategoryId, x.Category.Name, x.Category.Type })
                .Select(g => new { categoryId = g.Key.CategoryId, categoryName = g.Key.Name, type = g.Key.Type,
                    amountVnd = g.Sum(x => (decimal)x.AmountVnd), transactionCount = g.Count() }).ToListAsync();
            var income = groups.Where(x => x.type == "income").Sum(x => x.amountVnd);
            var expense = groups.Where(x => x.type == "expense").Sum(x => x.amountVnd);
            return Results.Ok(new
            {
                period, startDate = start, endDate = end.AddDays(-1), incomeVnd = income,
                expenseVnd = expense, balanceVnd = income - expense,
                transactionCount = groups.Sum(x => x.transactionCount),
                expenseByCategory = groups.Where(x => x.type == "expense").OrderByDescending(x => x.amountVnd)
                    .Select(x => new { x.categoryId, x.categoryName, x.type, x.amountVnd, x.transactionCount,
                        percent = expense == 0 ? 0 : Math.Round(x.amountVnd * 100 / expense, 2) })
            });
        });

        app.MapGet("/api/reports/export", async (string period, string date, FinanceDbContext db) =>
        {
            if (!TryRange(period, date, out var start, out var end))
                return Error("Kỳ phải là week, month hoặc year; ngày phải có dạng yyyy-MM-dd (1900–2100).");
            var items = await db.Transactions.AsNoTracking()
                .Where(x => x.TransactionDate >= start && x.TransactionDate < end)
                .OrderByDescending(x => x.TransactionDate).ThenByDescending(x => x.Id)
                .Select(x => new { x.Id, x.TransactionDate, x.Category.Name, x.Category.Type, x.AmountVnd, x.Note })
                .ToListAsync();
            var csv = new StringBuilder("Mã giao dịch,Ngày,Danh mục,Loại,Số tiền VNĐ,Ghi chú\r\n");
            foreach (var item in items)
                csv.AppendLine(string.Join(",", item.Id, item.TransactionDate.ToString("yyyy-MM-dd"),
                    Csv(item.Name), Csv(item.Type == "expense" ? "Chi" : "Thu"),
                    item.AmountVnd.ToString(CultureInfo.InvariantCulture), Csv(item.Note)));
            var encoding = new UTF8Encoding(true);
            var bytes = encoding.GetPreamble().Concat(encoding.GetBytes(csv.ToString())).ToArray();
            return Results.File(bytes, "text/csv; charset=utf-8", $"vi-sinh-vien-{period}-{start:yyyy-MM-dd}.csv");
        });

        app.MapGet("/api/budgets/{month}", async (string month, FinanceDbContext db) =>
        {
            if (!TryMonth(month, out var start)) return Error("Tháng phải có dạng yyyy-MM (1900–2100).");
            var end = start.AddMonths(1);
            var overall = await db.MonthlyBudgets.AsNoTracking().SingleOrDefaultAsync(x => x.BudgetMonth == start);
            var spending = await db.Transactions.AsNoTracking()
                .Where(x => x.TransactionDate >= start && x.TransactionDate < end && x.Category.Type == "expense")
                .GroupBy(x => x.CategoryId)
                .Select(g => new { categoryId = g.Key, spent = g.Sum(x => (decimal)x.AmountVnd) })
                .ToDictionaryAsync(x => x.categoryId, x => x.spent);
            var budgets = await db.CategoryBudgets.AsNoTracking().Where(x => x.BudgetMonth == start)
                .ToDictionaryAsync(x => x.CategoryId, x => x.LimitVnd);
            var categoryIds = spending.Keys.Concat(budgets.Keys).ToList();
            var categories = await db.Categories.AsNoTracking()
                .Where(x => x.Type == "expense" && (!x.IsArchived || categoryIds.Contains(x.Id)))
                .OrderBy(x => x.Name).ToListAsync();
            var total = spending.Values.Sum();
            return Results.Ok(new
            {
                month, limitVnd = overall?.LimitVnd, spentVnd = total,
                remainingVnd = overall is null ? (decimal?)null : overall.LimitVnd - total,
                percent = Percent(total, overall?.LimitVnd), status = Status(total, overall?.LimitVnd),
                categoryBudgets = categories.Select(c =>
                {
                    var spent = spending.GetValueOrDefault(c.Id);
                    long? limit = budgets.TryGetValue(c.Id, out var value) ? value : null;
                    return new { categoryId = c.Id, categoryName = c.Name, isArchived = c.IsArchived,
                        limitVnd = limit, spentVnd = spent,
                        remainingVnd = limit is null ? (decimal?)null : limit - spent,
                        percent = Percent(spent, limit), status = Status(spent, limit) };
                })
            });
        });

        app.MapPut("/api/budgets/{month}/categories/{categoryId:long}",
            async (string month, long categoryId, LimitInput input, FinanceDbContext db) =>
        {
            if (!TryMonth(month, out var start)) return Error("Tháng phải có dạng yyyy-MM (1900–2100).");
            if (input.LimitVnd is <= 0 or > 1000000000000) return Error("Hạn mức phải từ 1 đến 1.000.000.000.000 đồng.");
            var category = await db.Categories.FindAsync(categoryId);
            if (category is null) return Results.NotFound(new { message = "Không tìm thấy danh mục." });
            if (category.Type != "expense" || category.IsArchived) return Error("Chỉ thiết lập hạn mức cho danh mục chi đang sử dụng.");
            await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO category_budgets (budget_month, category_id, limit_vnd) VALUES ({start}, {categoryId}, {input.LimitVnd}) ON CONFLICT (budget_month, category_id) DO UPDATE SET limit_vnd = EXCLUDED.limit_vnd");
            return Results.Ok(new { month, categoryId, input.LimitVnd });
        });

        app.MapDelete("/api/budgets/{month}/categories/{categoryId:long}",
            async (string month, long categoryId, FinanceDbContext db) =>
        {
            if (!TryMonth(month, out var start)) return Error("Tháng phải có dạng yyyy-MM (1900–2100).");
            var count = await db.CategoryBudgets.Where(x => x.BudgetMonth == start && x.CategoryId == categoryId).ExecuteDeleteAsync();
            return count == 0 ? Results.NotFound(new { message = "Danh mục chưa có hạn mức trong tháng này." }) : Results.NoContent();
        });

        app.MapGet("/api/profile", async (FinanceDbContext db) =>
            Results.Ok(new { displayName = await db.UserProfiles.Where(x => x.Id == 1).Select(x => x.DisplayName).SingleOrDefaultAsync() ?? "" }));
        app.MapPut("/api/profile", async (ProfileInput input, FinanceDbContext db) =>
        {
            var name = input.DisplayName?.Trim() ?? "";
            if (name.Length > 80 || name.Any(char.IsControl)) return Error("Tên hiển thị tối đa 80 ký tự và không chứa ký tự điều khiển.");
            await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO user_profile (id, display_name) VALUES (1, {name}) ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name");
            return Results.Ok(new { displayName = name });
        });
    }

    private static decimal? Percent(decimal spent, long? limit) => limit is null ? null : Math.Round(spent * 100 / limit.Value, 2);
    private static string Status(decimal spent, long? limit) => limit is null ? "unset" : spent > limit ? "exceeded" : spent == limit ? "reached" : spent >= limit * .8m ? "warning" : "normal";
    private static IResult Error(string message) => Results.BadRequest(new { message });
    private static bool TryMonth(string text, out DateOnly date) =>
        DateOnly.TryParseExact(text + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out date) && date.Year is >= 1900 and <= 2100;
    private static bool TryRange(string period, string text, out DateOnly start, out DateOnly end)
    {
        start = end = default;
        if (!DateOnly.TryParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var date)
            || date.Year is < 1900 or > 2100) return false;
        switch (period)
        {
            case "week": start = date.AddDays(-(((int)date.DayOfWeek + 6) % 7)); end = start.AddDays(7); return true;
            case "month": start = new DateOnly(date.Year, date.Month, 1); end = start.AddMonths(1); return true;
            case "year": start = new DateOnly(date.Year, 1, 1); end = start.AddYears(1); return true;
            default: return false;
        }
    }
    private static string Csv(string value)
    {
        // Excel must treat notes and category names as text, including formula-like input.
        if (value.TrimStart().StartsWith('=') || value.TrimStart().StartsWith('+') || value.TrimStart().StartsWith('-') || value.TrimStart().StartsWith('@')) value = "'" + value;
        return "\"" + value.Replace("\"", "\"\"") + "\"";
    }
    public record LimitInput(long LimitVnd);
    public record ProfileInput(string? DisplayName);
}
