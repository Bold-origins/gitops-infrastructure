#!/bin/bash

# diagnose-component.sh: Diagnose issues with a specific component
# Provides detailed diagnostics for a component in the GitOps infrastructure

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <component-name>"
  echo "Example: $0 cert-manager"
  exit 1
fi

# Component to diagnose
COMPONENT="$1"

# Configuration
LOG_DIR="logs/diagnostics"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$COMPONENT-$(date +"%Y-%m-%d_%H-%M-%S").log"

# Function to log messages
log() {
  local message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Map component to namespace
get_namespace() {
  case "$COMPONENT" in
    "cert-manager") echo "cert-manager" ;;
    "sealed-secrets") echo "sealed-secrets" ;;
    "ingress") echo "ingress-nginx" ;;
    "metallb") echo "metallb-system" ;;
    "vault") echo "vault" ;;
    "minio") echo "minio-system" ;;
    "policy-engine") echo "policy-engine" ;;
    "security") echo "security" ;;
    "gatekeeper") echo "gatekeeper-system" ;;
    *) echo "$COMPONENT" ;;
  esac
}

NAMESPACE=$(get_namespace)

# Display banner
log "=========================================="
log "   Component Diagnostic: $COMPONENT"
log "   Namespace: $NAMESPACE"
log "=========================================="

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
  log "✅ Environment variables loaded from .env file"
else
  log "⚠️ Warning: .env file not found"
fi

# Check if namespace exists
log "Checking namespace $NAMESPACE..."
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  log "✅ Namespace exists"
else
  log "❌ Namespace does not exist"
fi

# Check Flux kustomization
log "Checking Flux kustomization for $COMPONENT..."
if kubectl get kustomization -n flux-system "single-$COMPONENT" &>/dev/null; then
  log "✅ Kustomization exists, checking status..."
  kubectl get kustomization -n flux-system "single-$COMPONENT" -o yaml
else
  log "❌ Kustomization does not exist"
fi

# Check local manifests
log "Checking local manifests for $COMPONENT..."
if [ -d "clusters/local/infrastructure/$COMPONENT" ]; then
  log "--- Directory listing ---"
  find "clusters/local/infrastructure/$COMPONENT" -type f | sort
  
  log "--- Kustomization file content ---"
  cat "clusters/local/infrastructure/$COMPONENT/kustomization.yaml"
  
  log "Running kustomize build to see what would be applied..."
  kustomize build "clusters/local/infrastructure/$COMPONENT"
else
  log "❌ Component directory does not exist at clusters/local/infrastructure/$COMPONENT"
fi

# Check if there are any deployments in the namespace
log "Checking deployments in namespace $NAMESPACE..."
kubectl get deployments -n "$NAMESPACE" 2>/dev/null || true

# Check if there are any pods in the namespace
log "Checking pods in namespace $NAMESPACE..."
kubectl get pods -n "$NAMESPACE" 2>/dev/null || true

# Check events in the namespace
log "Checking events in namespace $NAMESPACE..."
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10 2>/dev/null || true

# Check all resources in the namespace
log "All resources in namespace $NAMESPACE..."
kubectl get all -n "$NAMESPACE" 2>/dev/null || true

# Component-specific diagnostics
log "Checking $COMPONENT specific resources..."
case "$COMPONENT" in
  "cert-manager")
    # Check for CRDs
    kubectl get crds | grep cert-manager 2>/dev/null || log "No cert-manager CRDs found"
    
    # Check for cluster issuers
    kubectl get clusterissuers 2>/dev/null || log "No ClusterIssuers found"
    
    # Check for issues with HelmRepository/HelmRelease
    kubectl get helmrepository -A | grep jetstack || log "No jetstack HelmRepository found"
    kubectl get helmrelease -n cert-manager 2>/dev/null || log "No HelmRelease found in cert-manager namespace"
    kubectl get helmchart -A | grep cert-manager || log "No cert-manager HelmChart found"
    
    # Common cert-manager issues
    log "Checking for common cert-manager issues..."
    if kubectl get helmrepository -n cert-manager jetstack &>/dev/null && ! kubectl get helmrepository -n flux-system jetstack &>/dev/null; then
      log "⚠️ HelmRepository exists in cert-manager namespace but not in flux-system namespace"
      log "This may cause issues with the HelmRelease. Consider copying it to flux-system namespace."
    fi
    ;;
  "sealed-secrets")
    kubectl get -n sealed-secrets deployment sealed-secrets-controller 2>/dev/null || log "No sealed-secrets controller found"
    kubectl get sealedsecrets --all-namespaces 2>/dev/null || log "No SealedSecrets found or CRD not installed"
    ;;
  "ingress")
    kubectl get -n ingress-nginx deployment ingress-nginx-controller 2>/dev/null || log "No ingress-nginx controller found"
    kubectl get ingress --all-namespaces 2>/dev/null || true
    ;;
  "metallb")
    kubectl get -n metallb-system deployment controller 2>/dev/null || log "No MetalLB controller found"
    kubectl get ipaddresspools -n metallb-system 2>/dev/null || log "No IPAddressPools found or CRD not installed"
    kubectl get l2advertisements -n metallb-system 2>/dev/null || log "No L2Advertisements found or CRD not installed"
    ;;
  "vault")
    kubectl get -n vault statefulset vault 2>/dev/null || log "No Vault StatefulSet found"
    kubectl get -n vault pvc 2>/dev/null || log "No PVCs found for Vault"
    ;;
  # Add more component-specific checks as needed
  *)
    log "No specific diagnostics available for $COMPONENT"
    ;;
esac

# Check Flux reconciliation status
log "Checking Flux reconciliation status..."
flux get kustomization "single-$COMPONENT" 2>/dev/null || true

# Summary and recommendations
log "=========================================="
log "   Diagnostic Summary"
log "=========================================="

# Check for common issues and provide recommendations
if ! kubectl get deployments -n "$NAMESPACE" 2>/dev/null | grep -q .; then
  log "❌ No resources found for $COMPONENT in namespace $NAMESPACE"
  log "Recommendations:"
  log "1. Check the component's kustomization file to make sure it's correctly configured"
  log "2. Try manually running: kubectl apply -k clusters/local/infrastructure/$COMPONENT"
  log "3. Check for any CRDs that need to be installed first"
fi

# Check for timeout errors
if kubectl get kustomization -n flux-system "single-$COMPONENT" -o yaml 2>/dev/null | grep -q "timeout\|exceeded"; then
  log "⚠️ Timeout errors detected - component may need more time to initialize"
fi

log ""
log "Diagnostic log saved to: $LOG_FILE"
log "==========================================" 