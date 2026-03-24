namespace ApartmentOS.API.Models;

public class BillPayment
{
    public int Id { get; set; }
    public int BillId { get; set; }
    public int ApartmentId { get; set; }
    public decimal AmountDue { get; set; }
    public bool IsPaid { get; set; }
    public DateTime? PaidAt { get; set; }

    public Bill Bill { get; set; } = null!;
    public Apartment Apartment { get; set; } = null!;
}
