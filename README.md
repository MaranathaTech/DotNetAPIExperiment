# PayloadApi

A .NET Core REST API that receives payloads and stores them in MySQL.

## Project Structure

```
.
├── app/
│   ├── PayloadApi/              # Main API project
│   └── PayloadApi.Tests/        # Unit tests
├── k8s/                         # Kubernetes manifests
│   ├── local/                   # Local environment
│   ├── dev/                     # Dev environment
│   └── prod/                    # Production environment
├── secrets/                     # Encrypted secrets (use ansible-vault)
│   ├── local.yml
│   ├── dev.yml
│   └── prod.yml
├── scripts/
│   ├── run-k8s.sh               # Local Kubernetes deployment script
│   └── generate-openapi-schema.sh
├── Dockerfile                   # Multi-stage build with tests
├── .dockerignore                # Docker build exclusions
├── PayloadApi.sln               # Solution file
├── Jenkinsfile                  # CI/CD pipeline for dev/prod
└── .gitignore
```

## Local Development

You can run the API either **directly with .NET** (fastest for development) or **via Kubernetes** (production-like environment).

### Quick Start - Run Directly with .NET

**Prerequisites:**
- .NET 10.0 SDK
- MySQL running locally (or update connection string in appsettings.json)

**Steps:**

```bash
# Navigate to the API project
cd app/PayloadApi

# Run the application
dotnet run

# Or run with watch mode (auto-restart on file changes)
dotnet watch run
```

The API will start on `http://localhost:5038` (configured in `Properties/launchSettings.json`).

**Test it:**
```bash
# V1 endpoint
curl -X POST http://localhost:5038/api/v1/Payload \
  -H 'Content-Type: application/json' \
  -d '{"content":"test payload"}'

# V2 endpoint
curl -X POST http://localhost:5038/api/v2/Payload \
  -H 'Content-Type: application/json' \
  -d '{"content":"test","source":"curl","priority":"high"}'
```

**OpenAPI docs (Development only):**
- V1: http://localhost:5038/openapi/v1.json
- V2: http://localhost:5038/openapi/v2.json

### Kubernetes Deployment (Production-like)

**Prerequisites:**
- Docker
- kubectl
- ansible-vault (from ansible package)
- Local Kubernetes cluster (kind or minikube)
- NGINX Ingress Controller

### Setup NGINX Ingress (one-time)

**For kind:**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

**For minikube:**
```bash
minikube addons enable ingress
```

### Secrets Configuration

The project includes a `.vault` file containing the vault password (`password123`). This file is **gitignored** for security.

**Secrets are already encrypted** with ansible-vault. To view or edit them:

```bash
# View encrypted secret
ansible-vault view secrets/local.yml --vault-password-file=.vault

# Edit encrypted secret
ansible-vault edit secrets/local.yml --vault-password-file=.vault

# Decrypt to file (not recommended - auto-cleaned by deployment)
ansible-vault decrypt secrets/local.yml --output=secrets/local.decrypted.yml --vault-password-file=.vault
```

**To re-encrypt secrets** (if you need to change them):

```bash
# Edit the secret (decrypts, opens editor, re-encrypts on save)
ansible-vault edit secrets/local.yml --vault-password-file=.vault
```

### Deploy to Local Kubernetes

```bash
# Deploy with default version (latest)
./scripts/run-k8s.sh

# Deploy with specific version
./scripts/run-k8s.sh v1.0.0
```

The script will:
1. Check if namespace exists (prompt to delete if needed)
2. Decrypt secrets automatically (uses `.vault` file - no prompt needed)
3. **Build Docker image and run all tests** (build fails if tests fail)
4. Load image into local cluster
5. Deploy to Kubernetes
6. Wait for deployment to be ready
7. Auto-cleanup decrypted secrets

**Note:** The Docker build includes running all unit tests. The image will only be created if all tests pass!

### Access the API

**Via Port Forward:**
```bash
kubectl port-forward -n payloadapi-local svc/payloadapi 8080:80

curl -X POST http://localhost:8080/api/Payload \
  -H 'Content-Type: application/json' \
  -d '{"content":"test"}'
```

**Via Ingress:**
```bash
# Add to /etc/hosts
echo "127.0.0.1 payloadapi.local" | sudo tee -a /etc/hosts

# Test
curl -X POST http://payloadapi.local/api/Payload \
  -H 'Content-Type: application/json' \
  -d '{"content":"test"}'
```

### Useful Commands

```bash
# View all resources
kubectl get all,ingress -n payloadapi-local

# View logs
kubectl logs -n payloadapi-local -l app=payloadapi -f

# Delete deployment
kubectl delete namespace payloadapi-local
```

## Dev/Prod Deployment (Jenkins)

For dev and prod environments, use the Jenkins pipeline.

### Jenkins Setup

Configure these credentials in Jenkins:

1. **ansible-vault-password** (Secret file)
   - Upload your vault password file

2. **kubeconfig-dev** (Secret file)
   - Upload your dev cluster kubeconfig

3. **kubeconfig-prod** (Secret file)
   - Upload your prod cluster kubeconfig

4. **docker-registry-url** (Secret text)
   - Your Docker registry URL (e.g., `registry.example.com`)

5. **docker-registry-credentials** (Username/Password)
   - Docker registry username and password

### Deploy via Jenkins

1. Go to your Jenkins pipeline
2. Click "Build with Parameters"
3. Select:
   - **ENVIRONMENT**: `dev` or `prod`
   - **VERSION**: Docker image tag (e.g., `v1.0.0` or `latest`)
4. Click "Build"

The Jenkinsfile will:
1. Checkout code
2. Decrypt secrets for the selected environment
3. Build Docker image
4. Push to Docker registry
5. Deploy to Kubernetes cluster
6. Verify deployment

### Environment Configurations

**Local:**
- 1 replica
- Debug logging
- 256Mi-512Mi memory
- Host: `payloadapi.local`

**Dev:**
- 2 replicas
- Information logging
- 256Mi-512Mi memory
- Host: `payloadapi-dev.example.com`

**Prod:**
- 3 replicas
- Warning logging
- 512Mi-1Gi memory
- Host: `payloadapi.example.com`
- SSL redirect enabled

## API Versioning

The API uses **URL path versioning** to support multiple versions simultaneously, allowing breaking changes while maintaining backward compatibility for existing clients.

### Current Versions

**V1** - `/api/v1/Payload`
- Original implementation
- Simple request/response format
- Maintained for backward compatibility

**V2** - `/api/v2/Payload`
- Enhanced with metadata (source, priority)
- Structured error responses
- Recommended for new clients

### Creating a New Version

When you need to make **breaking changes** (changing request/response structure, removing fields, etc.):

1. Create a new controller in `Controllers/V{N}/`
2. Add `[ApiVersion("{N}.0")]` attribute
3. Implement your changes
4. Update the OpenAPI configuration in `Program.cs`
5. Generate new schemas with the script

**Example: Creating V3**

```csharp
namespace PayloadApi.Controllers.V3;

[ApiController]
[ApiVersion("3.0")]
[Route("api/v{version:apiVersion}/[controller]")]
public class PayloadController : ControllerBase
{
    // Your V3 implementation with breaking changes
}
```

Then add to `Program.cs`:
```csharp
builder.Services.AddOpenApi("v3", options => { /* ... */ });
```

### Versioning Best Practices

- **Breaking changes** → New version
- **Non-breaking changes** (new optional fields, new endpoints) → Add to current version
- Keep old versions running until all clients migrate
- Set a **deprecation date** for old versions
- Document changes between versions clearly

## API Documentation

The project generates OpenAPI 3.1 schemas for each API version for integration with your internal API documentation server.

### Generate OpenAPI Schemas

```bash
./scripts/generate-openapi-schema.sh
```

This will:
- Build the application
- Start it temporarily
- Download OpenAPI JSONs from `/openapi/v1.json` and `/openapi/v2.json`
- Save them to `docs/openapi-v1.json` and `docs/openapi-v2.json`
- Automatically stop the application

**Output:** `docs/openapi-v1.json` and `docs/openapi-v2.json` - Ready to upload to your API docs server

### When to Regenerate

Run the schema generator whenever you:
- Add new endpoints
- Modify existing endpoints
- Change request/response models
- Update API documentation
- Create a new API version

## Running Tests

Tests are automatically run during Docker image build. You can also run them manually:

```bash
# Run all tests in the solution
dotnet test

# Run tests for specific project
dotnet test app/PayloadApi.Tests/PayloadApi.Tests.csproj

# Run tests with detailed output
dotnet test --verbosity detailed
```

**Important:** Docker builds will fail if any tests fail, ensuring only tested code gets deployed!

## Logging

The application has comprehensive structured logging configured:

### Log Levels by Environment

**Development** (`appsettings.Development.json`):
- Application logs: `Debug`
- HTTP requests: `Information`
- Database commands: `Information`
- ASP.NET Core: `Information`

**Production** (configured in K8s ConfigMaps):
- Application logs: `Information` (local), `Warning` (prod)
- HTTP requests: `Information`
- Database commands: `Warning`
- ASP.NET Core: `Warning`

### What Gets Logged

**Controller Level:**
- ✅ Every incoming request with content length
- ✅ Validation warnings (empty content)
- ✅ Successful saves with payload ID
- ✅ Errors with full exception details and stack trace

**HTTP Request Logging:**
- ✅ Request method, path, status code
- ✅ Request/response headers (User-Agent, Content-Type)
- ✅ Request/response body for JSON
- ✅ Request duration

**Application Lifecycle:**
- ✅ Startup with environment name
- ✅ Configuration loaded
- ✅ OpenAPI enabled (dev only)

### Viewing Logs in Kubernetes

```bash
# Follow logs in real-time
kubectl logs -n payloadapi-local -l app=payloadapi -f

# View logs from specific pod
kubectl logs -n payloadapi-local <pod-name>

# View logs with timestamps
kubectl logs -n payloadapi-local -l app=payloadapi --timestamps=true

# View last 100 lines
kubectl logs -n payloadapi-local -l app=payloadapi --tail=100
```

### Log Format

Logs are output as structured JSON for easy parsing:
```json
{
  "Timestamp": "2025-01-14 12:34:56",
  "Level": "Information",
  "Category": "PayloadApi.Controllers.PayloadController",
  "Message": "Payload saved successfully. ID: 123, Content length: 45"
}
```

## Security Notes

- **Never commit unencrypted secrets** - Always use `ansible-vault encrypt`
- **Decrypted files are auto-cleaned** - The deployment script removes them automatically
- **Generated K8s secrets are gitignored** - `k8s/**/secret.yml` (not `.template`)
- **RBAC is configured** - Pods have minimal permissions via ServiceAccount

## Troubleshooting

**"Cannot connect to Kubernetes cluster"**
- Ensure your cluster is running: `minikube start` or `kind create cluster`

**"ansible-vault not found"**
- Install ansible: `pip install ansible`

**Ingress not working**
- Ensure NGINX Ingress Controller is installed (see prerequisites)
- Check ingress status: `kubectl get ingress -n payloadapi-local`

**Namespace already exists**
- The script will prompt you to delete it
- Or manually delete: `kubectl delete namespace payloadapi-local`
