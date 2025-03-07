#!/bin/bash

# verify-environment.sh: Verifies the local Kubernetes environment
# This script performs comprehensive checks on all components

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Verifying Local Kubernetes Environment"
echo "========================================"

# Check if minikube is running
if ! minikube status &>/dev/null; then
    echo "❌ Error: Minikube is not running. Please start Minikube first with ./scripts/cluster/setup-minikube.sh"
    exit 1
fi

# Check for kubectl
if ! command -v kubectl &>/dev/null; then
    echo "❌ Error: kubectl not found. Please install kubectl."
    exit 1
fi

# Function to check component status
check_component() {
    component=$1
    namespace=$2
    label_selector=${3:-""}
    
    echo "Checking ${component} in namespace ${namespace}..."
    
    # Check if namespace exists
    if ! kubectl get namespace "${namespace}" &>/dev/null; then
        echo "  ❌ Namespace ${namespace} does not exist."
        return 1
    fi
    
    # Check if pods exist
    if [ -n "${label_selector}" ]; then
        if ! kubectl get pods -n "${namespace}" -l "${label_selector}" &>/dev/null; then
            echo "  ❌ No pods found for ${component} with selector ${label_selector}."
            return 1
        fi
        
        # Check pod status
        if kubectl get pods -n "${namespace}" -l "${label_selector}" | grep -v Running | grep -v Completed | grep -v "NAME" &>/dev/null; then
            echo "  ⚠️ Some pods for ${component} are not in Running or Completed state:"
            kubectl get pods -n "${namespace}" -l "${label_selector}" | grep -v Running | grep -v Completed | grep -v "NAME"
            return 2
        fi
    else
        if ! kubectl get pods -n "${namespace}" &>/dev/null || [ "$(kubectl get pods -n "${namespace}" --no-headers | wc -l)" -eq 0 ]; then
            echo "  ❌ No pods found for ${component}."
            return 1
        fi
        
        # Check pod status
        if kubectl get pods -n "${namespace}" | grep -v Running | grep -v Completed | grep -v "NAME" &>/dev/null; then
            echo "  ⚠️ Some pods for ${component} are not in Running or Completed state:"
            kubectl get pods -n "${namespace}" | grep -v Running | grep -v Completed | grep -v "NAME"
            return 2
        fi
    fi
    
    echo "  ✅ ${component} is running correctly."
    return 0
}

# Function to check Service accessibility
check_service() {
    component=$1
    namespace=$2
    service_name=$3
    
    echo "Checking ${component} service..."
    
    # Check if service exists
    if ! kubectl get svc -n "${namespace}" "${service_name}" &>/dev/null; then
        echo "  ❌ Service ${service_name} does not exist in namespace ${namespace}."
        return 1
    fi
    
    # Check if service has endpoints
    if [ "$(kubectl get endpoints -n "${namespace}" "${service_name}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)" = "" ]; then
        echo "  ⚠️ Service ${service_name} has no endpoints."
        return 2
    fi
    
    echo "  ✅ Service ${service_name} is accessible."
    return 0
}

# Check if ingress domains are resolvable
check_ingress() {
    domain=$1
    
    echo "Checking if ${domain} is resolvable..."
    if ! ping -c 1 "${domain}" &>/dev/null; then
        echo "  ⚠️ Domain ${domain} is not resolvable. You may need to add it to your /etc/hosts file."
        return 1
    fi
    
    echo "  ✅ Domain ${domain} is resolvable."
    return 0
}

echo "========== Core Infrastructure =========="

# Check cert-manager
check_component "cert-manager" "cert-manager" "app=cert-manager"
cert_manager_status=$?

# Check if cert-manager CRDs are installed
if kubectl get crd | grep -q "certificates.cert-manager.io"; then
    echo "  ✅ cert-manager CRDs are installed."
else
    echo "  ❌ cert-manager CRDs are not installed."
fi

# Check sealed-secrets
check_component "sealed-secrets" "kube-system" "app.kubernetes.io/name=sealed-secrets"
sealed_secrets_status=$?

# Check vault
check_component "vault" "vault"
vault_status=$?

# Check if vault is sealed
if kubectl exec -n vault vault-0 -- vault status 2>/dev/null | grep -q "Sealed: true"; then
    echo "  ⚠️ Vault is sealed. You may need to unseal it using scripts/components/vault-unseal.sh"
    vault_status=2
fi

# Check gatekeeper
check_component "gatekeeper" "gatekeeper-system" "control-plane=controller-manager"
gatekeeper_status=$?

# Check minio
check_component "minio" "minio" "app=minio"
minio_status=$?

echo "========== Networking =========="

# Check ingress-nginx
check_component "ingress-nginx" "ingress-nginx" "app.kubernetes.io/component=controller"
ingress_status=$?

# Check if ingress has external IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -n "${INGRESS_IP}" ]; then
    echo "  ✅ Ingress has external IP: ${INGRESS_IP}"
else
    echo "  ⚠️ Ingress does not have an external IP."
    ingress_status=2
fi

# Check metallb
check_component "metallb" "metallb-system" "app=metallb"
metallb_status=$?

echo "========== Observability =========="

# Check prometheus
check_component "prometheus" "observability" "app=prometheus"
prometheus_status=$?

# Check grafana
check_component "grafana" "observability" "app.kubernetes.io/name=grafana"
grafana_status=$?

# Check loki
check_component "loki" "observability" "app=loki"
loki_status=$?

# Check if Grafana is accessible through service
check_service "grafana" "observability" "grafana"
grafana_service_status=$?

echo "========== Applications =========="

# Check supabase
check_component "supabase" "supabase"
supabase_status=$?

echo "========== Domain Resolution =========="

# Check if local domains are in /etc/hosts
echo "Checking if local domains are in /etc/hosts..."
if grep -q ".local" /etc/hosts; then
    echo "  ✅ Local domains found in /etc/hosts"
    
    # Output the current entries
    echo "  Current entries:"
    grep ".local" /etc/hosts
else
    echo "  ⚠️ No local domains found in /etc/hosts"
    echo "  You should add: ${INGRESS_IP} grafana.local prometheus.local vault.local supabase.local"
fi

# Check if Flux is installed
if kubectl get namespace flux-system &>/dev/null; then
    echo "========== GitOps (Flux) =========="
    
    # Check flux components
    check_component "flux" "flux-system" "app.kubernetes.io/part-of=flux"
    flux_status=$?
    
    # Check if git repository is configured
    if kubectl get gitrepositories -n flux-system &>/dev/null; then
        echo "  ✅ Flux Git repository is configured."
    else
        echo "  ⚠️ Flux Git repository is not configured."
        flux_status=2
    fi
    
    # Check kustomizations
    if kubectl get kustomizations -n flux-system &>/dev/null; then
        echo "  ✅ Flux kustomizations are configured."
    else
        echo "  ⚠️ Flux kustomizations are not configured."
        flux_status=2
    fi
fi

# Summary of results
echo "========================================"
echo "   Environment Verification Summary"
echo "========================================"
echo ""
echo "Core Infrastructure:"
echo "- cert-manager: $([ $cert_manager_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo "- sealed-secrets: $([ $sealed_secrets_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo "- vault: $([ $vault_status -eq 0 ] && echo "✅ OK" || ([ $vault_status -eq 2 ] && echo "⚠️ WARNINGS" || echo "❌ ISSUES"))"
echo "- gatekeeper: $([ $gatekeeper_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo "- minio: $([ $minio_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo ""
echo "Networking:"
echo "- ingress-nginx: $([ $ingress_status -eq 0 ] && echo "✅ OK" || ([ $ingress_status -eq 2 ] && echo "⚠️ WARNINGS" || echo "❌ ISSUES"))"
echo "- metallb: $([ $metallb_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo ""
echo "Observability:"
echo "- prometheus: $([ $prometheus_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo "- grafana: $([ $grafana_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo "- loki: $([ $loki_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo ""
echo "Applications:"
echo "- supabase: $([ $supabase_status -eq 0 ] && echo "✅ OK" || echo "❌ ISSUES")"
echo ""
if [ -n "$flux_status" ]; then
    echo "GitOps:"
    echo "- flux: $([ $flux_status -eq 0 ] && echo "✅ OK" || ([ $flux_status -eq 2 ] && echo "⚠️ WARNINGS" || echo "❌ ISSUES"))"
    echo ""
fi

# Check overall status
overall_status=0
for status in "$cert_manager_status" "$sealed_secrets_status" "$vault_status" "$gatekeeper_status" "$minio_status" \
              "$ingress_status" "$metallb_status" \
              "$prometheus_status" "$grafana_status" "$loki_status" \
              "$supabase_status"; do
    if [ "$status" -ne 0 ]; then
        overall_status=1
    fi
done

# Final result
if [ $overall_status -eq 0 ]; then
    echo "✅ Overall: All components are working correctly!"
else
    echo "⚠️ Overall: Some components have issues. Check the details above."
fi
echo "========================================" 