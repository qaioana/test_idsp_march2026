namespace ApartmentOS.API.Models;

public class Apartment
{
    public int Id { get; set; }
    public string Number { get; set; } = string.Empty;
    public string Owner { get; set; } = string.Empty;
    public double AreaSqM { get; set; }
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public bool Active { get; set; } = true;

    public ICollection<BillPayment> Payments { get; set; } = [];
    public ICollection<WaterReading> WaterReadings { get; set; } = [];
}
