#!/bin/bash

# install-flux.sh - Installs and configures Flux CD for the staging environment
# This script bootstraps Flux CD and configures it to sync with the GitOps repository

set -e

# Source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "Flux CD Installation for Staging Environment"
ui_log_info "This script will install and configure Flux CD for the staging environment."

# Check if required tools are installed
ui_log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    ui_log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v flux &> /dev/null; then
    ui_log_error "flux not found. Please install the Flux CLI first."
    ui_log_info "Visit https://fluxcd.io/docs/installation/ for installation instructions."
    exit 1
fi

if ! command -v git &> /dev/null; then
    ui_log_error "git not found. Please install git first."
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

# Check if flux is already installed
ui_log_info "Checking if Flux is already installed..."
if kubectl get namespace flux-system &>/dev/null; then
  ui_log_warning "Flux appears to be already installed in the cluster."
  read -p "Do you want to continue anyway? This might reset your Flux installation. (y/n): " CONTINUE_FLUX
  if [[ "${CONTINUE_FLUX}" != "y" && "${CONTINUE_FLUX}" != "Y" ]]; then
    ui_log_info "Aborting Flux installation."
    exit 0
  fi
fi

# Get required input
ui_subheader "Git Repository Configuration"

# Get the git repository URL
REPO_ROOT="$(git rev-parse --show-toplevel)"
DEFAULT_REPO_URL=$(git config --get remote.origin.url || echo "")

if [[ -z "${DEFAULT_REPO_URL}" ]]; then
  ui_log_warning "Could not automatically detect Git repository URL."
  read -p "Enter your GitOps repository URL (e.g., git@github.com:username/repo.git): " REPO_URL
else
  ui_log_info "Detected Git repository URL: ${DEFAULT_REPO_URL}"
  read -p "Enter your GitOps repository URL (press Enter to use detected URL): " REPO_URL
  if [[ -z "${REPO_URL}" ]]; then
    REPO_URL="${DEFAULT_REPO_URL}"
  fi
fi

if [[ -z "${REPO_URL}" ]]; then
  ui_log_error "Repository URL is required."
  exit 1
fi

# Get the git branch
DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
ui_log_info "Current Git branch: ${DEFAULT_BRANCH}"
read -p "Enter the branch to use for GitOps (press Enter to use current branch): " BRANCH
if [[ -z "${BRANCH}" ]]; then
  BRANCH="${DEFAULT_BRANCH}"
fi

# Get the path within the repository for staging manifests
read -p "Enter the path within the repository for staging manifests (press Enter for 'clusters/staging'): " PATH
if [[ -z "${PATH}" ]]; then
  PATH="clusters/staging"
fi

# Confirm if using a Personal Access Token (vs. SSH key)
ui_log_info "Flux can authenticate with your Git provider using an SSH key or a Personal Access Token."
read -p "Would you like to use a Personal Access Token (PAT) for authentication? (y/n): " USE_PAT
if [[ "${USE_PAT}" == "y" || "${USE_PAT}" == "Y" ]]; then
  read -p "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
  if [[ -z "${GITHUB_TOKEN}" ]]; then
    ui_log_error "GitHub token is required when using PAT authentication."
    exit 1
  fi
  AUTH_FLAG="--token-auth"
else
  AUTH_FLAG=""
fi

# Generate the temporary flux bootstrap manifests
ui_subheader "Generating Flux Bootstrap Manifests"
ui_log_info "Generating temporary Flux bootstrap manifests..."

TEMP_DIR="$(mktemp -d)"
ui_log_info "Using temporary directory: ${TEMP_DIR}"

# Generate flux manifests
if [[ -n "${GITHUB_TOKEN}" ]]; then
  ui_log_info "Generating manifests with token authentication..."
  export GITHUB_TOKEN
  flux bootstrap github \
    --owner=$(echo "${REPO_URL}" | sed -E 's/.*[:/]([^/]+)\/[^/]+.git/\1/') \
    --repository=$(echo "${REPO_URL}" | sed -E 's/.*[:/][^/]+\/([^/]+).git/\1/') \
    --branch=${BRANCH} \
    --path=${PATH} \
    --token-auth \
    --verbose \
    --components-extra=image-reflector-controller,image-automation-controller \
    --export > "${TEMP_DIR}/flux-system.yaml"
else
  ui_log_info "Generating manifests with SSH authentication..."
  flux bootstrap github \
    --owner=$(echo "${REPO_URL}" | sed -E 's/.*[:/]([^/]+)\/[^/]+.git/\1/') \
    --repository=$(echo "${REPO_URL}" | sed -E 's/.*[:/][^/]+\/([^/]+).git/\1/') \
    --branch=${BRANCH} \
    --path=${PATH} \
    --verbose \
    --components-extra=image-reflector-controller,image-automation-controller \
    --export > "${TEMP_DIR}/flux-system.yaml"
fi

if [ ! -s "${TEMP_DIR}/flux-system.yaml" ]; then
  ui_log_error "Failed to generate Flux manifests."
  ui_log_info "Please check your repository URL and credentials."
  exit 1
fi

ui_log_success "Flux bootstrap manifests generated successfully."

# Apply the manifests to install Flux
ui_subheader "Installing Flux to Cluster"
read -p "Ready to install Flux to your cluster. Continue? (y/n): " INSTALL_FLUX

if [[ "${INSTALL_FLUX}" == "y" || "${INSTALL_FLUX}" == "Y" ]]; then
  ui_log_info "Installing Flux..."
  
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    ui_log_info "Installing Flux with token authentication..."
    export GITHUB_TOKEN
    flux bootstrap github \
      --owner=$(echo "${REPO_URL}" | sed -E 's/.*[:/]([^/]+)\/[^/]+.git/\1/') \
      --repository=$(echo "${REPO_URL}" | sed -E 's/.*[:/][^/]+\/([^/]+).git/\1/') \
      --branch=${BRANCH} \
      --path=${PATH} \
      --token-auth \
      --components-extra=image-reflector-controller,image-automation-controller
  else
    ui_log_info "Installing Flux with SSH authentication..."
    flux bootstrap github \
      --owner=$(echo "${REPO_URL}" | sed -E 's/.*[:/]([^/]+)\/[^/]+.git/\1/') \
      --repository=$(echo "${REPO_URL}" | sed -E 's/.*[:/][^/]+\/([^/]+).git/\1/') \
      --branch=${BRANCH} \
      --path=${PATH} \
      --components-extra=image-reflector-controller,image-automation-controller
  fi
  
  if [ $? -eq 0 ]; then
    ui_log_success "Flux CD has been successfully installed and configured."
  else
    ui_log_error "Flux installation failed."
    ui_log_info "Please check the error messages above and try again."
    exit 1
  fi
else
  ui_log_info "Skipping Flux installation as requested."
  ui_log_info "You can apply the generated manifests manually:"
  ui_log_info "  kubectl apply -f ${TEMP_DIR}/flux-system.yaml"
fi

# Verify Flux installation
ui_subheader "Verifying Flux Installation"
ui_log_info "Checking Flux components status..."

if kubectl get namespace flux-system &>/dev/null; then
  ui_log_success "Flux namespace exists."
  
  # Check Flux deployments
  FLUX_DEPLOYMENTS=$(kubectl get deployments -n flux-system -o jsonpath='{.items[*].metadata.name}')
  ui_log_info "Detected Flux deployments: ${FLUX_DEPLOYMENTS}"
  
  # Check if deployments are ready
  READY_DEPLOYMENTS=$(kubectl get deployments -n flux-system -o json | jq -r '.items[] | select(.status.readyReplicas == .status.replicas) | .metadata.name')
  NOT_READY=$(kubectl get deployments -n flux-system -o json | jq -r '.items[] | select(.status.readyReplicas != .status.replicas) | .metadata.name')
  
  if [[ -n "${NOT_READY}" ]]; then
    ui_log_warning "The following Flux deployments are not ready: ${NOT_READY}"
    ui_log_info "You may need to wait a few minutes for all components to be ready."
  else
    ui_log_success "All Flux deployments are ready."
  fi
  
  # Check if GitRepository resource exists
  if kubectl get gitrepositories -n flux-system &>/dev/null; then
    REPO_NAME=$(kubectl get gitrepositories -n flux-system -o jsonpath='{.items[0].metadata.name}')
    REPO_STATUS=$(kubectl get gitrepositories -n flux-system -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
    
    if [[ "${REPO_STATUS}" == "True" ]]; then
      ui_log_success "GitRepository ${REPO_NAME} is ready and synced."
    else
      ui_log_warning "GitRepository ${REPO_NAME} is not ready. Status: ${REPO_STATUS}"
      ui_log_info "Check the repository URL and credentials."
    fi
  else
    ui_log_warning "No GitRepository resources found. Flux may not be fully configured."
  fi

  # Check if Kustomization resource exists
  if kubectl get kustomizations -n flux-system &>/dev/null; then
    KUST_NAME=$(kubectl get kustomizations -n flux-system -o jsonpath='{.items[0].metadata.name}')
    KUST_STATUS=$(kubectl get kustomizations -n flux-system -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
    
    if [[ "${KUST_STATUS}" == "True" ]]; then
      ui_log_success "Kustomization ${KUST_NAME} is ready and synced."
    else
      ui_log_warning "Kustomization ${KUST_NAME} is not ready. Status: ${KUST_STATUS}"
      ui_log_info "Check the path and branch in your repository."
    fi
  else
    ui_log_warning "No Kustomization resources found. Flux may not be fully configured."
  fi
else
  ui_log_error "Flux namespace not found. Installation may have failed."
  ui_log_info "Please check for error messages during installation."
fi

# Clean up temporary files
ui_log_info "Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"

ui_header "Flux Installation Complete"
ui_log_success "Flux has been installed and configured for your staging environment."
ui_log_info "Flux will now continuously reconcile your cluster state with the Git repository."
ui_log_info "You can check the status of Flux with: flux get all -A"

exit 0 