using Microsoft.EntityFrameworkCore;
using ViSinhVien.Api.Models;
namespace ViSinhVien.Api.Data;

public class FinanceDbContext(DbContextOptions<FinanceDbContext> options) : DbContext(options)
{
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<FinanceTransaction> Transactions => Set<FinanceTransaction>();
    public DbSet<MonthlyBudget> MonthlyBudgets => Set<MonthlyBudget>();
    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<Category>(e =>
        {
            e.ToTable("categories", t =>
            {
                t.HasCheckConstraint("ck_category_type", "type IN ('income', 'expense')");
                t.HasCheckConstraint("ck_category_name", "length(trim(name)) > 0");
            });
            e.Property(x => x.Id).HasColumnName("id");
            e.Property(x => x.Name).HasColumnName("name").HasMaxLength(100);
            e.Property(x => x.Type).HasColumnName("type").HasMaxLength(10);
            e.Property(x => x.IsArchived).HasColumnName("is_archived");
            e.HasIndex(x => new { x.Type, x.Name }).IsUnique();
            e.HasData(
                new Category { Id = 1, Name = "Ăn uống", Type = "expense" },
                new Category { Id = 2, Name = "Đi lại", Type = "expense" },
                new Category { Id = 3, Name = "Học tập", Type = "expense" },
                new Category { Id = 4, Name = "Sinh hoạt", Type = "expense" },
                new Category { Id = 5, Name = "Gia đình hỗ trợ", Type = "income" },
                new Category { Id = 6, Name = "Làm thêm", Type = "income" });
        });
        model.Entity<FinanceTransaction>(e =>
        {
            e.ToTable("transactions", t => t.HasCheckConstraint("ck_transaction_amount", "amount_vnd > 0 AND amount_vnd <= 1000000000000"));
            e.Property(x => x.Id).HasColumnName("id");
            e.Property(x => x.CategoryId).HasColumnName("category_id");
            e.Property(x => x.AmountVnd).HasColumnName("amount_vnd");
            e.Property(x => x.TransactionDate).HasColumnName("transaction_date");
            e.Property(x => x.Note).HasColumnName("note").HasMaxLength(500);
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.HasOne(x => x.Category).WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(x => x.TransactionDate);
        });
        model.Entity<MonthlyBudget>(e =>
        {
            e.ToTable("monthly_budgets", t =>
            {
                t.HasCheckConstraint("ck_budget_limit", "limit_vnd > 0 AND limit_vnd <= 1000000000000");
                t.HasCheckConstraint("ck_budget_month", "EXTRACT(DAY FROM budget_month) = 1");
            });
            e.Property(x => x.Id).HasColumnName("id");
            e.Property(x => x.BudgetMonth).HasColumnName("budget_month");
            e.Property(x => x.LimitVnd).HasColumnName("limit_vnd");
            e.HasIndex(x => x.BudgetMonth).IsUnique();
        });
    }
}
