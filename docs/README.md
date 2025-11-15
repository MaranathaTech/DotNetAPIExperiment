# API Documentation

This folder contains the generated OpenAPI schemas for PayloadApi.

## Files

- `openapi-v1.json` - OpenAPI 3.1 specification for API V1 (auto-generated)
- `openapi-v2.json` - OpenAPI 3.1 specification for API V2 (auto-generated)

## API Versioning

The API uses **URL path versioning** to support multiple versions simultaneously:
- **V1**: `/api/v1/Payload` - Original implementation (backward compatibility)
- **V2**: `/api/v2/Payload` - Enhanced with metadata and structured responses

## Generating the Schemas

To regenerate the OpenAPI schemas after making API changes:

```bash
./scripts/generate-openapi-schema.sh
```

This script will:
1. Build the application
2. Start it temporarily in Development mode
3. Download both OpenAPI JSONs from:
   - `/openapi/v1.json`
   - `/openapi/v2.json`
4. Save them to `docs/openapi-v1.json` and `docs/openapi-v2.json`
5. Automatically stop the application

## Using the Schemas

Upload the versioned schemas to your internal API documentation server:
- Keep both versions published for existing clients
- New clients should use V2
- Deprecate V1 with a sunset date when ready

## When to Create a New Version

Create a new API version when making **breaking changes**:
- Changing request/response structure
- Removing or renaming fields
- Changing validation rules
- Modifying error response formats

Non-breaking changes (new optional fields, new endpoints) can be added to the current version.

## Notes

- Schemas are generated from the built application, so they reflect actual endpoints
- Run this script whenever you make changes to controllers, models, or API behavior
- Both versions share the same database and business logic
- Consider adding this to your CI/CD pipeline to auto-update docs on merge to main
