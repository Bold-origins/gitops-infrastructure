#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set the Kubernetes config
export KUBECONFIG=~/.kube/config-vps

echo -e "${GREEN}Fixing flux-system kustomization...${NC}"

# First, suspend the flux-system kustomization to prevent any reconciliation
echo -e "${YELLOW}Suspending the current flux-system kustomization...${NC}"
kubectl patch kustomization flux-system -n flux-system --type=merge -p '{"spec":{"suspend":true}}'
echo -e "${GREEN}✓ Kustomization suspended${NC}"

# Check the current state before applying
echo -e "${YELLOW}Current state of flux-system kustomization:${NC}"
kubectl get kustomization flux-system -n flux-system -o yaml | grep "path:"

# Create a temporary file with the updated kustomization
echo -e "${YELLOW}Creating new kustomization config...${NC}"
cat > flux-system-kustomization.yaml << EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/vps/flux-system
  prune: true
  suspend: false
  sourceRef:
    kind: GitRepository
    name: flux-system
EOF

# Apply the updated kustomization
echo -e "${YELLOW}Applying the updated kustomization...${NC}"
kubectl apply -f flux-system-kustomization.yaml
echo -e "${GREEN}✓ New kustomization applied${NC}"

# Verify the change was applied
echo -e "${YELLOW}Verifying the update:${NC}"
kubectl get kustomization flux-system -n flux-system -o yaml | grep "path:"

# Clean up
rm flux-system-kustomization.yaml
echo -e "${GREEN}✓ Temporary file cleaned up${NC}"

# Reconcile the kustomization
echo -e "${YELLOW}Reconciling the kustomization...${NC}"
flux reconcile kustomization flux-system
echo -e "${GREEN}✓ Reconciliation triggered${NC}"

# Create namespaces for staging and production if they don't exist
echo -e "${YELLOW}Creating flux-staging namespace...${NC}"
kubectl create namespace flux-staging --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ flux-staging namespace created/verified${NC}"

echo -e "${YELLOW}Creating flux-production namespace...${NC}"
kubectl create namespace flux-production --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ flux-production namespace created/verified${NC}"

# Delete any existing kustomizations
if kubectl get kustomization staging -n flux-system &>/dev/null; then
  echo -e "${YELLOW}Deleting existing staging kustomization from flux-system namespace...${NC}"
  kubectl delete kustomization staging -n flux-system
  echo -e "${GREEN}✓ Deleted existing staging kustomization${NC}"
fi

if kubectl get kustomization production -n flux-system &>/dev/null; then
  echo -e "${YELLOW}Deleting existing production kustomization from flux-system namespace...${NC}"
  kubectl delete kustomization production -n flux-system
  echo -e "${GREEN}✓ Deleted existing production kustomization${NC}"
fi

if kubectl get kustomization staging -n flux-staging &>/dev/null; then
  echo -e "${YELLOW}Deleting existing staging kustomization from flux-staging namespace...${NC}"
  kubectl delete kustomization staging -n flux-staging
  echo -e "${GREEN}✓ Deleted existing staging kustomization${NC}"
fi

if kubectl get kustomization production -n flux-production &>/dev/null; then
  echo -e "${YELLOW}Deleting existing production kustomization from flux-production namespace...${NC}"
  kubectl delete kustomization production -n flux-production
  echo -e "${GREEN}✓ Deleted existing production kustomization${NC}"
fi

# Now create individual kustomizations for each environment
echo -e "${YELLOW}Creating kustomization for staging in flux-staging namespace...${NC}"
flux create kustomization staging \
  --source=GitRepository/flux-system.flux-system \
  --path="./clusters/vps/staging" \
  --prune=true \
  --interval=10m \
  --health-check-timeout=2m \
  --depends-on=flux-system.flux-system \
  --wait=false \
  --namespace=flux-staging
echo -e "${GREEN}✓ Staging kustomization created${NC}"

echo -e "${YELLOW}Creating kustomization for production in flux-production namespace...${NC}"
flux create kustomization production \
  --source=GitRepository/flux-system.flux-system \
  --path="./clusters/vps/production" \
  --prune=true \
  --interval=10m \
  --health-check-timeout=2m \
  --depends-on=flux-system.flux-system \
  --wait=false \
  --namespace=flux-production
echo -e "${GREEN}✓ Production kustomization created${NC}"

# Check the status
echo -e "${YELLOW}Checking the status of kustomizations...${NC}"
flux get kustomizations --all-namespaces

echo -e "${GREEN}Flux system kustomization fixed!${NC}" 