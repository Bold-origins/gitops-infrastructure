#!/bin/bash

# install-flux-staging.sh - Installs Flux CD on the staging cluster

set -e

# Source common libraries and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "Staging Environment Flux CD Installation"
ui_log_info "This script will install Flux CD on the staging environment cluster"

# Validate prerequisites
ui_log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    ui_log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v flux &> /dev/null; then
    ui_log_error "flux not found. Please install Flux CLI first."
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

# Set the staging-specific variables
GITHUB_OWNER=${GITHUB_OWNER:-"Bold-origins"}
GITHUB_REPO=${GITHUB_REPO:-"gitops-infrastructure"}
GITHUB_BRANCH=${GITHUB_BRANCH:-"main"}
GITHUB_PATH=${GITHUB_PATH:-"./clusters/staging"}

# Check if GITHUB_TOKEN is set
if [[ -z "${GITHUB_TOKEN}" ]]; then
  ui_log_warning "GITHUB_TOKEN environment variable is not set."
  ui_log_warning "This is required for Flux to authenticate with GitHub."
  ui_log_info "Please set the GITHUB_TOKEN environment variable with a token that has repo permissions:"
  ui_log_info "export GITHUB_TOKEN=ghp_your_token_here"
  exit 1
fi

# Display configuration
ui_subheader "Flux CD Installation Configuration"
ui_log_info "GitHub Owner: ${GITHUB_OWNER}"
ui_log_info "GitHub Repository: ${GITHUB_REPO}"
ui_log_info "GitHub Branch: ${GITHUB_BRANCH}"
ui_log_info "Path in repository: ${GITHUB_PATH}"
ui_log_info "Cluster: Staging (91.108.112.146)"

# Prompt for confirmation
read -p "Do you want to proceed with the installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  ui_log_info "Installation cancelled."
  exit 0
fi

# Install Flux components with specific components for staging
ui_subheader "Installing Flux CD components"
ui_log_info "Bootstrapping Flux on the staging cluster..."

# Bootstrap Flux CD using the CLI
flux bootstrap github \
  --owner="${GITHUB_OWNER}" \
  --repository="${GITHUB_REPO}" \
  --branch="${GITHUB_BRANCH}" \
  --path="${GITHUB_PATH}" \
  --components-extra=image-reflector-controller,image-automation-controller \
  --read-write-key

ui_log_success "Flux CD installed successfully on the staging cluster."

# Verify installation
ui_subheader "Verifying Flux installation"
if kubectl get namespace flux-system &>/dev/null; then
  ui_log_success "Flux system namespace created."
else
  ui_log_error "Flux system namespace not found. Installation may have failed."
  exit 1
fi

# Wait for controllers to be ready
ui_log_info "Waiting for Flux controllers to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=flux -n flux-system --timeout=3m

ui_subheader "Flux CD Installation Complete"
ui_log_success "Flux CD has been successfully installed on the staging cluster."

# Apply the cluster configuration
ui_subheader "Applying Staging Cluster Configuration"
ui_log_info "Creating initial GitRepository source..."

# Create the initial kustomization
kubectl apply -f - <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/staging/infrastructure
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  validation: client
  timeout: 5m
EOF

ui_log_success "Initial infrastructure kustomization created."

ui_log_info "Creating observability kustomization..."
kubectl apply -f - <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: observability
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/staging/observability
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  validation: client
  timeout: 5m
  dependsOn:
    - name: infrastructure
EOF

ui_log_success "Observability kustomization created."

ui_log_info "Creating applications kustomization..."
kubectl apply -f - <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: applications
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/staging/applications
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  validation: client
  timeout: 5m
  dependsOn:
    - name: infrastructure
    - name: observability
EOF

ui_log_success "Applications kustomization created."

# Check reconciliation status
ui_subheader "Checking initial reconciliation"
ui_log_info "Checking GitRepository status..."
flux get sources git --all-namespaces

ui_log_info "Checking Kustomization status..."
flux get kustomizations --all-namespaces

ui_header "Staging Cluster Configuration Complete"
ui_log_success "Flux CD has been successfully installed and configured for the staging environment."
ui_log_info "Next steps:"
ui_log_info "1. Monitor the GitOps reconciliation process: flux get all -A"
ui_log_info "2. Check the Flux logs for any issues: flux logs -n flux-system"
ui_log_info "3. Access the cluster components via their ingress URLs when deployed"

exit 0 