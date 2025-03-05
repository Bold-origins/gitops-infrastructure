#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Kubernetes GitOps Cluster Setup ===${NC}"
echo -e "${YELLOW}This script will set up a complete Kubernetes GitOps cluster using Minikube and Flux.${NC}"
echo

# Check prerequisites
echo -e "${GREEN}Checking prerequisites...${NC}"

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Minikube is not installed. Please install it first: https://minikube.sigs.k8s.io/docs/start/${NC}"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install it first: https://kubernetes.io/docs/tasks/tools/${NC}"
    exit 1
fi

# Check if flux is installed
if ! command -v flux &> /dev/null; then
    echo -e "${RED}Flux CLI is not installed. Please install it first: https://fluxcd.io/docs/installation/${NC}"
    exit 1
fi

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo -e "${YELLOW}kubeseal is not installed. It's recommended for working with sealed secrets.${NC}"
    echo -e "${YELLOW}Install it from: https://github.com/bitnami-labs/sealed-secrets#installation${NC}"
fi

echo -e "${GREEN}All required tools are installed.${NC}"
echo

# Start Minikube
echo -e "${GREEN}Starting Minikube cluster...${NC}"
minikube start --memory=8g --cpus=4 --driver=docker

# Enable addons
echo -e "${GREEN}Enabling Minikube addons...${NC}"
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable registry

# Ask for GitHub details
echo
echo -e "${GREEN}GitHub Configuration for Flux${NC}"
read -p "GitHub Username: " GITHUB_USER
read -p "GitHub Repository Name: " GITHUB_REPO
read -sp "GitHub Personal Access Token: " GITHUB_TOKEN
echo

# Export variables for Flux
export GITHUB_TOKEN
export GITHUB_USER
export GITHUB_REPO

# Bootstrap Flux
echo -e "${GREEN}Bootstrapping Flux with GitHub...${NC}"
echo -e "${YELLOW}This will create the repository if it doesn't exist and set up Flux components.${NC}"
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/local \
  --personal

# Wait for Flux to be ready
echo -e "${GREEN}Waiting for Flux components to be ready...${NC}"
kubectl -n flux-system wait --for=condition=ready pod --all --timeout=300s

# Verify installation
echo -e "${GREEN}Verifying installation...${NC}"
flux check

echo
echo -e "${GREEN}=== Cluster Setup Complete ===${NC}"
echo -e "${YELLOW}Your Kubernetes GitOps cluster is now set up with Flux.${NC}"
echo -e "${YELLOW}The infrastructure components will be deployed automatically by Flux.${NC}"
echo
echo -e "${GREEN}To monitor the deployment progress:${NC}"
echo "  flux get kustomizations --all-namespaces"
echo "  kubectl get pods --all-namespaces"
echo
echo -e "${GREEN}To access the cluster:${NC}"
echo "  minikube ip                # Get the cluster IP"
echo "  kubectl get svc -A         # List all services"
echo
echo -e "${GREEN}Happy GitOps!${NC}" 