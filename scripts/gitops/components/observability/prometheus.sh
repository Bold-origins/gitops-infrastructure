#!/bin/bash
# prometheus.sh: Prometheus Component Functions
# Handles all operations specific to Prometheus monitoring component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="prometheus"
NAMESPACE="observability"
COMPONENT_DEPENDENCIES=()  # No explicit dependencies
RESOURCE_TYPES=("deployment" "service" "configmap" "secret" "statefulset" "prometheus" "servicemonitor" "podmonitor")

# Pre-deployment function - runs before deployment
prometheus_pre_deploy() {
  ui_log_info "Running Prometheus pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Prometheus"
    return 1
  fi
  
  # Add Helm repo if needed
  if ! helm repo list | grep -q "prometheus-community"; then
    ui_log_info "Adding Prometheus Community Helm repository"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
  fi
  
  # Check for prometheus-operator CRDs
  local crds=(
    "prometheuses.monitoring.coreos.com"
    "alertmanagers.monitoring.coreos.com"
    "servicemonitors.monitoring.coreos.com"
    "podmonitors.monitoring.coreos.com"
    "prometheusrules.monitoring.coreos.com"
    "thanosrulers.monitoring.coreos.com"
  )
  
  local crds_missing=false
  for crd in "${crds[@]}"; do
    if ! kubectl get crd "$crd" &>/dev/null; then
      ui_log_warning "CRD $crd is not installed"
      crds_missing=true
    fi
  done
  
  if [ "$crds_missing" = true ]; then
    ui_log_info "Installing Prometheus Operator CRDs"
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
  fi
  
  return 0
}

# Deploy function - deploys the component
prometheus_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Prometheus using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      ui_log_info "Applying Prometheus kustomization with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/prometheus"
      
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
      ui_log_info "Applying Prometheus manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/prometheus"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying Prometheus with Helm"
      
      # Check if already installed
      if helm list -n "$NAMESPACE" | grep -q "prometheus"; then
        ui_log_info "Prometheus is already installed via Helm"
        return 0
      fi
      
      # Install kube-prometheus-stack which includes Prometheus, Alertmanager and Grafana
      helm install prometheus prometheus-community/kube-prometheus-stack -n "$NAMESPACE" \
        --set prometheus.service.type=ClusterIP \
        --set alertmanager.service.type=ClusterIP \
        --set grafana.service.type=ClusterIP \
        --set grafana.adminPassword=admin \
        --set prometheus.prometheusSpec.retention=10d \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
        --set prometheus.prometheusSpec.resources.requests.cpu=300m \
        --set prometheus.prometheusSpec.resources.requests.memory=1Gi \
        --set prometheus.prometheusSpec.resources.limits.cpu=1000m \
        --set prometheus.prometheusSpec.resources.limits.memory=2Gi \
        --set alertmanager.alertmanagerSpec.resources.requests.cpu=100m \
        --set alertmanager.alertmanagerSpec.resources.requests.memory=256Mi \
        --set alertmanager.alertmanagerSpec.resources.limits.cpu=300m \
        --set alertmanager.alertmanagerSpec.resources.limits.memory=512Mi
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
prometheus_post_deploy() {
  ui_log_info "Running Prometheus post-deployment tasks"
  
  # Wait for Prometheus operator to be ready
  local operator_deployment="prometheus-kube-prometheus-operator"
  ui_log_info "Waiting for Prometheus operator to be ready"
  kubectl rollout status deployment -n "$NAMESPACE" "$operator_deployment" --timeout=300s || true
  
  # Wait for Prometheus StatefulSet to be ready
  ui_log_info "Waiting for Prometheus server to be ready"
  kubectl rollout status statefulset -n "$NAMESPACE" prometheus-prometheus-kube-prometheus-prometheus --timeout=300s || true
  
  # Wait for Alertmanager StatefulSet to be ready
  ui_log_info "Waiting for Alertmanager to be ready"
  kubectl rollout status statefulset -n "$NAMESPACE" alertmanager-prometheus-kube-prometheus-alertmanager --timeout=180s || true
  
  # Wait for Grafana deployment to be ready (part of kube-prometheus-stack)
  ui_log_info "Waiting for Grafana to be ready"
  kubectl rollout status deployment -n "$NAMESPACE" prometheus-grafana --timeout=180s || true
  
  # Apply additional ServiceMonitors if they exist
  local servicemonitors_dir="${BASE_DIR}/clusters/local/observability/prometheus/servicemonitors"
  if [ -d "$servicemonitors_dir" ]; then
    ui_log_info "Applying additional ServiceMonitors from $servicemonitors_dir"
    kubectl apply -f "$servicemonitors_dir"
  fi
  
  # Apply additional PrometheusRules if they exist
  local rules_dir="${BASE_DIR}/clusters/local/observability/prometheus/rules"
  if [ -d "$rules_dir" ]; then
    ui_log_info "Applying additional PrometheusRules from $rules_dir"
    kubectl apply -f "$rules_dir"
  fi
  
  # Create an ingress for Grafana if ingress-nginx is available
  if kubectl get ingressclass nginx &>/dev/null; then
    ui_log_info "Creating Ingress for Grafana"
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - host: grafana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
EOF
  fi
  
  ui_log_success "Prometheus stack post-deployment completed"
  return 0
}

# Verification function - verifies the component is working
prometheus_verify() {
  ui_log_info "Verifying Prometheus installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check if Prometheus operator deployment exists
  local operator_deployment="prometheus-kube-prometheus-operator"
  if ! kubectl get deployment -n "$NAMESPACE" "$operator_deployment" &>/dev/null; then
    ui_log_error "Prometheus operator deployment not found"
    return 1
  fi
  
  # Check if Prometheus statefulset exists
  if ! kubectl get statefulset -n "$NAMESPACE" prometheus-prometheus-kube-prometheus-prometheus &>/dev/null; then
    ui_log_error "Prometheus statefulset not found"
    return 1
  fi
  
  # Check if Alertmanager statefulset exists
  if ! kubectl get statefulset -n "$NAMESPACE" alertmanager-prometheus-kube-prometheus-alertmanager &>/dev/null; then
    ui_log_error "Alertmanager statefulset not found"
    return 1
  fi
  
  # Check if Grafana deployment exists
  if ! kubectl get deployment -n "$NAMESPACE" prometheus-grafana &>/dev/null; then
    ui_log_error "Grafana deployment not found"
    return 1
  fi
  
  # Check if the pods are running
  ui_log_info "Checking if Prometheus pods are running"
  
  local prometheus_pods=$(kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$prometheus_pods" || "$prometheus_pods" != *"Running"* ]]; then
    ui_log_error "Prometheus pods are not running"
    return 1
  fi
  
  local grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
  if [ -z "$grafana_pod" ]; then
    ui_log_error "Grafana pod not found"
    return 1
  fi
  
  # Check if Prometheus can be accessed
  ui_log_info "Testing Prometheus API access"
  local prometheus_svc="prometheus-kube-prometheus-prometheus"
  local access_test=$(kubectl run --rm -i --restart=Never curl-test --image=curlimages/curl:7.78.0 --namespace "$NAMESPACE" -- \
    curl -s --connect-timeout 5 "http://$prometheus_svc:9090/api/v1/status/buildinfo" | grep version || echo "failed")
  
  if [[ "$access_test" == *"failed"* ]]; then
    ui_log_warning "Could not access Prometheus API. Network policies or other issues may be preventing access."
  else
    ui_log_success "Successfully accessed Prometheus API"
  fi
  
  # Check if some ServiceMonitors are created
  local servicemonitors=$(kubectl get servicemonitors -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  if [ -z "$servicemonitors" ]; then
    ui_log_warning "No ServiceMonitors found in namespace $NAMESPACE"
  else
    ui_log_success "Found ServiceMonitors: $servicemonitors"
  fi
  
  # Check if some Prometheus rules are created
  local rules=$(kubectl get prometheusrules -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
  if [ -z "$rules" ]; then
    ui_log_warning "No PrometheusRules found in namespace $NAMESPACE"
  else
    ui_log_success "Found PrometheusRules: $rules"
  fi
  
  # Output services and access information
  ui_log_info "Prometheus UI is available at: http://prometheus-kube-prometheus-prometheus.$NAMESPACE.svc:9090"
  ui_log_info "Alertmanager UI is available at: http://alertmanager-prometheus-kube-prometheus-alertmanager.$NAMESPACE.svc:9093"
  ui_log_info "Grafana is available at: http://prometheus-grafana.$NAMESPACE.svc"
  ui_log_info "Default Grafana credentials: admin / admin"
  
  ui_log_success "Prometheus verification completed"
  return 0
}

# Cleanup function - removes the component
prometheus_cleanup() {
  ui_log_info "Cleaning up Prometheus"
  
  # Delete Ingress for Grafana if it exists
  kubectl delete ingress -n "$NAMESPACE" grafana-ingress --ignore-not-found
  
  # Delete additional resources if they exist
  local servicemonitors_dir="${BASE_DIR}/clusters/local/observability/prometheus/servicemonitors"
  if [ -d "$servicemonitors_dir" ]; then
    ui_log_info "Removing custom ServiceMonitors"
    kubectl delete -f "$servicemonitors_dir" --ignore-not-found
  fi
  
  local rules_dir="${BASE_DIR}/clusters/local/observability/prometheus/rules"
  if [ -d "$rules_dir" ]; then
    ui_log_info "Removing custom PrometheusRules"
    kubectl delete -f "$rules_dir" --ignore-not-found
  fi
  
  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "prometheus"; then
    ui_log_info "Uninstalling Prometheus Helm release"
    helm uninstall prometheus -n "$NAMESPACE"
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/observability/prometheus/kustomization.yaml" --ignore-not-found
  
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
  
  # Check for Prometheus Operator CRDs and optionally remove them
  ui_log_info "Checking for Prometheus Operator CRDs"
  local crds=(
    "prometheuses.monitoring.coreos.com"
    "alertmanagers.monitoring.coreos.com"
    "servicemonitors.monitoring.coreos.com"
    "podmonitors.monitoring.coreos.com"
    "prometheusrules.monitoring.coreos.com"
    "thanosrulers.monitoring.coreos.com"
  )
  
  for crd in "${crds[@]}"; do
    if kubectl get crd "$crd" &>/dev/null; then
      ui_log_warning "CRD $crd still exists. You may want to remove it manually if no other components use it."
      # Uncomment to automatically delete CRDs if needed
      # ui_log_info "Deleting CRD: $crd"
      # kubectl delete crd "$crd"
    fi
  done
  
  return 0
}

# Diagnose function - provides detailed diagnostics
prometheus_diagnose() {
  ui_log_info "Running Prometheus diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Display pod status
  ui_subheader "Prometheus Stack Pod Status"
  kubectl get pods -n "$NAMESPACE" -o wide
  
  # Display deployments
  ui_subheader "Prometheus Stack Deployments"
  kubectl get deployments -n "$NAMESPACE"
  
  # Display statefulsets
  ui_subheader "Prometheus Stack StatefulSets"
  kubectl get statefulsets -n "$NAMESPACE"
  
  # Display services
  ui_subheader "Prometheus Stack Services"
  kubectl get services -n "$NAMESPACE"
  
  # Display configmaps
  ui_subheader "Prometheus ConfigMaps"
  kubectl get configmaps -n "$NAMESPACE" | grep -E "prometheus|grafana|alertmanager"
  
  # Display Prometheus CRs
  ui_subheader "Prometheus Custom Resources"
  kubectl get prometheuses -n "$NAMESPACE"
  
  # Display Alertmanager CRs
  ui_subheader "Alertmanager Custom Resources"
  kubectl get alertmanagers -n "$NAMESPACE"
  
  # Display ServiceMonitors
  ui_subheader "ServiceMonitors"
  kubectl get servicemonitors --all-namespaces
  
  # Display PodMonitors
  ui_subheader "PodMonitors"
  kubectl get podmonitors --all-namespaces
  
  # Display PrometheusRules
  ui_subheader "PrometheusRules"
  kubectl get prometheusrules --all-namespaces
  
  # Check Prometheus logs
  ui_subheader "Prometheus Logs"
  local prometheus_pod=$(kubectl get pods -n "$NAMESPACE" -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$prometheus_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$prometheus_pod" --tail=30
  else
    ui_log_error "No Prometheus pod found"
  fi
  
  # Check Grafana logs
  ui_subheader "Grafana Logs"
  local grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$grafana_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$grafana_pod" --tail=30
  else
    ui_log_error "No Grafana pod found"
  fi
  
  # Check Alertmanager logs
  ui_subheader "Alertmanager Logs"
  local alertmanager_pod=$(kubectl get pods -n "$NAMESPACE" -l app=alertmanager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$alertmanager_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$alertmanager_pod" --tail=30
  else
    ui_log_error "No Alertmanager pod found"
  fi
  
  # Check Prometheus Targets
  ui_subheader "Prometheus Targets Status"
  ui_log_info "To check targets manually: kubectl port-forward -n $NAMESPACE svc/prometheus-kube-prometheus-prometheus 9090:9090 and visit http://localhost:9090/targets"
  
  # Display PVCs
  ui_subheader "Persistent Volume Claims"
  kubectl get pvc -n "$NAMESPACE"
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20
  
  return 0
}

# Export functions
export -f prometheus_pre_deploy
export -f prometheus_deploy
export -f prometheus_post_deploy
export -f prometheus_verify
export -f prometheus_cleanup
export -f prometheus_diagnose 