#!/bin/bash

# resume-setup.sh: Resume a failed GitOps setup
# This script can be used when the initial setup times out or fails

set -e

# Display banner
echo "=========================================="
echo "   Resuming GitOps Setup"
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

# Check if Flux is installed
if ! kubectl get namespace flux-system &>/dev/null; then
    echo "❌ Error: Flux system namespace doesn't exist. Please run the full setup script first."
    exit 1
fi

# Check if GitRepository exists and has the correct URL
echo "Checking GitRepository configuration..."
if ! kubectl get gitrepository -n flux-system flux-system &>/dev/null; then
    echo "❌ GitRepository not found. Creating it now..."
    
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
    
    echo "✅ GitRepository created"
else
    echo "✅ GitRepository exists, verifying configuration..."
    REPO_URL=$(kubectl get gitrepository -n flux-system flux-system -o jsonpath='{.spec.url}')
    EXPECTED_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
    
    if [ "$REPO_URL" != "$EXPECTED_URL" ]; then
        echo "⚠️ GitRepository URL mismatch. Updating..."
        kubectl patch gitrepository flux-system -n flux-system --type=json -p "[{\"op\": \"replace\", \"path\": \"/spec/url\", \"value\": \"$EXPECTED_URL\"}]"
        echo "✅ GitRepository URL updated"
    else
        echo "✅ GitRepository URL matches expected value"
    fi
fi

# Check and apply stage 1 kustomization
echo "Checking stage 1 kustomization..."
if ! kubectl get kustomization -n flux-system local-core-infra &>/dev/null; then
    echo "❌ Stage 1 kustomization not found. Creating it now..."
    if [ -f "clusters/local/flux-kustomization.yaml" ]; then
        kubectl apply -f clusters/local/flux-kustomization.yaml
    else
        echo "Creating default stage 1 kustomization..."
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
    fi
    echo "✅ Stage 1 kustomization created"
else
    echo "✅ Stage 1 kustomization exists"
fi

# Reconcile stage 1
echo "Reconciling stage 1 kustomization..."
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

# Check and apply stage 2 kustomization
echo "Checking stage 2 kustomization..."
if ! kubectl get kustomization -n flux-system local-core-infra-stage2 &>/dev/null; then
    echo "❌ Stage 2 kustomization not found. Creating it now..."
    if [ -f "clusters/local/infrastructure-stage2.yaml" ]; then
        kubectl apply -f clusters/local/infrastructure-stage2.yaml
        echo "✅ Stage 2 kustomization created"
    else
        echo "⚠️ Stage 2 kustomization file not found, skipping"
    fi
else
    echo "✅ Stage 2 kustomization exists"
fi

# Reconcile stage 2 if it exists
if kubectl get kustomization -n flux-system local-core-infra-stage2 &>/dev/null; then
    echo "Reconciling stage 2 kustomization..."
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

# Check namespaces to see what's been created
echo "Checking deployed namespaces..."
kubectl get ns

# Check if Vault namespace exists
if kubectl get namespace vault &>/dev/null; then
    echo "✅ Vault namespace exists. Checking Vault pods..."
    kubectl get pods -n vault
else
    echo "⚠️ Vault namespace doesn't exist yet."
fi

# Final message
echo "=========================================="
echo "   GitOps Resume Complete!"
echo "=========================================="
echo ""
echo "The GitOps setup has been resumed. Check the status of your resources with:"
echo ""
echo "  flux get all"
echo "  kubectl get pods -A"
echo ""
echo "If you're still experiencing issues, you can:"
echo "1. Check logs: flux logs"
echo "2. Try again: ./scripts/gitops/resume-setup.sh"
echo "3. Get more detailed status: flux get kustomization local-core-infra --verbose"
echo "==========================================" 