# Build and Test stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy solution file
COPY app/PayloadApi.sln .

# Copy project files
COPY app/PayloadApi/PayloadApi.csproj app/PayloadApi/
COPY app/PayloadApi.Tests/PayloadApi.Tests.csproj app/PayloadApi.Tests/

# Restore dependencies for all projects
RUN dotnet restore

# Copy all source code
COPY app/ app/

# Build the solution
RUN dotnet build -c Release --no-restore

# Run tests - build will fail if tests fail
RUN dotnet test app/PayloadApi.Tests/PayloadApi.Tests.csproj \
    -c Release \
    --no-build \
    --verbosity normal \
    --logger "console;verbosity=detailed"

# Publish the API project
RUN dotnet publish app/PayloadApi/PayloadApi.csproj \
    -c Release \
    --no-build \
    -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy published app from build stage
COPY --from=build /app/publish .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Set environment variable for ASP.NET to listen on 8080
ENV ASPNETCORE_URLS=http://+:8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Run the application
ENTRYPOINT ["dotnet", "PayloadApi.dll"]
