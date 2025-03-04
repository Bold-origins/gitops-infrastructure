#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Kubernetes GitOps Cluster Cleanup ===${NC}"
echo -e "${YELLOW}This script will clean up your Minikube cluster.${NC}"
echo

# Confirm with the user
read -p "Are you sure you want to delete the Minikube cluster? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup aborted.${NC}"
    exit 0
fi

# Stop and delete Minikube
echo -e "${GREEN}Stopping and deleting Minikube cluster...${NC}"
minikube stop
minikube delete

echo
echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo -e "${YELLOW}Your Minikube cluster has been deleted.${NC}"
echo -e "${YELLOW}Note: Your GitHub repository with Flux configuration still exists.${NC}"
echo -e "${YELLOW}You may want to delete it manually if you no longer need it.${NC}" 