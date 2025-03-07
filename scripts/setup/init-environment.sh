#!/bin/bash

# init-environment.sh: Initialize the local environment for GitOps deployment
# This script sets up Minikube with proper resources and required addons

set -e

# Configuration
LOG_DIR="logs/setup"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/init-$(date +"%Y-%m-%d_%H-%M-%S").log"

# Function to log messages
log() {
  local message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Display banner
log "=========================================="
log "   Initializing Local Environment"
log "=========================================="
log ""

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
  log "✅ Environment variables loaded from .env file"
else
  log "⚠️ Warning: .env file not found"
  log "Creating a template .env file. Please fill in the details."
  cat > .env << EOF
# GitHub credentials for Flux GitOps
GITHUB_USER=your-github-username
GITHUB_REPO=gitops-infrastructure
GITHUB_TOKEN=your-personal-access-token

# MinIO credentials
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# Vault credentials (will be updated after deployment)
VAULT_ADDR=http://localhost:8200
VAULT_UNSEAL_KEY="Replace with actual key"
VAULT_ROOT_TOKEN="Replace with actual token"
EOF
  log "Template .env file created. Please edit it with your actual values."
  exit 1
fi

# Check if Minikube is already running
log "Checking if Minikube is already running..."
if minikube status | grep -q "Running"; then
  log "✅ Minikube is already running"
  MINIKUBE_RUNNING=true
else
  log "Minikube is not running, starting it now..."
  MINIKUBE_RUNNING=false

  # Get available memory and set a reasonable default
  SYSTEM_MEMORY=$(sysctl -n hw.memsize 2>/dev/null || free -m | awk '/^Mem:/{print $2}')
  if [ -z "$SYSTEM_MEMORY" ]; then
    # Default for macOS if sysctl fails
    MINIKUBE_MEMORY=6144
  else
    # Set to 60% of system memory (in MB), max 8GB, min 4GB
    if [[ "$SYSTEM_MEMORY" =~ ^[0-9]+$ ]]; then
      # If already in MB (from free -m)
      CALCULATED_MEMORY=$((SYSTEM_MEMORY * 60 / 100))
    else
      # If in bytes (from sysctl)
      CALCULATED_MEMORY=$((SYSTEM_MEMORY / 1024 / 1024 * 60 / 100))
    fi
    
    MINIKUBE_MEMORY=$(( CALCULATED_MEMORY < 4096 ? 4096 : (CALCULATED_MEMORY > 8192 ? 8192 : CALCULATED_MEMORY) ))
  fi
  
  # Get available CPU cores and set a reasonable default
  CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
  MINIKUBE_CPUS=$(( CPU_CORES > 8 ? 4 : (CPU_CORES / 2) ))
  MINIKUBE_CPUS=$(( MINIKUBE_CPUS < 2 ? 2 : MINIKUBE_CPUS ))
  
  log "Starting Minikube with ${MINIKUBE_CPUS} CPUs and ${MINIKUBE_MEMORY}MB memory..."
  minikube start --driver=docker --memory=${MINIKUBE_MEMORY} --cpus=${MINIKUBE_CPUS} --kubernetes-version=v1.28.3
  
  if [ $? -ne 0 ]; then
    log "❌ Failed to start Minikube. Please check the error message above."
    exit 1
  fi
  
  log "✅ Minikube started successfully"
fi

# Enable required addons
log "Enabling required Minikube addons..."
minikube addons enable ingress
minikube addons enable metrics-server
log "✅ Addons enabled"

# Verify kubectl context
log "Verifying kubectl context..."
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" = "minikube" ]; then
  log "✅ kubectl is configured to use Minikube"
else
  log "⚠️ Warning: kubectl is not using Minikube context"
  log "Current context: $CURRENT_CONTEXT"
  log "Switching to Minikube context..."
  kubectl config use-context minikube
  log "✅ Context switched to Minikube"
fi

# Check if Flux is installed
log "Checking if Flux is installed..."
if kubectl get namespace flux-system &>/dev/null; then
  log "✅ Flux is already installed"
else
  log "Installing Flux..."
  flux install
  log "✅ Flux installed"
  
  # Create Flux system secret
  log "Creating Flux credentials secret..."
  kubectl -n flux-system create secret generic flux-system \
    --from-literal=username=${GITHUB_USER} \
    --from-literal=password=${GITHUB_TOKEN} \
    --dry-run=client -o yaml | kubectl apply -f -
  
  # Create GitRepository
  log "Creating GitRepository resource..."
  flux create source git flux-system \
    --url=https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
    --branch=main \
    --username=${GITHUB_USER} \
    --password=${GITHUB_TOKEN} \
    --namespace=flux-system
  log "✅ GitRepository created"
fi

# Final status
log "=========================================="
log "   Environment Initialization Complete!"
log "=========================================="
log ""
log "Next steps:"
log "1. Run the component deployment script:"
log "   ./scripts/gitops/component-deploy.sh"
log ""
log "2. Monitor deployment progress:"
log "   ./scripts/gitops/show-progress.sh"
log ""
log "Initialization log saved to: $LOG_FILE"
log "==========================================" 