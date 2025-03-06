#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set the Kubernetes config
export KUBECONFIG=~/.kube/config-vps

echo -e "${GREEN}Reconciling individual components...${NC}"

# Reconcile the source first
echo -e "${YELLOW}Reconciling the Flux source...${NC}"
flux reconcile source git flux-system

# Reconcile observability components
echo -e "${YELLOW}Reconciling observability components...${NC}"

# Grafana
echo "Reconciling grafana..."
flux create kustomization grafana \
  --source=GitRepository/flux-system \
  --path="./clusters/vps/staging/observability/grafana" \
  --prune=true \
  --interval=10m \
  --health-check-timeout=2m \
  --wait=false

# Prometheus
echo "Reconciling prometheus..."
flux create kustomization prometheus \
  --source=GitRepository/flux-system \
  --path="./clusters/vps/staging/observability/prometheus" \
  --prune=true \
  --interval=10m \
  --health-check-timeout=2m \
  --wait=false

# Loki
echo "Reconciling loki..."
flux create kustomization loki \
  --source=GitRepository/flux-system \
  --path="./clusters/vps/staging/observability/loki" \
  --prune=true \
  --interval=10m \
  --health-check-timeout=2m \
  --wait=false

# OpenTelemetry
echo "Reconciling opentelemetry..."
flux create kustomization opentelemetry \
  --source=GitRepository/flux-system \
  --path="./clusters/vps/staging/observability/opentelemetry" \
  --prune=true \
  --interval=10m \
  --health-check-timeout=2m \
  --wait=false

# Reconcile infrastructure components
echo -e "${YELLOW}Reconciling infrastructure components...${NC}"

# Ingress
echo "Reconciling ingress..."
flux create kustomization ingress \
  --source=GitRepository/flux-system \
  --path="./clusters/vps/staging/infrastructure/ingress" \
  --prune=true \
  --interval=10m \
  --health-check-timeout=2m \
  --wait=false

# Check the status
echo -e "${YELLOW}Checking the status of kustomizations...${NC}"
flux get kustomizations

echo -e "${GREEN}Reconciliation completed!${NC}" 