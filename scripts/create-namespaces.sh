#!/bin/bash

# create-namespaces.sh - Creates all necessary namespaces for the staging environment
# This script ensures all required namespaces exist before deploying components

set -e

# Source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "Creating Namespaces for Staging Environment"
ui_log_info "This script will ensure all necessary namespaces exist for the staging environment"

# Check if required tools are installed
ui_log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    ui_log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check cluster connection
ui_log_info "Checking connection to staging cluster..."
if ! kubectl get nodes &>/dev/null; then
  ui_log_error "Cannot connect to the staging cluster. Please check your kubeconfig."
  ui_log_info "Make sure you're connected to the correct cluster context."
  exit 1
fi

ui_log_success "Successfully connected to the staging cluster."

# Define the namespaces to create
# Format: "namespace:description:label"
NAMESPACES=(
    "flux-system:Flux GitOps system:tier=system"
    "metallb-system:MetalLB load balancer:tier=infrastructure"
    "gatekeeper-system:OPA Gatekeeper policy engine:tier=infrastructure"
    "sealed-secrets:Sealed Secrets controller:tier=infrastructure"
    "vault:HashiCorp Vault secrets management:tier=infrastructure"
    "cert-manager:Certificate management:tier=infrastructure"
    "minio:MinIO object storage:tier=infrastructure"
    "monitoring:Monitoring tools (Prometheus, Grafana):tier=observability"
    "loki:Loki logging system:tier=observability"
    "tempo:Tempo tracing system:tier=observability"
    "supabase:Supabase database platform:tier=applications"
    "security:Security tools:tier=infrastructure"
)

ui_subheader "Creating Namespaces"

# Function to create namespace with labels
create_namespace() {
    local namespace=$1
    local description=$2
    local labels=$3
    
    if ! kubectl get namespace "$namespace" &>/dev/null; then
        ui_log_info "Creating namespace: $namespace ($description)"
        
        # Create the namespace with labels
        kubectl create namespace "$namespace"
        
        # Add environment=staging label
        kubectl label namespace "$namespace" environment=staging
        
        # Add any additional labels
        if [[ -n "$labels" ]]; then
            IFS=',' read -ra LABEL_ARRAY <<< "$labels"
            for label in "${LABEL_ARRAY[@]}"; do
                kubectl label namespace "$namespace" "$label"
            done
        fi
        
        ui_log_success "Created namespace: $namespace"
    else
        ui_log_info "Namespace $namespace already exists"
        
        # Ensure the environment label exists
        if ! kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.environment}' | grep -q "staging"; then
            ui_log_info "Adding environment=staging label to namespace $namespace"
            kubectl label namespace "$namespace" environment=staging --overwrite
        fi
        
        # Add any additional labels if they don't exist
        if [[ -n "$labels" ]]; then
            IFS=',' read -ra LABEL_ARRAY <<< "$labels"
            for label in "${LABEL_ARRAY[@]}"; do
                key=$(echo "$label" | cut -d= -f1)
                if ! kubectl get namespace "$namespace" -o jsonpath="{.metadata.labels.$key}" &>/dev/null; then
                    ui_log_info "Adding $label label to namespace $namespace"
                    kubectl label namespace "$namespace" "$label"
                fi
            done
        fi
    fi
}

# Create all namespaces
for ns_info in "${NAMESPACES[@]}"; do
    IFS=':' read -ra PARTS <<< "$ns_info"
    namespace="${PARTS[0]}"
    description="${PARTS[1]}"
    labels="${PARTS[2]}"
    
    create_namespace "$namespace" "$description" "$labels"
done

ui_log_success "All namespaces created/verified"

# Display summary of namespaces
ui_subheader "Namespace Summary"
kubectl get namespaces -l environment=staging

ui_header "Namespace Creation Complete"
ui_log_success "All necessary namespaces have been created for the staging environment."
ui_log_info "You can now deploy components to these namespaces."

exit 0 