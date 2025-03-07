#!/bin/bash

# init-environment.sh: Initialize development environment for the cluster project
# This script sets up Minikube with proper resources and loads environment variables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Display banner
echo "=========================================================="
echo "   Initializing Development Environment"
echo "=========================================================="
echo ""

# Load environment variables from .env
if [ -f "${PROJECT_ROOT}/.env" ]; then
  echo "Loading environment variables from .env file..."
  source "${PROJECT_ROOT}/.env"
  
  # Verify critical environment variables
  if [[ -n "$GITHUB_USER" && -n "$GITHUB_REPO" && -n "$GITHUB_TOKEN" ]]; then
    echo "✅ GitHub credentials loaded successfully:"
    echo "  - GitHub User: $GITHUB_USER"
    echo "  - GitHub Repo: $GITHUB_REPO"
    echo "  - GitHub Token: ${GITHUB_TOKEN:0:3}...${GITHUB_TOKEN: -3}"
  else
    echo "⚠️  Warning: One or more GitHub credentials not set in .env file."
    echo "    You'll need to provide these during the setup process."
  fi
else
  echo "⚠️  Warning: .env file not found. Using default values where available."
fi

# Set Minikube parameters with defaults if not set in environment
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-6144}
MINIKUBE_CPUS=${MINIKUBE_CPUS:-4}
MINIKUBE_DISK_SIZE=${MINIKUBE_DISK_SIZE:-20g}
MINIKUBE_DRIVER=${MINIKUBE_DRIVER:-docker}

# Check if Minikube is installed
if ! command -v minikube &> /dev/null; then
  echo "❌ Error: Minikube is not installed. Please install Minikube first."
  echo "   Visit: https://minikube.sigs.k8s.io/docs/start/"
  exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo "❌ Error: kubectl is not installed. Please install kubectl first."
  echo "   Visit: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
  exit 1
fi

# Check if existing Minikube cluster exists and ask to delete
if minikube status &> /dev/null; then
  echo "⚠️  Existing Minikube cluster found."
  read -p "Do you want to delete the existing cluster and start fresh? (y/N): " delete_cluster
  
  if [[ "$delete_cluster" == "y" || "$delete_cluster" == "Y" ]]; then
    echo "Deleting existing Minikube cluster..."
    minikube delete
  else
    echo "Keeping existing Minikube cluster. Configuration may not match expected values."
  fi
fi

# Start Minikube with specified parameters if it's not running
if ! minikube status &> /dev/null; then
  echo "Starting Minikube with the following configuration:"
  echo "  - Memory: ${MINIKUBE_MEMORY}MB"
  echo "  - CPUs: ${MINIKUBE_CPUS}"
  echo "  - Disk Size: ${MINIKUBE_DISK_SIZE}"
  echo "  - Driver: ${MINIKUBE_DRIVER}"
  echo ""
  
  minikube start \
    --memory="${MINIKUBE_MEMORY}" \
    --cpus="${MINIKUBE_CPUS}" \
    --disk-size="${MINIKUBE_DISK_SIZE}" \
    --driver="${MINIKUBE_DRIVER}"
    
  echo "✅ Minikube started successfully."
else
  echo "✅ Minikube is already running."
fi

# Enable required addons
echo "Enabling required Minikube addons..."
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner
echo "✅ Addons enabled successfully."

# Verify kubectl context is set correctly
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" == "minikube" ]]; then
  echo "✅ kubectl context set to minikube."
else
  echo "⚠️  kubectl context is not set to minikube. Current context: ${CURRENT_CONTEXT}"
  read -p "Do you want to switch to minikube context? (Y/n): " switch_context
  
  if [[ "$switch_context" != "n" && "$switch_context" != "N" ]]; then
    kubectl config use-context minikube
    echo "✅ kubectl context switched to minikube."
  fi
fi

# Final verification
echo ""
echo "Verifying environment initialization:"
echo "  Minikube Status:"
minikube status
echo ""
echo "  Kubernetes Version:"
kubectl version --output=yaml | grep -A1 "clientVersion"
echo ""

# Print next steps
echo "=========================================================="
echo "   Environment Initialization Complete!"
echo "=========================================================="
echo ""
echo "Next steps:"
echo "1. Run the full setup script to deploy all components:"
echo "   ./scripts/cluster/setup-all.sh"
echo ""
echo "2. After setup, verify the environment with:"
echo "   ./scripts/cluster/verify-environment.sh"
echo ""
echo "3. To clean up the environment when you're done:"
echo "   minikube stop"
echo "==========================================================" 