using ApartmentOS.API.Models;

namespace ApartmentOS.API.Services;

public record CreateBillRequest(
    string Category,
    string Month,
    decimal TotalAmount,
    SplitMethod SplitMethod,
    string? Note
);

public record BillSummary(
    int BillId,
    string Category,
    string Month,
    decimal TotalAmount,
    SplitMethod SplitMethod,
    string? Note,
    int PaidCount,
    int TotalCount
);

public record ApartmentPaymentDetail(
    int ApartmentId,
    string ApartmentNumber,
    string Owner,
    decimal AmountDue,
    bool IsPaid,
    DateTime? PaidAt
);

public interface IBillService
{
    Task<Bill> CreateBillAsync(CreateBillRequest request);
    Task<IReadOnlyList<BillSummary>> GetBillsAsync(string? month = null);
    Task<IReadOnlyList<ApartmentPaymentDetail>> GetBillPaymentsAsync(int billId);
    Task MarkAsPaidAsync(int billId, int apartmentId);
    Task MarkAsUnpaidAsync(int billId, int apartmentId);
    Task UpdateNoteAsync(int billId, string? note);
    Task DeleteBillAsync(int billId);
}
