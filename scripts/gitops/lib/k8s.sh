#!/bin/bash
# k8s.sh: Kubernetes Helper Functions
# Provides common Kubernetes operations for GitOps scripts

# Source UI helpers if not already loaded
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/ui.sh"

# Create a namespace if it doesn't exist
k8s_create_namespace() {
  local namespace="$1"
  
  if ! kubectl get namespace "$namespace" &>/dev/null; then
    ui_log_info "Creating namespace: $namespace"
    kubectl create namespace "$namespace"
    return $?
  else
    ui_log_info "Namespace $namespace already exists"
    return 0
  fi
}

# Apply a file with kubectl
k8s_apply_file() {
  local file="$1"
  local flags="${2:-}"
  
  ui_log_info "Applying file: $file"
  kubectl apply $flags -f "$file"
  return $?
}

# Apply a directory with kubectl
k8s_apply_dir() {
  local dir="$1"
  local flags="${2:-}"
  
  ui_log_info "Applying directory: $dir"
  kubectl apply $flags -f "$dir"
  return $?
}

# Apply a kustomization using kubectl
k8s_apply_kustomization() {
  local name="$1"
  local path="$2"
  local namespace="${3:-flux-system}"
  
  ui_log_info "Creating kustomization: $name"
  cat > "/tmp/kustomization-$name.yaml" <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: $name
  namespace: $namespace
spec:
  interval: 10m0s
  path: ./$path
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  timeout: 10m0s
  retryInterval: 2m0s
  wait: true
EOF
  
  kubectl apply -f "/tmp/kustomization-$name.yaml"
  return $?
}

# Delete a kustomization
k8s_delete_kustomization() {
  local name="$1"
  local namespace="${2:-flux-system}"
  
  if kubectl get kustomization -n "$namespace" "$name" &>/dev/null; then
    ui_log_info "Deleting kustomization: $name"
    kubectl delete kustomization -n "$namespace" "$name" --wait=false
    
    # Remove finalizers if needed
    sleep 2
    if kubectl get kustomization -n "$namespace" "$name" &>/dev/null; then
      ui_log_warning "Removing finalizers from kustomization: $name"
      kubectl patch kustomization -n "$namespace" "$name" --type json \
        -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
    fi
    
    return 0
  else
    ui_log_info "Kustomization $name does not exist"
    return 0
  fi
}

# Wait for Custom Resource Definitions to be established
k8s_wait_for_crds() {
  local prefix="$1"
  local timeout="${2:-60}"
  
  ui_log_info "Waiting for CRDs with prefix '$prefix' to be established"
  
  local start_time=$(date +%s)
  local wait_until=$((start_time + timeout))
  
  while true; do
    local current_time=$(date +%s)
    if [[ $current_time -gt $wait_until ]]; then
      ui_log_error "Timeout waiting for CRDs"
      return 1
    fi
    
    local crds=$(kubectl get crds -o name | grep "$prefix" | wc -l)
    if [[ $crds -eq 0 ]]; then
      ui_log_warning "No CRDs found with prefix '$prefix'"
      sleep 5
      continue
    fi
    
    local established=0
    for crd in $(kubectl get crds -o name | grep "$prefix" | cut -d/ -f2); do
      local condition=$(kubectl get crd "$crd" -o jsonpath='{.status.conditions[?(@.type=="Established")].status}')
      if [[ "$condition" == "True" ]]; then
        ((established++))
      fi
    done
    
    if [[ $established -eq $crds ]]; then
      ui_log_success "All $established CRDs are established"
      return 0
    else
      ui_log_info "Waiting for CRDs to be established: $established/$crds"
      sleep 5
    fi
  done
}

# Wait for a deployment to be ready
k8s_wait_for_deployment() {
  local namespace="$1"
  local deployment="$2"
  local timeout="${3:-120}"
  
  ui_log_info "Waiting for deployment $namespace/$deployment to be ready"
  kubectl rollout status deployment -n "$namespace" "$deployment" --timeout="${timeout}s"
  return $?
}

# Verify all deployments in a namespace
k8s_verify_deployments() {
  local namespace="$1"
  
  ui_log_info "Verifying deployments in namespace: $namespace"
  
  local deployments=$(kubectl get deployments -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [[ -z "$deployments" ]]; then
    ui_log_warning "No deployments found in namespace $namespace"
    return 0
  fi
  
  local ready_count=0
  local total_count=0
  
  for deployment in $deployments; do
    ((total_count++))
    local ready=$(kubectl get deployment -n "$namespace" "$deployment" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired=$(kubectl get deployment -n "$namespace" "$deployment" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    if [[ "$ready" == "$desired" && "$ready" != "0" ]]; then
      ui_log_success "Deployment $deployment is ready: $ready/$desired"
      ((ready_count++))
    else
      ui_log_warning "Deployment $deployment not ready: $ready/$desired"
    fi
  done
  
  if [[ $ready_count -eq $total_count ]]; then
    ui_log_success "All deployments in $namespace are ready: $ready_count/$total_count"
    return 0
  else
    ui_log_error "Not all deployments in $namespace are ready: $ready_count/$total_count"
    return 1
  fi
}

# Get logs from a pod
k8s_get_pod_logs() {
  local namespace="$1"
  local pod_prefix="$2"
  local container="${3:-}"
  local tail="${4:-100}"
  
  local pod=$(kubectl get pods -n "$namespace" | grep "$pod_prefix" | head -1 | awk '{print $1}')
  if [[ -z "$pod" ]]; then
    ui_log_error "No pod found with prefix '$pod_prefix' in namespace $namespace"
    return 1
  fi
  
  if [[ -n "$container" ]]; then
    ui_log_info "Getting logs for $namespace/$pod, container $container"
    kubectl logs -n "$namespace" "$pod" -c "$container" --tail="$tail"
  else
    ui_log_info "Getting logs for $namespace/$pod"
    kubectl logs -n "$namespace" "$pod" --tail="$tail"
  fi
  
  return $?
}

# Check if pods are in crash loop
k8s_check_crash_loop() {
  local namespace="$1"
  local label_selector="${2:-}"
  
  local pods=""
  if [[ -n "$label_selector" ]]; then
    pods=$(kubectl get pods -n "$namespace" -l "$label_selector" -o name 2>/dev/null)
  else
    pods=$(kubectl get pods -n "$namespace" -o name 2>/dev/null)
  fi
  
  if [[ -z "$pods" ]]; then
    ui_log_warning "No pods found in namespace $namespace with selector '$label_selector'"
    return 1
  fi
  
  for pod in $pods; do
    local status=$(kubectl get "$pod" -n "$namespace" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
    if [[ "$status" == "CrashLoopBackOff" ]]; then
      ui_log_error "Pod $pod is in CrashLoopBackOff state"
      return 0
    fi
  done
  
  return 1
}

# Get all resources in a namespace
k8s_get_all_resources() {
  local namespace="$1"
  
  ui_log_info "Getting all resources in namespace: $namespace"
  kubectl get all -n "$namespace"
  return $?
}

# Get events for a namespace
k8s_get_events() {
  local namespace="$1"
  local limit="${2:-20}"
  
  ui_log_info "Getting events in namespace: $namespace"
  kubectl get events -n "$namespace" --sort-by='.lastTimestamp' | tail -n "$limit"
  return $?
}

# Check if a CRD exists
k8s_check_crd() {
  local crd_name="$1"
  
  if kubectl get crd "$crd_name" &>/dev/null; then
    ui_log_info "CRD $crd_name exists"
    return 0
  else
    ui_log_warning "CRD $crd_name does not exist"
    return 1
  fi
} 