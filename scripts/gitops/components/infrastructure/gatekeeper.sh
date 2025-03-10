#!/bin/bash
# gatekeeper.sh: Gatekeeper Component Functions
# Handles all operations specific to OPA Gatekeeper component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="gatekeeper"
NAMESPACE="gatekeeper-system"
COMPONENT_DEPENDENCIES=()  # No explicit dependencies
RESOURCE_TYPES=("deployment" "service" "constrainttemplate" "constraint" "config")

# Pre-deployment function - runs before deployment
gatekeeper_pre_deploy() {
  ui_log_info "Running Gatekeeper pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Gatekeeper"
    return 1
  fi
  
  # Add Helm repo if needed
  if ! helm repo list | grep -q "gatekeeper"; then
    ui_log_info "Adding Gatekeeper Helm repository"
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
    helm repo update
  fi
  
  return 0
}

# Deploy function - deploys the component
gatekeeper_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Gatekeeper using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      kubectl apply -f "${BASE_DIR}/clusters/local/infrastructure/gatekeeper/kustomization.yaml"
      ;;
    
    kubectl)
      # Direct kubectl apply
      ui_log_info "Applying Gatekeeper manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/infrastructure/gatekeeper"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying Gatekeeper with Helm"
      
      # Check if already installed
      if helm list -n "$NAMESPACE" | grep -q "gatekeeper"; then
        ui_log_info "Gatekeeper is already installed via Helm"
        return 0
      fi
      
      # Install with Helm
      helm install gatekeeper gatekeeper/gatekeeper -n "$NAMESPACE" \
        --set replicas=1 \
        --set auditInterval=300 \
        --set constraintViolationsLimit=100 \
        --set audit.resources.limits.cpu=500m \
        --set audit.resources.limits.memory=512Mi \
        --set audit.resources.requests.cpu=100m \
        --set audit.resources.requests.memory=256Mi \
        --set controllerManager.resources.limits.cpu=500m \
        --set controllerManager.resources.limits.memory=512Mi \
        --set controllerManager.resources.requests.cpu=100m \
        --set controllerManager.resources.requests.memory=256Mi
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
gatekeeper_post_deploy() {
  ui_log_info "Running Gatekeeper post-deployment tasks"
  
  # Wait for deployment to be ready
  ui_log_info "Waiting for Gatekeeper audit controller to be ready"
  kubectl rollout status deployment gatekeeper-audit -n "$NAMESPACE" --timeout=180s
  
  ui_log_info "Waiting for Gatekeeper controller manager to be ready"
  kubectl rollout status deployment gatekeeper-controller-manager -n "$NAMESPACE" --timeout=180s
  
  # Wait for webhooks to be ready
  ui_log_info "Checking webhook configurations"
  if kubectl get validatingwebhookconfigurations gatekeeper-validating-webhook-configuration &>/dev/null; then
    ui_log_success "Gatekeeper validating webhook is configured"
  else
    ui_log_warning "Gatekeeper validating webhook is not configured"
  fi
  
  # Check and apply example constraints if available
  local constraints_dir="${BASE_DIR}/clusters/local/infrastructure/gatekeeper/constraints"
  if [ -d "$constraints_dir" ]; then
    ui_log_info "Applying example constraints from $constraints_dir"
    kubectl apply -f "$constraints_dir"
  else
    ui_log_info "No example constraints directory found at $constraints_dir"
  fi
  
  return 0
}

# Verification function - verifies the component is working
gatekeeper_verify() {
  ui_log_info "Verifying Gatekeeper installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check if audit controller is running
  if ! kubectl get deployment gatekeeper-audit -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "Gatekeeper audit controller deployment not found"
    return 1
  fi
  
  # Check if controller manager is running
  if ! kubectl get deployment gatekeeper-controller-manager -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "Gatekeeper controller manager deployment not found"
    return 1
  fi
  
  # Check if pods are running
  local audit_pods=$(kubectl get pods -n "$NAMESPACE" -l control-plane=audit-controller -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$audit_pods" || "$audit_pods" != *"Running"* ]]; then
    ui_log_error "Gatekeeper audit controller pods are not running"
    return 1
  fi
  
  local controller_pods=$(kubectl get pods -n "$NAMESPACE" -l control-plane=controller-manager -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$controller_pods" || "$controller_pods" != *"Running"* ]]; then
    ui_log_error "Gatekeeper controller manager pods are not running"
    return 1
  fi
  
  # Check if validating webhook is configured
  if ! kubectl get validatingwebhookconfigurations gatekeeper-validating-webhook-configuration &>/dev/null; then
    ui_log_error "Gatekeeper validating webhook configuration not found"
    return 1
  fi
  
  # Check if any constraint templates are defined
  local constraint_templates=$(kubectl get constrainttemplates -o jsonpath='{.items[*].metadata.name}')
  if [ -z "$constraint_templates" ]; then
    ui_log_warning "No constraint templates found. Gatekeeper won't enforce any policies yet."
  else
    ui_log_success "Found constraint templates: $constraint_templates"
  fi
  
  # Test Gatekeeper with a simple constraint template and constraint
  ui_log_info "Testing Gatekeeper with a simple constraint to verify it's working"
  
  # Create a test namespace
  kubectl create namespace gatekeeper-test 2>/dev/null || true
  
  # Create a test constraint template that requires certain labels
  cat <<EOF | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          input.review.object.kind == "Namespace"
          input.review.object.metadata.labels != null
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Namespace is missing required labels: %v", [missing])
        }
EOF
  
  # Create a constraint based on the template
  cat <<EOF | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-require-test-label
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["test-label"]
EOF
  
  # Wait for the constraint to be active
  sleep 5
  
  # Create a namespace without required label
  ui_log_info "Testing constraint with a namespace missing required label"
  if ! kubectl create namespace gatekeeper-test-missing-label 2>/dev/null; then
    ui_log_success "Gatekeeper correctly blocked namespace without required label"
  else
    ui_log_warning "Gatekeeper did not block namespace without required label. It may still be initializing."
    kubectl delete namespace gatekeeper-test-missing-label
  fi
  
  # Create a namespace with required label
  ui_log_info "Testing constraint with a namespace having required label"
  kubectl create namespace gatekeeper-test-with-label --dry-run=client -o yaml | \
    kubectl label --dry-run=client -f - test-label=true -o yaml | \
    kubectl apply -f -
  
  # Check if the labeled namespace was created
  if kubectl get namespace gatekeeper-test-with-label &>/dev/null; then
    ui_log_success "Gatekeeper correctly allowed namespace with required label"
    kubectl delete namespace gatekeeper-test-with-label
  else
    ui_log_warning "Namespace with required label not created. Gatekeeper may be misconfigured."
  fi
  
  # Clean up test resources
  kubectl delete constraint ns-require-test-label
  kubectl delete constrainttemplate k8srequiredlabels
  kubectl delete namespace gatekeeper-test
  
  ui_log_success "Gatekeeper verification completed"
  return 0
}

# Cleanup function - removes the component
gatekeeper_cleanup() {
  ui_log_info "Cleaning up Gatekeeper"
  
  # Remove any constraints and constraint templates first
  ui_log_info "Removing any constraints"
  kubectl get constraints --no-headers -o custom-columns=":metadata.name" 2>/dev/null | \
    xargs --no-run-if-empty kubectl delete constraint
  
  ui_log_info "Removing any constraint templates"
  kubectl get constrainttemplates --no-headers -o custom-columns=":metadata.name" 2>/dev/null | \
    xargs --no-run-if-empty kubectl delete constrainttemplate
  
  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "gatekeeper"; then
    ui_log_info "Uninstalling Gatekeeper Helm release"
    helm uninstall gatekeeper -n "$NAMESPACE"
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/infrastructure/gatekeeper/kustomization.yaml" --ignore-not-found
  
  # Remove webhook configurations
  if kubectl get validatingwebhookconfigurations gatekeeper-validating-webhook-configuration &>/dev/null; then
    ui_log_info "Deleting Gatekeeper validating webhook configuration"
    kubectl delete validatingwebhookconfigurations gatekeeper-validating-webhook-configuration
  fi
  
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
  for crd in $(kubectl get crd | grep gatekeeper.sh | awk '{print $1}'); do
    ui_log_info "Deleting CRD: $crd"
    kubectl delete crd "$crd"
  done
  
  return 0
}

# Diagnose function - provides detailed diagnostics
gatekeeper_diagnose() {
  ui_log_info "Running Gatekeeper diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Display pod status
  ui_subheader "Gatekeeper Pod Status"
  kubectl get pods -n "$NAMESPACE" -o wide
  
  # Display deployments
  ui_subheader "Gatekeeper Deployments"
  kubectl get deployment -n "$NAMESPACE" -o yaml
  
  # Display services
  ui_subheader "Gatekeeper Services"
  kubectl get services -n "$NAMESPACE"
  
  # Display webhook configurations
  ui_subheader "Gatekeeper Webhook Configurations"
  kubectl get validatingwebhookconfigurations | grep gatekeeper
  
  # Display constraint templates
  ui_subheader "Gatekeeper Constraint Templates"
  kubectl get constrainttemplates
  
  # Display constraints
  ui_subheader "Gatekeeper Constraints"
  kubectl get constraints --all-namespaces
  
  # Display CRDs
  ui_subheader "Gatekeeper CRDs"
  kubectl get crd | grep gatekeeper.sh
  
  # Check Pod logs
  ui_subheader "Gatekeeper Audit Controller Logs"
  local audit_pod=$(kubectl get pods -n "$NAMESPACE" -l control-plane=audit-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$audit_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$audit_pod" --tail=30
  else
    ui_log_error "No Gatekeeper audit controller pod found"
  fi
  
  ui_subheader "Gatekeeper Controller Manager Logs"
  local controller_pod=$(kubectl get pods -n "$NAMESPACE" -l control-plane=controller-manager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$controller_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$controller_pod" --tail=30
  else
    ui_log_error "No Gatekeeper controller manager pod found"
  fi
  
  # Check for audits
  ui_subheader "Gatekeeper Audit Results"
  kubectl get constraints -o json | jq '.items[].status.violations'
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20
  
  return 0
}

# Export functions
export -f gatekeeper_pre_deploy
export -f gatekeeper_deploy
export -f gatekeeper_post_deploy
export -f gatekeeper_verify
export -f gatekeeper_cleanup
export -f gatekeeper_diagnose 