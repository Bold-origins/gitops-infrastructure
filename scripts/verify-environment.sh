#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BLUE}==== GitOps Infrastructure Verification ====${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}== $1 ==${NC}"
}

# Check prerequisites
print_section "Checking Prerequisites"

PREREQS_OK=true

# Check if minikube exists
if command_exists minikube; then
    echo -e "${GREEN}✓ Minikube is installed${NC}"
else
    echo -e "${RED}✗ Minikube is not installed. Please install Minikube first.${NC}"
    echo "Visit: https://minikube.sigs.k8s.io/docs/start/"
    PREREQS_OK=false
fi

# Check if kubectl exists
if command_exists kubectl; then
    echo -e "${GREEN}✓ kubectl is installed${NC}"
else
    echo -e "${RED}✗ kubectl is not installed. Please install kubectl first.${NC}"
    echo "Visit: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    PREREQS_OK=false
fi

# Check if kubeseal exists
if command_exists kubeseal; then
    echo -e "${GREEN}✓ kubeseal is installed${NC}"
else
    echo -e "${YELLOW}⚠ kubeseal is not installed. It's recommended for working with Sealed Secrets.${NC}"
    echo "Visit: https://github.com/bitnami-labs/sealed-secrets#kubeseal"
fi

# Check if vault CLI exists
if command_exists vault; then
    echo -e "${GREEN}✓ Vault CLI is installed${NC}"
else
    echo -e "${YELLOW}⚠ Vault CLI is not installed. It's recommended for working with HashiCorp Vault.${NC}"
    echo "Visit: https://www.vaultproject.io/downloads"
fi

# If prerequisites are not met, exit
if [ "$PREREQS_OK" = false ]; then
    echo -e "${RED}Prerequisites not met. Please install the required tools before continuing.${NC}"
    exit 1
fi

# Check Minikube status
print_section "Checking Minikube Status"

MINIKUBE_STATUS=$(minikube status --format={{.Host}} 2>/dev/null || echo "Not Running")
if [ "$MINIKUBE_STATUS" == "Running" ]; then
    echo -e "${GREEN}✓ Minikube is running${NC}"
    MINIKUBE_IP=$(minikube ip)
    echo -e "  Minikube IP: ${MINIKUBE_IP}"
else
    echo -e "${RED}✗ Minikube is not running. Please start Minikube first.${NC}"
    echo -e "  Run: ${YELLOW}minikube start --memory=4096 --cpus=2 --driver=docker${NC}"
    exit 1
fi

# Check if required addons are enabled
print_section "Checking Minikube Addons"

INGRESS_ENABLED=$(minikube addons list -o json | grep -A3 "ingress" | grep "enabled" | awk '{print $2}' | tr -d ',"')
if [ "$INGRESS_ENABLED" == "true" ]; then
    echo -e "${GREEN}✓ Ingress addon is enabled${NC}"
else
    echo -e "${RED}✗ Ingress addon is not enabled. Please enable it.${NC}"
    echo -e "  Run: ${YELLOW}minikube addons enable ingress${NC}"
fi

METRICS_ENABLED=$(minikube addons list -o json | grep -A3 "metrics-server" | grep "enabled" | awk '{print $2}' | tr -d ',"')
if [ "$METRICS_ENABLED" == "true" ]; then
    echo -e "${GREEN}✓ Metrics Server addon is enabled${NC}"
else
    echo -e "${YELLOW}⚠ Metrics Server addon is not enabled. It's recommended for monitoring.${NC}"
    echo -e "  Run: ${YELLOW}minikube addons enable metrics-server${NC}"
fi

# Check /etc/hosts file for local domain configuration
print_section "Checking Local Domain Configuration"

if grep -q "# Minikube domains" /etc/hosts; then
    echo -e "${GREEN}✓ Minikube domains are configured in /etc/hosts${NC}"

    # Check if the IP matches current Minikube IP
    HOSTS_IP=$(grep -A1 "# Minikube domains" /etc/hosts | tail -n1 | awk '{print $1}')
    if [ "$HOSTS_IP" == "$MINIKUBE_IP" ]; then
        echo -e "${GREEN}✓ Minikube IP in /etc/hosts matches current Minikube IP${NC}"
    else
        echo -e "${RED}✗ Minikube IP in /etc/hosts ($HOSTS_IP) does not match current Minikube IP ($MINIKUBE_IP)${NC}"
        echo -e "  Please update /etc/hosts or run: ${YELLOW}./scripts/setup-minikube.sh${NC}"
    fi
else
    echo -e "${RED}✗ Minikube domains are not configured in /etc/hosts${NC}"
    echo -e "  Please run: ${YELLOW}./scripts/setup-minikube.sh${NC}"
fi

# Check if core components are installed
print_section "Checking Core Components"

# Function to check if a namespace exists
namespace_exists() {
    kubectl get namespace "$1" &>/dev/null
    return $?
}

# Check cert-manager
if namespace_exists cert-manager; then
    echo -e "${GREEN}✓ cert-manager namespace exists${NC}"

    # Check cert-manager pods
    CM_READY_PODS=$(kubectl get pods -n cert-manager -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | tr ' ' '\n' | grep -c "true" || echo "0")
    CM_TOTAL_PODS=$(kubectl get pods -n cert-manager -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | tr ' ' '\n' | wc -l || echo "0")

    if [ "$CM_READY_PODS" -eq "$CM_TOTAL_PODS" ] && [ "$CM_TOTAL_PODS" -gt 0 ]; then
        echo -e "${GREEN}✓ All cert-manager pods are ready ($CM_READY_PODS/$CM_TOTAL_PODS)${NC}"
    else
        echo -e "${RED}✗ Not all cert-manager pods are ready ($CM_READY_PODS/$CM_TOTAL_PODS)${NC}"
        echo -e "  Check pod status: ${YELLOW}kubectl get pods -n cert-manager${NC}"
    fi

    # Check ClusterIssuers
    if kubectl get clusterissuer selfsigned-cluster-issuer &>/dev/null; then
        echo -e "${GREEN}✓ selfsigned-cluster-issuer exists${NC}"
    else
        echo -e "${RED}✗ selfsigned-cluster-issuer does not exist${NC}"
    fi

    if kubectl get clusterissuer letsencrypt-staging &>/dev/null; then
        echo -e "${GREEN}✓ letsencrypt-staging ClusterIssuer exists${NC}"
    else
        echo -e "${RED}✗ letsencrypt-staging ClusterIssuer does not exist${NC}"
    fi

    if kubectl get clusterissuer letsencrypt-prod &>/dev/null; then
        echo -e "${GREEN}✓ letsencrypt-prod ClusterIssuer exists${NC}"
    else
        echo -e "${RED}✗ letsencrypt-prod ClusterIssuer does not exist${NC}"
    fi
else
    echo -e "${RED}✗ cert-manager namespace does not exist${NC}"
    echo -e "  Please run: ${YELLOW}kubectl apply -k clusters/local/infrastructure/cert-manager${NC}"
fi

# Check Vault
if namespace_exists vault; then
    echo -e "${GREEN}✓ vault namespace exists${NC}"

    # Check vault pods
    VAULT_READY_PODS=$(kubectl get pods -n vault -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | tr ' ' '\n' | grep -c "true" || echo "0")
    VAULT_TOTAL_PODS=$(kubectl get pods -n vault -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | tr ' ' '\n' | wc -l || echo "0")

    if [ "$VAULT_READY_PODS" -eq "$VAULT_TOTAL_PODS" ] && [ "$VAULT_TOTAL_PODS" -gt 0 ]; then
        echo -e "${GREEN}✓ All vault pods are ready ($VAULT_READY_PODS/$VAULT_TOTAL_PODS)${NC}"
    else
        echo -e "${RED}✗ Not all vault pods are ready ($VAULT_READY_PODS/$VAULT_TOTAL_PODS)${NC}"
        echo -e "  Check pod status: ${YELLOW}kubectl get pods -n vault${NC}"
    fi

    # Check if Vault is accessible via Ingress
    echo -e "${YELLOW}ℹ To access Vault UI: https://vault.local${NC}"
else
    echo -e "${RED}✗ vault namespace does not exist${NC}"
    echo -e "  Please run: ${YELLOW}kubectl apply -k clusters/local/infrastructure/vault${NC}"
fi

# Check Example Application
if namespace_exists example; then
    echo -e "${GREEN}✓ example namespace exists${NC}"

    # Check example app pods
    EXAMPLE_READY_PODS=$(kubectl get pods -n example -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | tr ' ' '\n' | grep -c "true" || echo "0")
    EXAMPLE_TOTAL_PODS=$(kubectl get pods -n example -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | tr ' ' '\n' | wc -l || echo "0")

    if [ "$EXAMPLE_READY_PODS" -eq "$EXAMPLE_TOTAL_PODS" ] && [ "$EXAMPLE_TOTAL_PODS" -gt 0 ]; then
        echo -e "${GREEN}✓ All example application pods are ready ($EXAMPLE_READY_PODS/$EXAMPLE_TOTAL_PODS)${NC}"
    else
        echo -e "${RED}✗ Not all example application pods are ready ($EXAMPLE_READY_PODS/$EXAMPLE_TOTAL_PODS)${NC}"
        echo -e "  Check pod status: ${YELLOW}kubectl get pods -n example${NC}"
    fi

    # Check ingress
    if kubectl get ingress -n example example-app-ingress &>/dev/null; then
        echo -e "${GREEN}✓ example-app-ingress exists${NC}"

        # Check certificate
        if kubectl get certificate -n example example-tls &>/dev/null; then
            CERT_STATUS=$(kubectl get certificate -n example example-tls -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
            if [ "$CERT_STATUS" == "True" ]; then
                echo -e "${GREEN}✓ TLS certificate for example.local is ready${NC}"
            else
                echo -e "${YELLOW}⚠ TLS certificate for example.local is not ready${NC}"
                echo -e "  Check certificate status: ${YELLOW}kubectl describe certificate -n example example-tls${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ No TLS certificate found for example.local${NC}"
        fi

        echo -e "${YELLOW}ℹ To access Example App: https://example.local${NC}"
    else
        echo -e "${RED}✗ example-app-ingress does not exist${NC}"
    fi
else
    echo -e "${RED}✗ example namespace does not exist${NC}"
    echo -e "  Please run: ${YELLOW}kubectl apply -k clusters/local/apps/example${NC}"
fi

# Check policies
print_section "Checking OPA Gatekeeper"

if kubectl get pods -n gatekeeper-system &>/dev/null; then
    echo -e "${GREEN}✓ OPA Gatekeeper is installed${NC}"

    # Check for constraint templates
    CT_COUNT=$(kubectl get constrainttemplate --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$CT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ $CT_COUNT ConstraintTemplates found${NC}"
    else
        echo -e "${YELLOW}⚠ No ConstraintTemplates found${NC}"
    fi

    # Check for constraints
    CONSTRAINT_COUNT=$(kubectl get constraints --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$CONSTRAINT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ $CONSTRAINT_COUNT Constraints found${NC}"
    else
        echo -e "${YELLOW}⚠ No Constraints found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ OPA Gatekeeper is not installed${NC}"
    echo -e "  Please run: ${YELLOW}kubectl apply -k clusters/local/infrastructure/gatekeeper${NC}"
fi

# Final summary
print_section "Summary"

echo -e "${GREEN}✓ Verification complete${NC}"
echo -e "${YELLOW}ℹ To run the complete setup:${NC}"
echo -e "  ${YELLOW}./scripts/setup-minikube.sh${NC}"
echo -e "${YELLOW}ℹ For detailed troubleshooting:${NC}"
echo -e "  Refer to: ${YELLOW}docs/minikube-setup.md${NC} and ${YELLOW}docs/tls-certificates.md${NC}"
echo -e "${YELLOW}ℹ To test the example application with Vault and Sealed Secrets:${NC}"
echo -e "  Refer to: ${YELLOW}clusters/local/apps/example/README.md${NC}"
