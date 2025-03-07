#!/bin/bash

# setup-full-environment.sh: Comprehensive setup for the entire local development environment
# This script runs all necessary setup steps in the correct order for a complete GitOps-based environment

set -e

# Current timestamp for logging
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Function to log step execution
log_step() {
    echo "[${TIMESTAMP}] $1: $2"
}

# Display banner
echo "=========================================================="
echo "   Complete Local Kubernetes Environment Setup"
echo "=========================================================="
echo ""
echo "This script will set up the entire local environment with GitOps:"
echo "1. Initialize Minikube cluster with the right resources"
echo "2. Set up Flux for GitOps workflow"
echo "3. Deploy core infrastructure components"
echo "4. Deploy networking components"
echo "5. Deploy observability stack"
echo "6. Deploy applications"
echo ""
echo "The setup will take 10-15 minutes to complete, depending on"
echo "your system's performance and internet connection speed."
echo ""
echo "Prerequisites:"
echo "- Docker, Minikube, kubectl, flux, helm, and GitHub CLI installed"
echo "- A GitHub Personal Access Token with repo scope access"
echo "- .env file with the necessary credentials"
echo ""

# Confirm with the user
read -p "Continue with setup? (y/N): " proceed
if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
    echo "Setup aborted."
    exit 0
fi

# Source environment variables if .env file exists
if [ -f ".env" ]; then
    source .env
    echo "✅ Environment variables loaded from .env file"
else
    echo "❌ Error: .env file not found"
    exit 1
fi

# STEP 1: Initialize the environment (Minikube)
log_step "Starting" "Environment Initialization"
./scripts/setup/init-environment.sh
log_step "Completed" "Environment Initialization"

# STEP 2: Set up GitOps with Flux
log_step "Starting" "GitOps Setup"
# Create gitops directory if it doesn't exist
mkdir -p scripts/gitops
# Make the setup-gitops.sh script executable
chmod +x scripts/gitops/setup-gitops.sh
# Run the GitOps setup script
./scripts/gitops/setup-gitops.sh
log_step "Completed" "GitOps Setup"

# STEP 3: Set up Core Infrastructure
log_step "Starting" "Core Infrastructure Setup"
./scripts/cluster/setup-core-infrastructure.sh
log_step "Completed" "Core Infrastructure Setup"

# STEP 4: Set up Networking
log_step "Starting" "Networking Setup"
./scripts/cluster/setup-networking.sh
log_step "Completed" "Networking Setup"

# STEP 5: Set up Observability
log_step "Starting" "Observability Setup"
./scripts/cluster/setup-observability.sh
log_step "Completed" "Observability Setup"

# STEP 6: Set up Applications
log_step "Starting" "Applications Setup"
./scripts/cluster/setup-applications.sh
log_step "Completed" "Applications Setup"

# STEP 7: Verify Environment
log_step "Starting" "Environment Verification"
./scripts/cluster/verify-environment.sh
log_step "Completed" "Environment Verification"

# Final message
echo "=========================================================="
echo "   Local Development Environment Setup Complete!"
echo "=========================================================="
echo ""
echo "Your local Kubernetes environment with GitOps workflow has been successfully set up."
echo ""
echo "Key components deployed:"
echo "✅ Minikube with proper resources"
echo "✅ Flux GitOps controllers"
echo "✅ Core infrastructure (cert-manager, sealed-secrets, vault)"
echo "✅ Networking (ingress-nginx, metallb)"
echo "✅ Observability (prometheus, grafana, loki)"
echo "✅ Applications (supabase)"
echo ""
echo "To access services, add the following to your /etc/hosts file:"
MINIKUBE_IP=$(minikube ip)
echo "${MINIKUBE_IP} grafana.local prometheus.local vault.local supabase.local"
echo ""
echo "For more information and troubleshooting, see:"
echo "- README.md for general usage"
echo "- docs/TROUBLESHOOTING.md for common issues"
echo "==========================================================" 