#!/bin/bash

# setup-core-infrastructure.sh: Sets up core infrastructure components
# This script installs essential infrastructure in the correct dependency order

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Setting up Core Infrastructure"
echo "========================================"

# Check if minikube is running
if ! minikube status &>/dev/null; then
    echo "Error: Minikube is not running. Please start Minikube first with ./scripts/cluster/setup-minikube.sh"
    exit 1
fi

# Check for kubectl
if ! command -v kubectl &>/dev/null; then
    echo "Error: kubectl not found. Please install kubectl."
    exit 1
fi

# Function to wait for pods in a namespace to be ready
wait_for_pods_ready() {
    namespace=$1
    echo "Waiting for pods in namespace '${namespace}' to be ready..."
    kubectl wait --for=condition=ready pod --all -n "${namespace}" --timeout=300s || true
    echo "Pods in namespace '${namespace}' are now ready (or timeout reached)."
}

# Function to install a component
install_component() {
    component=$1
    namespace=$2
    
    echo "Installing ${component}..."
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace "${namespace}" &>/dev/null; then
        kubectl create namespace "${namespace}"
    fi
    
    # Apply the component using kustomize
    kubectl apply -k "clusters/local/infrastructure/${component}"
    
    # Wait for pods to be ready
    wait_for_pods_ready "${namespace}"
    
    echo "${component} installed successfully."
    echo
}

# Step 1: Install cert-manager
echo "Step 1/5: Setting up cert-manager..."
install_component "cert-manager" "cert-manager"

# Step 2: Install sealed-secrets
echo "Step 2/5: Setting up sealed-secrets..."
install_component "sealed-secrets" "kube-system"

# Step 3: Install vault
echo "Step 3/5: Setting up vault..."
install_component "vault" "vault"

# Check if Vault initialization script needs to be run
if kubectl exec -n vault vault-0 -- vault status 2>/dev/null | grep -q "Sealed: true"; then
    echo "Vault needs initialization. Checking for initialization script..."
    if [ -f "scripts/components/vault-init.sh" ]; then
        echo "Running Vault initialization script..."
        ./scripts/components/vault-init.sh
    else
        echo "Warning: Vault initialization script not found. Vault may need manual initialization."
    fi
fi

# Step 4: Install gatekeeper
echo "Step 4/5: Setting up gatekeeper (OPA)..."
install_component "gatekeeper" "gatekeeper-system"

# Step 5: Install Minio
echo "Step 5/5: Setting up Minio (object storage)..."
install_component "minio" "minio"

# Final message
echo "========================================"
echo "   Core Infrastructure Setup Complete!"
echo "========================================"
echo ""
echo "Core infrastructure components have been successfully installed:"
echo "- cert-manager: Certificate management"
echo "- sealed-secrets: Encrypted Kubernetes secrets"
echo "- vault: Advanced secrets management"
echo "- gatekeeper: Policy enforcement"
echo "- minio: S3-compatible object storage"
echo ""
echo "Next steps:"
echo "1. Run './scripts/cluster/setup-networking.sh' to set up networking"
echo "2. Run './scripts/cluster/setup-observability.sh' to set up observability"
echo "3. Run './scripts/cluster/setup-applications.sh' to set up applications"
echo "========================================" 