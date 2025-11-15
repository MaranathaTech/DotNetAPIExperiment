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
│   └── run.sh                   # Local deployment script
├── Jenkinsfile                  # CI/CD pipeline for dev/prod
└── .gitignore
```

## Local Development

### Prerequisites

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

### Deploy Locally

```bash
# Deploy with default version (latest)
./scripts/run.sh

# Deploy with specific version
./scripts/run.sh v1.0.0
```

The script will:
1. Check if namespace exists (prompt to delete if needed)
2. Decrypt secrets automatically (uses `.vault` file - no prompt needed)
3. Build Docker image
4. Load image into local cluster
5. Deploy to Kubernetes
6. Wait for deployment to be ready
7. Auto-cleanup decrypted secrets

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

## Running Tests

```bash
cd app/PayloadApi.Tests
dotnet test
```

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
