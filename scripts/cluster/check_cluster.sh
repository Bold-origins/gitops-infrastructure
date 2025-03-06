#!/bin/bash
# Script to check the status of all components in the cluster

set -e

# Set colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Checking Cluster Component Status${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${BLUE}1. Checking Minikube Status:${NC}"
minikube status

echo -e "${BLUE}2. Checking namespaces:${NC}"
kubectl get namespaces

echo -e "${BLUE}3. Checking Flux System:${NC}"
kubectl get pods -n flux-system

echo -e "${BLUE}4. Checking Infrastructure Components:${NC}"

echo -e "${YELLOW}   a. cert-manager:${NC}"
kubectl get pods -n cert-manager

echo -e "${YELLOW}   b. sealed-secrets:${NC}"
kubectl get pods -n sealed-secrets

echo -e "${YELLOW}   c. vault:${NC}"
kubectl get pods -n vault
echo "Vault status: (skipping detailed status check due to protocol issues)"
# We're not checking vault status using exec since it requires proper HTTPS setup
# Instead, just check if pod is running

echo -e "${YELLOW}   d. gatekeeper:${NC}"
kubectl get pods -n gatekeeper-system

echo -e "${YELLOW}   e. minio:${NC}"
kubectl get pods -n minio
echo "MinIO buckets cannot be directly listed via kubectl, use the MinIO console or API"

echo -e "${BLUE}5. Checking Application Components:${NC}"
EXAMPLE_POD=$(kubectl get pod -n example -l app=example-app -o name 2>/dev/null)
if [ -n "$EXAMPLE_POD" ]; then
  CONTAINER_STATUS=$(kubectl get pod -n example -l app=example-app -o jsonpath='{.items[0].status.phase}')
  if [ "$CONTAINER_STATUS" != "Running" ]; then
    echo -e "${RED}Example app pod is not running. Status: ${CONTAINER_STATUS}${NC}"
    echo "Checking for container creation errors..."
    ERROR_DETAIL=$(kubectl get pod -n example -l app=example-app -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
    if [ "$ERROR_DETAIL" == "CreateContainerConfigError" ]; then
      echo -e "${RED}Container has a configuration error. Checking related events:${NC}"
      kubectl get events -n example --field-selector involvedObject.kind=Pod,involvedObject.name=$(kubectl get pod -n example -l app=example-app -o jsonpath='{.items[0].metadata.name}')
    fi
  else
    echo -e "${GREEN}Example app pod is running normally${NC}"
  fi
else
  echo "No example app pod found"
fi

echo -e "${BLUE}6. Checking Storage:${NC}"
kubectl get pv,pvc --all-namespaces

echo -e "${BLUE}7. Checking ingress-nginx:${NC}"
kubectl get pods -n ingress-nginx
kubectl get job -n ingress-nginx

echo -e "${BLUE}8. Checking for any pods in error state:${NC}"
kubectl get pods --all-namespaces | grep -v "Running\|Completed" | grep -v "NAME" || echo "No pods in error state found"

echo -e "${BLUE}9. Checking node resources:${NC}"
kubectl top nodes

echo -e "${BLUE}10. Checking pod resources:${NC}"
kubectl top pods --all-namespaces

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cluster Component Check Complete${NC}"
echo -e "${GREEN}========================================${NC}"

# Exit with code 0 to indicate success even if some components have issues
exit 0 