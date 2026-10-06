namespace ViSinhVien.Api.Models;

public class Category
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public string Type { get; set; } = "expense";
    public bool IsArchived { get; set; }
}
public class FinanceTransaction
{
    public long Id { get; set; }
    public long CategoryId { get; set; }
    public Category Category { get; set; } = null!;
    public long AmountVnd { get; set; }
    public DateOnly TransactionDate { get; set; }
    public string Note { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
public class MonthlyBudget
{
    public long Id { get; set; }
    public DateOnly BudgetMonth { get; set; }
    public long LimitVnd { get; set; }
}
