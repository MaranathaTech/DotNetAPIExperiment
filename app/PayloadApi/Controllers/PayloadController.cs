using Microsoft.AspNetCore.Mvc;
using PayloadApi.Data;
using PayloadApi.Models;

namespace PayloadApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PayloadController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<PayloadController> _logger;

    public PayloadController(ApplicationDbContext context, ILogger<PayloadController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpPost]
    public async Task<IActionResult> ReceivePayload([FromBody] PayloadRequest request)
    {
        _logger.LogInformation("Received payload request. Content length: {ContentLength}",
            request.Content?.Length ?? 0);

        if (string.IsNullOrWhiteSpace(request.Content))
        {
            _logger.LogWarning("Received payload request with empty or null content");
            return BadRequest(new { success = false, message = "Content cannot be empty" });
        }

        try
        {
            var payload = new Payload
            {
                Content = request.Content,
                ReceivedAt = DateTime.UtcNow
            };

            _logger.LogDebug("Creating payload entity. Content: {Content}, ReceivedAt: {ReceivedAt}",
                payload.Content?.Substring(0, Math.Min(50, payload.Content?.Length ?? 0)),
                payload.ReceivedAt);

            _context.Payloads.Add(payload);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Payload saved successfully. ID: {PayloadId}, Content length: {ContentLength}",
                payload.Id, payload.Content?.Length);

            return Ok(new { success = true, message = "Payload saved successfully", id = payload.Id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save payload. Error: {ErrorMessage}", ex.Message);
            return StatusCode(500, new { success = false, message = "Failed to save payload", error = ex.Message });
        }
    }
}

public class PayloadRequest
{
    public string? Content { get; set; }
}
