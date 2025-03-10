#!/bin/bash
# minio.sh: MinIO Component Functions
# Handles all operations specific to MinIO object storage component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="minio"
NAMESPACE="minio"
COMPONENT_DEPENDENCIES=()
RESOURCE_TYPES=("deployment" "service" "statefulset" "pvc" "configmap" "secret")

# Pre-deployment function - runs before deployment
minio_pre_deploy() {
  ui_log_info "Running MinIO pre-deployment checks"

  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for MinIO"
    return 1
  fi

  # Add Helm repo if needed
  if ! helm repo list | grep -q "minio"; then
    ui_log_info "Adding MinIO Helm repository"
    helm repo add minio https://charts.min.io/
    helm repo update
  fi

  return 0
}

# Deploy function - deploys the component
minio_deploy() {
  local deploy_mode="${1:-flux}"

  ui_log_info "Deploying MinIO using $deploy_mode mode"

  case "$deploy_mode" in
  flux)
    # Deploy using Flux
    kubectl apply -f "${BASE_DIR}/clusters/local/infrastructure/minio/kustomization.yaml"
    ;;

  kubectl)
    # Direct kubectl apply
    ui_log_info "Applying MinIO manifests directly with kubectl"
    kubectl apply -k "${BASE_DIR}/clusters/local/infrastructure/minio"
    ;;

  helm)
    # Helm-based installation
    ui_log_info "Deploying MinIO with Helm"

    # Check if already installed
    if helm list -n "$NAMESPACE" | grep -q "minio"; then
      ui_log_info "MinIO is already installed via Helm"
      return 0
    fi

    # Install with Helm - using default values for development
    # Generate random credentials for development environment
    local access_key="minio$(openssl rand -hex 4)"
    local secret_key="minio$(openssl rand -hex 8)"

    ui_log_info "Installing MinIO with generated credentials"
    ui_log_info "Access Key: $access_key"
    ui_log_info "Secret Key: $secret_key"

    helm install minio minio/minio -n "$NAMESPACE" \
      --set accessKey="$access_key" \
      --set secretKey="$secret_key" \
      --set mode="standalone" \
      --set persistence.enabled=true \
      --set persistence.size=10Gi \
      --set service.type=ClusterIP \
      --set resources.requests.memory=512Mi \
      --set resources.requests.cpu=100m

    # Save credentials to a secret for reference
    ui_log_info "Saving MinIO credentials to Secret for reference"
    kubectl create secret generic minio-credentials -n "$NAMESPACE" \
      --from-literal=accesskey="$access_key" \
      --from-literal=secretkey="$secret_key" \
      --dry-run=client -o yaml | kubectl apply -f -
    ;;

  *)
    ui_log_error "Invalid deployment mode: $deploy_mode"
    return 1
    ;;
  esac

  return $?
}

# Post-deployment function - runs after deployment
minio_post_deploy() {
  ui_log_info "Running MinIO post-deployment tasks"

  # Wait for deployment or statefulset to be ready
  if kubectl get statefulset minio -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for MinIO StatefulSet to be ready"
    kubectl rollout status statefulset minio -n "$NAMESPACE" --timeout=180s
  else
    ui_log_info "Waiting for MinIO Deployment to be ready"
    kubectl rollout status deployment minio -n "$NAMESPACE" --timeout=180s
  fi

  # Check if MinIO service is running
  if ! kubectl get service minio -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "MinIO service not found"
    return 1
  fi

  # Get service details
  local service_type=$(kubectl get service minio -n "$NAMESPACE" -o jsonpath='{.spec.type}')
  ui_log_info "MinIO service type: $service_type"

  if [[ "$service_type" == "LoadBalancer" ]]; then
    local external_ip
    local count=0
    while [ -z "$external_ip" ] && [ $count -lt 12 ]; do
      external_ip=$(kubectl get service minio -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      if [ -z "$external_ip" ]; then
        ui_log_info "Waiting for MinIO external IP..."
        sleep 10
        count=$((count + 1))
      fi
    done

    if [ -n "$external_ip" ]; then
      ui_log_success "MinIO is accessible at http://$external_ip:9000"
    else
      ui_log_warning "Could not determine MinIO external IP, service may be pending"
    fi
  else
    ui_log_info "MinIO is running in ClusterIP mode. To access UI use port-forwarding:"
    ui_log_info "kubectl port-forward -n $NAMESPACE svc/minio 9000:9000"
  fi

  return 0
}

# Verification function - verifies the component is working
minio_verify() {
  ui_log_info "Verifying MinIO installation"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Check if MinIO is running
  local minio_pod

  if kubectl get statefulset minio -n "$NAMESPACE" &>/dev/null; then
    minio_pod=$(kubectl get pods -n "$NAMESPACE" -l app=minio -o jsonpath='{.items[0].metadata.name}')
  else
    minio_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}')
  fi

  if [ -z "$minio_pod" ]; then
    ui_log_error "No MinIO pod found"
    return 1
  fi

  # Check pod status
  local pod_status=$(kubectl get pod -n "$NAMESPACE" "$minio_pod" -o jsonpath='{.status.phase}')
  if [[ "$pod_status" != "Running" ]]; then
    ui_log_error "MinIO pod is not running, current status: $pod_status"
    return 1
  fi

  # Verify MinIO is responsive by checking API
  ui_log_info "Verifying MinIO API is responsive"
  # Using kubectl exec to run curl in the pod to test internal connectivity
  if kubectl exec -n "$NAMESPACE" "$minio_pod" -- curl -s http://localhost:9000/minio/health/live 2>/dev/null | grep -q "OK"; then
    ui_log_success "MinIO API is responsive"
  else
    ui_log_warning "MinIO API health check failed. It might still be initializing."
  fi

  # Test creating a bucket (optional)
  ui_log_info "Testing bucket creation functionality"

  # Get credentials
  local access_key=""
  local secret_key=""

  # Try to get from secret first
  if kubectl get secret minio-credentials -n "$NAMESPACE" &>/dev/null; then
    access_key=$(kubectl get secret minio-credentials -n "$NAMESPACE" -o jsonpath='{.data.accesskey}' | base64 --decode)
    secret_key=$(kubectl get secret minio-credentials -n "$NAMESPACE" -o jsonpath='{.data.secretkey}' | base64 --decode)
  # Fallback to Helm created secret
  elif kubectl get secret minio -n "$NAMESPACE" &>/dev/null; then
    access_key=$(kubectl get secret minio -n "$NAMESPACE" -o jsonpath='{.data.rootUser}' | base64 --decode)
    secret_key=$(kubectl get secret minio -n "$NAMESPACE" -o jsonpath='{.data.rootPassword}' | base64 --decode)
  fi

  if [ -n "$access_key" ] && [ -n "$secret_key" ]; then
    # Install s3cmd in pod if needed
    kubectl exec -n "$NAMESPACE" "$minio_pod" -- apt-get update -qq &>/dev/null || true
    kubectl exec -n "$NAMESPACE" "$minio_pod" -- apt-get install -qq -y s3cmd &>/dev/null || true

    # Create a test file
    kubectl exec -n "$NAMESPACE" "$minio_pod" -- sh -c "echo 'Hello MinIO' > /tmp/test-file.txt" || true

    # Create a test bucket and upload file
    kubectl exec -n "$NAMESPACE" "$minio_pod" -- sh -c "
      export MC_HOST_local=http://$access_key:$secret_key@localhost:9000;
      mc mb local/test-bucket;
      mc cp /tmp/test-file.txt local/test-bucket/;
      mc ls local/test-bucket/;
      mc rb --force local/test-bucket;
    " &>/dev/null && ui_log_success "Successfully created test bucket" || ui_log_warning "Failed to test bucket operations"
  else
    ui_log_warning "Could not find MinIO credentials for verification tests"
  fi

  ui_log_success "MinIO verification completed"
  return 0
}

# Cleanup function - removes the component
minio_cleanup() {
  ui_log_info "Cleaning up MinIO"

  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "minio"; then
    ui_log_info "Uninstalling MinIO Helm release"
    helm uninstall minio -n "$NAMESPACE"
  fi

  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/infrastructure/minio/kustomization.yaml" --ignore-not-found

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

  return 0
}

# Diagnose function - provides detailed diagnostics
minio_diagnose() {
  ui_log_info "Running MinIO diagnostics"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Display pod status
  ui_subheader "MinIO Pod Status"
  kubectl get pods -n "$NAMESPACE" -o wide

  # Display deployments or statefulsets
  if kubectl get statefulset minio -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "MinIO StatefulSet"
    kubectl get statefulset minio -n "$NAMESPACE" -o yaml
  elif kubectl get deployment minio -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "MinIO Deployment"
    kubectl get deployment minio -n "$NAMESPACE" -o yaml
  fi

  # Display services
  ui_subheader "MinIO Services"
  kubectl get services -n "$NAMESPACE"

  # Display service details
  ui_subheader "MinIO Service Details"
  kubectl get service minio -n "$NAMESPACE" -o yaml

  # Display PVCs
  ui_subheader "MinIO PVCs"
  kubectl get pvc -n "$NAMESPACE"

  # Display secrets (excluding content)
  ui_subheader "MinIO Secrets"
  kubectl get secrets -n "$NAMESPACE"

  # Check for credentials
  if kubectl get secret minio-credentials -n "$NAMESPACE" &>/dev/null; then
    ui_log_success "MinIO credentials secret exists"
  elif kubectl get secret minio -n "$NAMESPACE" &>/dev/null; then
    ui_log_success "MinIO Helm secret exists"
  else
    ui_log_warning "No MinIO credentials secret found"
  fi

  # Check pod logs
  ui_subheader "MinIO Pod Logs"
  local minio_pod

  if kubectl get statefulset minio -n "$NAMESPACE" &>/dev/null; then
    minio_pod=$(kubectl get pods -n "$NAMESPACE" -l app=minio -o jsonpath='{.items[0].metadata.name}')
  else
    minio_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}')
  fi

  if [ -n "$minio_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$minio_pod" --tail=50
  else
    ui_log_error "No MinIO pod found"
  fi

  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20

  return 0
}

# Export functions
export -f minio_pre_deploy
export -f minio_deploy
export -f minio_post_deploy
export -f minio_verify
export -f minio_cleanup
export -f minio_diagnose
