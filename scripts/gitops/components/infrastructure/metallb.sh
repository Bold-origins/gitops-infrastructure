#!/bin/bash
# metallb.sh: MetalLB Component Functions
# Handles all operations specific to metallb component

# Get script directory and repository root (with proper error handling)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Source shared libraries
if [[ -f "${REPO_ROOT}/scripts/lib/ui.sh" ]]; then
  source "${REPO_ROOT}/scripts/lib/ui.sh"
else
  echo "ERROR: ui.sh library not found at ${REPO_ROOT}/scripts/lib/ui.sh" >&2
  exit 1
fi

# Simple echo function to use when ui functions might not be available
log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

# Component-specific configuration
COMPONENT_NAME="metallb"
NAMESPACE="metallb-system"
COMPONENT_DEPENDENCIES=() # No dependencies
RESOURCE_TYPES=("deployment" "service" "ipaddresspool" "l2advertisement")

# Helper function to validate path exists
validate_dir() {
  local dir_path="$1"
  local description="$2"

  if [[ ! -d "$dir_path" ]]; then
    log_error "$description directory not found: $dir_path"
    return 1
  fi

  log_info "$description directory found: $dir_path"
  return 0
}

# Pre-deployment function - runs before deployment
metallb_pre_deploy() {
  log_info "Running metallb pre-deployment checks"

  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  echo "Namespace created or already exists"

  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    log_error "Helm is not installed but required for metallb"
    return 1
  fi
  echo "Helm is installed"

  # Add Helm repo if needed
  if ! helm repo list | grep -q "metallb"; then
    log_info "Adding metallb Helm repository"
    helm repo add metallb https://metallb.github.io/metallb
    helm repo update
  else
    echo "MetalLB Helm repository already added"
  fi

  # Validate that required paths exist
  validate_dir "${REPO_ROOT}/clusters/local/infrastructure/metallb" "MetalLB kustomization directory" || return 1

  log_info "Pre-deployment checks completed successfully"
  return 0
}

# Deploy function - deploys the component
metallb_deploy() {
  local deploy_mode="${1:-flux}"

  log_info "Deploying metallb using $deploy_mode mode"

  case "$deploy_mode" in
  flux)
    # Deploy using Flux
    log_info "Applying Flux kustomization for MetalLB"
    kubectl apply -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/kustomization.yaml"
    ;;

  kubectl)
    # Direct kubectl apply
    log_info "Applying metallb manifests directly with kubectl"
    
    # First, check if CRDs exist, and if not, install them
    if ! kubectl get crd ipaddresspools.metallb.io &>/dev/null; then
      log_info "MetalLB CRDs not found, installing them first..."
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml
      
      # Wait for CRDs to be established
      log_info "Waiting for MetalLB CRDs to be established..."
      kubectl wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io
      kubectl wait --for condition=established --timeout=60s crd/l2advertisements.metallb.io
      
      # Wait for controller deployment
      log_info "Waiting for controller deployment to be ready..."
      kubectl -n metallb-system rollout status deployment/controller --timeout=90s
      
      # Wait for webhook service to be ready
      log_info "Waiting for webhook service to be ready..."
      # Sleep to allow the webhook service to become ready
      sleep 15
    else
      log_info "MetalLB CRDs already installed"
    fi
    
    # Now apply the kustomization with retries for webhook issues
    log_info "Applying MetalLB kustomization with retries"
    local retry_count=0
    local max_retries=3
    local success=false
    
    while [[ $retry_count -lt $max_retries && $success == false ]]; do
      if kubectl apply -k "${REPO_ROOT}/clusters/local/infrastructure/metallb" 2>/dev/null; then
        success=true
        log_info "Successfully applied MetalLB kustomization"
      else
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
          log_info "Webhook not ready yet, retrying in 10 seconds (attempt $retry_count of $max_retries)..."
          sleep 10
        else
          log_info "Maximum retries reached. Will attempt to apply resources individually."
        fi
      fi
    done
    
    # If kustomize application failed, apply IPAddressPool and L2Advertisement manually after a delay
    if [[ $success == false ]]; then
      log_info "Applying MetalLB configuration resources individually"
      
      # Wait a bit more for the webhook to be ready
      sleep 10
      
      # Apply the IPAddressPool
      log_info "Applying IPAddressPool configuration"
      if kubectl apply -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/patches/ipaddresspool-patch.yaml"; then
        log_info "Successfully applied IPAddressPool"
      else
        log_info "Failed to apply IPAddressPool, will retry during post-deployment"
      fi
      
      # Apply L2Advertisement
      if [[ -f "${REPO_ROOT}/clusters/base/infrastructure/metallb/l2advertisement.yaml" ]]; then
        log_info "Applying L2Advertisement configuration"
        if kubectl apply -f "${REPO_ROOT}/clusters/base/infrastructure/metallb/l2advertisement.yaml"; then
          log_info "Successfully applied L2Advertisement"
        else
          log_info "Failed to apply L2Advertisement, will retry during post-deployment"
        fi
      fi
    fi
    ;;

  helm)
    # Helm-based installation
    log_info "Deploying metallb with Helm"

    # Check if already installed
    if helm list -n "$NAMESPACE" | grep -q "metallb"; then
      log_info "metallb is already installed via Helm"
      return 0
    fi

    # Install CRDs first
    log_info "Installing MetalLB CRDs"
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-crds.yaml
    
    # Wait for CRDs to be established
    log_info "Waiting for MetalLB CRDs to be established..."
    kubectl wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io
    kubectl wait --for condition=established --timeout=60s crd/l2advertisements.metallb.io

    # Install with Helm
    log_info "Installing MetalLB via Helm"
    helm install metallb metallb/metallb -n "$NAMESPACE" \
      --set speaker.frr.enabled=false \
      --set speaker.logLevel=debug \
      --set controller.logLevel=debug

    # Wait for controller to be ready
    log_info "Waiting for MetalLB controller to be ready..."
    kubectl -n "$NAMESPACE" rollout status deployment/controller --timeout=90s
    
    # Wait for webhook service to be ready
    log_info "Waiting for webhook service to be ready..."
    sleep 15

    # Apply IP address pool configuration with retries
    log_info "Applying IPAddressPool with retries..."
    local retry_count=0
    local max_retries=3
    local success=false
    
    while [[ $retry_count -lt $max_retries && $success == false ]]; do
      if [ -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/config/ipaddresspool.yaml" ]; then
        if kubectl apply -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/config/ipaddresspool.yaml"; then
          success=true
          log_info "Successfully applied IPAddressPool configuration from config directory"
        else
          retry_count=$((retry_count + 1))
          sleep 10
        fi
      else
        if kubectl apply -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/patches/ipaddresspool-patch.yaml"; then
          success=true
          log_info "Successfully applied IPAddressPool patch"
        else
          retry_count=$((retry_count + 1))
          sleep 10
        fi
      fi
    done
    
    if [[ $success == false ]]; then
      log_info "Failed to apply IPAddressPool after $max_retries attempts, will retry during post-deployment"
    fi

    # Apply L2Advertisement configuration with retries
    log_info "Applying L2Advertisement with retries..."
    retry_count=0
    success=false
    
    while [[ $retry_count -lt $max_retries && $success == false ]]; do
      if [ -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/config/l2advertisement.yaml" ]; then
        if kubectl apply -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/config/l2advertisement.yaml"; then
          success=true
          log_info "Successfully applied L2Advertisement configuration from config directory"
        else
          retry_count=$((retry_count + 1))
          sleep 10
        fi
      else
        if kubectl apply -f "${REPO_ROOT}/clusters/base/infrastructure/metallb/l2advertisement.yaml"; then
          success=true
          log_info "Successfully applied L2Advertisement from base directory"
        else
          retry_count=$((retry_count + 1))
          sleep 10
        fi
      fi
    done
    
    if [[ $success == false ]]; then
      log_info "Failed to apply L2Advertisement after $max_retries attempts, will retry during post-deployment"
    fi
    ;;

  *)
    log_error "Invalid deployment mode: $deploy_mode"
    return 1
    ;;
  esac

  log_info "Deployment completed"
  return 0
}

# Post-deployment function - runs after deployment
metallb_post_deploy() {
  log_info "Running metallb post-deployment tasks"

  # Wait for deployment to be ready
  log_info "Waiting for metallb controller to be ready"
  kubectl rollout status deployment controller -n "$NAMESPACE" --timeout=120s

  # Wait for daemonset to be ready
  log_info "Waiting for metallb speaker to be ready"
  kubectl rollout status daemonset speaker -n "$NAMESPACE" --timeout=120s

  # Sleep to allow the controller to initialize properly
  sleep 5

  # Check if IPAddressPool CRD exists
  if kubectl get crd ipaddresspools.metallb.io l2advertisements.metallb.io &>/dev/null; then
    log_info "MetalLB CRDs are installed successfully"
    
    # Check if we have any IPAddressPools, if not retry applying them
    if ! kubectl get ipaddresspools -n "$NAMESPACE" &>/dev/null; then
      log_info "No IPAddressPools found, attempting to apply them now"
      
      # Try applying the IPAddressPool again
      if [ -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/config/ipaddresspool.yaml" ]; then
        log_info "Applying IPAddressPool from config directory"
        kubectl apply -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/config/ipaddresspool.yaml"
      else
        log_info "Applying IPAddressPool from patches directory"
        kubectl apply -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/patches/ipaddresspool-patch.yaml"
      fi
      
      # Sleep to allow the resource to be processed
      sleep 5
    fi
    
    # Check if we have any L2Advertisements, if not retry applying them
    if ! kubectl get l2advertisements -n "$NAMESPACE" &>/dev/null; then
      log_info "No L2Advertisements found, attempting to apply them now"
      
      # Try applying the L2Advertisement again
      if [ -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/config/l2advertisement.yaml" ]; then
        log_info "Applying L2Advertisement from config directory"
        kubectl apply -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/config/l2advertisement.yaml"
      else
        log_info "Applying L2Advertisement from base directory"
        kubectl apply -f "${REPO_ROOT}/clusters/base/infrastructure/metallb/l2advertisement.yaml"
      fi
      
      # Sleep to allow the resource to be processed
      sleep 5
    fi
  else
    log_info "WARNING: MetalLB CRDs are not installed, MetalLB might not function correctly"
  fi

  # Final verification of resources
  if kubectl get ipaddresspools -n "$NAMESPACE" 2>/dev/null; then
    log_info "MetalLB IP address pools are configured successfully"
  else
    log_info "WARNING: No MetalLB IP address pools found. Services of type LoadBalancer may not work."
  fi
  
  if kubectl get l2advertisements -n "$NAMESPACE" 2>/dev/null; then
    log_info "MetalLB L2Advertisements are configured successfully"
  else
    log_info "WARNING: No MetalLB L2Advertisements found. Services of type LoadBalancer may not work."
  fi

  log_info "Post-deployment tasks completed"
  return 0
}

# Verification function - verifies the component is working
metallb_verify() {
  log_info "Verifying metallb installation"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Check if controller is running
  if ! kubectl get deployment controller -n "$NAMESPACE" &>/dev/null; then
    log_error "metallb controller deployment not found"
    return 1
  fi

  # Check if speaker is running
  if ! kubectl get daemonset speaker -n "$NAMESPACE" &>/dev/null; then
    log_error "metallb speaker daemonset not found"
    return 1
  fi

  # Check if controller pods are running
  local controller_pods=$(kubectl get pods -n "$NAMESPACE" -l app=metallb,component=controller -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$controller_pods" || "$controller_pods" != "Running" ]]; then
    log_error "metallb controller pod is not running"
    return 1
  fi

  # Check if speaker pods are running
  local speaker_pods=$(kubectl get pods -n "$NAMESPACE" -l app=metallb,component=speaker -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$speaker_pods" || "$speaker_pods" != *"Running"* ]]; then
    log_error "metallb speaker pods are not running"
    return 1
  fi

  # Check if CRDs exist
  if ! kubectl get crd ipaddresspools.metallb.io l2advertisements.metallb.io &>/dev/null; then
    log_error "MetalLB CRDs are not installed"
    return 1
  fi

  # Test metallb by creating a simple test service
  log_info "Creating a test service to verify MetalLB works"
  cat <<EOF | kubectl apply -f - 2>/dev/null
apiVersion: v1
kind: Service
metadata:
  name: metallb-test
  namespace: $NAMESPACE
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nonexistent
  type: LoadBalancer
EOF

  # Wait a bit for the service to get an IP
  sleep 5

  # Check if the service got an IP
  local external_ip=$(kubectl get service metallb-test -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [[ -z "$external_ip" ]]; then
    log_info "WARNING: Test service did not receive an external IP address. MetalLB may not be fully functional."
  else
    log_info "SUCCESS: Test service received external IP: $external_ip. MetalLB is functional."
  fi

  # Clean up test service
  kubectl delete service metallb-test -n "$NAMESPACE" 2>/dev/null

  log_info "metallb verification completed successfully"
  return 0
}

# Cleanup function - removes the component
metallb_cleanup() {
  log_info "Cleaning up metallb"

  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "metallb"; then
    log_info "Uninstalling metallb Helm release"
    helm uninstall metallb -n "$NAMESPACE"
  fi

  # Delete Flux kustomization if present
  kubectl delete -f "${REPO_ROOT}/clusters/local/infrastructure/metallb/kustomization.yaml" --ignore-not-found

  # Delete namespace
  if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_info "Deleting namespace: $NAMESPACE"
    kubectl delete namespace "$NAMESPACE" --wait=false

    # Remove finalizers if needed
    sleep 2
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
      log_info "WARNING: Removing finalizers from namespace: $NAMESPACE"
      kubectl patch namespace "$NAMESPACE" --type json \
        -p='[{"op": "remove", "path": "/spec/finalizers"}]'
    fi
  fi

  # Clean up CRDs
  if kubectl get crd ipaddresspools.metallb.io &>/dev/null; then
    log_info "Deleting metallb CRDs"
    kubectl delete crd ipaddresspools.metallb.io l2advertisements.metallb.io bgppeers.metallb.io bgpadvertisements.metallb.io
  fi

  log_info "Cleanup completed successfully"
  return 0
}

# Diagnose function - provides detailed diagnostics
metallb_diagnose() {
  log_info "Running metallb diagnostics"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Display component status
  echo -e "\n--- MetalLB Pod Status ---"
  kubectl get pods -n "$NAMESPACE" -o wide

  # Display deployments
  echo -e "\n--- MetalLB Controller Deployment ---"
  kubectl get deployment controller -n "$NAMESPACE" -o yaml

  # Display daemonset
  echo -e "\n--- MetalLB Speaker DaemonSet ---"
  kubectl get daemonset speaker -n "$NAMESPACE" -o yaml

  # Display services
  echo -e "\n--- MetalLB Services ---"
  kubectl get services -n "$NAMESPACE"

  # Display CRDs and resources
  echo -e "\n--- MetalLB CRDs ---"
  kubectl get crd | grep metallb.io

  echo -e "\n--- MetalLB IPAddressPools ---"
  kubectl get ipaddresspools -n "$NAMESPACE" -o yaml 2>/dev/null || \
    echo "WARNING: No IPAddressPools found"

  echo -e "\n--- MetalLB L2Advertisements ---"
  kubectl get l2advertisements -n "$NAMESPACE" -o yaml 2>/dev/null || \
    echo "WARNING: No L2Advertisements found"

  # Show services using LoadBalancer
  echo -e "\n--- LoadBalancer Services in Cluster ---"
  kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer

  # Check for controller logs
  echo -e "\n--- Controller Logs ---"
  local controller_pod=$(kubectl get pods -n "$NAMESPACE" -l app=metallb,component=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$controller_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$controller_pod" --tail=50
  else
    echo "ERROR: No metallb controller pod found"
  fi

  # Check for speaker logs
  echo -e "\n--- Speaker Logs (first node) ---"
  local speaker_pod=$(kubectl get pods -n "$NAMESPACE" -l app=metallb,component=speaker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$speaker_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$speaker_pod" --tail=50
  else
    echo "ERROR: No metallb speaker pod found"
  fi

  # Check events
  echo -e "\n--- Recent Events ---"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20

  log_info "Diagnostics completed"
  return 0
}

# Export functions
export -f metallb_pre_deploy
export -f metallb_deploy
export -f metallb_post_deploy
export -f metallb_verify
export -f metallb_cleanup
export -f metallb_diagnose

# If called directly, execute the specified function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "$1" == "metallb_pre_deploy" ]]; then
    metallb_pre_deploy
  elif [[ "$1" == "metallb_deploy" ]]; then
    metallb_deploy "$2"
  elif [[ "$1" == "metallb_post_deploy" ]]; then
    metallb_post_deploy
  elif [[ "$1" == "metallb_verify" ]]; then
    metallb_verify
  elif [[ "$1" == "metallb_cleanup" ]]; then
    metallb_cleanup
  elif [[ "$1" == "metallb_diagnose" ]]; then
    metallb_diagnose
  else
    echo "Usage: $0 [metallb_pre_deploy|metallb_deploy [mode]|metallb_post_deploy|metallb_verify|metallb_cleanup|metallb_diagnose]"
    exit 1
  fi
fi
