#!/bin/bash

# setup-networking.sh: Sets up networking components for local environment
# This script installs MetalLB and Ingress

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Setting up Networking Components"
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
    kubectl wait --for=condition=ready pod --all -n "${namespace}" --timeout=180s || true
    echo "Pods in namespace '${namespace}' are now ready (or timeout reached)."
}

# Function to check if core infrastructure components are ready
check_core_infrastructure() {
    echo "Checking if core infrastructure components are ready..."
    
    # Check cert-manager
    if ! kubectl get namespace cert-manager &>/dev/null || ! kubectl get pods -n cert-manager &>/dev/null; then
        echo "Error: cert-manager not found. Please run ./scripts/cluster/setup-core-infrastructure.sh first."
        return 1
    fi
    
    # Check sealed-secrets
    if ! kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets &>/dev/null; then
        echo "Error: sealed-secrets not found. Please run ./scripts/cluster/setup-core-infrastructure.sh first."
        return 1
    fi
    
    echo "Core infrastructure components are available."
    return 0
}

# Check if core infrastructure is ready
if ! check_core_infrastructure; then
    echo "Please run './scripts/cluster/setup-core-infrastructure.sh' first."
    exit 1
fi

# Step 1: Install MetalLB
echo "Step 1/2: Setting up MetalLB (Load Balancer)..."

# Create metallb-system namespace if needed
if ! kubectl get namespace metallb-system &>/dev/null; then
    kubectl create namespace metallb-system
fi

# Apply MetalLB configuration
echo "Applying MetalLB configuration..."
kubectl apply -k clusters/local/infrastructure/metallb

# Wait for MetalLB pods to be ready
wait_for_pods_ready "metallb-system"

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
MINIKUBE_IP_PREFIX=$(echo "${MINIKUBE_IP}" | sed 's/\.[0-9]*$//')

# Configure address pool if needed
if ! kubectl get configmap -n metallb-system config &>/dev/null; then
    echo "Creating MetalLB address pool configuration..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${MINIKUBE_IP_PREFIX}.200-${MINIKUBE_IP_PREFIX}.250
EOF
fi

echo "MetalLB installed successfully."
echo

# Step 2: Install Ingress
echo "Step 2/2: Setting up Ingress Controller..."

# Create ingress-nginx namespace if needed
if ! kubectl get namespace ingress-nginx &>/dev/null; then
    kubectl create namespace ingress-nginx
fi

# Apply Ingress configuration
echo "Applying Ingress configuration..."
kubectl apply -k clusters/local/infrastructure/ingress

# Wait for Ingress pods to be ready
wait_for_pods_ready "ingress-nginx"

# Get Ingress controller address
echo "Waiting for Ingress controller to get an external IP..."
INGRESS_IP=""
for i in {1..30}; do
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "${INGRESS_IP}" ]; then
        break
    fi
    echo "Waiting for Ingress IP... (attempt ${i}/30)"
    sleep 5
done

if [ -n "${INGRESS_IP}" ]; then
    echo "Ingress controller is available at ${INGRESS_IP}"
    echo "You may need to add the following to your /etc/hosts file:"
    echo "${INGRESS_IP} grafana.local prometheus.local vault.local supabase.local"
else
    echo "Warning: Ingress controller did not get an external IP. You may need to troubleshoot."
fi

echo "Ingress controller installed successfully."

# Final message
echo "========================================"
echo "   Networking Setup Complete!"
echo "========================================"
echo ""
echo "Networking components have been successfully installed:"
echo "- metallb: Load balancer implementation"
echo "- ingress-nginx: Ingress controller for external access"
echo ""
echo "Next steps:"
echo "1. Run './scripts/cluster/setup-observability.sh' to set up monitoring"
echo "2. Run './scripts/cluster/setup-applications.sh' to set up applications"
echo "========================================" 