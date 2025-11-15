#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_PROJECT="$PROJECT_ROOT/app/PayloadApi"
OUTPUT_FILE="$PROJECT_ROOT/docs/openapi.json"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}OpenAPI Schema Generator${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Build the project
echo -e "${YELLOW}Building PayloadApi...${NC}"
cd "$PROJECT_ROOT"
dotnet build PayloadApi.sln -c Release > /dev/null 2>&1
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Run the API in the background
echo -e "${YELLOW}Starting API temporarily...${NC}"
cd "$API_PROJECT"

# Set environment to Development so OpenAPI endpoint is enabled
export ASPNETCORE_ENVIRONMENT=Development
export ASPNETCORE_URLS=http://localhost:5038

# Start the app in background and capture PID
dotnet run --no-build -c Release > /dev/null 2>&1 &
API_PID=$!

echo -e "${GREEN}✓ API started (PID: $API_PID)${NC}"

# Function to cleanup on exit
cleanup() {
    if kill -0 $API_PID 2>/dev/null; then
        echo ""
        echo -e "${YELLOW}Stopping API...${NC}"
        kill $API_PID 2>/dev/null || true
        wait $API_PID 2>/dev/null || true
        echo -e "${GREEN}✓ API stopped${NC}"
    fi
}

# Set trap to cleanup on exit or interrupt
trap cleanup EXIT INT TERM

# Wait for API to start
echo -e "${YELLOW}Waiting for API to start...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:5038/openapi/v1.json > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: API failed to start within 30 seconds${NC}"
        exit 1
    fi
    sleep 1
done
echo ""

# Download OpenAPI schema
echo -e "${YELLOW}Downloading OpenAPI schema...${NC}"
HTTP_STATUS=$(curl -s -o "$OUTPUT_FILE" -w "%{http_code}" http://localhost:5038/openapi/v1.json)

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo -e "${GREEN}✓ Schema downloaded successfully${NC}"
else
    echo -e "${RED}Error: Failed to download schema (HTTP $HTTP_STATUS)${NC}"
    exit 1
fi

# Pretty print the JSON (optional)
if command -v jq &> /dev/null; then
    echo -e "${YELLOW}Formatting JSON with jq...${NC}"
    jq '.' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
    echo -e "${GREEN}✓ JSON formatted${NC}"
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Schema Generated Successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Output location:${NC}"
echo "  $OUTPUT_FILE"
echo ""

# Show file size
FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
echo -e "${BLUE}File size:${NC} $FILE_SIZE"
echo ""

# Show a preview of the schema
echo -e "${BLUE}Preview (first 10 lines):${NC}"
head -n 10 "$OUTPUT_FILE"
echo "..."
echo ""
