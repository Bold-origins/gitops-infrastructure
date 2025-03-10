#!/bin/bash
# policy-engine.sh: Policy Engine Component Functions
# Handles all operations specific to policy engine component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="policy-engine"
NAMESPACE="policy-system"
COMPONENT_DEPENDENCIES=() # May depend on other security components in practice
RESOURCE_TYPES=("deployment" "service" "configmap" "policy")

# Pre-deployment function - runs before deployment
policy-engine_pre_deploy() {
  ui_log_info "Running policy-engine pre-deployment checks"

  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for policy-engine"
    return 1
  fi

  # Note: The policy engine may use a different Helm repo based on which engine you're using (Kyverno, OPA, etc.)
  # For this example, we'll assume it's using Kyverno as the policy engine

  # Add Helm repo if needed
  if ! helm repo list | grep -q "kyverno"; then
    ui_log_info "Adding Kyverno Helm repository"
    helm repo add kyverno https://kyverno.github.io/kyverno/
    helm repo update
  fi

  return 0
}

# Deploy function - deploys the component
policy-engine_deploy() {
  local deploy_mode="${1:-flux}"

  ui_log_info "Deploying policy-engine using $deploy_mode mode"

  case "$deploy_mode" in
  flux)
    # Deploy using Flux
    ui_log_info "Applying Flux kustomization for policy-engine"
    kubectl apply -f "${BASE_DIR}/clusters/local/infrastructure/policy-engine/kustomization.yaml"
    ;;

  kubectl)
    # Direct kubectl apply
    ui_log_info "Applying policy-engine manifests directly with kubectl"
    kubectl apply -k "${BASE_DIR}/clusters/local/infrastructure/policy-engine"
    ;;

  helm)
    # Helm-based installation
    ui_log_info "Deploying policy-engine with Helm"

    # Check if already installed
    if helm list -n "$NAMESPACE" | grep -q "kyverno"; then
      ui_log_info "Kyverno is already installed via Helm"
      return 0
    fi

    # Install with Helm
    ui_log_info "Installing Kyverno via Helm"
    helm install kyverno kyverno/kyverno -n "$NAMESPACE" \
      --set replicaCount=1 \
      --set resources.limits.cpu=500m \
      --set resources.limits.memory=512Mi \
      --set resources.requests.cpu=100m \
      --set resources.requests.memory=128Mi
    ;;

  *)
    ui_log_error "Invalid deployment mode: $deploy_mode"
    return 1
    ;;
  esac

  return 0
}

# Post-deployment function - runs after deployment
policy-engine_post_deploy() {
  ui_log_info "Running policy-engine post-deployment tasks"

  # Wait for policy engine controller to be ready
  ui_log_info "Waiting for policy engine controller to be ready"
  kubectl -n "$NAMESPACE" wait --for=condition=available --timeout=120s deployment/kyverno

  # Check webhook configurations
  ui_log_info "Checking webhook configurations"
  if kubectl get validatingwebhookconfigurations | grep -q "kyverno"; then
    ui_log_info "Kyverno validating webhook is configured"
  else
    ui_log_warning "Kyverno validating webhook is not configured"
  fi

  # Apply custom policies if they exist
  local policies_dir="${BASE_DIR}/clusters/local/infrastructure/policy-engine/policies"
  if [ -d "$policies_dir" ]; then
    ui_log_info "Applying custom policies from $policies_dir"
    kubectl apply -f "$policies_dir"
  else
    ui_log_info "No custom policies directory found at $policies_dir"
  fi

  return 0
}

# Verification function - verifies the component is working
policy-engine_verify() {
  ui_log_info "Verifying policy-engine installation"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Check if policy engine pods are running
  local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kyverno -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$pods" || "$pods" != *"Running"* ]]; then
    ui_log_error "Policy engine pods are not running"
    return 1
  fi

  ui_log_info "Policy engine pods are running"

  # Test policy functionality with a sample policy
  ui_log_info "Testing policy functionality with a sample policy"
  
  # Create a temporary policy file
  local temp_policy=$(mktemp)
  cat > "$temp_policy" <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: audit
  rules:
  - name: check-for-labels
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "label 'app.kubernetes.io/name' is required"
      pattern:
        metadata:
          labels:
            app.kubernetes.io/name: "?*"
EOF

  # Apply the policy
  kubectl apply -f "$temp_policy"
  
  # Check if policy was created
  if kubectl get clusterpolicy require-labels &>/dev/null; then
    ui_log_info "Sample policy was created successfully"
    
    # Clean up
    kubectl delete -f "$temp_policy"
    rm "$temp_policy"
  else
    ui_log_error "Failed to create sample policy"
    rm "$temp_policy"
    return 1
  fi

  ui_log_info "Policy engine verification completed successfully"
  return 0
}

# Cleanup function - removes the component
policy-engine_cleanup() {
  ui_log_info "Cleaning up policy-engine"

  # Delete any policies first
  ui_log_info "Deleting policies"
  kubectl delete clusterpolicies --all

  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "kyverno"; then
    ui_log_info "Uninstalling Kyverno Helm release"
    helm uninstall kyverno -n "$NAMESPACE"
  fi

  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/infrastructure/policy-engine/kustomization.yaml" --ignore-not-found

  # Delete namespace
  ui_log_info "Deleting namespace: $NAMESPACE"
  kubectl delete namespace "$NAMESPACE" --wait=false

  # Remove finalizers if needed
  sleep 2
  if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_info "Removing finalizers from namespace: $NAMESPACE"
    kubectl patch namespace "$NAMESPACE" --type json \
      -p='[{"op": "remove", "path": "/spec/finalizers"}]'
  fi

  ui_log_info "Cleanup completed successfully"
  return 0
}

# Diagnose function - provides detailed diagnostics
policy-engine_diagnose() {
  ui_log_info "Running policy-engine diagnostics"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Display component status
  ui_subheader "Policy Engine Pod Status"
  kubectl get pods -n "$NAMESPACE" -o wide

  # Display deployments
  ui_subheader "Policy Engine Deployments"
  kubectl get deployments -n "$NAMESPACE" -o wide

  # Display services
  ui_subheader "Policy Engine Services"
  kubectl get services -n "$NAMESPACE"

  # Display policies
  ui_subheader "Cluster Policies"
  kubectl get clusterpolicies

  # Display webhook configurations
  ui_subheader "Webhook Configurations"
  kubectl get validatingwebhookconfigurations | grep -E 'kyverno|policy'

  # Display logs from main controller
  ui_subheader "Controller Logs"
  local controller_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kyverno -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$controller_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$controller_pod" --tail=50
  else
    ui_log_error "No policy engine controller pod found"
  fi

  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20

  return 0
}

# Export functions
export -f policy-engine_pre_deploy
export -f policy-engine_deploy
export -f policy-engine_post_deploy
export -f policy-engine_verify
export -f policy-engine_cleanup
export -f policy-engine_diagnose

# If called directly, execute the specified function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "$1" == "policy-engine_pre_deploy" ]]; then
    policy-engine_pre_deploy
  elif [[ "$1" == "policy-engine_deploy" ]]; then
    policy-engine_deploy "$2"
  elif [[ "$1" == "policy-engine_post_deploy" ]]; then
    policy-engine_post_deploy
  elif [[ "$1" == "policy-engine_verify" ]]; then
    policy-engine_verify
  elif [[ "$1" == "policy-engine_cleanup" ]]; then
    policy-engine_cleanup
  elif [[ "$1" == "policy-engine_diagnose" ]]; then
    policy-engine_diagnose
  else
    echo "Usage: $0 [policy-engine_pre_deploy|policy-engine_deploy [mode]|policy-engine_post_deploy|policy-engine_verify|policy-engine_cleanup|policy-engine_diagnose]"
    exit 1
  fi
fi
