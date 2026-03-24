using ApartmentOS.API.Data;
using ApartmentOS.API.Models;
using Microsoft.EntityFrameworkCore;

namespace ApartmentOS.API.Services;

public class BillService(AppDbContext db) : IBillService
{
    public async Task<Bill> CreateBillAsync(CreateBillRequest request)
    {
        var apartments = await db.Apartments
            .Where(a => a.Active)
            .ToListAsync();

        if (apartments.Count == 0)
            throw new InvalidOperationException("No active apartments found.");

        var bill = new Bill
        {
            Category = request.Category,
            Month = request.Month,
            TotalAmount = request.TotalAmount,
            SplitMethod = request.SplitMethod,
            Note = request.Note
        };

        db.Bills.Add(bill);
        await db.SaveChangesAsync();

        var payments = CalculatePayments(bill, apartments);
        db.BillPayments.AddRange(payments);
        await db.SaveChangesAsync();

        return bill;
    }

    public async Task<IReadOnlyList<BillSummary>> GetBillsAsync(string? month = null)
    {
        var query = db.Bills
            .Where(b => b.Active)
            .Include(b => b.Payments)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(month))
            query = query.Where(b => b.Month == month);

        var bills = await query.OrderByDescending(b => b.Month).ToListAsync();

        return bills.Select(b => new BillSummary(
            b.Id,
            b.Category,
            b.Month,
            b.TotalAmount,
            b.SplitMethod,
            b.Note,
            b.Payments.Count(p => p.IsPaid),
            b.Payments.Count
        )).ToList();
    }

    public async Task<IReadOnlyList<ApartmentPaymentDetail>> GetBillPaymentsAsync(int billId)
    {
        var payments = await db.BillPayments
            .Where(p => p.BillId == billId)
            .Include(p => p.Apartment)
            .OrderBy(p => p.Apartment.Number)
            .ToListAsync();

        return payments.Select(p => new ApartmentPaymentDetail(
            p.ApartmentId,
            p.Apartment.Number,
            p.Apartment.Owner,
            p.AmountDue,
            p.IsPaid,
            p.PaidAt
        )).ToList();
    }

    public async Task MarkAsPaidAsync(int billId, int apartmentId)
    {
        var payment = await GetPaymentOrThrowAsync(billId, apartmentId);
        payment.IsPaid = true;
        payment.PaidAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
    }

    public async Task MarkAsUnpaidAsync(int billId, int apartmentId)
    {
        var payment = await GetPaymentOrThrowAsync(billId, apartmentId);
        payment.IsPaid = false;
        payment.PaidAt = null;
        await db.SaveChangesAsync();
    }

    public async Task UpdateNoteAsync(int billId, string? note)
    {
        var bill = await db.Bills.FindAsync(billId)
            ?? throw new KeyNotFoundException($"Bill {billId} not found.");
        bill.Note = note;
        await db.SaveChangesAsync();
    }

    public async Task DeleteBillAsync(int billId)
    {
        var bill = await db.Bills.FindAsync(billId)
            ?? throw new KeyNotFoundException($"Bill {billId} not found.");
        bill.Active = false;
        await db.SaveChangesAsync();
    }

    // ── helpers ────────────────────────────────────────────────────────────

    private static List<BillPayment> CalculatePayments(Bill bill, List<Apartment> apartments)
    {
        return bill.SplitMethod switch
        {
            SplitMethod.Equal => SplitEqually(bill, apartments),
            SplitMethod.ByArea => SplitByArea(bill, apartments),
            _ => throw new ArgumentOutOfRangeException()
        };
    }

    private static List<BillPayment> SplitEqually(Bill bill, List<Apartment> apartments)
    {
        var share = bill.TotalAmount / apartments.Count;
        return apartments.Select(a => new BillPayment
        {
            BillId = bill.Id,
            ApartmentId = a.Id,
            AmountDue = Math.Round(share, 2)
        }).ToList();
    }

    private static List<BillPayment> SplitByArea(Bill bill, List<Apartment> apartments)
    {
        var totalArea = (decimal)apartments.Sum(a => a.AreaSqM);
        return apartments.Select(a => new BillPayment
        {
            BillId = bill.Id,
            ApartmentId = a.Id,
            AmountDue = Math.Round(bill.TotalAmount * (decimal)(a.AreaSqM / (double)totalArea), 2)
        }).ToList();
    }

    private async Task<BillPayment> GetPaymentOrThrowAsync(int billId, int apartmentId)
        => await db.BillPayments
               .FirstOrDefaultAsync(p => p.BillId == billId && p.ApartmentId == apartmentId)
           ?? throw new KeyNotFoundException($"Payment for bill {billId}, apartment {apartmentId} not found.");
}
