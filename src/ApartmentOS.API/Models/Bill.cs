namespace ApartmentOS.API.Models;

public enum SplitMethod
{
    Equal,
    ByArea
}

public class Bill
{
    public int Id { get; set; }
    public string Category { get; set; } = string.Empty;
    public string Month { get; set; } = string.Empty; // YYYY-MM
    public decimal TotalAmount { get; set; }
    public SplitMethod SplitMethod { get; set; }
    public string? Note { get; set; }
    public bool Active { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<BillPayment> Payments { get; set; } = [];
}
