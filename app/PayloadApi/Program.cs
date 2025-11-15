using Asp.Versioning;
using Microsoft.EntityFrameworkCore;
using PayloadApi.Data;

var builder = WebApplication.CreateBuilder(args);

// Configure Logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

// Set log levels from configuration (appsettings.json or environment variables)
builder.Logging.SetMinimumLevel(LogLevel.Information);

// Add services to the container.
builder.Services.AddControllers();

// Configure API Versioning
builder.Services.AddApiVersioning(options =>
{
    // Report API versions in response headers
    options.ReportApiVersions = true;

    // Use default version when client doesn't specify
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.DefaultApiVersion = new ApiVersion(1, 0);

    // Support versioning via URL path (e.g., /api/v1/Payload)
    options.ApiVersionReader = new UrlSegmentApiVersionReader();
})
.AddApiExplorer(options =>
{
    // Format version as 'v'major[.minor][-status]
    options.GroupNameFormat = "'v'VVV";

    // Substitute version in route template
    options.SubstituteApiVersionInUrl = true;
});

// Add OpenAPI only in Development environment
// Generate separate OpenAPI documents for each API version
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddOpenApi("v1", options =>
    {
        options.AddDocumentTransformer((document, context, ct) =>
        {
            document.Info.Title = "PayloadApi V1";
            document.Info.Version = "1.0";
            document.Info.Description = "Original Payload API - Maintained for backward compatibility";
            return Task.CompletedTask;
        });
    });

    builder.Services.AddOpenApi("v2", options =>
    {
        options.AddDocumentTransformer((document, context, ct) =>
        {
            document.Info.Title = "PayloadApi V2";
            document.Info.Version = "2.0";
            document.Info.Description = "Enhanced Payload API with metadata support and structured responses";
            return Task.CompletedTask;
        });
    });
}

// Add HTTP request logging
builder.Services.AddHttpLogging(logging =>
{
    logging.LoggingFields = Microsoft.AspNetCore.HttpLogging.HttpLoggingFields.All;
    logging.RequestHeaders.Add("User-Agent");
    logging.RequestHeaders.Add("Content-Type");
    logging.MediaTypeOptions.AddText("application/json");
});

// Configure Database
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString)));

var app = builder.Build();

// Log application startup
var logger = app.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation("PayloadApi starting up. Environment: {Environment}", app.Environment.EnvironmentName);

// Configure the HTTP request pipeline.
// SECURITY: OpenAPI endpoint is ONLY available in Development
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi("/openapi/{documentName}.json");
    logger.LogInformation("OpenAPI documentation enabled:");
    logger.LogInformation("  - V1: /openapi/v1.json");
    logger.LogInformation("  - V2: /openapi/v2.json");
}
else
{
    logger.LogInformation("OpenAPI documentation disabled (Production/Staging mode)");
}

// Enable HTTP request logging
app.UseHttpLogging();

app.UseHttpsRedirection();

app.MapControllers();

logger.LogInformation("PayloadApi started successfully. Listening on {Urls}",
    string.Join(", ", builder.WebHost.GetSetting("urls")?.Split(';') ?? new[] { "default" }));

app.Run();
