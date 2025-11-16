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
COLLECTION_FILE="$PROJECT_ROOT/docs/insomnia-collection.json"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Insomnia Collection Generator${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Check if collection file exists
if [ -f "$COLLECTION_FILE" ]; then
    FILE_SIZE=$(du -h "$COLLECTION_FILE" | cut -f1)
    echo -e "${GREEN}✓ Insomnia collection file exists${NC}"
    echo -e "  Location: $COLLECTION_FILE"
    echo -e "  Size: $FILE_SIZE"
    echo ""
else
    echo -e "${RED}Error: Collection file not found at $COLLECTION_FILE${NC}"
    exit 1
fi

# Validate JSON format
if command -v jq &> /dev/null; then
    echo -e "${YELLOW}Validating JSON format...${NC}"
    if jq empty "$COLLECTION_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ JSON is valid${NC}"
    else
        echo -e "${RED}Error: Invalid JSON in collection file${NC}"
        exit 1
    fi
    echo ""
fi

# Count resources
if command -v jq &> /dev/null; then
    echo -e "${BLUE}Collection Contents:${NC}"

    WORKSPACE_COUNT=$(jq '[.resources[] | select(._type == "workspace")] | length' "$COLLECTION_FILE")
    ENVIRONMENT_COUNT=$(jq '[.resources[] | select(._type == "environment")] | length' "$COLLECTION_FILE")
    FOLDER_COUNT=$(jq '[.resources[] | select(._type == "request_group")] | length' "$COLLECTION_FILE")
    REQUEST_COUNT=$(jq '[.resources[] | select(._type == "request")] | length' "$COLLECTION_FILE")

    echo -e "  Workspaces:   $WORKSPACE_COUNT"
    echo -e "  Environments: $ENVIRONMENT_COUNT"
    echo -e "  Folders:      $FOLDER_COUNT"
    echo -e "  Requests:     $REQUEST_COUNT"
    echo ""
fi

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Collection Ready!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

echo -e "${BLUE}How to Import into Insomnia:${NC}"
echo ""
echo -e "  1. Open Insomnia"
echo -e "  2. Click 'Create' → 'Import'"
echo -e "  3. Select 'From File'"
echo -e "  4. Choose: ${YELLOW}$COLLECTION_FILE${NC}"
echo -e "  5. Click 'Scan' and 'Import'"
echo ""

echo -e "${BLUE}Available Environments:${NC}"
echo ""
echo -e "  ${GREEN}• Local Development${NC} - http://localhost:5038"
echo -e "    Use when running 'dotnet run' locally"
echo ""
echo -e "  ${GREEN}• Kubernetes Local${NC} - http://payloadapi.local"
echo -e "    Use when running in local K8s cluster"
echo ""
echo -e "  ${GREEN}• Development Cluster${NC} - https://payloadapi-dev.example.com"
echo -e "    Use for dev environment testing"
echo ""
echo -e "  ${GREEN}• Production Cluster${NC} - https://payloadapi.example.com"
echo -e "    Use for production testing"
echo ""

echo -e "${BLUE}Available Test Collections:${NC}"
echo ""
echo -e "  ${GREEN}API V1 - Legacy${NC}"
echo -e "    • POST Payload - Success"
echo -e "    • POST Payload - Long Content"
echo -e "    • POST Payload - Empty Content (Error)"
echo -e "    • POST Payload - Null Content (Error)"
echo ""
echo -e "  ${GREEN}API V2 - Enhanced${NC}"
echo -e "    • POST Payload - Success with Metadata"
echo -e "    • POST Payload - Minimal (Content Only)"
echo -e "    • POST Payload - Mobile App (High Priority)"
echo -e "    • POST Payload - Web App (Normal Priority)"
echo -e "    • POST Payload - Batch Job (Low Priority)"
echo -e "    • POST Payload - Empty Content (Error)"
echo -e "    • POST Payload - Large Content"
echo ""
echo -e "  ${GREEN}API Documentation${NC}"
echo -e "    • GET OpenAPI V1 Schema"
echo -e "    • GET OpenAPI V2 Schema"
echo ""

echo -e "${YELLOW}Note:${NC} OpenAPI endpoints are only available in Development environment"
echo -e "${YELLOW}      (when ASPNETCORE_ENVIRONMENT=Development)${NC}"
echo ""

# Offer to open the file
if command -v open &> /dev/null; then
    echo -e "${YELLOW}Would you like to open the collection file now? (y/N):${NC} "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        open "$COLLECTION_FILE"
        echo -e "${GREEN}✓ File opened${NC}"
    fi
elif command -v xdg-open &> /dev/null; then
    echo -e "${YELLOW}Would you like to open the collection file now? (y/N):${NC} "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        xdg-open "$COLLECTION_FILE"
        echo -e "${GREEN}✓ File opened${NC}"
    fi
fi

echo ""
