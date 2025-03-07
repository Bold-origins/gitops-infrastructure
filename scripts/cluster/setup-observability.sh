#!/bin/bash

# setup-observability.sh: Sets up observability stack for local environment
# This script installs Prometheus, Grafana, Loki, and OpenTelemetry

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Setting up Observability Stack"
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
    
    # Check ingress-nginx
    if ! kubectl get namespace ingress-nginx &>/dev/null || ! kubectl get pods -n ingress-nginx &>/dev/null; then
        echo "Error: ingress-nginx not found. Please run ./scripts/cluster/setup-networking.sh first."
        return 1
    fi
    
    echo "Dependencies are available."
    return 0
}

# Check if dependencies are ready
if ! check_dependencies; then
    echo "Please run './scripts/cluster/setup-networking.sh' first."
    exit 1
fi

# Step 1: Create observability namespace if it doesn't exist
echo "Creating observability namespace..."
if ! kubectl get namespace observability &>/dev/null; then
    kubectl create namespace observability
fi

# Step 2: Install Prometheus
echo "Step 1/4: Setting up Prometheus..."
kubectl apply -k clusters/local/observability/prometheus
wait_for_pods_ready "observability"
echo "Prometheus setup complete."
echo

# Step 3: Install Grafana
echo "Step 2/4: Setting up Grafana..."
kubectl apply -k clusters/local/observability/grafana
wait_for_pods_ready "observability"
echo "Grafana setup complete."
echo

# Step 4: Install Loki
echo "Step 3/4: Setting up Loki (Log Aggregation)..."
kubectl apply -k clusters/local/observability/loki
wait_for_pods_ready "observability"
echo "Loki setup complete."
echo

# Step 5: Install OpenTelemetry
echo "Step 4/4: Setting up OpenTelemetry (Distributed Tracing)..."
kubectl apply -k clusters/local/observability/opentelemetry
wait_for_pods_ready "observability"
echo "OpenTelemetry setup complete."
echo

# Install common resources and networking monitoring
echo "Setting up additional observability components..."
kubectl apply -k clusters/local/observability/common
kubectl apply -k clusters/local/observability/network

# Display access information
echo "Retrieving access information..."

# Get Ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

# Get Grafana admin password
GRAFANA_ADMIN_PASSWORD=""
if kubectl get secret -n observability grafana-admin-credentials &>/dev/null; then
    GRAFANA_ADMIN_PASSWORD=$(kubectl get secret -n observability grafana-admin-credentials -o jsonpath="{.data.admin-password}" | base64 --decode)
fi

# Final message
echo "========================================"
echo "   Observability Stack Setup Complete!"
echo "========================================"
echo ""
echo "The observability stack has been successfully installed:"
echo "- Prometheus: Metrics collection"
echo "- Grafana: Visualization and dashboards"
echo "- Loki: Log aggregation"
echo "- OpenTelemetry: Distributed tracing"
echo ""
echo "Access Information:"
echo "- Grafana: https://grafana.local"
if [ -n "${GRAFANA_ADMIN_PASSWORD}" ]; then
    echo "  Username: admin"
    echo "  Password: ${GRAFANA_ADMIN_PASSWORD}"
else
    echo "  (Credentials stored in 'grafana-admin-credentials' secret)"
fi
echo "- Prometheus: https://prometheus.local"
echo ""
echo "If you haven't already, add these entries to your /etc/hosts file:"
echo "${INGRESS_IP} grafana.local prometheus.local"
echo ""
echo "Next steps:"
echo "1. Run './scripts/cluster/setup-applications.sh' to set up applications"
echo "2. Explore the observability dashboards at https://grafana.local"
echo "========================================" 