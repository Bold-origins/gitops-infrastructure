#!/bin/bash

# e2e-test.sh: End-to-end testing of the entire local Kubernetes environment
# This script creates a fresh Minikube cluster, installs all components,
# tests that everything is working, and then optionally deletes the cluster.

set -e

# Default configuration
MINIKUBE_MEMORY=8192
MINIKUBE_CPUS=4
MINIKUBE_DISK_SIZE=20g
MINIKUBE_DRIVER="docker"
KEEP_CLUSTER=false
VERBOSE=false
SKIP_TESTS=false
TIMEOUT=600 # 10 minutes timeout for component setup

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --memory=*)
      MINIKUBE_MEMORY="${key#*=}"
      shift
      ;;
    --cpus=*)
      MINIKUBE_CPUS="${key#*=}"
      shift
      ;;
    --disk-size=*)
      MINIKUBE_DISK_SIZE="${key#*=}"
      shift
      ;;
    --driver=*)
      MINIKUBE_DRIVER="${key#*=}"
      shift
      ;;
    --keep-cluster)
      KEEP_CLUSTER=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
    --timeout=*)
      TIMEOUT="${key#*=}"
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --memory=SIZE      Set Minikube memory in MB (default: 8192)"
      echo "  --cpus=COUNT       Set Minikube CPU count (default: 4)"
      echo "  --disk-size=SIZE   Set Minikube disk size (default: 20g)"
      echo "  --driver=NAME      Set Minikube driver (default: docker)"
      echo "  --keep-cluster     Keep the cluster after tests (default: false)"
      echo "  --verbose          Enable verbose output (default: false)"
      echo "  --skip-tests       Skip running tests (default: false)"
      echo "  --timeout=SECONDS  Set timeout for component setup (default: 600)"
      echo "  --help             Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $key"
      exit 1
      ;;
  esac
done

# Export variables for component setup scripts
export MINIKUBE_MEMORY
export MINIKUBE_CPUS
export MINIKUBE_DISK_SIZE
export MINIKUBE_DRIVER
export VERBOSE

# Function to log messages
log() {
  local level=$1
  local message=$2
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  case $level in
    info)
      echo -e "\033[0;34m[INFO]\033[0m $timestamp - $message"
      ;;
    success)
      echo -e "\033[0;32m[SUCCESS]\033[0m $timestamp - $message"
      ;;
    warning)
      echo -e "\033[0;33m[WARNING]\033[0m $timestamp - $message"
      ;;
    error)
      echo -e "\033[0;31m[ERROR]\033[0m $timestamp - $message"
      ;;
    phase)
      echo -e "\n\033[1;36m===== $message =====\033[0m"
      ;;
  esac
}

# Function to run a command with timeout
run_with_timeout() {
  local command=$1
  local timeout=$2
  local message=$3
  
  log info "Starting: $message"
  
  # Create a temporary file for the command output
  output_file=$(mktemp)
  
  # Start the command in the background
  bash -c "$command" > "$output_file" 2>&1 &
  command_pid=$!
  
  # Wait for the command to complete or timeout
  waited=0
  while kill -0 $command_pid 2>/dev/null; do
    if [ $waited -ge $timeout ]; then
      kill -9 $command_pid 2>/dev/null || true
      log error "$message timed out after ${timeout}s"
      cat "$output_file"
      rm -f "$output_file"
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
    
    # Print a progress indicator every 30 seconds
    if [ $((waited % 30)) -eq 0 ]; then
      log info "$message - still running (${waited}s)..."
    fi
  done
  
  # Get the exit code of the command
  wait $command_pid
  exit_code=$?
  
  # Check if the command succeeded
  if [ $exit_code -eq 0 ]; then
    log success "$message completed successfully"
    
    # Only show output in verbose mode
    if [ "$VERBOSE" = "true" ]; then
      cat "$output_file"
    fi
    
    rm -f "$output_file"
    return 0
  else
    log error "$message failed with exit code $exit_code"
    cat "$output_file"
    rm -f "$output_file"
    return $exit_code
  fi
}

# Function to wait for pods to be ready in a namespace
wait_for_pods_ready() {
  local namespace=$1
  local timeout=${2:-300}
  local waited=0
  
  log info "Waiting for pods in namespace '$namespace' to be ready..."
  
  while true; do
    if [ $waited -ge $timeout ]; then
      log error "Timeout waiting for pods in namespace '$namespace' to be ready"
      kubectl get pods -n "$namespace"
      return 1
    fi
    
    # Count total and ready pods
    local total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    # If no pods found yet, wait
    if [ "$total_pods" -eq 0 ]; then
      sleep 5
      waited=$((waited + 5))
      continue
    fi
    
    local ready_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -v "0/\|1/2\|2/3\|Pending\|Error\|CrashLoopBackOff" | wc -l)
    
    if [ "$ready_pods" -eq "$total_pods" ]; then
      log success "All pods in namespace '$namespace' are ready"
      return 0
    fi
    
    # Print progress every 30 seconds
    if [ $((waited % 30)) -eq 0 ]; then
      log info "Waiting for pods in namespace '$namespace': $ready_pods/$total_pods ready (${waited}s)..."
      if [ "$VERBOSE" = "true" ]; then
        kubectl get pods -n "$namespace"
      fi
    fi
    
    sleep 5
    waited=$((waited + 5))
  done
}

# Function to cleanup on exit
cleanup() {
  if [ "$KEEP_CLUSTER" != "true" ]; then
    log phase "Cleaning up resources"
    log info "Deleting Minikube cluster"
    minikube delete
    log success "Minikube cluster deleted"
  else
    log info "Keeping Minikube cluster as requested"
  fi
}

# Register cleanup function to run on exit
trap cleanup EXIT

# Check prerequisites
log phase "Checking prerequisites"

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
  log error "Minikube is not installed. Please install Minikube first."
  exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  log error "kubectl is not installed. Please install kubectl first."
  exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
  log error "Helm is not installed. Please install Helm first."
  exit 1
fi

# Set up Minikube cluster
log phase "Setting up Minikube cluster"

# Delete existing Minikube cluster if it exists
if minikube status &> /dev/null; then
  log info "Existing Minikube cluster found. Deleting..."
  minikube delete
  log success "Existing cluster deleted."
fi

# Start Minikube with specified resources
log info "Starting Minikube with ${MINIKUBE_MEMORY}MB memory, ${MINIKUBE_CPUS} CPUs, ${MINIKUBE_DISK_SIZE} disk, using ${MINIKUBE_DRIVER} driver"
minikube start --memory="${MINIKUBE_MEMORY}" --cpus="${MINIKUBE_CPUS}" --disk-size="${MINIKUBE_DISK_SIZE}" --driver="${MINIKUBE_DRIVER}"

# Enable required addons
log info "Enabling required Minikube addons"
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Wait for addons to be ready
log info "Waiting for addons to be ready..."
sleep 10

# Verify all pods are running in kube-system
wait_for_pods_ready "kube-system" 180

# Create a default storage class if needed
log info "Setting up storage classes..."
if ! kubectl get storageclass standard &> /dev/null; then
  cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
  log success "Default storage class created"
else
  log info "Default storage class already exists"
fi

# Get Minikube IP for hosts file
MINIKUBE_IP=$(minikube ip)
log info "Minikube IP: ${MINIKUBE_IP}"

# Add Minikube IP to /etc/hosts file
log info "Checking /etc/hosts entries"
DOMAINS=("grafana.local" "prometheus.local" "vault.local" "supabase.local" "minio.local")
MISSING_DOMAINS=()

for domain in "${DOMAINS[@]}"; do
  if grep -q "${domain}" /etc/hosts; then
    host_ip=$(grep "${domain}" /etc/hosts | awk '{print $1}')
    if [ "${host_ip}" = "${MINIKUBE_IP}" ]; then
      log info "${domain} is already in /etc/hosts with correct IP"
    else
      log warning "${domain} is in /etc/hosts but with IP ${host_ip}, should be ${MINIKUBE_IP}"
      MISSING_DOMAINS+=("${domain}")
    fi
  else
    log info "${domain} not found in /etc/hosts"
    MISSING_DOMAINS+=("${domain}")
  fi
done

if [ ${#MISSING_DOMAINS[@]} -gt 0 ]; then
  log warning "The following domains need to be added to /etc/hosts:"
  echo "${MINIKUBE_IP} ${MISSING_DOMAINS[*]}"
  
  # Try to add domains to /etc/hosts if running with sudo
  if [ "$(id -u)" -eq 0 ]; then
    log info "Running as root, adding domains to /etc/hosts"
    echo "${MINIKUBE_IP} ${MISSING_DOMAINS[*]}" >> /etc/hosts
    log success "Added domains to /etc/hosts"
  else
    log warning "You need to manually add the above line to /etc/hosts with sudo privileges"
    log warning "Run: sudo -- sh -c \"echo '${MINIKUBE_IP} ${MISSING_DOMAINS[*]}' >> /etc/hosts\""
    
    # Ask if user wants to continue anyway
    read -p "Continue without updating /etc/hosts? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log error "Aborting as requested"
      exit 1
    fi
  fi
fi

# Set up core infrastructure components
log phase "Setting up core infrastructure components"

# Set up cert-manager
log info "Setting up cert-manager"
run_with_timeout "./scripts/cluster/setup-core-infrastructure.sh" $TIMEOUT "Core infrastructure setup"

# Verify cert-manager and other core components
wait_for_pods_ready "cert-manager" 180
wait_for_pods_ready "vault" 180
wait_for_pods_ready "kube-system" 180 # For sealed-secrets
log success "Core infrastructure components are running"

# Set up networking components
log phase "Setting up networking components"
run_with_timeout "./scripts/cluster/setup-networking.sh" $TIMEOUT "Networking setup"
wait_for_pods_ready "ingress-nginx" 180
wait_for_pods_ready "metallb-system" 180
log success "Networking components are running"

# Set up observability stack
log phase "Setting up observability stack"
run_with_timeout "./scripts/cluster/setup-observability.sh" $TIMEOUT "Observability setup"
wait_for_pods_ready "observability" 300
log success "Observability stack is running"

# Set up applications
log phase "Setting up applications"
run_with_timeout "./scripts/cluster/setup-applications.sh" $TIMEOUT "Applications setup"
wait_for_pods_ready "supabase" 300
log success "Applications are running"

# Set up GitOps with Flux (if configured)
if [ -f "./scripts/cluster/setup-flux.sh" ] && command -v flux &> /dev/null; then
  log phase "Setting up GitOps with Flux"
  
  # Check if we have required GitHub environment variables
  if [ -n "${GITHUB_USER}" ] && [ -n "${GITHUB_REPO}" ] && [ -n "${GITHUB_TOKEN}" ]; then
    log info "GitHub credentials found, setting up Flux"
    run_with_timeout "./scripts/cluster/setup-flux.sh" $TIMEOUT "Flux setup"
    wait_for_pods_ready "flux-system" 180
    log success "GitOps with Flux is configured"
  else
    log warning "GitHub credentials not found, skipping Flux setup"
    log warning "To set up Flux later, export GITHUB_USER, GITHUB_REPO, GITHUB_TOKEN and run ./scripts/cluster/setup-flux.sh"
  fi
fi

# Run tests if not skipped
if [ "$SKIP_TESTS" != "true" ]; then
  log phase "Running tests"
  
  # Make all test scripts executable
  chmod +x scripts/cluster/test-environment.sh scripts/cluster/test-web-interfaces.sh scripts/gitops/test-gitops-workflow.sh scripts/cluster/test-all.sh
  
  # Run test-all.sh which runs all individual tests
  if run_with_timeout "./scripts/cluster/test-all.sh" $TIMEOUT "Comprehensive tests"; then
    log success "All tests passed successfully!"
    test_passed=true
  else
    log error "Some tests failed. Check the output above for details."
    test_passed=false
  fi
else
  log info "Skipping tests as requested"
  test_passed=true
fi

# Summary
log phase "Summary"

if [ "$test_passed" = "true" ]; then
  log success "The local Kubernetes environment was set up successfully!"
  
  if [ "$SKIP_TESTS" = "true" ]; then
    log info "Tests were skipped. To run tests manually, use: ./scripts/cluster/test-all.sh"
  fi
  
  log info "Minikube IP: ${MINIKUBE_IP}"
  log info "You can access the following services:"
  log info "- Grafana: https://grafana.local"
  log info "- Prometheus: https://prometheus.local"
  log info "- Vault: https://vault.local"
  log info "- Supabase: https://supabase.local"
  log info "- MinIO: https://minio.local"
  
  if [ "$KEEP_CLUSTER" = "true" ]; then
    log info "The Minikube cluster will be kept running."
    log info "To delete it later, run: minikube delete"
  else
    log info "The Minikube cluster will be deleted (use --keep-cluster to keep it)."
  fi
else
  log error "The setup was completed but some tests failed."
  log error "Check the logs above for details on what went wrong."
  
  if [ "$KEEP_CLUSTER" = "true" ]; then
    log info "The Minikube cluster will be kept running for debugging."
    log info "To delete it later, run: minikube delete"
  else
    log info "The Minikube cluster will be deleted. Use --keep-cluster to keep it for debugging."
  fi
  
  exit 1
fi 