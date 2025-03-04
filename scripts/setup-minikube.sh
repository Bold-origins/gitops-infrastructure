#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Minikube setup for local GitOps testing...${NC}"

# Check if minikube exists
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Minikube not found. Please install minikube first.${NC}"
    echo "Visit: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if kubectl exists
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Kubectl not found. Please install kubectl first.${NC}"
    echo "Visit: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
fi

# Check if minikube is already running
MINIKUBE_STATUS=$(minikube status --format={{.Host}} 2>/dev/null || echo "Not Running")
if [ "$MINIKUBE_STATUS" != "Running" ]; then
    # Start Minikube with appropriate resources
    echo -e "${YELLOW}Starting Minikube with 4GB memory and 2 CPUs...${NC}"
    minikube start --memory=4096 --cpus=2 --driver=docker \
      --addons=ingress \
      --addons=metrics-server \
      --addons=dashboard \
      --insecure-registry="10.0.0.0/24"
else
    echo -e "${GREEN}Minikube is already running${NC}"
fi

# Ensure addons are enabled
echo -e "${YELLOW}Ensuring addons are enabled...${NC}"
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable registry

# Create local domain mapping
MINIKUBE_IP=$(minikube ip)
echo -e "${YELLOW}Minikube IP: ${MINIKUBE_IP}${NC}"

echo -e "${YELLOW}Adding local domain entries to /etc/hosts...${NC}"
# Check if the entries already exist
if ! grep -q "# Minikube domains" /etc/hosts; then
    echo "
# Minikube domains
$MINIKUBE_IP vault.local
$MINIKUBE_IP example.local
$MINIKUBE_IP prometheus.local
$MINIKUBE_IP grafana.local
$MINIKUBE_IP minio.local
$MINIKUBE_IP alertmanager.local" | sudo tee -a /etc/hosts > /dev/null
    echo -e "${GREEN}Added Minikube domains to /etc/hosts${NC}"
else
    echo -e "${YELLOW}Minikube domains already in /etc/hosts, updating IPs...${NC}"
    sudo sed -i.bak "/# Minikube domains/,/alertmanager.local/c\# Minikube domains\n$MINIKUBE_IP vault.local\n$MINIKUBE_IP example.local\n$MINIKUBE_IP prometheus.local\n$MINIKUBE_IP grafana.local\n$MINIKUBE_IP minio.local\n$MINIKUBE_IP alertmanager.local" /etc/hosts
fi

# Apply infrastructure
echo -e "${YELLOW}Applying cert-manager...${NC}"
kubectl apply -k clusters/local/infrastructure/cert-manager

echo -e "${YELLOW}Waiting for cert-manager to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=cert-manager --timeout=120s -n cert-manager || echo "Timed out waiting for cert-manager, continuing anyway..."

echo -e "${YELLOW}Applying Sealed Secrets...${NC}"
kubectl apply -k clusters/local/infrastructure/sealed-secrets

echo -e "${YELLOW}Applying Vault...${NC}"
kubectl apply -k clusters/local/infrastructure/vault

echo -e "${YELLOW}Applying OPA Gatekeeper...${NC}"
kubectl apply -k clusters/local/infrastructure/gatekeeper

echo -e "${YELLOW}Applying policies...${NC}"
kubectl apply -k clusters/local/policies/templates || echo "Policy templates not found or failed, continuing..."
kubectl apply -k clusters/local/policies/constraints || echo "Policy constraints not found or failed, continuing..."

echo -e "${YELLOW}Applying MinIO...${NC}"
kubectl apply -k clusters/local/apps/minio || echo "MinIO not found or failed, continuing..."

echo -e "${YELLOW}Applying example application...${NC}"
kubectl apply -k clusters/local/apps/example

# Setup dashboard access
echo -e "${GREEN}Setting up dashboard access...${NC}"
kubectl proxy &
PROXY_PID=$!
echo -e "${GREEN}Kubernetes dashboard available at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/${NC}"

# Show available services
echo -e "${GREEN}Available services:${NC}"
echo -e "- Vault: https://vault.local"
echo -e "- Example App: https://example.local"
echo -e "- MinIO: https://minio.local"
echo -e "- Prometheus: https://prometheus.local"
echo -e "- Grafana: https://grafana.local"
echo -e "- Alertmanager: https://alertmanager.local"

echo -e "${GREEN}Minikube setup complete! Happy testing!${NC}"
echo -e "${YELLOW}Note: For the first access to services with HTTPS, you'll need to accept the self-signed certificate warnings.${NC}"
echo -e "${YELLOW}To stop the Kubernetes dashboard proxy, run: kill $PROXY_PID${NC}"

# Print helpful commands
echo -e "\n${GREEN}Helpful commands:${NC}"
echo -e "minikube dashboard           # Open the Minikube dashboard"
echo -e "minikube stop                # Stop the Minikube cluster"
echo -e "minikube delete              # Delete the Minikube cluster"
echo -e "kubectl get pods --all-namespaces    # List all pods"
echo -e "kubectl get ingress --all-namespaces # List all ingress resources" 