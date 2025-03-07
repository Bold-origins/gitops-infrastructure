#!/bin/bash

# setup-all.sh: Sets up the entire local Kubernetes environment
# This script runs all setup scripts in the correct order

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "=========================================================="
echo "   Complete Local Kubernetes Environment Setup"
echo "=========================================================="
echo ""
echo "This script will set up the entire local environment:"
echo "1. Minikube cluster"
echo "2. Core infrastructure components"
echo "3. Networking components"
echo "4. Observability stack"
echo "5. Applications"
echo ""
echo "The setup will take 10-15 minutes to complete, depending on"
echo "your system's performance and internet connection speed."
echo ""
echo "Prerequisites:"
echo "- Minikube, kubectl, helm, and kustomize installed"
echo "- At least 8GB RAM and 4 CPU cores available"
echo ""
read -p "Continue with setup? (y/N): " continue_setup

if [[ "$continue_setup" != "y" && "$continue_setup" != "Y" ]]; then
    echo "Setup aborted."
    exit 0
fi

# Create a timestamp for logging
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_DIR="logs/cluster-setup"
LOG_FILE="${LOG_DIR}/setup_${TIMESTAMP}.log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Function to log output
log_step() {
    step=$1
    echo "[$TIMESTAMP] Starting step: $step" | tee -a "${LOG_FILE}"
}

log_completion() {
    step=$1
    echo "[$TIMESTAMP] Completed step: $step" | tee -a "${LOG_FILE}"
    echo "" | tee -a "${LOG_FILE}"
}

# Step 1: Set up Minikube
log_step "Minikube Setup"
./scripts/cluster/setup-minikube.sh | tee -a "${LOG_FILE}"
log_completion "Minikube Setup"

# Step 2: Set up core infrastructure
log_step "Core Infrastructure Setup"
./scripts/cluster/setup-core-infrastructure.sh | tee -a "${LOG_FILE}"
log_completion "Core Infrastructure Setup"

# Step 3: Set up networking
log_step "Networking Setup"
./scripts/cluster/setup-networking.sh | tee -a "${LOG_FILE}"
log_completion "Networking Setup"

# Step 4: Set up observability
log_step "Observability Setup"
./scripts/cluster/setup-observability.sh | tee -a "${LOG_FILE}"
log_completion "Observability Setup"

# Step 5: Set up applications
log_step "Applications Setup"
./scripts/cluster/setup-applications.sh | tee -a "${LOG_FILE}"
log_completion "Applications Setup"

# Ask if user wants to set up Flux for GitOps
echo ""
echo "Do you want to set up Flux for GitOps workflow? (y/N): "
read -p "" setup_flux

if [[ "$setup_flux" == "y" || "$setup_flux" == "Y" ]]; then
    log_step "Flux GitOps Setup"
    ./scripts/cluster/setup-flux.sh | tee -a "${LOG_FILE}"
    log_completion "Flux GitOps Setup"
fi

# Verify setup
log_step "Environment Verification"
./scripts/cluster/verify-environment.sh | tee -a "${LOG_FILE}"
log_completion "Environment Verification"

# Get Ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

# Final message
echo "=========================================================="
echo "   Local Kubernetes Environment Setup Complete!"
echo "=========================================================="
echo ""
echo "Setup has been completed and logged to: ${LOG_FILE}"
echo ""
echo "Access your services at:"
echo "- Grafana: https://grafana.local"
echo "- Prometheus: https://prometheus.local"
echo "- Vault: https://vault.local"
echo "- Supabase: https://supabase.local"
echo ""
echo "Make sure these domains are in your /etc/hosts file:"
echo "${INGRESS_IP} grafana.local prometheus.local vault.local supabase.local"
echo ""
echo "To verify the environment's health:"
echo "./scripts/cluster/verify-environment.sh"
echo ""
echo "To stop the environment when not in use:"
echo "minikube stop"
echo ""
echo "To start the environment again:"
echo "minikube start"
echo "==========================================================" 