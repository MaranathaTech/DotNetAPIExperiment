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

// Add OpenAPI only in Development environment
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddOpenApi();
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
    app.MapOpenApi();
    logger.LogInformation("OpenAPI documentation enabled at /openapi/v1.json");
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
