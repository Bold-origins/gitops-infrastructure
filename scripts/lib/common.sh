#!/bin/bash
# Common utilities for scripts
# Provides common functions used across various scripts

# Source the UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
init_logging() {
  # Set default log level if not already set
  export LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}
  ui_log_debug "Logging initialized at level ${LOG_LEVEL}"
}

# Check if a command is available
check_command() {
  local cmd="$1"
  local error_msg="${2:-Command '$cmd' not found. Please install it.}"
  
  if ! command -v "$cmd" &> /dev/null; then
    ui_log_error "$error_msg"
    return 1
  fi
  
  ui_log_debug "Command '$cmd' is available"
  return 0
}

# Check if kubectl is connected to the correct cluster
check_kubectl_context() {
  local expected_context="$1"
  local current_context
  
  if [[ -z "$expected_context" ]]; then
    ui_log_warning "No expected kubectl context provided, skipping check"
    return 0
  fi
  
  current_context=$(kubectl config current-context 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    ui_log_error "Failed to get current kubectl context"
    return 1
  fi
  
  if [[ "$current_context" != "$expected_context" ]]; then
    ui_log_error "Wrong kubectl context: expected '$expected_context', got '$current_context'"
    ui_log_info "Use 'kubectl config use-context $expected_context' to switch context"
    return 1
  fi
  
  ui_log_debug "Using correct kubectl context: $current_context"
  return 0
}

# Wait for a resource to be ready
wait_for_resource() {
  local resource_type="$1"
  local resource_name="$2"
  local namespace="${3:-default}"
  local timeout="${4:-300}"
  
  ui_log_info "Waiting for $resource_type/$resource_name in namespace $namespace to be ready..."
  
  if ! kubectl wait --for=condition=ready "$resource_type/$resource_name" -n "$namespace" --timeout="${timeout}s"; then
    ui_log_error "Resource $resource_type/$resource_name in namespace $namespace not ready after ${timeout}s"
    return 1
  fi
  
  ui_log_success "Resource $resource_type/$resource_name in namespace $namespace is ready"
  return 0
}

# Create a namespace if it doesn't exist
create_namespace_if_not_exists() {
  local namespace="$1"
  
  if ! kubectl get namespace "$namespace" &>/dev/null; then
    ui_log_info "Creating namespace $namespace"
    kubectl create namespace "$namespace"
    ui_log_success "Namespace $namespace created"
  else
    ui_log_debug "Namespace $namespace already exists"
  fi
}

# Check if running on the staging server
is_staging_server() {
  # Add logic to determine if we're on the staging server
  # This could check for specific hostname, IP, or environment variables
  if [[ "$(hostname)" == "staging-server" ]] || [[ -f "/etc/staging-environment" ]]; then
    return 0
  fi
  return 1
}

# Get the current Git branch
get_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# Check if the repository is clean (no uncommitted changes)
git_repo_is_clean() {
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    return 1  # Dirty
  fi
  return 0  # Clean
}

# Export common functions
export -f init_logging
export -f check_command
export -f check_kubectl_context
export -f wait_for_resource
export -f create_namespace_if_not_exists
export -f is_staging_server
export -f get_current_branch
export -f git_repo_is_clean 