#!/bin/bash
# ingress.sh: Ingress Controller Component Functions
# Handles all operations specific to ingress-nginx component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="ingress"
NAMESPACE="ingress-nginx"
COMPONENT_DEPENDENCIES=()  # No explicit dependencies, but usually requires metallb in practice
RESOURCE_TYPES=("deployment" "service" "configmap" "ingressclass")

# Pre-deployment function - runs before deployment
ingress_pre_deploy() {
  ui_log_info "Running ingress-nginx pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for ingress-nginx"
    return 1
  fi
  
  # Add Helm repo if needed
  if ! helm repo list | grep -q "ingress-nginx"; then
    ui_log_info "Adding ingress-nginx Helm repository"
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
  fi
  
  return 0
}

# Deploy function - deploys the component
ingress_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying ingress-nginx using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      kubectl apply -f "${BASE_DIR}/clusters/local/infrastructure/ingress/kustomization.yaml"
      ;;
    
    kubectl)
      # Direct kubectl apply
      ui_log_info "Applying ingress-nginx manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/infrastructure/ingress"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying ingress-nginx with Helm"
      
      # Check if already installed
      if helm list -n "$NAMESPACE" | grep -q "ingress-nginx"; then
        ui_log_info "ingress-nginx is already installed via Helm"
        return 0
      fi
      
      # Install with Helm
      helm install ingress-nginx ingress-nginx/ingress-nginx -n "$NAMESPACE" \
        --set controller.service.type=LoadBalancer \
        --set controller.service.externalTrafficPolicy=Local \
        --set controller.metrics.enabled=true \
        --set controller.autoscaling.enabled=false \
        --set controller.resources.requests.cpu=100m \
        --set controller.resources.requests.memory=90Mi
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
ingress_post_deploy() {
  ui_log_info "Running ingress-nginx post-deployment tasks"
  
  # Wait for deployment to be ready
  ui_log_info "Waiting for ingress-nginx controller to be ready"
  kubectl rollout status deployment ingress-nginx-controller -n "$NAMESPACE" --timeout=180s
  
  # Check for IngressClass resource
  if kubectl get ingressclass nginx &>/dev/null; then
    ui_log_success "Ingress class 'nginx' is configured"
  else
    ui_log_warning "IngressClass 'nginx' not found. Creating default IngressClass"
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
EOF
  fi
  
  # Check if LoadBalancer service got an external IP
  local max_attempts=30
  local attempt=0
  local external_ip=""
  
  ui_log_info "Waiting for external IP (this may take a few minutes)..."
  while [ $attempt -lt $max_attempts ]; do
    external_ip=$(kubectl get service ingress-nginx-controller -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [[ -n "$external_ip" ]]; then
      ui_log_success "Ingress controller received external IP: $external_ip"
      break
    fi
    attempt=$((attempt+1))
    ui_log_info "Waiting for external IP... Attempt $attempt/$max_attempts"
    sleep 10
  done
  
  if [[ -z "$external_ip" ]]; then
    ui_log_warning "Ingress controller did not receive an external IP. Check your MetalLB or cloud provider configuration."
  fi
  
  return 0
}

# Verification function - verifies the component is working
ingress_verify() {
  ui_log_info "Verifying ingress-nginx installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check if controller is running
  if ! kubectl get deployment ingress-nginx-controller -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "ingress-nginx controller deployment not found"
    return 1
  fi
  
  # Check if pods are running
  local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$pods" || "$pods" != *"Running"* ]]; then
    ui_log_error "ingress-nginx pods are not running"
    return 1
  fi
  
  # Check if service is created
  if ! kubectl get service ingress-nginx-controller -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "ingress-nginx service not found"
    return 1
  fi
  
  # Check for IngressClass
  if ! kubectl get ingressclass nginx &>/dev/null; then
    ui_log_error "IngressClass 'nginx' not found"
    return 1
  fi
  
  # Test ingress controller by creating a test ingress
  ui_log_info "Creating a test deployment and service to verify ingress works"
  
  # Create a test namespace
  kubectl create namespace ingress-test 2>/dev/null || true
  
  # Create a simple test deployment
  cat <<EOF | kubectl apply -f - 2>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-test
  namespace: ingress-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ingress-test
  template:
    metadata:
      labels:
        app: ingress-test
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: ingress-test
  namespace: ingress-test
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: ingress-test
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-test
  namespace: ingress-test
spec:
  ingressClassName: nginx
  rules:
  - host: test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ingress-test
            port:
              number: 80
EOF
  
  # Wait for the test deployment to be ready
  kubectl rollout status deployment ingress-test -n ingress-test --timeout=60s
  
  # Check if the ingress resource is created
  if kubectl get ingress ingress-test -n ingress-test &>/dev/null; then
    ui_log_success "Test ingress created successfully"
  else
    ui_log_error "Failed to create test ingress"
  fi
  
  # Clean up test resources
  kubectl delete namespace ingress-test --wait=false
  
  ui_log_success "ingress-nginx verification completed"
  return 0
}

# Cleanup function - removes the component
ingress_cleanup() {
  ui_log_info "Cleaning up ingress-nginx"
  
  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "ingress-nginx"; then
    ui_log_info "Uninstalling ingress-nginx Helm release"
    helm uninstall ingress-nginx -n "$NAMESPACE"
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/infrastructure/ingress/kustomization.yaml" --ignore-not-found
  
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
  
  # Delete IngressClass
  if kubectl get ingressclass nginx &>/dev/null; then
    ui_log_info "Deleting default IngressClass"
    kubectl delete ingressclass nginx
  fi
  
  return 0
}

# Diagnose function - provides detailed diagnostics
ingress_diagnose() {
  ui_log_info "Running ingress-nginx diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Display pod status
  ui_subheader "Ingress Controller Pod Status"
  kubectl get pods -n "$NAMESPACE" -o wide
  
  # Display deployments
  ui_subheader "Ingress Controller Deployment"
  kubectl get deployment ingress-nginx-controller -n "$NAMESPACE" -o yaml
  
  # Display services
  ui_subheader "Ingress Controller Services"
  kubectl get services -n "$NAMESPACE"
  
  # Display service details
  ui_subheader "Ingress Controller Service Details"
  kubectl get service ingress-nginx-controller -n "$NAMESPACE" -o yaml
  
  # Show IngressClass resources
  ui_subheader "IngressClass Resources"
  kubectl get ingressclass
  
  # Check for ingress resources across all namespaces
  ui_subheader "Ingress Resources in Cluster"
  kubectl get ingress --all-namespaces
  
  # Check controller logs
  ui_subheader "Controller Logs"
  local controller_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$controller_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$controller_pod" --tail=50
  else
    ui_log_error "No ingress-nginx controller pod found"
  fi
  
  # Check config maps
  ui_subheader "Controller ConfigMaps"
  kubectl get configmap -n "$NAMESPACE" -l app.kubernetes.io/name=ingress-nginx
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20
  
  return 0
}

# Export functions
export -f ingress_pre_deploy
export -f ingress_deploy
export -f ingress_post_deploy
export -f ingress_verify
export -f ingress_cleanup
export -f ingress_diagnose 