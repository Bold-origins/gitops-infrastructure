#!/bin/bash
# kube-state-metrics.sh: Kube State Metrics Component Functions
# Handles all operations for Kubernetes resource state metrics collection component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="kube-state-metrics"
NAMESPACE="monitoring"  # Using the same namespace as Prometheus and other monitoring components
COMPONENT_DEPENDENCIES=("prometheus")  # Works best with Prometheus for scraping metrics
RESOURCE_TYPES=("deployment" "service" "clusterrole" "clusterrolebinding" "serviceaccount")

# Pre-deployment function - runs before deployment
kube_state_metrics_pre_deploy() {
  ui_log_info "Running Kube State Metrics pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Kube State Metrics"
    return 1
  fi
  
  # Add Helm repo if needed
  if ! helm repo list | grep -q "prometheus-community"; then
    ui_log_info "Adding Prometheus Community Helm repository"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
  fi
  
  # Check if already installed by prometheus-operator
  if kubectl get deployment -n "$NAMESPACE" | grep -q "prometheus-kube-state-metrics"; then
    ui_log_warning "Kube State Metrics already appears to be deployed by prometheus-operator"
    ui_log_warning "Installing another instance may cause duplicated metrics and resource waste"
    
    # Offer to abort the installation
    if [ -t 0 ] && [ -t 1 ]; then  # Only if running in interactive mode
      read -p "Continue with this deployment? [y/N] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        ui_log_info "Deployment aborted. Use the existing Kube State Metrics instance."
        exit 0
      fi
    fi
  fi
  
  return 0
}

# Deploy function - deploys the component
kube_state_metrics_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Kube State Metrics using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      kubectl apply -f "${BASE_DIR}/clusters/local/observability/kube-state-metrics/kustomization.yaml"
      ;;
    
    kubectl)
      # Direct kubectl apply from the official repository
      ui_log_info "Applying Kube State Metrics manifests directly with kubectl"
      kubectl apply -f https://github.com/kubernetes/kube-state-metrics/releases/download/v2.9.2/standard-manifests.yaml
      
      # Patch the deployment to set specific namespace
      kubectl -n kube-system patch deployment kube-state-metrics --patch "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"app.kubernetes.io/name\":\"kube-state-metrics\"}}}}}"
      
      # Move the deployment to the monitoring namespace if needed
      if [ "$NAMESPACE" != "kube-system" ]; then
        ui_log_info "Moving Kube State Metrics from kube-system to $NAMESPACE namespace"
        
        # Extract current resources
        kubectl get deployment kube-state-metrics -n kube-system -o yaml > /tmp/ksm-deployment.yaml
        kubectl get service kube-state-metrics -n kube-system -o yaml > /tmp/ksm-service.yaml
        kubectl get serviceaccount kube-state-metrics -n kube-system -o yaml > /tmp/ksm-sa.yaml
        kubectl get clusterrole kube-state-metrics -o yaml > /tmp/ksm-cr.yaml
        kubectl get clusterrolebinding kube-state-metrics -o yaml > /tmp/ksm-crb.yaml
        
        # Update namespace in the resources
        sed -i.bak "s/namespace: kube-system/namespace: $NAMESPACE/g" /tmp/ksm-*.yaml
        
        # Apply resources in the new namespace
        kubectl apply -f /tmp/ksm-sa.yaml
        kubectl apply -f /tmp/ksm-deployment.yaml
        kubectl apply -f /tmp/ksm-service.yaml
        kubectl apply -f /tmp/ksm-cr.yaml
        kubectl apply -f /tmp/ksm-crb.yaml
        
        # Delete resources from the old namespace
        kubectl delete deployment kube-state-metrics -n kube-system
        kubectl delete service kube-state-metrics -n kube-system
        kubectl delete serviceaccount kube-state-metrics -n kube-system
        
        # Clean up temp files
        rm -f /tmp/ksm-*.yaml /tmp/ksm-*.yaml.bak
      fi
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying Kube State Metrics with Helm"
      
      # Check if already installed
      if helm list -n "$NAMESPACE" | grep -q "kube-state-metrics"; then
        ui_log_info "Kube State Metrics is already installed via Helm"
        return 0
      fi
      
      # Install with Helm
      helm install kube-state-metrics prometheus-community/kube-state-metrics -n "$NAMESPACE" \
        --set replicas=1 \
        --set resources.requests.cpu=10m \
        --set resources.requests.memory=32Mi \
        --set resources.limits.cpu=100m \
        --set resources.limits.memory=128Mi \
        --set autoDiscovery.enabled=true \
        --set rbac.create=true \
        --set serviceAccount.create=true \
        --set prometheusScrape=true \
        --set metricLabelsAllowlist.default=["persistentvolumeclaim:*"]
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
kube_state_metrics_post_deploy() {
  ui_log_info "Running Kube State Metrics post-deployment tasks"
  
  # Wait for deployment to be ready
  local deployment_name="kube-state-metrics"
  
  # Handle case where prometheus-operator deployed it
  if ! kubectl get deployment "$deployment_name" -n "$NAMESPACE" &>/dev/null; then
    if kubectl get deployment prometheus-kube-state-metrics -n "$NAMESPACE" &>/dev/null; then
      deployment_name="prometheus-kube-state-metrics"
    fi
  fi
  
  if kubectl get deployment "$deployment_name" -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for $deployment_name deployment to be ready"
    kubectl rollout status deployment "$deployment_name" -n "$NAMESPACE" --timeout=180s
  else
    ui_log_warning "Kube State Metrics deployment not found in namespace $NAMESPACE"
    return 1
  fi
  
  # Create ServiceMonitor for Prometheus if it doesn't exist and Prometheus-operator is installed
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor && \
     ! kubectl get servicemonitor -n "$NAMESPACE" | grep -q "$deployment_name"; then
    ui_log_info "Creating ServiceMonitor for Kube State Metrics"
    
    cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: $deployment_name
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: $deployment_name
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: $deployment_name
  namespaceSelector:
    matchNames:
      - $NAMESPACE
  endpoints:
  - port: http
    interval: 30s
    honorLabels: true
    metricRelabelings:
    - sourceLabels: [namespace]
      action: replace
      regex: (.*)
      targetLabel: kubernetes_namespace
      replacement: \$1
    - sourceLabels: [pod]
      action: replace
      regex: (.*)
      targetLabel: pod_name
      replacement: \$1
EOF
    
    ui_log_success "ServiceMonitor created for Kube State Metrics"
  fi
  
  return 0
}

# Verification function - verifies the component is working
kube_state_metrics_verify() {
  ui_log_info "Verifying Kube State Metrics installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # First check for the standard deployment name
  local deployment_name="kube-state-metrics"
  
  # If not found, check for the prometheus-operator style name
  if ! kubectl get deployment "$deployment_name" -n "$NAMESPACE" &>/dev/null; then
    if kubectl get deployment prometheus-kube-state-metrics -n "$NAMESPACE" &>/dev/null; then
      deployment_name="prometheus-kube-state-metrics"
      ui_log_info "Found prometheus-operator style deployment: $deployment_name"
    else
      ui_log_error "Kube State Metrics deployment not found in namespace $NAMESPACE"
      return 1
    fi
  fi
  
  # Check if pods are running
  local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$deployment_name" -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$pods" || "$pods" != *"Running"* ]]; then
    ui_log_error "Kube State Metrics pods are not running"
    return 1
  else
    ui_log_success "Kube State Metrics pods are running"
  fi
  
  # Check if service exists
  if ! kubectl get service "$deployment_name" -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "Kube State Metrics service not found"
    return 1
  else
    ui_log_success "Kube State Metrics service exists"
  fi
  
  # Check RBAC resources
  if ! kubectl get clusterrole | grep -q "$deployment_name"; then
    ui_log_warning "Kube State Metrics ClusterRole not found - it might not have sufficient permissions"
  else
    ui_log_success "Kube State Metrics ClusterRole exists"
  fi
  
  if ! kubectl get clusterrolebinding | grep -q "$deployment_name"; then
    ui_log_warning "Kube State Metrics ClusterRoleBinding not found - it might not have sufficient permissions"
  else
    ui_log_success "Kube State Metrics ClusterRoleBinding exists"
  fi
  
  # Check if ServiceMonitor exists if Prometheus-operator is installed
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor; then
    if ! kubectl get servicemonitor -n "$NAMESPACE" | grep -q "$deployment_name"; then
      ui_log_warning "ServiceMonitor for Kube State Metrics not found - Prometheus may not auto-discover it"
    else
      ui_log_success "ServiceMonitor for Kube State Metrics exists"
    fi
  fi
  
  # Test metrics endpoint
  ui_log_info "Testing Kube State Metrics API access"
  local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$deployment_name" -o jsonpath='{.items[0].metadata.name}')
  if [ -n "$pod_name" ]; then
    # Test the metrics endpoint
    local metrics_test=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q -O- http://localhost:8080/metrics 2>/dev/null | head -5)
    
    if [ -n "$metrics_test" ]; then
      ui_log_success "Successfully accessed Kube State Metrics endpoint"
      ui_log_info "Sample metrics from endpoint: "
      echo "$metrics_test"
    else
      ui_log_warning "Could not access Kube State Metrics endpoint"
    fi
  else
    ui_log_error "No Kube State Metrics pod found"
    return 1
  fi
  
  ui_log_success "Kube State Metrics verification completed"
  return 0
}

# Cleanup function - removes the component
kube_state_metrics_cleanup() {
  ui_log_info "Cleaning up Kube State Metrics"
  
  # Determine deployment name
  local deployment_name="kube-state-metrics"
  if ! kubectl get deployment "$deployment_name" -n "$NAMESPACE" &>/dev/null; then
    if kubectl get deployment prometheus-kube-state-metrics -n "$NAMESPACE" &>/dev/null; then
      deployment_name="prometheus-kube-state-metrics"
    fi
  fi
  
  # Remove ServiceMonitor if it exists
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor; then
    if kubectl get servicemonitor -n "$NAMESPACE" "$deployment_name" &>/dev/null; then
      ui_log_info "Removing ServiceMonitor for Kube State Metrics"
      kubectl delete servicemonitor "$deployment_name" -n "$NAMESPACE"
    fi
  fi
  
  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "kube-state-metrics"; then
    ui_log_info "Uninstalling Kube State Metrics Helm release"
    helm uninstall kube-state-metrics -n "$NAMESPACE"
  else
    # Only clean up if not part of prometheus-operator
    if [ "$deployment_name" != "prometheus-kube-state-metrics" ]; then
      ui_log_info "Removing Kube State Metrics resources"
      
      # Delete deployment and service
      kubectl delete deployment "$deployment_name" -n "$NAMESPACE" --ignore-not-found
      kubectl delete service "$deployment_name" -n "$NAMESPACE" --ignore-not-found
      
      # Delete RBAC resources
      kubectl delete serviceaccount "$deployment_name" -n "$NAMESPACE" --ignore-not-found
      kubectl delete clusterrole "$deployment_name" --ignore-not-found
      kubectl delete clusterrolebinding "$deployment_name" --ignore-not-found
    else
      ui_log_info "Skipping cleanup of $deployment_name as it appears to be managed by prometheus-operator"
    fi
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/observability/kube-state-metrics/kustomization.yaml" --ignore-not-found
  
  # We don't delete the namespace since other monitoring components likely share it
  ui_log_info "Keeping namespace $NAMESPACE as it likely contains other monitoring components"
  
  return 0
}

# Diagnose function - provides detailed diagnostics
kube_state_metrics_diagnose() {
  ui_log_info "Running Kube State Metrics diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Determine deployment name
  local deployment_name="kube-state-metrics"
  if ! kubectl get deployment "$deployment_name" -n "$NAMESPACE" &>/dev/null; then
    if kubectl get deployment prometheus-kube-state-metrics -n "$NAMESPACE" &>/dev/null; then
      deployment_name="prometheus-kube-state-metrics"
    fi
  fi
  
  # Display pod status
  ui_subheader "Kube State Metrics Pod Status"
  kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$deployment_name" -o wide
  
  # Display deployment
  ui_subheader "Kube State Metrics Deployment"
  kubectl get deployment "$deployment_name" -n "$NAMESPACE" -o yaml
  
  # Display service
  ui_subheader "Kube State Metrics Service"
  kubectl get service "$deployment_name" -n "$NAMESPACE" -o yaml
  
  # Display RBAC resources
  ui_subheader "Kube State Metrics RBAC Resources"
  kubectl get clusterrole | grep "$deployment_name"
  kubectl get clusterrolebinding | grep "$deployment_name"
  kubectl get serviceaccount "$deployment_name" -n "$NAMESPACE" -o yaml
  
  # Display ServiceMonitor if it exists
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor; then
    ui_subheader "Kube State Metrics ServiceMonitor"
    kubectl get servicemonitor "$deployment_name" -n "$NAMESPACE" -o yaml 2>/dev/null || \
      ui_log_warning "No ServiceMonitor found for $deployment_name"
  fi
  
  # Check pod logs
  ui_subheader "Kube State Metrics Logs"
  local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$deployment_name" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$pod_name" ]; then
    kubectl logs -n "$NAMESPACE" "$pod_name" --tail=30
  else
    ui_log_error "No Kube State Metrics pod found"
  fi
  
  # Check metrics
  ui_subheader "Kube State Metrics Sample"
  if [ -n "$pod_name" ]; then
    ui_log_info "Metrics sample:"
    kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q -O- http://localhost:8080/metrics 2>/dev/null | grep -E "^kube_node|^kube_pod|^kube_deployment" | head -20 || \
      ui_log_warning "Could not retrieve metrics from Kube State Metrics"
    
    ui_log_info "Metric types available:"
    kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q -O- http://localhost:8080/metrics 2>/dev/null | grep "^kube_" | grep -v "{" | cut -d ' ' -f 1 | sort | uniq | head -20 || \
      ui_log_warning "Could not retrieve metric types from Kube State Metrics"
  fi
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp' | tail -10
  
  # Check if Prometheus can scrape kube-state-metrics
  if kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' &>/dev/null; then
    ui_subheader "Prometheus Target Status"
    kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' | \
      xargs -I{} kubectl exec -n "$NAMESPACE" {} -- wget -q -O- http://localhost:9090/api/v1/targets 2>/dev/null | \
      grep -A 10 -B 2 "kube-state-metrics" || ui_log_warning "Could not check if Prometheus is scraping kube-state-metrics"
  fi
  
  return 0
}

# Export functions
export -f kube_state_metrics_pre_deploy
export -f kube_state_metrics_deploy
export -f kube_state_metrics_post_deploy
export -f kube_state_metrics_verify
export -f kube_state_metrics_cleanup
export -f kube_state_metrics_diagnose 