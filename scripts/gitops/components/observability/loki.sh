#!/bin/bash
# loki.sh: Loki Component Functions
# Handles all operations specific to Loki log aggregation component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../..//"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="loki"
NAMESPACE="observability"  # Using the same namespace as Prometheus for easier integration
COMPONENT_DEPENDENCIES=("prometheus")  # Typically used with Prometheus/Grafana
RESOURCE_TYPES=("deployment" "service" "configmap" "secret" "statefulset" "persistentvolumeclaim")

# Pre-deployment function - runs before deployment
loki_pre_deploy() {
  ui_log_info "Running Loki pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Loki"
    return 1
  fi
  
  # Add Helm repo if needed
  if ! helm repo list | grep -q "grafana"; then
    ui_log_info "Adding Grafana Helm repository"
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
  fi
  
  return 0
}

# Deploy function - deploys the component
loki_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Loki using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      ui_log_info "Applying Loki kustomization with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/loki"
      
      # Check if the Flux GitRepository and Kustomization resources need to be created
      if ! kubectl get gitrepository -n flux-system observability &>/dev/null; then
        ui_log_info "Creating Flux GitRepository resource for observability components"
        # This would be handled by the cluster bootstrap process in a real environment
        ui_log_warning "Skipping creation of Flux GitRepository - use cluster bootstrap for full GitOps"
      fi

      if ! kubectl get kustomization -n flux-system observability &>/dev/null; then
        ui_log_info "Creating Flux Kustomization resource for observability components"
        # This would be handled by the cluster bootstrap process in a real environment
        ui_log_warning "Skipping creation of Flux Kustomization - use cluster bootstrap for full GitOps"
      fi
      ;;
    
    kubectl)
      # Direct kubectl apply
      ui_log_info "Applying Loki manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/loki"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying Loki with Helm"
      
      # Check if already installed
      if helm list -n "$NAMESPACE" | grep -q "loki"; then
        ui_log_info "Loki is already installed via Helm"
        return 0
      fi
      
      # Install Loki with default values for development
      helm install loki grafana/loki-stack -n "$NAMESPACE" \
        --set loki.persistence.enabled=true \
        --set loki.persistence.size=10Gi \
        --set loki.config.limits_config.enforce_metric_name=false \
        --set loki.config.limits_config.reject_old_samples=true \
        --set loki.config.limits_config.reject_old_samples_max_age=168h \
        --set loki.config.chunk_store_config.max_look_back_period=168h \
        --set loki.config.table_manager.retention_deletes_enabled=true \
        --set loki.config.table_manager.retention_period=168h \
        --set loki.resources.requests.cpu=100m \
        --set loki.resources.requests.memory=256Mi \
        --set loki.resources.limits.cpu=200m \
        --set loki.resources.limits.memory=512Mi \
        --set promtail.enabled=true
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
loki_post_deploy() {
  ui_log_info "Running Loki post-deployment tasks"
  
  # Wait for Loki deployment to be ready
  if kubectl get statefulset loki -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for Loki statefulset to be ready"
    kubectl rollout status statefulset loki -n "$NAMESPACE" --timeout=180s
  elif kubectl get deployment loki -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for Loki deployment to be ready"
    kubectl rollout status deployment loki -n "$NAMESPACE" --timeout=180s
  fi
  
  # Wait for Promtail daemonset to be ready
  if kubectl get daemonset promtail -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for Promtail daemonset to be ready"
    kubectl rollout status daemonset promtail -n "$NAMESPACE" --timeout=180s
  fi
  
  # Configure Grafana datasource for Loki if Grafana is present
  if kubectl get deployment -n "$NAMESPACE" | grep -q grafana; then
    ui_log_info "Configuring Grafana datasource for Loki"
    
    # Create Loki datasource configmap
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-grafana-datasource
  namespace: $NAMESPACE
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |-
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki:3100
      version: 1
      editable: true
      isDefault: false
EOF
    
    # Find the Grafana pod and restart it to apply the datasource
    local grafana_deployment=$(kubectl get deployment -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$grafana_deployment" ]; then
      ui_log_info "Restarting Grafana to apply new datasource configuration"
      kubectl rollout restart deployment "$grafana_deployment" -n "$NAMESPACE"
      kubectl rollout status deployment "$grafana_deployment" -n "$NAMESPACE" --timeout=180s
    fi
  else
    ui_log_warning "Grafana not found in namespace $NAMESPACE. Loki datasource must be configured manually."
  fi
  
  return 0
}

# Verification function - verifies the component is working
loki_verify() {
  ui_log_info "Verifying Loki installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check if Loki service exists
  if ! kubectl get service loki -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "Loki service not found"
    return 1
  fi
  
  # Check if Loki is running
  local loki_running=false
  if kubectl get statefulset loki -n "$NAMESPACE" &>/dev/null; then
    local loki_pods=$(kubectl get pods -n "$NAMESPACE" -l app=loki -o jsonpath='{.items[*].status.phase}')
    if [[ -n "$loki_pods" && "$loki_pods" == *"Running"* ]]; then
      loki_running=true
    fi
  elif kubectl get deployment loki -n "$NAMESPACE" &>/dev/null; then
    local loki_pods=$(kubectl get pods -n "$NAMESPACE" -l app=loki -o jsonpath='{.items[*].status.phase}')
    if [[ -n "$loki_pods" && "$loki_pods" == *"Running"* ]]; then
      loki_running=true
    fi
  fi
  
  if [ "$loki_running" = false ]; then
    ui_log_error "Loki is not running"
    return 1
  else
    ui_log_success "Loki is running"
  fi
  
  # Check if Promtail is running
  if kubectl get daemonset promtail -n "$NAMESPACE" &>/dev/null; then
    local promtail_pods=$(kubectl get pods -n "$NAMESPACE" -l app=promtail -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$promtail_pods" || "$promtail_pods" != *"Running"* ]]; then
      ui_log_error "Promtail pods are not running"
      return 1
    else
      ui_log_success "Promtail is running"
    fi
  else
    ui_log_warning "Promtail daemonset not found. Log collection might not be working."
  fi
  
  # Check if Loki API is accessible
  ui_log_info "Testing Loki API access"
  local loki_pod=$(kubectl get pods -n "$NAMESPACE" -l app=loki -o jsonpath='{.items[0].metadata.name}')
  if [ -n "$loki_pod" ]; then
    # Test if Loki responds to the ready endpoint
    local loki_ready=$(kubectl exec -n "$NAMESPACE" "$loki_pod" -- wget -q -O- http://localhost:3100/ready || echo "failed")
    if [[ "$loki_ready" == "ready" ]]; then
      ui_log_success "Loki API is accessible and ready"
    else
      ui_log_warning "Loki API did not respond correctly. It returned: $loki_ready"
    fi
  else
    ui_log_error "No Loki pods found"
    return 1
  fi
  
  # Check if Grafana has Loki datasource configured
  if kubectl get deployment -n "$NAMESPACE" | grep -q grafana; then
    ui_log_info "Checking if Loki datasource is configured in Grafana"
    
    local grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$grafana_pod" ]; then
      # We can't easily check the datasource config, so just note that Grafana is available
      ui_log_success "Grafana is available. Loki datasource should be configured."
      ui_log_info "To verify Loki datasource in Grafana UI: kubectl port-forward -n $NAMESPACE svc/prometheus-grafana 3000:80 and login to http://localhost:3000 (default: admin/admin)"
    fi
  else
    ui_log_warning "Grafana not found. Cannot verify Loki datasource configuration."
  fi
  
  ui_log_success "Loki verification completed"
  return 0
}

# Cleanup function - removes the component
loki_cleanup() {
  ui_log_info "Cleaning up Loki"
  
  # Remove Grafana datasource ConfigMap
  kubectl delete configmap loki-grafana-datasource -n "$NAMESPACE" --ignore-not-found
  
  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "loki"; then
    ui_log_info "Uninstalling Loki Helm release"
    helm uninstall loki -n "$NAMESPACE"
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/observability/loki/kustomization.yaml" --ignore-not-found
  
  # Delete PVCs if any
  ui_log_info "Checking for Loki PVCs"
  for pvc in $(kubectl get pvc -n "$NAMESPACE" -l app=loki -o jsonpath='{.items[*].metadata.name}'); do
    ui_log_info "Deleting PVC: $pvc"
    kubectl delete pvc "$pvc" -n "$NAMESPACE"
  done
  
  # Check if we need to delete the namespace (only if Prometheus is also not installed)
  if ! kubectl get deployment -n "$NAMESPACE" | grep -q prometheus; then
    ui_log_info "No other monitoring components found, considering namespace deletion"
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
  else
    ui_log_info "Keeping namespace $NAMESPACE as it contains other monitoring components"
  fi
  
  return 0
}

# Diagnose function - provides detailed diagnostics
loki_diagnose() {
  ui_log_info "Running Loki diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Display pod status
  ui_subheader "Loki and Promtail Pod Status"
  kubectl get pods -n "$NAMESPACE" -l app=loki -o wide
  kubectl get pods -n "$NAMESPACE" -l app=promtail -o wide
  
  # Display deployments or statefulsets
  ui_subheader "Loki Deployments/StatefulSets"
  if kubectl get statefulset loki -n "$NAMESPACE" &>/dev/null; then
    kubectl get statefulset loki -n "$NAMESPACE" -o yaml
  elif kubectl get deployment loki -n "$NAMESPACE" &>/dev/null; then
    kubectl get deployment loki -n "$NAMESPACE" -o yaml
  fi
  
  # Display Promtail daemonset
  ui_subheader "Promtail DaemonSet"
  if kubectl get daemonset promtail -n "$NAMESPACE" &>/dev/null; then
    kubectl get daemonset promtail -n "$NAMESPACE" -o yaml
  fi
  
  # Display services
  ui_subheader "Loki Services"
  kubectl get services -n "$NAMESPACE" -l app=loki
  
  # Display configmaps
  ui_subheader "Loki and Promtail ConfigMaps"
  kubectl get configmaps -n "$NAMESPACE" | grep -E "loki|promtail"
  
  # Display persistent volume claims
  ui_subheader "Loki PVCs"
  kubectl get pvc -n "$NAMESPACE" -l app=loki
  
  # Check Loki logs
  ui_subheader "Loki Logs"
  local loki_pod=$(kubectl get pods -n "$NAMESPACE" -l app=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$loki_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$loki_pod" --tail=30
  else
    ui_log_error "No Loki pod found"
  fi
  
  # Check Promtail logs
  ui_subheader "Promtail Logs (from first pod)"
  local promtail_pod=$(kubectl get pods -n "$NAMESPACE" -l app=promtail -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$promtail_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$promtail_pod" --tail=30
  else
    ui_log_error "No Promtail pod found"
  fi
  
  # Check Loki configuration
  ui_subheader "Loki Configuration"
  if kubectl get configmap loki -n "$NAMESPACE" &>/dev/null; then
    kubectl get configmap loki -n "$NAMESPACE" -o jsonpath='{.data.loki\.yaml}' | grep -v "^$"
  elif kubectl get configmap loki-stack -n "$NAMESPACE" &>/dev/null; then
    kubectl get configmap loki-stack -n "$NAMESPACE" -o jsonpath='{.data.loki\.yaml}' | grep -v "^$"
  else
    ui_log_warning "No Loki configmap found"
  fi
  
  # Check Grafana datasource configuration
  ui_subheader "Loki Grafana Datasource ConfigMap"
  kubectl get configmap loki-grafana-datasource -n "$NAMESPACE" -o yaml 2>/dev/null || ui_log_warning "Loki Grafana datasource configmap not found"
  
  # Check if Loki is working properly using API endpoints
  ui_subheader "Loki API Status"
  if [ -n "$loki_pod" ]; then
    ui_log_info "Loki Ready Status:"
    kubectl exec -n "$NAMESPACE" "$loki_pod" -- wget -q -O- http://localhost:3100/ready || echo "Not ready"
    
    ui_log_info "Loki Metrics (sample):"
    kubectl exec -n "$NAMESPACE" "$loki_pod" -- wget -q -O- http://localhost:3100/metrics | grep -E "loki_build_info|loki_distributor|loki_ingester" | head -5
  fi
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$loki_pod" --sort-by='.lastTimestamp' | tail -10
  
  return 0
}

# Export functions
export -f loki_pre_deploy
export -f loki_deploy
export -f loki_post_deploy
export -f loki_verify
export -f loki_cleanup
export -f loki_diagnose 