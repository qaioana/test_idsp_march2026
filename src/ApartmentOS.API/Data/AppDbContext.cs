using ApartmentOS.API.Models;
using Microsoft.EntityFrameworkCore;

namespace ApartmentOS.API.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Apartment> Apartments => Set<Apartment>();
    public DbSet<Bill> Bills => Set<Bill>();
    public DbSet<BillPayment> BillPayments => Set<BillPayment>();
    public DbSet<WaterReading> WaterReadings => Set<WaterReading>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<BillPayment>()
            .HasOne(p => p.Bill)
            .WithMany(b => b.Payments)
            .HasForeignKey(p => p.BillId);

        modelBuilder.Entity<BillPayment>()
            .HasOne(p => p.Apartment)
            .WithMany(a => a.Payments)
            .HasForeignKey(p => p.ApartmentId);

        modelBuilder.Entity<WaterReading>()
            .HasOne(r => r.Apartment)
            .WithMany(a => a.WaterReadings)
            .HasForeignKey(r => r.ApartmentId);

        modelBuilder.Entity<Bill>()
            .Property(b => b.TotalAmount)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<BillPayment>()
            .Property(p => p.AmountDue)
            .HasColumnType("decimal(18,2)");
    }
}
