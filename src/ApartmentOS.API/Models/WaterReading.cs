namespace ApartmentOS.API.Models;

public class WaterReading
{
    public int Id { get; set; }
    public int ApartmentId { get; set; }
    public string Month { get; set; } = string.Empty; // YYYY-MM
    public double Reading { get; set; }
    public DateTime SubmittedAt { get; set; } = DateTime.UtcNow;

    public Apartment Apartment { get; set; } = null!;
}
