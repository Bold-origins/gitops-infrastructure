#!/bin/bash
# grafana.sh: Grafana Component Functions
# Handles all operations specific to Grafana visualization platform

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="grafana"
NAMESPACE="monitoring"  # Using the same namespace as Prometheus, Loki, and Tempo
COMPONENT_DEPENDENCIES=("prometheus")  # Primarily dependent on Prometheus
RESOURCE_TYPES=("deployment" "service" "configmap" "secret" "ingress" "persistentvolumeclaim")

# Pre-deployment function - runs before deployment
grafana_pre_deploy() {
  ui_log_info "Running Grafana pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Grafana"
    return 1
  fi
  
  # Add Helm repo if needed
  if ! helm repo list | grep -q "grafana"; then
    ui_log_info "Adding Grafana Helm repository"
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
  fi
  
  # Check for existing Grafana instance (might be deployed with Prometheus)
  if kubectl get deployment -n "$NAMESPACE" | grep -q "prometheus-grafana\|grafana"; then
    ui_log_warning "Grafana instance already detected in namespace $NAMESPACE. This might be from the kube-prometheus-stack."
    ui_log_warning "If you continue, ensure you're not creating conflicts with the existing Grafana deployment."
    
    # Offer to use the existing deployment instead
    if [ -t 0 ] && [ -t 1 ]; then  # Only if running in interactive mode
      read -p "Continue with this deployment? [y/N] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        ui_log_info "Deployment aborted. Use the existing Grafana instance."
        exit 0
      fi
    fi
  fi
  
  return 0
}

# Deploy function - deploys the component
grafana_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Grafana using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      kubectl apply -f "${BASE_DIR}/clusters/local/observability/grafana/kustomization.yaml"
      ;;
    
    kubectl)
      # Direct kubectl apply
      ui_log_info "Applying Grafana manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/grafana"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying Grafana with Helm"
      
      # Check if already installed
      if helm list -n "$NAMESPACE" | grep -q "^grafana"; then
        ui_log_info "Grafana is already installed via Helm"
        return 0
      fi
      
      # Install with default values for development
      helm install grafana grafana/grafana -n "$NAMESPACE" \
        --set persistence.enabled=true \
        --set persistence.size=5Gi \
        --set service.type=ClusterIP \
        --set adminPassword=admin \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=128Mi \
        --set resources.limits.cpu=200m \
        --set resources.limits.memory=256Mi \
        --set plugins="grafana-piechart-panel,grafana-worldmap-panel,grafana-clock-panel,grafana-polystat-panel" \
        --set "datasources.secretName=grafana-datasources" \
        --set "dashboardProviders.dashboardproviders\\.yaml.apiVersion=1" \
        --set "dashboardProviders.dashboardproviders\\.yaml.providers[0].name=default" \
        --set "dashboardProviders.dashboardproviders\\.yaml.providers[0].orgId=1" \
        --set "dashboardProviders.dashboardproviders\\.yaml.providers[0].folder=" \
        --set "dashboardProviders.dashboardproviders\\.yaml.providers[0].type=file" \
        --set "dashboardProviders.dashboardproviders\\.yaml.providers[0].disableDeletion=false" \
        --set "dashboardProviders.dashboardproviders\\.yaml.providers[0].editable=true" \
        --set "dashboardProviders.dashboardproviders\\.yaml.providers[0].options.path=/var/lib/grafana/dashboards/default"
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
grafana_post_deploy() {
  ui_log_info "Running Grafana post-deployment tasks"
  
  # Wait for deployment to be ready
  ui_log_info "Waiting for Grafana deployment to be ready"
  kubectl rollout status deployment grafana -n "$NAMESPACE" --timeout=180s
  
  # Create datasources based on what's available in the cluster
  ui_log_info "Configuring Grafana datasources"
  
  # Prepare datasource configurations
  local datasources="[]"
  
  # Check if Prometheus is available and add datasource
  if kubectl get service -n "$NAMESPACE" | grep -q "prometheus-kube-prometheus-prometheus"; then
    ui_log_info "Adding Prometheus datasource"
    datasources=$(echo "$datasources" | jq '. += [{
      "name": "Prometheus",
      "type": "prometheus",
      "access": "proxy",
      "url": "http://prometheus-kube-prometheus-prometheus:9090",
      "isDefault": true,
      "editable": true,
      "jsonData": {
        "timeInterval": "5s"
      }
    }]')
  elif kubectl get service -n "$NAMESPACE" | grep -q "prometheus"; then
    ui_log_info "Adding generic Prometheus datasource"
    datasources=$(echo "$datasources" | jq '. += [{
      "name": "Prometheus",
      "type": "prometheus",
      "access": "proxy",
      "url": "http://prometheus:9090",
      "isDefault": true,
      "editable": true,
      "jsonData": {
        "timeInterval": "5s"
      }
    }]')
  fi
  
  # Check if Loki is available and add datasource
  if kubectl get service -n "$NAMESPACE" | grep -q "loki"; then
    ui_log_info "Adding Loki datasource"
    datasources=$(echo "$datasources" | jq '. += [{
      "name": "Loki",
      "type": "loki",
      "access": "proxy",
      "url": "http://loki:3100",
      "isDefault": false,
      "editable": true
    }]')
  fi
  
  # Check if Tempo is available and add datasource
  if kubectl get service -n "$NAMESPACE" | grep -q "tempo"; then
    ui_log_info "Adding Tempo datasource"
    # Determine Loki UID for linking traces to logs
    local loki_uid="loki"
    if command -v jq &>/dev/null; then
      loki_uid=$(echo "$datasources" | jq -r '.[] | select(.name == "Loki") | .uid // "loki"')
    fi
    
    datasources=$(echo "$datasources" | jq --arg loki_uid "$loki_uid" '. += [{
      "name": "Tempo",
      "type": "tempo",
      "access": "proxy",
      "url": "http://tempo:3100",
      "isDefault": false,
      "editable": true,
      "jsonData": {
        "httpMethod": "GET",
        "tracesToLogs": {
          "datasourceUid": $loki_uid,
          "tags": ["instance", "pod", "namespace"],
          "spanEndTimeShift": "100ms",
          "spanStartTimeShift": "-100ms",
          "filterByTraceID": true,
          "filterBySpanID": true,
          "lokiSearch": true
        }
      }
    }]')
  fi
  
  # Create datasources secret
  if [ "$(echo "$datasources" | jq 'length')" -gt 0 ]; then
    kubectl create secret generic grafana-datasources -n "$NAMESPACE" \
      --from-literal=datasources.yaml="$(cat <<EOF
apiVersion: 1
datasources: $(echo "$datasources" | jq -c .)
EOF
)" \
      --dry-run=client -o yaml | kubectl apply -f -
    
    ui_log_success "Created Grafana datasources configuration"
  fi
  
  # If using ingress-nginx, create an ingress for Grafana
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
            name: grafana
            port:
              number: 80
EOF
  fi
  
  # Import some useful dashboards
  ui_log_info "Importing useful dashboards"
  
  # Create a ConfigMap with dashboard definitions
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: $NAMESPACE
  labels:
    grafana_dashboard: "1"
data:
  kubernetes-cluster-monitoring.json: |-
    $(curl -s https://raw.githubusercontent.com/grafana/grafana/main/public/app/plugins/datasource/prometheus/dashboards/kubernetes-cluster-monitoring.json | jq -c .)
  kubernetes-pod-monitoring.json: |-
    $(curl -s https://raw.githubusercontent.com/grafana/grafana/main/public/app/plugins/datasource/prometheus/dashboards/kubernetes-pod-monitoring.json | jq -c .)
  kubernetes-nodes.json: |-
    $(curl -s https://raw.githubusercontent.com/grafana/grafana/main/public/app/plugins/datasource/prometheus/dashboards/kubernetes-nodes.json | jq -c .)
EOF
  
  # Restart Grafana to apply changes
  ui_log_info "Restarting Grafana to apply new configurations"
  kubectl rollout restart deployment grafana -n "$NAMESPACE"
  kubectl rollout status deployment grafana -n "$NAMESPACE" --timeout=180s
  
  return 0
}

# Verification function - verifies the component is working
grafana_verify() {
  ui_log_info "Verifying Grafana installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check if deployment exists and is running
  if ! kubectl get deployment grafana -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "Grafana deployment not found"
    return 1
  fi
  
  local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$pods" || "$pods" != *"Running"* ]]; then
    ui_log_error "Grafana pods are not running"
    return 1
  else
    ui_log_success "Grafana pods are running"
  fi
  
  # Check if service exists
  if ! kubectl get service grafana -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "Grafana service not found"
    return 1
  else
    ui_log_success "Grafana service exists"
  fi
  
  # Check if ingress exists if ingress controller is available
  if kubectl get ingressclass nginx &>/dev/null; then
    if ! kubectl get ingress grafana-ingress -n "$NAMESPACE" &>/dev/null; then
      ui_log_warning "Grafana ingress not found, but ingress controller is available"
    else
      ui_log_success "Grafana ingress exists"
    fi
  fi
  
  # Check if datasources are configured
  if kubectl get secret grafana-datasources -n "$NAMESPACE" &>/dev/null; then
    ui_log_success "Grafana datasources are configured"
  else
    ui_log_warning "Grafana datasources secret not found"
  fi
  
  # Check if dashboards are imported
  if kubectl get configmap grafana-dashboards -n "$NAMESPACE" &>/dev/null; then
    ui_log_success "Grafana dashboards are imported"
  else
    ui_log_warning "Grafana dashboards configmap not found"
  fi
  
  # Test API access
  ui_log_info "Testing Grafana API access"
  local grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
  if [ -n "$grafana_pod" ]; then
    # Get Grafana health status
    local grafana_health=$(kubectl exec -n "$NAMESPACE" "$grafana_pod" -- wget -q -O- http://localhost:3000/api/health 2>/dev/null)
    if [[ "$grafana_health" == *"ok"* ]]; then
      ui_log_success "Grafana API is accessible and reports healthy status"
    else
      ui_log_warning "Grafana API did not respond with healthy status: $grafana_health"
    fi
  else
    ui_log_error "No Grafana pod found"
    return 1
  fi
  
  # Print access information
  ui_log_info "Grafana is accessible via:"
  ui_log_info "- Service: grafana.$NAMESPACE:80"
  
  # Get Ingress URL if available
  local ingress_host=$(kubectl get ingress grafana-ingress -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
  if [ -n "$ingress_host" ]; then
    local ingress_ip=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$ingress_ip" ]; then
      ui_log_info "- Ingress: http://$ingress_host (add \"$ingress_ip $ingress_host\" to your /etc/hosts)"
    else
      ui_log_info "- Ingress: http://$ingress_host (DNS needs to be configured)"
    fi
  fi
  
  ui_log_info "- Port Forward: kubectl port-forward -n $NAMESPACE svc/grafana 3000:80"
  ui_log_info "Default credentials: admin / admin"
  
  ui_log_success "Grafana verification completed"
  return 0
}

# Cleanup function - removes the component
grafana_cleanup() {
  ui_log_info "Cleaning up Grafana"
  
  # Remove ingress
  kubectl delete ingress grafana-ingress -n "$NAMESPACE" --ignore-not-found
  
  # Remove dashboard ConfigMap
  kubectl delete configmap grafana-dashboards -n "$NAMESPACE" --ignore-not-found
  
  # Remove datasources secret
  kubectl delete secret grafana-datasources -n "$NAMESPACE" --ignore-not-found
  
  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "^grafana"; then
    ui_log_info "Uninstalling Grafana Helm release"
    helm uninstall grafana -n "$NAMESPACE"
  else
    # For non-Helm deployments
    ui_log_info "Removing Grafana resources"
    kubectl delete deployment grafana -n "$NAMESPACE" --ignore-not-found
    kubectl delete service grafana -n "$NAMESPACE" --ignore-not-found
    kubectl delete configmap grafana -n "$NAMESPACE" --ignore-not-found
    kubectl delete secret grafana -n "$NAMESPACE" --ignore-not-found
    kubectl delete pvc -l app.kubernetes.io/name=grafana -n "$NAMESPACE" --ignore-not-found
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/observability/grafana/kustomization.yaml" --ignore-not-found
  
  # Check if we need to delete the namespace (only if other components are also not installed)
  if ! kubectl get deployment -n "$NAMESPACE" | grep -qE "prometheus|loki|tempo"; then
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
grafana_diagnose() {
  ui_log_info "Running Grafana diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Display pod status
  ui_subheader "Grafana Pod Status"
  kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o wide
  
  # Display deployment
  ui_subheader "Grafana Deployment"
  kubectl get deployment grafana -n "$NAMESPACE" -o yaml
  
  # Display service
  ui_subheader "Grafana Service"
  kubectl get service grafana -n "$NAMESPACE" -o yaml
  
  # Display ingress if exists
  if kubectl get ingress grafana-ingress -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "Grafana Ingress"
    kubectl get ingress grafana-ingress -n "$NAMESPACE" -o yaml
  fi
  
  # Display datasources
  ui_subheader "Grafana Datasources"
  if kubectl get secret grafana-datasources -n "$NAMESPACE" &>/dev/null; then
    kubectl get secret grafana-datasources -n "$NAMESPACE" -o jsonpath='{.data.datasources\.yaml}' | base64 -d
  else
    ui_log_warning "No Grafana datasources secret found"
  fi
  
  # Display dashboards
  ui_subheader "Grafana Dashboards"
  if kubectl get configmap grafana-dashboards -n "$NAMESPACE" &>/dev/null; then
    kubectl get configmap grafana-dashboards -n "$NAMESPACE" -o jsonpath='{.data}' | grep -o '"title":"[^"]*"' | sort
  else
    ui_log_warning "No Grafana dashboards configmap found"
  fi
  
  # Display persistent volume claims
  ui_subheader "Grafana PVCs"
  kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/name=grafana
  
  # Check Grafana logs
  ui_subheader "Grafana Logs"
  local grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$grafana_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$grafana_pod" --tail=50
  else
    ui_log_error "No Grafana pod found"
  fi
  
  # Check Grafana health and configuration
  if [ -n "$grafana_pod" ]; then
    ui_subheader "Grafana Health Status"
    kubectl exec -n "$NAMESPACE" "$grafana_pod" -- wget -q -O- http://localhost:3000/api/health || echo "Health check failed"
    
    ui_subheader "Grafana Settings"
    kubectl exec -n "$NAMESPACE" "$grafana_pod" -- wget -q -O- http://localhost:3000/api/admin/settings || echo "Failed to get settings"
    
    ui_subheader "Grafana Datasources"
    kubectl exec -n "$NAMESPACE" "$grafana_pod" -- wget -q -O- http://admin:admin@localhost:3000/api/datasources | grep -o '"name":"[^"]*"' || echo "Failed to get datasources"
    
    ui_subheader "Grafana Plugins"
    kubectl exec -n "$NAMESPACE" "$grafana_pod" -- wget -q -O- http://admin:admin@localhost:3000/api/plugins | grep -o '"id":"[^"]*"' | sort || echo "Failed to get plugins"
  fi
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$grafana_pod" --sort-by='.lastTimestamp' | tail -20
  
  return 0
}

# Export functions
export -f grafana_pre_deploy
export -f grafana_deploy
export -f grafana_post_deploy
export -f grafana_verify
export -f grafana_cleanup
export -f grafana_diagnose 