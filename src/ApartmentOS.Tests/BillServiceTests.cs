using ApartmentOS.API.Data;
using ApartmentOS.API.Models;
using ApartmentOS.API.Services;
using Microsoft.EntityFrameworkCore;

namespace ApartmentOS.Tests;

public class BillServiceTests : IDisposable
{
    private readonly AppDbContext _db;
    private readonly BillService _sut;

    public BillServiceTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        _db = new AppDbContext(options);
        _sut = new BillService(_db);
    }

    public void Dispose() => _db.Dispose();

    // ── helpers ──────────────────────────────────────────────────────────

    private async Task SeedApartmentsAsync(params (string number, double area)[] apartments)
    {
        foreach (var (number, area) in apartments)
            _db.Apartments.Add(new Apartment { Number = number, Owner = "Owner", AreaSqM = area, Active = true });
        await _db.SaveChangesAsync();
    }

    // ── CreateBill ────────────────────────────────────────────────────────

    [Fact]
    public async Task CreateBill_EqualSplit_DistributesEvenlyAcrossApartments()
    {
        await SeedApartmentsAsync(("1A", 50), ("1B", 50), ("1C", 50));

        var bill = await _sut.CreateBillAsync(new CreateBillRequest(
            "Maintenance", "2026-03", 300m, SplitMethod.Equal, null));

        var payments = await _db.BillPayments.Where(p => p.BillId == bill.Id).ToListAsync();
        Assert.Equal(3, payments.Count);
        Assert.All(payments, p => Assert.Equal(100m, p.AmountDue));
    }

    [Fact]
    public async Task CreateBill_AreaSplit_DistributesProportionallyToArea()
    {
        // Apt 1: 100 sqm, Apt 2: 100 sqm, Apt 3: 50 sqm  → total 250 sqm
        await SeedApartmentsAsync(("1A", 100), ("1B", 100), ("1C", 50));

        var bill = await _sut.CreateBillAsync(new CreateBillRequest(
            "Heating", "2026-03", 250m, SplitMethod.ByArea, null));

        var payments = await _db.BillPayments
            .Where(p => p.BillId == bill.Id)
            .Include(p => p.Apartment)
            .OrderBy(p => p.Apartment.Number)
            .ToListAsync();

        Assert.Equal(100m, payments[0].AmountDue); // 1A: 100/250 * 250
        Assert.Equal(100m, payments[1].AmountDue); // 1B: 100/250 * 250
        Assert.Equal(50m,  payments[2].AmountDue); // 1C:  50/250 * 250
    }

    [Fact]
    public async Task CreateBill_NoActiveApartments_ThrowsInvalidOperationException()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _sut.CreateBillAsync(new CreateBillRequest(
                "Water", "2026-03", 100m, SplitMethod.Equal, null)));
    }

    [Fact]
    public async Task CreateBill_OnlyIncludesActiveApartments()
    {
        _db.Apartments.Add(new Apartment { Number = "1A", Owner = "A", AreaSqM = 60, Active = true });
        _db.Apartments.Add(new Apartment { Number = "1B", Owner = "B", AreaSqM = 60, Active = false });
        await _db.SaveChangesAsync();

        var bill = await _sut.CreateBillAsync(new CreateBillRequest(
            "Cleaning", "2026-03", 60m, SplitMethod.Equal, null));

        var payments = await _db.BillPayments.Where(p => p.BillId == bill.Id).ToListAsync();
        Assert.Single(payments);
    }

    // ── GetBills ──────────────────────────────────────────────────────────

    [Fact]
    public async Task GetBills_FiltersByMonth()
    {
        await SeedApartmentsAsync(("1A", 50));
        await _sut.CreateBillAsync(new CreateBillRequest("A", "2026-02", 100m, SplitMethod.Equal, null));
        await _sut.CreateBillAsync(new CreateBillRequest("B", "2026-03", 200m, SplitMethod.Equal, null));

        var results = await _sut.GetBillsAsync("2026-03");

        Assert.Single(results);
        Assert.Equal("B", results[0].Category);
    }

    [Fact]
    public async Task GetBills_ExcludesSoftDeletedBills()
    {
        await SeedApartmentsAsync(("1A", 50));
        var bill = await _sut.CreateBillAsync(new CreateBillRequest("A", "2026-03", 100m, SplitMethod.Equal, null));
        await _sut.DeleteBillAsync(bill.Id);

        var results = await _sut.GetBillsAsync();

        Assert.Empty(results);
    }

    // ── MarkAsPaid / MarkAsUnpaid ─────────────────────────────────────────

    [Fact]
    public async Task MarkAsPaid_SetsIsPaidAndPaidAt()
    {
        await SeedApartmentsAsync(("1A", 50));
        var apt = await _db.Apartments.FirstAsync();
        var bill = await _sut.CreateBillAsync(new CreateBillRequest("Water", "2026-03", 100m, SplitMethod.Equal, null));

        await _sut.MarkAsPaidAsync(bill.Id, apt.Id);

        var payment = await _db.BillPayments.FirstAsync(p => p.BillId == bill.Id && p.ApartmentId == apt.Id);
        Assert.True(payment.IsPaid);
        Assert.NotNull(payment.PaidAt);
    }

    [Fact]
    public async Task MarkAsUnpaid_ClearsPaidAt()
    {
        await SeedApartmentsAsync(("1A", 50));
        var apt = await _db.Apartments.FirstAsync();
        var bill = await _sut.CreateBillAsync(new CreateBillRequest("Water", "2026-03", 100m, SplitMethod.Equal, null));

        await _sut.MarkAsPaidAsync(bill.Id, apt.Id);
        await _sut.MarkAsUnpaidAsync(bill.Id, apt.Id);

        var payment = await _db.BillPayments.FirstAsync(p => p.BillId == bill.Id && p.ApartmentId == apt.Id);
        Assert.False(payment.IsPaid);
        Assert.Null(payment.PaidAt);
    }

    [Fact]
    public async Task MarkAsPaid_UnknownPayment_ThrowsKeyNotFoundException()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _sut.MarkAsPaidAsync(999, 999));
    }

    // ── UpdateNote ────────────────────────────────────────────────────────

    [Fact]
    public async Task UpdateNote_ChangesNoteOnBill()
    {
        await SeedApartmentsAsync(("1A", 50));
        var bill = await _sut.CreateBillAsync(new CreateBillRequest("Water", "2026-03", 100m, SplitMethod.Equal, null));

        await _sut.UpdateNoteAsync(bill.Id, "Corrected reading");

        var updated = await _db.Bills.FindAsync(bill.Id);
        Assert.Equal("Corrected reading", updated!.Note);
    }

    // ── GetBillPayments ───────────────────────────────────────────────────

    [Fact]
    public async Task GetBillPayments_ReturnsSummaryPerApartment()
    {
        await SeedApartmentsAsync(("1A", 60), ("1B", 40));
        var bill = await _sut.CreateBillAsync(new CreateBillRequest("Gas", "2026-03", 100m, SplitMethod.Equal, null));

        var details = await _sut.GetBillPaymentsAsync(bill.Id);

        Assert.Equal(2, details.Count);
        Assert.All(details, d => Assert.Equal(50m, d.AmountDue));
    }
}
