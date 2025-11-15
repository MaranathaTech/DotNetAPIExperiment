using Asp.Versioning;
using Microsoft.AspNetCore.Mvc;
using PayloadApi.Data;
using PayloadApi.Models;
using System.ComponentModel.DataAnnotations;

namespace PayloadApi.Controllers.V2;

/// <summary>
/// Version 2 of the Payload API
/// Enhanced implementation with additional metadata and improved response format
/// </summary>
[ApiController]
[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/[controller]")]
public class PayloadController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<PayloadController> _logger;

    public PayloadController(ApplicationDbContext context, ILogger<PayloadController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Receives and stores a payload with enhanced metadata
    /// </summary>
    /// <param name="request">The payload with metadata</param>
    /// <returns>Enhanced response with full payload details</returns>
    [HttpPost]
    public async Task<IActionResult> ReceivePayload([FromBody] PayloadRequestV2 request)
    {
        _logger.LogInformation(
            "V2: Received payload request. Content length: {ContentLength}, Source: {Source}, Priority: {Priority}",
            request.Content?.Length ?? 0,
            request.Source ?? "unknown",
            request.Priority);

        if (string.IsNullOrWhiteSpace(request.Content))
        {
            _logger.LogWarning("V2: Received payload request with empty or null content");
            return BadRequest(new PayloadErrorResponse
            {
                Success = false,
                Error = new ErrorDetail
                {
                    Code = "EMPTY_CONTENT",
                    Message = "Content cannot be empty",
                    Field = "content"
                }
            });
        }

        try
        {
            var payload = new Payload
            {
                Content = request.Content,
                ReceivedAt = DateTime.UtcNow
            };

            _logger.LogDebug(
                "V2: Creating payload entity. Content: {Content}, ReceivedAt: {ReceivedAt}, Source: {Source}",
                payload.Content?.Substring(0, Math.Min(50, payload.Content?.Length ?? 0)),
                payload.ReceivedAt,
                request.Source);

            _context.Payloads.Add(payload);
            await _context.SaveChangesAsync();

            _logger.LogInformation(
                "V2: Payload saved successfully. ID: {PayloadId}, Content length: {ContentLength}, Priority: {Priority}",
                payload.Id,
                payload.Content?.Length,
                request.Priority);

            // V2 Response format (enhanced with more details)
            return Ok(new PayloadSuccessResponse
            {
                Success = true,
                Data = new PayloadData
                {
                    Id = payload.Id,
                    ContentLength = payload.Content?.Length ?? 0,
                    ReceivedAt = payload.ReceivedAt,
                    Source = request.Source ?? "unknown",
                    Priority = request.Priority
                },
                Meta = new ResponseMeta
                {
                    Version = "2.0",
                    ProcessedAt = DateTime.UtcNow
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "V2: Failed to save payload. Error: {ErrorMessage}", ex.Message);
            return StatusCode(500, new PayloadErrorResponse
            {
                Success = false,
                Error = new ErrorDetail
                {
                    Code = "SAVE_FAILED",
                    Message = "Failed to save payload",
                    Details = ex.Message
                }
            });
        }
    }
}

/// <summary>
/// V2 Request model - enhanced with metadata
/// BREAKING CHANGE from V1: Added required Source field and optional Priority
/// </summary>
public class PayloadRequestV2
{
    [Required]
    public string? Content { get; set; }

    /// <summary>
    /// Source system or application sending the payload
    /// </summary>
    public string? Source { get; set; }

    /// <summary>
    /// Priority level: low, normal, high
    /// </summary>
    public string Priority { get; set; } = "normal";
}

/// <summary>
/// V2 Success Response - structured format
/// BREAKING CHANGE from V1: Different response structure
/// </summary>
public class PayloadSuccessResponse
{
    public bool Success { get; set; }
    public PayloadData? Data { get; set; }
    public ResponseMeta? Meta { get; set; }
}

public class PayloadData
{
    public int Id { get; set; }
    public int ContentLength { get; set; }
    public DateTime ReceivedAt { get; set; }
    public string Source { get; set; } = string.Empty;
    public string Priority { get; set; } = string.Empty;
}

public class ResponseMeta
{
    public string Version { get; set; } = string.Empty;
    public DateTime ProcessedAt { get; set; }
}

/// <summary>
/// V2 Error Response - structured error format
/// </summary>
public class PayloadErrorResponse
{
    public bool Success { get; set; }
    public ErrorDetail? Error { get; set; }
}

public class ErrorDetail
{
    public string Code { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string? Field { get; set; }
    public string? Details { get; set; }
}
