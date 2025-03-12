#!/bin/bash

# setup-flux.sh - Installs Flux CD on a Kubernetes cluster and configures it for GitOps

set -e

# Source common libraries and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh" || { echo "Error: Failed to source common.sh"; exit 1; }

# Initialize logging
init_logging

# Validate prerequisites
check_command kubectl "Please install kubectl first: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
check_command flux "Please install Flux CLI first: https://fluxcd.io/docs/installation/"

# Default values
DEFAULT_GITHUB_USER=$(git config --get user.name 2>/dev/null || echo "")
DEFAULT_GITHUB_EMAIL=$(git config --get user.email 2>/dev/null || echo "")
DEFAULT_GITHUB_REPO="cluster"
DEFAULT_BRANCH="main"
DEFAULT_PATH="./clusters/staging"

# Parse arguments
GITHUB_USER=${GITHUB_USER:-$DEFAULT_GITHUB_USER}
GITHUB_EMAIL=${GITHUB_EMAIL:-$DEFAULT_GITHUB_EMAIL}
GITHUB_REPO=${GITHUB_REPO:-$DEFAULT_GITHUB_REPO}
BRANCH=${BRANCH:-$DEFAULT_BRANCH}
PATH_IN_REPO=${PATH_IN_REPO:-$DEFAULT_PATH}

# Ensure required environment variables are set
if [[ -z "${GITHUB_USER}" || -z "${GITHUB_EMAIL}" ]]; then
  ui_log_error "GitHub user or email not provided and could not be determined from git config"
  ui_log_info "Please set GITHUB_USER and GITHUB_EMAIL environment variables"
  exit 1
fi

# Check if GITHUB_TOKEN is set
if [[ -z "${GITHUB_TOKEN}" ]]; then
  ui_log_warning "GITHUB_TOKEN environment variable is not set."
  ui_log_info "You may need to set up a personal access token with repository permissions."
  ui_log_info "See: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token"
fi

# Display configuration
ui_log_section "Flux CD Installation Configuration"
ui_log_info "GitHub User: ${GITHUB_USER}"
ui_log_info "GitHub Email: ${GITHUB_EMAIL}"
ui_log_info "GitHub Repository: ${GITHUB_REPO}"
ui_log_info "Branch: ${BRANCH}"
ui_log_info "Path in repository: ${PATH_IN_REPO}"

# Prompt for confirmation
read -p "Do you want to continue with this configuration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  ui_log_info "Installation cancelled."
  exit 0
fi

# Check if cluster is accessible
ui_log_section "Checking cluster connection"
if ! kubectl get nodes &>/dev/null; then
  ui_log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig settings."
  exit 1
fi
ui_log_success "Successfully connected to Kubernetes cluster."

# Install Flux components
ui_log_section "Installing Flux CD components"
ui_log_info "Bootstrapping Flux on the cluster..."

# Bootstrap Flux CD using the CLI
flux bootstrap github \
  --owner="${GITHUB_USER}" \
  --repository="${GITHUB_REPO}" \
  --branch="${BRANCH}" \
  --path="${PATH_IN_REPO}" \
  --personal

ui_log_success "Flux CD installed successfully."

# Verify installation
ui_log_section "Verifying Flux installation"
if kubectl get namespace flux-system &>/dev/null; then
  ui_log_success "Flux system namespace created."
else
  ui_log_error "Flux system namespace not found. Installation may have failed."
  exit 1
fi

if kubectl get pods -n flux-system &>/dev/null; then
  ui_log_success "Flux pods are running."
else
  ui_log_error "No Flux pods found in flux-system namespace. Installation may have failed."
  exit 1
fi

# Check if controllers are ready
ui_log_section "Checking Flux controllers status"
ui_log_info "Waiting for Flux controllers to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=flux -n flux-system --timeout=2m

# Check reconciliation status
ui_log_section "Checking initial reconciliation"
ui_log_info "Checking GitRepository status..."
flux get sources git --all-namespaces

ui_log_info "Checking Kustomization status..."
flux get kustomizations --all-namespaces

ui_log_section "Flux CD Installation Complete"
ui_log_success "Flux CD has been successfully installed and configured for GitOps."
ui_log_info "Next steps:"
ui_log_info "1. Ensure your Kubernetes manifests are committed to the repository."
ui_log_info "2. Check Flux logs if you encounter issues: flux logs -n flux-system"
ui_log_info "3. Monitor reconciliation: flux get all -A"

exit 0 