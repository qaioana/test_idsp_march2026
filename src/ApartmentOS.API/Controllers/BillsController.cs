using ApartmentOS.API.Services;
using Microsoft.AspNetCore.Mvc;

namespace ApartmentOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BillsController(IBillService billService) : ControllerBase
{
    /// <summary>Get all bills, optionally filtered by month (YYYY-MM).</summary>
    [HttpGet]
    public async Task<IActionResult> GetBills([FromQuery] string? month)
    {
        var bills = await billService.GetBillsAsync(month);
        return Ok(bills);
    }

    /// <summary>Get per-apartment payment breakdown for a specific bill.</summary>
    [HttpGet("{billId:int}/payments")]
    public async Task<IActionResult> GetPayments(int billId)
    {
        try
        {
            var payments = await billService.GetBillPaymentsAsync(billId);
            return Ok(payments);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ex.Message);
        }
    }

    /// <summary>Create a new bill and distribute costs across active apartments.</summary>
    [HttpPost]
    public async Task<IActionResult> CreateBill([FromBody] CreateBillRequest request)
    {
        try
        {
            var bill = await billService.CreateBillAsync(request);
            return CreatedAtAction(nameof(GetPayments), new { billId = bill.Id }, new { bill.Id });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    /// <summary>Mark an apartment's payment on a bill as paid.</summary>
    [HttpPatch("{billId:int}/payments/{apartmentId:int}/pay")]
    public async Task<IActionResult> MarkPaid(int billId, int apartmentId)
    {
        try
        {
            await billService.MarkAsPaidAsync(billId, apartmentId);
            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ex.Message);
        }
    }

    /// <summary>Mark an apartment's payment on a bill as unpaid.</summary>
    [HttpPatch("{billId:int}/payments/{apartmentId:int}/unpay")]
    public async Task<IActionResult> MarkUnpaid(int billId, int apartmentId)
    {
        try
        {
            await billService.MarkAsUnpaidAsync(billId, apartmentId);
            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ex.Message);
        }
    }

    /// <summary>Update the note on a bill.</summary>
    [HttpPatch("{billId:int}/note")]
    public async Task<IActionResult> UpdateNote(int billId, [FromBody] string? note)
    {
        try
        {
            await billService.UpdateNoteAsync(billId, note);
            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ex.Message);
        }
    }

    /// <summary>Soft-delete a bill.</summary>
    [HttpDelete("{billId:int}")]
    public async Task<IActionResult> DeleteBill(int billId)
    {
        try
        {
            await billService.DeleteBillAsync(billId);
            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ex.Message);
        }
    }
}
