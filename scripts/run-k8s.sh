#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fixed to local environment only (dev/prod use Jenkins)
ENVIRONMENT="local"
VERSION="${1:-latest}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_ROOT/secrets"
K8S_DIR="$PROJECT_ROOT/k8s/$ENVIRONMENT"
DECRYPTED_SECRETS="$SECRETS_DIR/$ENVIRONMENT.decrypted.yml"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}PayloadApi Local Deployment${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "${GREEN}Version:${NC} $VERSION"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to cleanup decrypted secrets
cleanup() {
    if [ -f "$DECRYPTED_SECRETS" ]; then
        echo -e "${YELLOW}Cleaning up decrypted secrets...${NC}"
        rm -f "$DECRYPTED_SECRETS"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${RED}Error: docker is not installed${NC}"
    exit 1
fi

if ! command_exists kubectl; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command_exists ansible-vault; then
    echo -e "${RED}Error: ansible-vault is not installed${NC}"
    echo -e "${YELLOW}Install with: pip install ansible${NC}"
    exit 1
fi

# Check if Kubernetes cluster is accessible
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}Make sure your Kubernetes cluster is running (e.g., minikube start, kind create cluster)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Decrypt secrets
ENCRYPTED_SECRETS="$SECRETS_DIR/$ENVIRONMENT.yml"
if [ ! -f "$ENCRYPTED_SECRETS" ]; then
    echo -e "${RED}Error: Secrets file not found: $ENCRYPTED_SECRETS${NC}"
    exit 1
fi

echo -e "${YELLOW}Decrypting secrets for $ENVIRONMENT environment...${NC}"

# Check if file is encrypted
if grep -q "\$ANSIBLE_VAULT" "$ENCRYPTED_SECRETS"; then
    echo ""
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}Ansible Vault Password Required${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo ""
    echo -e "${YELLOW}This is a test project. The vault password is: ${GREEN}password123${NC}"
    echo ""
    echo -e "You will be prompted to enter the password below."
    echo ""

    # Prompt for password (ansible-vault will ask for it)
    ansible-vault decrypt "$ENCRYPTED_SECRETS" --output="$DECRYPTED_SECRETS"
else
    echo -e "${YELLOW}⚠ WARNING: Secrets file is NOT encrypted!${NC}"
    cp "$ENCRYPTED_SECRETS" "$DECRYPTED_SECRETS"
fi

echo -e "${GREEN}✓ Secrets decrypted${NC}"
echo ""

# Extract values from decrypted secrets
echo -e "${YELLOW}Extracting configuration...${NC}"

# Parse YAML using grep and awk (works without yq)
CONNECTION_STRING=$(grep "^connection_string:" "$DECRYPTED_SECRETS" | sed 's/^connection_string: *"\(.*\)"/\1/')
NAMESPACE=$(grep "^namespace:" "$DECRYPTED_SECRETS" | awk '{print $2}')

if [ -z "$CONNECTION_STRING" ]; then
    echo -e "${RED}Error: Could not extract connection_string from secrets file${NC}"
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo -e "${RED}Error: Could not extract namespace from secrets file${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Configuration extracted${NC}"
echo -e "  Namespace: $NAMESPACE"
echo ""

# Check if namespace already exists
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}⚠ Namespace '$NAMESPACE' already exists${NC}"
    echo -e "${YELLOW}Do you want to delete it and redeploy? (y/N):${NC} "
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting namespace '$NAMESPACE'...${NC}"
        kubectl delete namespace "$NAMESPACE"

        echo -e "${YELLOW}Waiting for namespace to be fully deleted...${NC}"
        while kubectl get namespace "$NAMESPACE" &>/dev/null; do
            echo -n "."
            sleep 2
        done
        echo ""
        echo -e "${GREEN}✓ Namespace deleted${NC}"
    else
        echo -e "${YELLOW}Skipping deployment. Namespace will not be modified.${NC}"
        exit 0
    fi
    echo ""
fi

# Build Docker image (includes running tests)
echo -e "${YELLOW}Building Docker image and running tests...${NC}"
cd "$PROJECT_ROOT"
docker build -t payloadapi:$VERSION .
echo -e "${GREEN}✓ Docker image built and tests passed: payloadapi:$VERSION${NC}"
echo ""

# Load image into local cluster
echo -e "${YELLOW}Loading image into local Kubernetes cluster...${NC}"
if command_exists kind; then
    echo -e "${YELLOW}Loading image into kind cluster...${NC}"
    kind load docker-image payloadapi:$VERSION
    echo -e "${GREEN}✓ Image loaded into kind${NC}"
elif command_exists minikube; then
    echo -e "${YELLOW}Loading image into minikube...${NC}"
    minikube image load payloadapi:$VERSION
    echo -e "${GREEN}✓ Image loaded into minikube${NC}"
else
    echo -e "${YELLOW}⚠ Neither kind nor minikube found. Assuming image is available to cluster.${NC}"
fi
echo ""

# Check if K8s manifests directory exists
if [ ! -d "$K8S_DIR" ]; then
    echo -e "${RED}Error: K8s manifests directory not found: $K8S_DIR${NC}"
    exit 1
fi

# Create secret manifest from template
echo -e "${YELLOW}Creating Kubernetes secret manifest...${NC}"
SECRET_TEMPLATE="$K8S_DIR/secret.yml.template"
SECRET_MANIFEST="$K8S_DIR/secret.yml"

if [ -f "$SECRET_TEMPLATE" ]; then
    sed "s|CONNECTION_STRING_PLACEHOLDER|$CONNECTION_STRING|g" "$SECRET_TEMPLATE" > "$SECRET_MANIFEST"
    echo -e "${GREEN}✓ Secret manifest created${NC}"
else
    echo -e "${RED}Error: Secret template not found: $SECRET_TEMPLATE${NC}"
    exit 1
fi
echo ""

# Deploy to Kubernetes
echo -e "${YELLOW}Deploying to Kubernetes...${NC}"
kubectl apply -f "$K8S_DIR/namespace.yml"
kubectl apply -f "$K8S_DIR/serviceaccount.yml"
kubectl apply -f "$K8S_DIR/configmap.yml"
kubectl apply -f "$K8S_DIR/secret.yml"
kubectl apply -f "$K8S_DIR/deployment.yml"
kubectl apply -f "$K8S_DIR/service.yml"
kubectl apply -f "$K8S_DIR/ingress.yml"

echo -e "${GREEN}✓ All resources deployed${NC}"
echo ""

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/payloadapi -n $NAMESPACE
echo -e "${GREEN}✓ Deployment is ready${NC}"
echo ""

# Clean up generated secret manifest
rm -f "$SECRET_MANIFEST"

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

echo -e "${BLUE}Useful commands:${NC}"
echo ""
echo -e "  ${GREEN}# View all resources${NC}"
echo "  kubectl get all,ingress -n $NAMESPACE"
echo ""
echo -e "  ${GREEN}# View pods${NC}"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo -e "  ${GREEN}# View ingress${NC}"
echo "  kubectl get ingress -n $NAMESPACE"
echo ""
echo -e "  ${GREEN}# View logs${NC}"
echo "  kubectl logs -n $NAMESPACE -l app=payloadapi -f"
echo ""
echo -e "  ${GREEN}# Port forward to access locally${NC}"
echo "  kubectl port-forward -n $NAMESPACE svc/payloadapi 8080:80"
echo ""
echo -e "  ${GREEN}# Test the API (via port-forward)${NC}"
echo "  curl -X POST http://localhost:8080/api/Payload -H 'Content-Type: application/json' -d '{\"content\":\"test\"}'"
echo ""
echo -e "  ${GREEN}# Test the API (via ingress - add host to /etc/hosts first)${NC}"
echo "  # Add to /etc/hosts: 127.0.0.1 payloadapi.local"
echo "  curl -X POST http://payloadapi.local/api/Payload -H 'Content-Type: application/json' -d '{\"content\":\"test\"}'"
echo ""
echo -e "  ${GREEN}# Delete deployment${NC}"
echo "  kubectl delete namespace $NAMESPACE"
echo ""
