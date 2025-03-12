#!/bin/bash

# setup-metallb.sh - Configures MetalLB for the staging environment
# This script sets up MetalLB for load balancing in a bare-metal Kubernetes environment

set -e

# Source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "MetalLB Setup for Staging Environment"
ui_log_info "This script will configure MetalLB for your staging environment"

# Server IP - This should be the IP of your VPS server
read -p "Enter your VPS server IP address: " SERVER_IP
if [[ -z "$SERVER_IP" ]]; then
    ui_log_error "Server IP is required."
    exit 1
fi

# Validate IP address format
if ! [[ $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ui_log_error "Invalid IP address format."
    exit 1
fi

# Check if required tools are installed
ui_log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    ui_log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v git &> /dev/null; then
    ui_log_error "git not found. Please install git first."
    exit 1
fi

# Check cluster connection
ui_log_info "Checking connection to staging cluster..."
if ! kubectl get nodes &>/dev/null; then
  ui_log_warning "Cannot connect to the staging cluster. This script will still create configuration files."
  read -p "Continue without cluster connection? (y/n): " CONTINUE_WITHOUT_CLUSTER
  if [[ "${CONTINUE_WITHOUT_CLUSTER}" != "y" && "${CONTINUE_WITHOUT_CLUSTER}" != "Y" ]]; then
    ui_log_error "Aborting MetalLB setup. Please check your cluster connection."
    exit 1
  fi
else
  ui_log_success "Successfully connected to the staging cluster."
  CLUSTER_CONNECTED=1
fi

# Get the Git repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"
ui_log_info "Using repository root: $REPO_ROOT"

# Ensure the MetalLB directories exist in the repository
ui_log_info "Checking repository structure..."
METALLB_DIR="${REPO_ROOT}/clusters/staging/infrastructure/metallb"
METALLB_PATCHES_DIR="${METALLB_DIR}/patches"

mkdir -p "${METALLB_PATCHES_DIR}"
ui_log_success "Repository structure verified."

# Create the IP pool configuration
ui_subheader "Creating MetalLB Configuration"
ui_log_info "Creating IPAddressPool configuration for IP: ${SERVER_IP}..."

# Create the IP address pool manifest
cat > "${METALLB_PATCHES_DIR}/ip-pool-config.yaml" << EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: staging-pool
  namespace: metallb-system
spec:
  addresses:
  - ${SERVER_IP}/32  # Single IP allocated to the VPS

---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: staging-l2-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - staging-pool
EOF

ui_log_success "Created IPAddressPool configuration at: ${METALLB_PATCHES_DIR}/ip-pool-config.yaml"

# Create the HelmRelease patch
ui_log_info "Creating HelmRelease patch for MetalLB..."

cat > "${METALLB_PATCHES_DIR}/helmrelease-patch.yaml" << EOF
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: metallb
  namespace: metallb-system
spec:
  interval: 15m
  values:
    # Enable service monitoring
    prometheus:
      serviceMonitor:
        enabled: true
    # Configure MetalLB controller resources
    controller:
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi
    # Configure MetalLB speaker resources
    speaker:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
    # Configure logging level
    logging:
      level: info
EOF

ui_log_success "Created HelmRelease patch at: ${METALLB_PATCHES_DIR}/helmrelease-patch.yaml"

# Create or update the kustomization.yaml file
ui_log_info "Creating kustomization.yaml for MetalLB..."

cat > "${METALLB_DIR}/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../../base/infrastructure/metallb
- patches/ip-pool-config.yaml
commonLabels:
  environment: staging
  tier: infrastructure
commonAnnotations:
  monitoring.enabled: "true"
patchesStrategicMerge:
- patches/helmrelease-patch.yaml
EOF

ui_log_success "Created kustomization.yaml at: ${METALLB_DIR}/kustomization.yaml"

# If connected to the cluster, check if MetalLB is deployed and offer to install if not
if [[ -n "${CLUSTER_CONNECTED}" ]]; then
  ui_subheader "Checking MetalLB Deployment"
  ui_log_info "Checking if MetalLB is deployed in the cluster..."
  
  if ! kubectl get namespace metallb-system &>/dev/null; then
    ui_log_warning "MetalLB namespace not found. MetalLB might not be deployed."
    ui_log_info "Ensure MetalLB is deployed through your GitOps process or manually."
    ui_log_info "You can deploy MetalLB using the following command:"
    ui_log_info "  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml"
    
    read -p "Do you want to deploy MetalLB manually now? (y/n): " DEPLOY_METALLB
    if [[ "${DEPLOY_METALLB}" == "y" || "${DEPLOY_METALLB}" == "Y" ]]; then
      ui_log_info "Deploying MetalLB..."
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml
      
      # Wait for MetalLB deployment to be ready
      ui_log_info "Waiting for MetalLB to be ready..."
      kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=90s || ui_log_warning "Timed out waiting for MetalLB to be ready."
    else
      ui_log_info "Skipping manual MetalLB deployment. It will be deployed via GitOps."
    fi
  else
    ui_log_success "MetalLB namespace found. MetalLB is likely deployed."
    
    # Check for existing LoadBalancer services
    ui_subheader "Checking LoadBalancer Services"
    LOADBALANCER_SERVICES=$(kubectl get svc --all-namespaces -o json | jq -r '.items[] | select(.spec.type == "LoadBalancer") | .metadata.namespace + "/" + .metadata.name' 2>/dev/null || echo "")
    
    if [[ -z "${LOADBALANCER_SERVICES}" ]]; then
      ui_log_info "No LoadBalancer services found in the cluster."
    else
      ui_log_info "Found the following LoadBalancer services:"
      echo "${LOADBALANCER_SERVICES}"
      ui_log_info "These services will receive IP addresses from MetalLB once the configuration is applied."
    fi
  fi
fi

ui_subheader "GitOps Integration"
ui_log_info "The MetalLB configuration has been created in your GitOps repository."
ui_log_info "To apply the configuration, commit and push the changes, or apply them with kubectl:"
ui_log_info "  git add ${METALLB_DIR}"
ui_log_info "  git commit -m \"Add MetalLB configuration for staging environment\""
ui_log_info "  git push"

# Offer direct application if connected to cluster
if [[ -n "${CLUSTER_CONNECTED}" ]]; then
  read -p "Do you want to apply the MetalLB configuration directly with kubectl? (y/n): " APPLY_CONFIG
  if [[ "${APPLY_CONFIG}" == "y" || "${APPLY_CONFIG}" == "Y" ]]; then
    ui_log_info "Applying MetalLB configuration with kubectl..."
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace metallb-system &>/dev/null; then
      ui_log_info "Creating metallb-system namespace..."
      kubectl create namespace metallb-system
    fi
    
    # Apply the configuration using kubectl
    kubectl apply -f "${METALLB_PATCHES_DIR}/ip-pool-config.yaml"
    
    ui_log_success "MetalLB configuration applied successfully."
    ui_log_info "Note: This direct application bypasses GitOps. For consistent deployments, commit and push your changes."
  else
    ui_log_info "Skipping direct application. The configuration will be applied through GitOps."
  fi
fi

ui_header "MetalLB Setup Complete"
ui_log_success "MetalLB has been configured for your staging environment."
ui_log_info "The address pool is set to: ${SERVER_IP}/32"
ui_log_info "Configuration files have been created in your GitOps repository at: ${METALLB_DIR}"

exit 0 