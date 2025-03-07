#!/bin/bash

# setup-flux.sh: Sets up Flux for GitOps workflow in the local environment
# This script initializes Flux and configures Git synchronization

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Default values if not set
GITHUB_USER=${GITHUB_USER:-""}
GITHUB_REPO=${GITHUB_REPO:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

# Display banner
echo "========================================"
echo "   Setting up Flux for GitOps Workflow"
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

# Check for flux CLI
if ! command -v flux &>/dev/null; then
    echo "Error: flux CLI not found. Please install the Flux CLI from https://fluxcd.io/docs/installation/"
    exit 1
fi

# Check if required environment variables are set
if [[ -z "$GITHUB_USER" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
    echo "Warning: GitHub credentials not fully set in environment."
    echo "You will need to manually configure Flux's Git repository access."
    
    # Ask for GitHub credentials if not set
    if [[ -z "$GITHUB_USER" ]]; then
        read -p "Enter your GitHub username: " GITHUB_USER
    fi
    
    if [[ -z "$GITHUB_REPO" ]]; then
        read -p "Enter your GitHub repository name: " GITHUB_REPO
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        read -sp "Enter your GitHub personal access token: " GITHUB_TOKEN
        echo
    fi
fi

# Check if flux-system namespace exists
if kubectl get namespace flux-system &>/dev/null; then
    echo "Flux system namespace already exists. Checking if Flux is already installed..."
    
    if kubectl get -n flux-system deployment/source-controller &>/dev/null; then
        echo "Flux appears to be already installed. Do you want to reinstall? (y/N)"
        read -r reinstall
        
        if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
            echo "Skipping Flux installation. You can manually upgrade with 'flux upgrade'."
            exit 0
        else
            echo "Reinstalling Flux..."
            kubectl delete namespace flux-system
            # Wait for namespace to be fully deleted
            until ! kubectl get namespace flux-system &>/dev/null; do
                echo "Waiting for flux-system namespace to be deleted..."
                sleep 5
            done
        fi
    fi
fi

# Install Flux if GitHub credentials are provided
if [[ -n "$GITHUB_USER" && -n "$GITHUB_REPO" && -n "$GITHUB_TOKEN" ]]; then
    echo "Setting up Flux with repository: ${GITHUB_USER}/${GITHUB_REPO}"
    
    # Secure debug output to verify values
    echo "Repository owner: ${GITHUB_USER}"
    echo "Repository name: ${GITHUB_REPO}"
    echo "Repository token: ${GITHUB_TOKEN:0:3}...${GITHUB_TOKEN: -3}" # Show only first and last 3 chars
    
    # Bootstrap Flux with the GitHub repository
    echo "Running bootstrap command..."
    flux bootstrap github \
        --owner="${GITHUB_USER}" \
        --repository="${GITHUB_REPO}" \
        --branch=main \
        --path=clusters/local \
        --personal \
        --token-auth \
        --token="${GITHUB_TOKEN}" \
        --components-extra=image-reflector-controller,image-automation-controller || true  # Continue on error
    
    # Verify if GitRepository was created, create it manually if not
    echo "Verifying GitRepository resource..."
    if ! kubectl get gitrepository -n flux-system flux-system &>/dev/null; then
        echo "GitRepository not created by bootstrap. Creating manually..."
        
        # Create namespace if it doesn't exist
        if ! kubectl get namespace flux-system &>/dev/null; then
            kubectl create namespace flux-system
        fi
        
        # Create secret for repository access
        kubectl -n flux-system create secret generic flux-system \
            --from-literal=username=${GITHUB_USER} \
            --from-literal=password=${GITHUB_TOKEN} \
            --dry-run=client -o yaml | kubectl apply -f -
        
        # Create GitRepository resource
        flux create source git flux-system \
            --url=https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
            --branch=main \
            --username=${GITHUB_USER} \
            --password=${GITHUB_TOKEN} \
            --namespace=flux-system \
            --secret-ref=flux-system
        
        echo "GitRepository manually created."
    else
        echo "GitRepository resource exists."
    fi
else
    echo "Installing Flux without Git repository configuration..."
    flux install
    
    echo "Note: You will need to manually configure the Git repository for Flux."
    echo "Example command:"
    echo "flux create source git flux-system \\"
    echo "  --url=https://github.com/your-username/your-repo \\"
    echo "  --branch=main \\"
    echo "  --username=your-username \\"
    echo "  --password=your-token"
fi

# Wait for Flux to be ready
echo "Waiting for Flux controllers to be ready..."
kubectl -n flux-system wait --for=condition=ready pod --all --timeout=180s

# Apply the flux-kustomization.yaml if it exists
if [ -f "clusters/local/flux-kustomization.yaml" ]; then
    echo "Applying Flux kustomization configuration..."
    kubectl apply -f clusters/local/flux-kustomization.yaml
fi

# Final message
echo "========================================"
echo "   Flux GitOps Setup Complete!"
echo "========================================"
echo ""
echo "Flux has been successfully installed and configured for GitOps workflow."
echo ""
echo "To check Flux status:"
echo "  flux check"
echo ""
echo "To view Flux resources:"
echo "  flux get all"
echo ""
echo "To trigger a manual reconciliation:"
echo "  flux reconcile source git flux-system"
echo "  flux reconcile kustomization flux-system"
echo ""
echo "To view logs:"
echo "  flux logs"
echo ""
echo "For more Flux commands, see: https://fluxcd.io/docs/cmd/"
echo "========================================" 