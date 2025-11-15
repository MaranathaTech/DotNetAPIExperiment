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
dotnet build app/PayloadApi.sln -c Release > /dev/null 2>&1
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

# Download OpenAPI schemas for all versions
echo -e "${YELLOW}Downloading OpenAPI schemas...${NC}"

# Download V1 schema
OUTPUT_FILE_V1="$PROJECT_ROOT/docs/openapi-v1.json"
HTTP_STATUS_V1=$(curl -s -o "$OUTPUT_FILE_V1" -w "%{http_code}" http://localhost:5038/openapi/v1.json)

if [ "$HTTP_STATUS_V1" -eq 200 ]; then
    echo -e "${GREEN}✓ V1 schema downloaded successfully${NC}"
else
    echo -e "${RED}Error: Failed to download V1 schema (HTTP $HTTP_STATUS_V1)${NC}"
    exit 1
fi

# Download V2 schema
OUTPUT_FILE_V2="$PROJECT_ROOT/docs/openapi-v2.json"
HTTP_STATUS_V2=$(curl -s -o "$OUTPUT_FILE_V2" -w "%{http_code}" http://localhost:5038/openapi/v2.json)

if [ "$HTTP_STATUS_V2" -eq 200 ]; then
    echo -e "${GREEN}✓ V2 schema downloaded successfully${NC}"
else
    echo -e "${RED}Error: Failed to download V2 schema (HTTP $HTTP_STATUS_V2)${NC}"
    exit 1
fi

# Pretty print the JSON files (optional)
if command -v jq &> /dev/null; then
    echo -e "${YELLOW}Formatting JSON with jq...${NC}"
    jq '.' "$OUTPUT_FILE_V1" > "${OUTPUT_FILE_V1}.tmp" && mv "${OUTPUT_FILE_V1}.tmp" "$OUTPUT_FILE_V1"
    jq '.' "$OUTPUT_FILE_V2" > "${OUTPUT_FILE_V2}.tmp" && mv "${OUTPUT_FILE_V2}.tmp" "$OUTPUT_FILE_V2"
    echo -e "${GREEN}✓ JSON formatted${NC}"
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Schemas Generated Successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${BLUE}Output locations:${NC}"
echo "  V1: $OUTPUT_FILE_V1"
echo "  V2: $OUTPUT_FILE_V2"
echo ""

# Show file sizes
FILE_SIZE_V1=$(du -h "$OUTPUT_FILE_V1" | cut -f1)
FILE_SIZE_V2=$(du -h "$OUTPUT_FILE_V2" | cut -f1)
echo -e "${BLUE}File sizes:${NC}"
echo "  V1: $FILE_SIZE_V1"
echo "  V2: $FILE_SIZE_V2"
echo ""
