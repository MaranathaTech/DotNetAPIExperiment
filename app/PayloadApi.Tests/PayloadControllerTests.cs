using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using PayloadApi.Controllers;
using PayloadApi.Data;
using PayloadApi.Models;

namespace PayloadApi.Tests;

public class PayloadControllerTests
{
    [Fact]
    public async Task ReceivePayload_Success_ReturnsOkWithSuccessMessage()
    {
        // Arrange - Set up the test
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase_Success")
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
    public async Task ReceivePayload_DatabaseError_Returns500WithErrorMessage()
    {
        // Arrange - Create a disposed context to simulate database error
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase_Error")
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
}
