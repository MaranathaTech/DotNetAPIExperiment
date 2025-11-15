# API Documentation

This folder contains the generated OpenAPI schema for PayloadApi.

## Files

- `openapi.json` - OpenAPI 3.0 specification (auto-generated)

## Generating the Schema

To regenerate the OpenAPI schema after making API changes:

```bash
./scripts/generate-openapi-schema.sh
```

This script will:
1. Build the application
2. Start it temporarily in Development mode
3. Download the OpenAPI JSON from `/openapi/v1.json`
4. Save it to `docs/openapi.json`
5. Automatically stop the application

## Using the Schema

Upload `openapi.json` to your internal API documentation server to keep the docs in sync with the actual API implementation.

## Notes

- The schema is generated from the built application, so it reflects the actual endpoints and models
- Run this script whenever you make changes to controllers, models, or API behavior
- Consider adding this to your CI/CD pipeline to automatically update docs on merge to main
