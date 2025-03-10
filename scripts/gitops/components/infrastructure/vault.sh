#!/bin/bash
# vault.sh: HashiCorp Vault Component Functions
# Handles all operations specific to Vault component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="vault"
NAMESPACE="vault"
COMPONENT_DEPENDENCIES=() # Technically depends on storage in production
RESOURCE_TYPES=("deployment" "service" "statefulset" "vault" "configmap" "secret")

# Pre-deployment function - runs before deployment
vault_pre_deploy() {
  ui_log_info "Running Vault pre-deployment checks"

  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Vault"
    return 1
  fi

  # Add Helm repo if needed
  if ! helm repo list | grep -q "hashicorp"; then
    ui_log_info "Adding HashiCorp Helm repository"
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
  fi

  # Check if kubectl-vault plugin is installed
  if ! command -v kubectl-vault &>/dev/null; then
    ui_log_warning "kubectl-vault plugin is not installed. Some operations may require it."
    ui_log_info "To install: https://www.vaultproject.io/docs/platform/k8s/helm/run#installing-the-vault-cli"
  fi

  return 0
}

# Deploy function - deploys the component
vault_deploy() {
  local deploy_mode="${1:-flux}"

  ui_log_info "Deploying Vault using $deploy_mode mode"

  case "$deploy_mode" in
  flux)
    # Deploy using Flux
    kubectl apply -f "${BASE_DIR}/clusters/local/infrastructure/vault/kustomization.yaml"
    ;;

  kubectl)
    # Direct kubectl apply
    ui_log_info "Applying Vault manifests directly with kubectl"
    kubectl apply -k "${BASE_DIR}/clusters/local/infrastructure/vault"
    ;;

  helm)
    # Helm-based installation
    ui_log_info "Deploying Vault with Helm"

    # Check if already installed
    if helm list -n "$NAMESPACE" | grep -q "vault"; then
      ui_log_info "Vault is already installed via Helm"
      return 0
    fi

    # For development, we'll use dev mode with memory storage
    # In production, you'd use HA mode with proper storage backends
    helm install vault hashicorp/vault -n "$NAMESPACE" \
      --set "server.dev.enabled=true" \
      --set "server.logLevel=debug" \
      --set "ui.enabled=true" \
      --set "ui.serviceType=ClusterIP" \
      --set "server.dataStorage.enabled=false"
    ;;

  *)
    ui_log_error "Invalid deployment mode: $deploy_mode"
    return 1
    ;;
  esac

  return $?
}

# Post-deployment function - runs after deployment
vault_post_deploy() {
  ui_log_info "Running Vault post-deployment tasks"

  # Wait for vault to be ready
  ui_log_info "Waiting for Vault to be ready"

  # For dev mode deployment
  if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' | grep -q "vault-0"; then
    # StatefulSet deployment (HA mode)
    kubectl rollout status statefulset vault -n "$NAMESPACE" --timeout=180s
  else
    # Deployment (dev mode)
    kubectl rollout status deployment vault -n "$NAMESPACE" --timeout=180s
  fi

  # Check if Vault is running
  local vault_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
  if [ -z "$vault_pod" ]; then
    ui_log_error "No Vault pod found"
    return 1
  fi

  ui_log_info "Vault pod is running: $vault_pod"

  # For development environments, Vault is likely running in dev mode
  # In dev mode, it's already initialized and unsealed
  # In production, you would need to initialize and unseal Vault

  # Get Vault status
  ui_log_info "Checking Vault status"
  kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault status || true

  return 0
}

# Verification function - verifies the component is working
vault_verify() {
  ui_log_info "Verifying Vault installation"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Check if vault is running
  local vault_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
  if [ -z "$vault_pod" ]; then
    ui_log_error "No Vault pod found"
    return 1
  fi

  # Check if vault pod is running
  local pod_status=$(kubectl get pod -n "$NAMESPACE" "$vault_pod" -o jsonpath='{.status.phase}')
  if [[ "$pod_status" != "Running" ]]; then
    ui_log_error "Vault pod is not running, current status: $pod_status"
    return 1
  fi

  # Check if vault service exists
  if ! kubectl get service vault -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "Vault service not found"
    return 1
  fi

  # For dev mode, verify Vault is unsealed
  ui_log_info "Checking if Vault is unsealed"
  local sealed_status=$(kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault status -format=json 2>/dev/null | grep -o '"sealed":[^,}]*' | cut -d ":" -f2)
  if [[ "$sealed_status" == "false" ]]; then
    ui_log_success "Vault is unsealed"
  else
    ui_log_warning "Vault is sealed, you may need to unseal it manually"
    return 1
  fi

  # Test basic vault functionality
  ui_log_info "Testing basic Vault functionality by writing a test secret"
  if kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault kv put secret/test key=value; then
    ui_log_success "Successfully wrote test secret to Vault"
    kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault kv get secret/test
    kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault kv delete secret/test
  else
    ui_log_error "Failed to write test secret to Vault"
    return 1
  fi

  ui_log_success "Vault verification completed successfully"
  return 0
}

# Cleanup function - removes the component
vault_cleanup() {
  ui_log_info "Cleaning up Vault"

  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "vault"; then
    ui_log_info "Uninstalling Vault Helm release"
    helm uninstall vault -n "$NAMESPACE"
  fi

  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/infrastructure/vault/kustomization.yaml" --ignore-not-found

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

  # Check for any CRDs and remove them
  for crd in $(kubectl get crd | grep vault | awk '{print $1}'); do
    ui_log_info "Deleting CRD: $crd"
    kubectl delete crd "$crd"
  done

  return 0
}

# Diagnose function - provides detailed diagnostics
vault_diagnose() {
  ui_log_info "Running Vault diagnostics"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Display pod status
  ui_subheader "Vault Pod Status"
  kubectl get pods -n "$NAMESPACE" -o wide

  # Display deployments or statefulsets
  if kubectl get statefulset vault -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "Vault StatefulSet"
    kubectl get statefulset vault -n "$NAMESPACE" -o yaml
  elif kubectl get deployment vault -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "Vault Deployment"
    kubectl get deployment vault -n "$NAMESPACE" -o yaml
  fi

  # Display services
  ui_subheader "Vault Services"
  kubectl get services -n "$NAMESPACE"

  # Display configmaps
  ui_subheader "Vault ConfigMaps"
  kubectl get configmap -n "$NAMESPACE" -l app.kubernetes.io/name=vault

  # Display secrets (excluding content)
  ui_subheader "Vault Secrets"
  kubectl get secrets -n "$NAMESPACE" -l app.kubernetes.io/name=vault

  # Get Vault status
  ui_subheader "Vault Status"
  local vault_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
  if [ -n "$vault_pod" ]; then
    kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault status || true

    # Check if initialized
    ui_log_info "Checking if Vault is initialized"
    kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault status -format=json | grep initialized || true

    # Check seal status
    ui_log_info "Checking if Vault is sealed"
    kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault status -format=json | grep sealed || true

    # Check Vault CLI version
    ui_log_info "Checking Vault CLI version"
    kubectl exec -n "$NAMESPACE" "$vault_pod" -- vault version || true
  else
    ui_log_error "No Vault pod found"
  fi

  # Check pod logs
  ui_subheader "Vault Pod Logs"
  if [ -n "$vault_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$vault_pod" --tail=50
  fi

  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20

  return 0
}

# Export functions
export -f vault_pre_deploy
export -f vault_deploy
export -f vault_post_deploy
export -f vault_verify
export -f vault_cleanup
export -f vault_diagnose
