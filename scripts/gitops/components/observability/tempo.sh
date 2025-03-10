#!/bin/bash
# tempo.sh: Tempo Component Functions
# Handles all operations specific to Tempo distributed tracing component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../..//"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="tempo"
NAMESPACE="observability"  # Using the same namespace as Prometheus and Loki for easier integration
COMPONENT_DEPENDENCIES=("prometheus" "loki")  # Works best with Prometheus and Loki for complete observability
RESOURCE_TYPES=("deployment" "service" "configmap" "secret" "statefulset" "persistentvolumeclaim")

# Pre-deployment function - runs before deployment
tempo_pre_deploy() {
  ui_log_info "Running Tempo pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Tempo"
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
tempo_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Tempo using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      ui_log_info "Applying Tempo kustomization with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/tempo"
      
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
      ui_log_info "Applying Tempo manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/tempo"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying Tempo with Helm"
      
      # Check if already installed
      if helm list -n "$NAMESPACE" | grep -q "tempo"; then
        ui_log_info "Tempo is already installed via Helm"
        return 0
      fi
      
      # Install Tempo with default values for development
      helm install tempo grafana/tempo -n "$NAMESPACE" \
        --set tempo.persistence.enabled=true \
        --set tempo.persistence.size=10Gi \
        --set tempo.receivers.jaeger.protocols.thrift_http.endpoint="0.0.0.0:14268" \
        --set tempo.receivers.jaeger.protocols.grpc.endpoint="0.0.0.0:14250" \
        --set tempo.receivers.zipkin.endpoint="0.0.0.0:9411" \
        --set tempo.receivers.otlp.protocols.grpc.endpoint="0.0.0.0:4317" \
        --set tempo.receivers.otlp.protocols.http.endpoint="0.0.0.0:4318" \
        --set tempo.resources.requests.cpu=100m \
        --set tempo.resources.requests.memory=256Mi \
        --set tempo.resources.limits.cpu=200m \
        --set tempo.resources.limits.memory=512Mi \
        --set global.clusterDomain=cluster.local
      
      # Install OpenTelemetry collector for easy instrumentation (optional)
      ui_log_info "Installing OpenTelemetry Collector for better instrumentation"
      if ! helm list -n "$NAMESPACE" | grep -q "opentelemetry-collector"; then
        helm install opentelemetry-collector grafana/opentelemetry-collector -n "$NAMESPACE" \
          --set config.exporters.otlp.endpoint="tempo:4317" \
          --set config.exporters.otlp.tls.insecure=true \
          --set mode=daemonset
      fi
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
tempo_post_deploy() {
  ui_log_info "Running Tempo post-deployment tasks"
  
  # Wait for Tempo deployment to be ready
  if kubectl get statefulset tempo -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for Tempo statefulset to be ready"
    kubectl rollout status statefulset tempo -n "$NAMESPACE" --timeout=180s
  elif kubectl get deployment tempo -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for Tempo deployment to be ready"
    kubectl rollout status deployment tempo -n "$NAMESPACE" --timeout=180s
  fi
  
  # Wait for OpenTelemetry Collector daemonset to be ready if installed
  if kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for OpenTelemetry Collector daemonset to be ready"
    kubectl rollout status daemonset opentelemetry-collector -n "$NAMESPACE" --timeout=180s
  fi
  
  # Configure Grafana datasource for Tempo if Grafana is present
  if kubectl get deployment -n "$NAMESPACE" | grep -q grafana; then
    ui_log_info "Configuring Grafana datasource for Tempo"
    
    # Create Tempo datasource configmap
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo-grafana-datasource
  namespace: $NAMESPACE
  labels:
    grafana_datasource: "1"
data:
  tempo-datasource.yaml: |-
    apiVersion: 1
    datasources:
    - name: Tempo
      type: tempo
      access: proxy
      url: http://tempo:3100
      version: 1
      editable: true
      isDefault: false
      jsonData:
        httpMethod: GET
        tracesToLogs:
          datasourceUid: ${LOKI_DS_UID:-loki}
          tags: ['instance', 'pod', 'namespace']
          spanEndTimeShift: "100ms"
          spanStartTimeShift: "-100ms"
          filterByTraceID: true
          filterBySpanID: true
          lokiSearch: true
EOF
    
    # Find the Grafana pod and restart it to apply the datasource
    local grafana_deployment=$(kubectl get deployment -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$grafana_deployment" ]; then
      ui_log_info "Restarting Grafana to apply new datasource configuration"
      kubectl rollout restart deployment "$grafana_deployment" -n "$NAMESPACE"
      kubectl rollout status deployment "$grafana_deployment" -n "$NAMESPACE" --timeout=180s
    fi
  else
    ui_log_warning "Grafana not found in namespace $NAMESPACE. Tempo datasource must be configured manually."
  fi
  
  return 0
}

# Verification function - verifies the component is working
tempo_verify() {
  ui_log_info "Verifying Tempo installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check if Tempo service exists
  if ! kubectl get service tempo -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "Tempo service not found"
    return 1
  fi
  
  # Check if Tempo is running
  local tempo_running=false
  if kubectl get statefulset tempo -n "$NAMESPACE" &>/dev/null; then
    local tempo_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tempo -o jsonpath='{.items[*].status.phase}')
    if [[ -n "$tempo_pods" && "$tempo_pods" == *"Running"* ]]; then
      tempo_running=true
    fi
  elif kubectl get deployment tempo -n "$NAMESPACE" &>/dev/null; then
    local tempo_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tempo -o jsonpath='{.items[*].status.phase}')
    if [[ -n "$tempo_pods" && "$tempo_pods" == *"Running"* ]]; then
      tempo_running=true
    fi
  fi
  
  if [ "$tempo_running" = false ]; then
    ui_log_error "Tempo is not running"
    return 1
  else
    ui_log_success "Tempo is running"
  fi
  
  # Check if OpenTelemetry Collector is running if installed
  if kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    local collector_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opentelemetry-collector -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$collector_pods" || "$collector_pods" != *"Running"* ]]; then
      ui_log_warning "OpenTelemetry Collector pods are not all running"
    else
      ui_log_success "OpenTelemetry Collector is running"
    fi
  fi
  
  # Check if Tempo API is accessible
  ui_log_info "Testing Tempo API access"
  local tempo_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.name}')
  if [ -n "$tempo_pod" ]; then
    # Test if Tempo responds to the ready endpoint
    local tempo_ready=$(kubectl exec -n "$NAMESPACE" "$tempo_pod" -- wget -q -O- http://localhost:3100/ready || echo "failed")
    if [[ "$tempo_ready" == "ready" ]]; then
      ui_log_success "Tempo API is accessible and ready"
    else
      ui_log_warning "Tempo API did not respond correctly. It returned: $tempo_ready"
    fi
  else
    ui_log_error "No Tempo pods found"
    return 1
  fi
  
  # Check if Grafana has Tempo datasource configured
  if kubectl get deployment -n "$NAMESPACE" | grep -q grafana; then
    ui_log_info "Checking if Tempo datasource is configured in Grafana"
    
    local grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$grafana_pod" ]; then
      # We can't easily check the datasource config, so just note that Grafana is available
      ui_log_success "Grafana is available. Tempo datasource should be configured."
      ui_log_info "To verify Tempo datasource in Grafana UI: kubectl port-forward -n $NAMESPACE svc/prometheus-grafana 3000:80 and login to http://localhost:3000 (default: admin/admin)"
    fi
  else
    ui_log_warning "Grafana not found. Cannot verify Tempo datasource configuration."
  fi
  
  # Provide information about how to test tracing
  ui_log_info "Tempo is now ready to receive traces. Applications need to be instrumented with OpenTelemetry or other tracing libraries."
  ui_log_info "Tempo accepts traces via multiple protocols:"
  ui_log_info "- Jaeger: http://tempo.$NAMESPACE:14268/api/traces (Thrift HTTP) or tempo.$NAMESPACE:14250 (gRPC)"
  ui_log_info "- Zipkin: http://tempo.$NAMESPACE:9411/api/v2/spans"
  ui_log_info "- OTLP: tempo.$NAMESPACE:4317 (gRPC) or http://tempo.$NAMESPACE:4318 (HTTP)"
  
  ui_log_success "Tempo verification completed"
  return 0
}

# Cleanup function - removes the component
tempo_cleanup() {
  ui_log_info "Cleaning up Tempo"
  
  # Remove Grafana datasource ConfigMap
  kubectl delete configmap tempo-grafana-datasource -n "$NAMESPACE" --ignore-not-found
  
  # Check OpenTelemetry Collector deployment method and clean up
  if helm list -n "$NAMESPACE" | grep -q "opentelemetry-collector"; then
    ui_log_info "Uninstalling OpenTelemetry Collector Helm release"
    helm uninstall opentelemetry-collector -n "$NAMESPACE"
  fi
  
  # Check Tempo deployment method and clean up
  if helm list -n "$NAMESPACE" | grep -q "tempo"; then
    ui_log_info "Uninstalling Tempo Helm release"
    helm uninstall tempo -n "$NAMESPACE"
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/observability/tempo/kustomization.yaml" --ignore-not-found
  
  # Delete PVCs if any
  ui_log_info "Checking for Tempo PVCs"
  for pvc in $(kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/name=tempo -o jsonpath='{.items[*].metadata.name}'); do
    ui_log_info "Deleting PVC: $pvc"
    kubectl delete pvc "$pvc" -n "$NAMESPACE"
  done
  
  # Check if we need to delete the namespace (only if Prometheus and Loki are also not installed)
  if ! kubectl get deployment -n "$NAMESPACE" | grep -qE "prometheus|loki"; then
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
tempo_diagnose() {
  ui_log_info "Running Tempo diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Display pod status
  ui_subheader "Tempo Pod Status"
  kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tempo -o wide
  
  # Display OpenTelemetry Collector pod status if installed
  if kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "OpenTelemetry Collector Pod Status"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opentelemetry-collector -o wide
  fi
  
  # Display deployments or statefulsets
  ui_subheader "Tempo Deployments/StatefulSets"
  if kubectl get statefulset tempo -n "$NAMESPACE" &>/dev/null; then
    kubectl get statefulset tempo -n "$NAMESPACE" -o yaml
  elif kubectl get deployment tempo -n "$NAMESPACE" &>/dev/null; then
    kubectl get deployment tempo -n "$NAMESPACE" -o yaml
  fi
  
  # Display services
  ui_subheader "Tempo Services"
  kubectl get services -n "$NAMESPACE" -l app.kubernetes.io/name=tempo
  
  # Display configmaps
  ui_subheader "Tempo ConfigMaps"
  kubectl get configmaps -n "$NAMESPACE" | grep -E "tempo"
  
  # Display persistent volume claims
  ui_subheader "Tempo PVCs"
  kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/name=tempo
  
  # Check Tempo logs
  ui_subheader "Tempo Logs"
  local tempo_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$tempo_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$tempo_pod" --tail=30
  else
    ui_log_error "No Tempo pod found"
  fi
  
  # Check OpenTelemetry Collector logs if installed
  if kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "OpenTelemetry Collector Logs (from first pod)"
    local collector_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$collector_pod" ]; then
      kubectl logs -n "$NAMESPACE" "$collector_pod" --tail=30
    else
      ui_log_error "No OpenTelemetry Collector pod found"
    fi
  fi
  
  # Check Tempo configuration
  ui_subheader "Tempo Configuration"
  if kubectl get configmap tempo -n "$NAMESPACE" &>/dev/null; then
    kubectl get configmap tempo -n "$NAMESPACE" -o yaml
  fi
  
  # Check Grafana datasource configuration
  ui_subheader "Tempo Grafana Datasource ConfigMap"
  kubectl get configmap tempo-grafana-datasource -n "$NAMESPACE" -o yaml 2>/dev/null || ui_log_warning "Tempo Grafana datasource configmap not found"
  
  # Check Tempo receiver status
  ui_subheader "Tempo API Status"
  if [ -n "$tempo_pod" ]; then
    ui_log_info "Tempo Ready Status:"
    kubectl exec -n "$NAMESPACE" "$tempo_pod" -- wget -q -O- http://localhost:3100/ready || echo "Not ready"
    
    ui_log_info "Tempo Metrics (sample):"
    kubectl exec -n "$NAMESPACE" "$tempo_pod" -- wget -q -O- http://localhost:3100/metrics | grep -E "tempo_ingester|tempo_receiver_accepted_spans" | head -5
  fi
  
  # Check OpenTelemetry Collector status if installed
  if kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" &>/dev/null && [ -n "$collector_pod" ]; then
    ui_subheader "OpenTelemetry Collector Status"
    kubectl exec -n "$NAMESPACE" "$collector_pod" -- wget -q -O- http://localhost:8888/metrics | grep -E "otelcol_receiver|otelcol_exporter" | head -5
  fi
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$tempo_pod" --sort-by='.lastTimestamp' | tail -10
  
  return 0
}

# Export functions
export -f tempo_pre_deploy
export -f tempo_deploy
export -f tempo_post_deploy
export -f tempo_verify
export -f tempo_cleanup
export -f tempo_diagnose 