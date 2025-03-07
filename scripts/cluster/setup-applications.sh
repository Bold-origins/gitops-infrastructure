#!/bin/bash

# setup-applications.sh: Sets up application components for local environment
# This script installs applications like Supabase

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Setting up Application Components"
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

# Function to check if dependencies are ready
check_dependencies() {
    echo "Checking if dependencies are ready..."
    
    # Check if networking is set up
    if ! kubectl get namespace ingress-nginx &>/dev/null || ! kubectl get pods -n ingress-nginx &>/dev/null; then
        echo "Error: ingress-nginx not found. Please run ./scripts/cluster/setup-networking.sh first."
        return 1
    fi
    
    echo "Dependencies are available."
    return 0
}

# Check if dependencies are ready
if ! check_dependencies; then
    echo "Please complete the infrastructure setup first."
    exit 1
fi

# Function to install a specific application
install_application() {
    app_name=$1
    app_namespace=$2
    
    echo "Installing ${app_name}..."
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace "${app_namespace}" &>/dev/null; then
        echo "Creating namespace ${app_namespace}..."
        kubectl create namespace "${app_namespace}"
    fi
    
    # Apply the application using kustomize
    echo "Applying ${app_name} configuration..."
    kubectl apply -k "clusters/local/applications/${app_name}"
    
    # Wait for pods to be ready
    wait_for_pods_ready "${app_namespace}"
    
    echo "${app_name} installation complete."
    echo
}

# Install Supabase
echo "Step 1/1: Setting up Supabase..."
install_application "supabase" "supabase"

# Get access information
echo "Retrieving access information..."

# Get Ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

# Final message
echo "========================================"
echo "   Application Setup Complete!"
echo "========================================"
echo ""
echo "Applications have been successfully installed:"
echo "- Supabase: PostgreSQL database and authentication services"
echo ""
echo "Access Information:"
echo "- Supabase Studio: https://supabase.local"
echo ""
echo "If you haven't already, add these entries to your /etc/hosts file:"
echo "${INGRESS_IP} supabase.local"
echo ""
echo "Complete Setup Process:"
echo "1. ✅ Minikube setup (./scripts/cluster/setup-minikube.sh)"
echo "2. ✅ Core infrastructure (./scripts/cluster/setup-core-infrastructure.sh)"
echo "3. ✅ Networking (./scripts/cluster/setup-networking.sh)"
echo "4. ✅ Observability (./scripts/cluster/setup-observability.sh)"
echo "5. ✅ Applications (./scripts/cluster/setup-applications.sh)"
echo ""
echo "For additional GitOps workflow setup:"
echo "Run './scripts/cluster/setup-flux.sh' to configure Flux"
echo "========================================" 