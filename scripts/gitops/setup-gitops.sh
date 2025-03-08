#!/bin/bash

# setup-gitops.sh: A comprehensive script to set up the GitOps workflow
# This script ensures proper setup of Flux, creates necessary resources,
# and validates the configuration for the cluster

set -e

# Display banner
echo "=========================================="
echo "   Setting up GitOps with Flux"
echo "=========================================="
echo ""

# Source environment variables if .env file exists
if [ -f ".env" ]; then
    source .env
    echo "✅ Environment variables loaded from .env file"
else
    echo "❌ Error: .env file not found"
    exit 1
fi

# Check prerequisites
echo "Checking prerequisites..."

# Check if minikube is running
if ! minikube status &>/dev/null; then
    echo "❌ Error: Minikube is not running. Please start Minikube first with:"
    echo "   ./scripts/setup/init-environment.sh"
    exit 1
fi

# Check for kubectl
if ! command -v kubectl &>/dev/null; then
    echo "❌ Error: kubectl not found. Please install kubectl."
    exit 1
fi

# Check for flux CLI
if ! command -v flux &>/dev/null; then
    echo "❌ Error: flux CLI not found. Please install the Flux CLI from:"
    echo "   https://fluxcd.io/docs/installation/"
    exit 1
fi

# Check for GitHub CLI
if ! command -v gh &>/dev/null; then
    echo "❌ Error: GitHub CLI not found. Please install the GitHub CLI from:"
    echo "   https://cli.github.com/manual/installation"
    exit 1
fi

# Verify GitHub credentials
echo "Verifying GitHub credentials..."

# Check if GitHub credentials are set
if [[ -z "$GITHUB_USER" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
    echo "❌ Error: GitHub credentials not fully set in .env file."
    echo "Please update the .env file with your GitHub username, repository, and token."
    exit 1
fi

# Test GitHub token
echo "Testing GitHub token for repository access..."
if ! curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO" | grep -q "200"; then
    echo "❌ Error: Unable to access repository with provided token."
    echo "Would you like to create a new GitHub token? (y/N)"
    read -r create_token

    if [[ "$create_token" == "y" || "$create_token" == "Y" ]]; then
        echo "Creating new GitHub token using GitHub CLI..."

        # Login to GitHub
        gh auth login --scopes repo,read:org

        # Get the token
        NEW_TOKEN=$(gh auth token)

        if [[ -n "$NEW_TOKEN" ]]; then
            # Update the .env file
            sed -i "" "s/GITHUB_TOKEN=.*/GITHUB_TOKEN=$NEW_TOKEN/" .env
            echo "✅ GitHub token updated in .env file"

            # Reload environment variables
            source .env
        else
            echo "❌ Failed to create new GitHub token."
            exit 1
        fi
    else
        echo "Please update your GitHub token manually and run this script again."
        exit 1
    fi
fi

echo "✅ GitHub token validated successfully"

# Check if Flux is already installed
echo "Checking Flux installation status..."
if kubectl get namespace flux-system &>/dev/null && kubectl get deployment -n flux-system source-controller &>/dev/null; then
    echo "Flux appears to be already installed."
    echo "Would you like to reinstall Flux? (y/N)"
    read -r reinstall

    if [[ "$reinstall" == "y" || "$reinstall" == "Y" ]]; then
        echo "Removing existing Flux installation..."
        flux uninstall --silent || true

        # Wait for namespace to be fully deleted
        echo "Waiting for flux-system namespace to be deleted..."
        while kubectl get namespace flux-system &>/dev/null; do
            echo "  - still waiting..."
            sleep 5
        done
        echo "✅ Existing Flux installation removed"
    else
        echo "Keeping existing Flux installation."
    fi
fi

# Install Flux
echo "Installing Flux..."
flux install

echo "✅ Flux core components installed"

# Create the GitRepository resource
echo "Setting up GitRepository resource..."
kubectl -n flux-system create secret generic flux-system \
    --from-literal=username=${GITHUB_USER} \
    --from-literal=password=${GITHUB_TOKEN} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Creating GitRepository resource..."
flux create source git flux-system \
    --url=https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
    --branch=main \
    --username=${GITHUB_USER} \
    --password=${GITHUB_TOKEN} \
    --namespace=flux-system \
    --secret-ref=flux-system

echo "✅ GitRepository resource created"

# Apply flux-kustomization.yaml files in stages
echo "Applying Flux kustomization configurations in stages..."

# Apply stage 1 kustomization
if [ -f "clusters/local/flux-kustomization.yaml" ]; then
    kubectl apply -f clusters/local/flux-kustomization.yaml
    echo "✅ Stage 1 kustomization configuration applied"
else
    echo "❌ Warning: clusters/local/flux-kustomization.yaml not found"
    echo "Creating stage 1 kustomization:"
    
    # Create a default kustomization file
    cat > clusters/local/flux-kustomization.yaml << EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: local-core-infra
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/local/infrastructure
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  timeout: 10m0s
  retryInterval: 2m0s
  wait: true
EOF
    
    kubectl apply -f clusters/local/flux-kustomization.yaml
    echo "✅ Stage 1 kustomization configuration created and applied"
fi

# Wait for stage 1 to complete with better retry logic
echo "Waiting for stage 1 resources to reconcile (this may take a few minutes)..."
MAX_RETRIES=5
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "  Attempt $(($RETRY_COUNT + 1))/$MAX_RETRIES..."
    if flux reconcile kustomization local-core-infra --with-source --timeout=5m; then
        echo "✅ Stage 1 reconciliation completed successfully"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "  Stage 1 reconciliation failed. Retrying in 30 seconds..."
            sleep 30
        else
            echo "⚠️ Failed to reconcile stage 1 after $MAX_RETRIES attempts."
            echo "  Continuing with stage 2 anyway, but some components may not be ready."
        fi
    fi
done

# Apply stage 2 kustomization
if [ -f "clusters/local/infrastructure-stage2.yaml" ]; then
    kubectl apply -f clusters/local/infrastructure-stage2.yaml
    echo "✅ Stage 2 kustomization configuration applied"
    
    # Wait for stage 2 to complete
    echo "Waiting for stage 2 resources to reconcile (this may take a few minutes)..."
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo "  Attempt $(($RETRY_COUNT + 1))/$MAX_RETRIES..."
        if flux reconcile kustomization local-core-infra-stage2 --with-source --timeout=5m; then
            echo "✅ Stage 2 reconciliation completed successfully"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo "  Stage 2 reconciliation failed. Retrying in 30 seconds..."
                sleep 30
            else
                echo "⚠️ Failed to reconcile stage 2 after $MAX_RETRIES attempts."
                echo "  Some components may not be ready."
                break
            fi
        fi
    done
fi

# Apply stage 3 (applications) if it exists
if [ -f "clusters/local/applications.yaml" ]; then
    kubectl apply -f clusters/local/applications.yaml
    echo "✅ Applications kustomization configuration applied"
    
    # Wait for applications to complete
    echo "Waiting for applications to reconcile..."
    flux reconcile kustomization local-applications --with-source --timeout=5m || true
fi

# Verify setup
echo "Verifying GitOps setup..."
echo "  - Checking GitRepository:"
flux get source git
echo ""
echo "  - Checking Kustomization:"
flux get kustomization
echo ""
echo "  - Checking Flux components health:"
kubectl get pods -n flux-system
echo ""

# Final message
echo "=========================================="
echo "   GitOps Setup Complete!"
echo "=========================================="
echo ""
echo "Your GitOps workflow has been successfully set up with Flux."
echo ""
echo "To check Flux status:"
echo "  flux check"
echo ""
echo "To view all Flux resources:"
echo "  flux get all"
echo ""
echo "To trigger a manual reconciliation:"
echo "  flux reconcile source git flux-system"
echo "  flux reconcile kustomization local-core-infra"
echo ""
echo "To view logs:"
echo "  flux logs"
echo ""
echo "Next steps:"
echo "1. Run './scripts/cluster/setup-core-infrastructure.sh' to deploy core infrastructure"
echo "2. Run './scripts/cluster/verify-environment.sh' to verify the deployment"
echo "=========================================="
