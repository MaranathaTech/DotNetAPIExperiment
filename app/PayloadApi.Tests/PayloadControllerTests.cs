using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using PayloadApi.Controllers.V1;
using PayloadApi.Data;
using PayloadApi.Models;

namespace PayloadApi.Tests;

public class PayloadControllerTests
{
    [Fact]
    public async Task ReceivePayload_V1_Success_ReturnsOkWithSuccessMessage()
    {
        // Arrange - Set up the test
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase_V1_Success")
            .Options;

        using var context = new ApplicationDbContext(options);
        var logger = NullLogger<PayloadController>.Instance;
        var controller = new PayloadController(context, logger);
        var request = new PayloadRequest { Content = "Test payload content" };

        // Act - Execute the method we're testing
        var result = await controller.ReceivePayload(request);

        // Assert - Verify the results
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.NotNull(okResult.Value);

        // Verify payload was saved to database
        var savedPayload = await context.Payloads.FirstOrDefaultAsync();
        Assert.NotNull(savedPayload);
        Assert.Equal("Test payload content", savedPayload.Content);
    }

    [Fact]
    public async Task ReceivePayload_V1_DatabaseError_Returns500WithErrorMessage()
    {
        // Arrange - Create a disposed context to simulate database error
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase_V1_Error")
            .Options;

        var context = new ApplicationDbContext(options);
        context.Dispose(); // Dispose to cause an error when trying to save

        var logger = NullLogger<PayloadController>.Instance;
        var controller = new PayloadController(context, logger);
        var request = new PayloadRequest { Content = "Test content" };

        // Act
        var result = await controller.ReceivePayload(request);

        // Assert - Should return 500 error
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(500, objectResult.StatusCode);
    }

    // ==========================================
    // V2 API Tests
    // ==========================================

    [Fact]
    public async Task ReceivePayload_V2_Success_ReturnsEnhancedResponseWithMetadata()
    {
        // Arrange
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase_V2_Success")
            .Options;

        using var context = new ApplicationDbContext(options);
        var logger = NullLogger<Controllers.V2.PayloadController>.Instance;
        var controller = new Controllers.V2.PayloadController(context, logger);
        var request = new Controllers.V2.PayloadRequestV2
        {
            Content = "V2 test payload",
            Source = "test-client",
            Priority = "high"
        };

        // Act
        var result = await controller.ReceivePayload(request);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.NotNull(okResult.Value);

        // Verify it's a V2 structured response
        var response = okResult.Value as Controllers.V2.PayloadSuccessResponse;
        Assert.NotNull(response);
        Assert.True(response.Success);
        Assert.NotNull(response.Data);
        Assert.Equal("test-client", response.Data.Source);
        Assert.Equal("high", response.Data.Priority);
        Assert.NotNull(response.Meta);
        Assert.Equal("2.0", response.Meta.Version);

        // Verify payload was saved to database
        var savedPayload = await context.Payloads.FirstOrDefaultAsync();
        Assert.NotNull(savedPayload);
        Assert.Equal("V2 test payload", savedPayload.Content);
    }

    [Fact]
    public async Task ReceivePayload_V2_EmptyContent_ReturnsStructuredError()
    {
        // Arrange
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase_V2_EmptyContent")
            .Options;

        using var context = new ApplicationDbContext(options);
        var logger = NullLogger<Controllers.V2.PayloadController>.Instance;
        var controller = new Controllers.V2.PayloadController(context, logger);
        var request = new Controllers.V2.PayloadRequestV2
        {
            Content = "",
            Source = "test",
            Priority = "normal"
        };

        // Act
        var result = await controller.ReceivePayload(request);

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        Assert.NotNull(badRequestResult.Value);

        // Verify it's a V2 structured error response
        var response = badRequestResult.Value as Controllers.V2.PayloadErrorResponse;
        Assert.NotNull(response);
        Assert.False(response.Success);
        Assert.NotNull(response.Error);
        Assert.Equal("EMPTY_CONTENT", response.Error.Code);
        Assert.Equal("content", response.Error.Field);
    }

    [Fact]
    public async Task ReceivePayload_V2_DefaultPriority_SetsNormal()
    {
        // Arrange
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase_V2_DefaultPriority")
            .Options;

        using var context = new ApplicationDbContext(options);
        var logger = NullLogger<Controllers.V2.PayloadController>.Instance;
        var controller = new Controllers.V2.PayloadController(context, logger);
        var request = new Controllers.V2.PayloadRequestV2
        {
            Content = "Test content",
            Source = "mobile-app"
            // Priority not specified - should default to "normal"
        };

        // Act
        var result = await controller.ReceivePayload(request);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = okResult.Value as Controllers.V2.PayloadSuccessResponse;
        Assert.NotNull(response);
        Assert.Equal("normal", response.Data?.Priority);
    }

    [Fact]
    public async Task ReceivePayload_V2_DatabaseError_ReturnsStructuredError()
    {
        // Arrange
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase_V2_Error")
            .Options;

        var context = new ApplicationDbContext(options);
        context.Dispose(); // Dispose to cause an error

        var logger = NullLogger<Controllers.V2.PayloadController>.Instance;
        var controller = new Controllers.V2.PayloadController(context, logger);
        var request = new Controllers.V2.PayloadRequestV2
        {
            Content = "Test",
            Source = "test"
        };

        // Act
        var result = await controller.ReceivePayload(request);

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(500, objectResult.StatusCode);

        // Verify V2 structured error response
        var response = objectResult.Value as Controllers.V2.PayloadErrorResponse;
        Assert.NotNull(response);
        Assert.False(response.Success);
        Assert.NotNull(response.Error);
        Assert.Equal("SAVE_FAILED", response.Error.Code);
    }
}
