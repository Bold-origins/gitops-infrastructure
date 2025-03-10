#!/bin/bash
# cert-manager.sh: Cert Manager Component Functions
# Handles all operations specific to cert-manager component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${BASE_DIR}/scripts/lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="cert-manager"
NAMESPACE="cert-manager"
COMPONENT_DEPENDENCIES=() # No dependencies
RESOURCE_TYPES=("deployment" "service" "secret" "certificate" "issuer" "clusterissuer")

# Pre-deployment function - runs before deployment
cert_manager_pre_deploy() {
  ui_log_info "Running cert-manager pre-deployment checks"

  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for cert-manager"
    return 1
  fi

  # Add Helm repo if needed
  if ! helm repo list | grep -q "jetstack"; then
    ui_log_info "Adding jetstack Helm repository for cert-manager"
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
  fi

  return 0
}

# Deploy function - deploys the component
cert_manager_deploy() {
  local deploy_mode="${1:-flux}"

  ui_log_info "Deploying cert-manager using $deploy_mode mode"

  case "$deploy_mode" in
  flux)
    # Deploy using Flux
    kubectl apply -f "${BASE_DIR}/clusters/local/infrastructure/cert-manager/kustomization.yaml"
    ;;

  kubectl)
    # Direct kubectl apply
    ui_log_info "Applying cert-manager manifests directly with kubectl"
    kubectl apply -k "${BASE_DIR}/clusters/local/infrastructure/cert-manager"
    ;;

  helm)
    # Helm-based installation
    ui_log_info "Deploying cert-manager with Helm"

    # Check if already installed
    if helm list -n "$NAMESPACE" | grep -q "cert-manager"; then
      ui_log_info "cert-manager is already installed via Helm"
      return 0
    fi

    # Install CRDs first
    ui_log_info "Installing cert-manager CRDs"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.crds.yaml

    # Install with Helm
    helm install cert-manager jetstack/cert-manager -n "$NAMESPACE" \
      --version v1.12.0 \
      --set installCRDs=false \
      --set webhook.timeoutSeconds=30 \
      --set cainjector.enabled=true
    ;;

  *)
    ui_log_error "Invalid deployment mode: $deploy_mode"
    return 1
    ;;
  esac

  return $?
}

# Post-deployment function - runs after deployment
cert_manager_post_deploy() {
  ui_log_info "Running cert-manager post-deployment tasks"

  # Wait for deployment to be ready
  ui_log_info "Waiting for cert-manager controller to be ready"
  kubectl rollout status deployment cert-manager -n "$NAMESPACE" --timeout=120s

  ui_log_info "Waiting for cert-manager webhook to be ready"
  kubectl rollout status deployment cert-manager-webhook -n "$NAMESPACE" --timeout=120s

  ui_log_info "Waiting for cert-manager cainjector to be ready"
  kubectl rollout status deployment cert-manager-cainjector -n "$NAMESPACE" --timeout=120s

  # Sleep to allow the controller to initialize properly
  sleep 5

  # Check the CRDs
  if kubectl get crd certificates.cert-manager.io issuers.cert-manager.io clusterissuers.cert-manager.io &>/dev/null; then
    ui_log_success "cert-manager CRDs are installed"
  else
    ui_log_warning "cert-manager CRDs are not installed, cert-manager might not function correctly"
  fi

  return 0
}

# Verification function - verifies the component is working
cert_manager_verify() {
  ui_log_info "Verifying cert-manager installation"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Check if controller is running
  if ! kubectl get deployment cert-manager -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "cert-manager controller deployment not found"
    return 1
  fi

  # Check if webhook is running
  if ! kubectl get deployment cert-manager-webhook -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "cert-manager webhook deployment not found"
    return 1
  fi

  # Check if cainjector is running
  if ! kubectl get deployment cert-manager-cainjector -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "cert-manager cainjector deployment not found"
    return 1
  fi

  # Check if pods are running
  local pods=$(kubectl get pods -n "$NAMESPACE" -l app=cert-manager -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$pods" || "$pods" != *"Running"* ]]; then
    ui_log_error "cert-manager pods are not running"
    return 1
  fi

  # Check if CRDs exist
  if ! kubectl get crd certificates.cert-manager.io issuers.cert-manager.io clusterissuers.cert-manager.io &>/dev/null; then
    ui_log_error "cert-manager CRDs are not installed"
    return 1
  fi

  ui_log_success "cert-manager verification successful"
  return 0
}

# Cleanup function - removes the component
cert_manager_cleanup() {
  ui_log_info "Cleaning up cert-manager"

  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "cert-manager"; then
    ui_log_info "Uninstalling cert-manager Helm release"
    helm uninstall cert-manager -n "$NAMESPACE"
  fi

  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/infrastructure/cert-manager/kustomization.yaml" --ignore-not-found

  # Delete namespace
  if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_info "Deleting namespace: $NAMESPACE"
    kubectl delete namespace "$NAMESPACE" --wait=false

    # Remove finalizers if needed
    sleep 2
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
      ui_log_warning "Removing finalizers from namespace: $NAMESPACE"
      kubectl patch namespace "$NAMESPACE" --type json \
        -p='[{"op": "remove", "path": "/spec/finalizers"}]'
    fi
  fi

  # Clean up CRDs
  if kubectl get crd certificates.cert-manager.io &>/dev/null; then
    ui_log_info "Deleting cert-manager CRDs"
    kubectl delete crd certificates.cert-manager.io certificaterequests.cert-manager.io challenges.acme.cert-manager.io clusterissuers.cert-manager.io issuers.cert-manager.io orders.acme.cert-manager.io
  fi

  return 0
}

# Diagnose function - provides detailed diagnostics
cert_manager_diagnose() {
  ui_log_info "Running cert-manager diagnostics"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Display component status
  ui_subheader "Cert Manager Pod Status"
  kubectl get pods -n "$NAMESPACE" -o wide

  # Display deployments
  ui_subheader "Cert Manager Deployments"
  kubectl get deployment -n "$NAMESPACE"

  # Display individual deployments
  ui_subheader "Cert Manager Controller Deployment"
  kubectl get deployment cert-manager -n "$NAMESPACE" -o yaml

  ui_subheader "Cert Manager Webhook Deployment"
  kubectl get deployment cert-manager-webhook -n "$NAMESPACE" -o yaml

  ui_subheader "Cert Manager CAInjector Deployment"
  kubectl get deployment cert-manager-cainjector -n "$NAMESPACE" -o yaml

  # Display services
  ui_subheader "Cert Manager Services"
  kubectl get services -n "$NAMESPACE"

  # Display CRDs
  ui_subheader "Cert Manager CRDs"
  kubectl get crd | grep cert-manager.io

  # Check for Issuers and ClusterIssuers
  ui_subheader "Cert Manager Issuers"
  kubectl get issuers --all-namespaces 2>/dev/null ||
    ui_log_warning "No Issuers found"

  ui_subheader "Cert Manager ClusterIssuers"
  kubectl get clusterissuers 2>/dev/null ||
    ui_log_warning "No ClusterIssuers found"

  # Check for Certificates
  ui_subheader "Cert Manager Certificates"
  kubectl get certificates --all-namespaces 2>/dev/null ||
    ui_log_warning "No Certificates found"

  # Check for pod logs
  ui_subheader "Controller Logs"
  local pod=$(kubectl get pods -n "$NAMESPACE" -l app=cert-manager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$pod" ]; then
    kubectl logs -n "$NAMESPACE" "$pod" --tail=50
  else
    ui_log_error "No cert-manager controller pod found"
  fi

  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20

  return 0
}

# Export functions
export -f cert_manager_pre_deploy
export -f cert_manager_deploy
export -f cert_manager_post_deploy
export -f cert_manager_verify
export -f cert_manager_cleanup
export -f cert_manager_diagnose
