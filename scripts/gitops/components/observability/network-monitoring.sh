#!/bin/bash
# network-monitoring.sh: Network Monitoring Component Functions
# Handles all operations for Kubernetes network monitoring and observability

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="network-monitoring"
NAMESPACE="monitoring"  # Using the same namespace as other monitoring components
COMPONENT_DEPENDENCIES=("prometheus")  # Primarily dependent on Prometheus for metrics storage
RESOURCE_TYPES=("deployment" "service" "configmap" "daemonset" "serviceaccount" "clusterrole" "clusterrolebinding")

# Pre-deployment function - runs before deployment
network_monitoring_pre_deploy() {
  ui_log_info "Running Network Monitoring pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Network Monitoring"
    return 1
  fi
  
  # Add Helm repo for Cilium if needed (for Hubble)
  if ! helm repo list | grep -q "cilium"; then
    ui_log_info "Adding Cilium Helm repository for Hubble"
    helm repo add cilium https://helm.cilium.io/
  fi
  
  # Add Helm repo for Prometheus community (for kube-prometheus-stack)
  if ! helm repo list | grep -q "prometheus-community"; then
    ui_log_info "Adding Prometheus Community Helm repository"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  fi
  
  # Update Helm repos
  ui_log_info "Updating Helm repositories"
  helm repo update
  
  return 0
}

# Deploy function - deploys the component
network_monitoring_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Network Monitoring using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      kubectl apply -f "${BASE_DIR}/clusters/local/observability/network/kustomization.yaml"
      ;;
    
    kubectl)
      # Direct kubectl apply
      ui_log_info "Applying Network Monitoring manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/network"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying Network Monitoring components with Helm"
      
      # Determine which network plugin the cluster is using
      local network_plugin=""
      if kubectl get daemonset -n kube-system cilium-agent &>/dev/null; then
        network_plugin="cilium"
        ui_log_info "Detected Cilium as the network plugin, will deploy Hubble for network observability"
      elif kubectl get daemonset -n kube-system calico-node &>/dev/null; then
        network_plugin="calico"
        ui_log_info "Detected Calico as the network plugin, will deploy Calico network observability"
      else
        ui_log_info "No specific network plugin detected, deploying generic network monitoring"
        network_plugin="generic"
      fi
      
      # Deploy network monitoring based on the detected network plugin
      case "$network_plugin" in
        cilium)
          # Deploy Hubble for Cilium network observability
          if ! helm list -n kube-system | grep -q "cilium"; then
            ui_log_warning "Cilium was detected but not managed via Helm, will try to enable Hubble with clustermesh-apiserver"
            # Create temporary file with Hubble configuration
            cat > /tmp/hubble-values.yaml <<EOF
clustermesh:
  apiserver:
    enabled: true
hubble:
  enabled: true
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
EOF
            
            # Install Hubble UI and Relay
            helm install hubble-ui cilium/hubble-ui --namespace kube-system
          else
            ui_log_info "Cilium is managed via Helm, updating to enable Hubble"
            # Update Cilium with Hubble enabled
            helm upgrade cilium cilium/cilium --namespace kube-system \
              --reuse-values \
              --set hubble.enabled=true \
              --set hubble.metrics.enabled=true \
              --set hubble.metrics.serviceMonitor.enabled=true \
              --set hubble.relay.enabled=true \
              --set hubble.ui.enabled=true
          fi
          
          # Wait for Hubble components to be ready
          ui_log_info "Waiting for Hubble components to be ready"
          if kubectl get deployment -n kube-system hubble-relay &>/dev/null; then
            kubectl rollout status deployment -n kube-system hubble-relay --timeout=180s
          fi
          
          if kubectl get deployment -n kube-system hubble-ui &>/dev/null; then
            kubectl rollout status deployment -n kube-system hubble-ui --timeout=180s
          fi
          ;;
        
        calico)
          # For Calico, deploy the Prometheus Adapter for Calico metrics
          ui_log_info "Setting up Calico network monitoring"
          
          # Check if Prometheus ServiceMonitor CRD exists
          if ! kubectl get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
            ui_log_warning "ServiceMonitor CRD not found, deploying Prometheus Operator first"
            helm install prometheus-operator prometheus-community/kube-prometheus-stack \
              --namespace "$NAMESPACE" \
              --set prometheusOperator.createCustomResource=true \
              --set prometheus.enabled=false \
              --set alertmanager.enabled=false \
              --set grafana.enabled=false
          fi
          
          # Create ServiceMonitor for Calico metrics
          cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: calico-monitoring
  namespace: $NAMESPACE
  labels:
    app: calico-monitoring
    release: prometheus
spec:
  selector:
    matchLabels:
      k8s-app: calico-node
  endpoints:
  - port: metrics
    interval: 30s
  namespaceSelector:
    matchNames:
    - kube-system
EOF
          ;;
        
        generic)
          # Install network monitoring components for generic Kubernetes
          ui_log_info "Deploying generic Kubernetes network monitoring"
          
          # Deploy kube-proxy metrics
          if kubectl get cm -n kube-system kube-proxy-config &>/dev/null; then
            ui_log_info "Found kube-proxy config, patching to enable metrics"
            # Get current config
            kubectl get cm -n kube-system kube-proxy-config -o yaml > /tmp/kube-proxy-config.yaml
            
            # Patch config to enable metrics server
            if ! grep -q "metricsBindAddress" /tmp/kube-proxy-config.yaml; then
              ui_log_info "Adding metrics configuration to kube-proxy"
              sed -i 's/kind: KubeProxyConfiguration/kind: KubeProxyConfiguration\nmetricsBindAddress: 0.0.0.0:10249/' /tmp/kube-proxy-config.yaml
              kubectl apply -f /tmp/kube-proxy-config.yaml
              
              # Restart kube-proxy
              ui_log_info "Restarting kube-proxy to apply new configuration"
              kubectl patch daemonset -n kube-system kube-proxy -p '{"spec": {"template": {"metadata": {"annotations": {"date": "'"$(date)"'"}}}}}' 
            fi
          fi
          
          # Deploy Prometheus NetworkMonitor CRD if using prometheus-operator
          if kubectl get crd servicemonitors.monitoring.coreos.com &>/dev/null; then
            ui_log_info "Creating ServiceMonitor for kube-proxy"
            cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kube-proxy
  namespace: $NAMESPACE
  labels:
    app: kube-proxy
    release: prometheus
spec:
  selector:
    matchLabels:
      k8s-app: kube-proxy
  endpoints:
  - port: metrics
    interval: 30s
  namespaceSelector:
    matchNames:
    - kube-system
EOF
          fi
          
          # Deploy network policy explorer if Kubernetes NetworkPolicy is used
          if kubectl get networkpolicies --all-namespaces 2>/dev/null | grep -q .; then
            ui_log_info "Detected NetworkPolicies, deploying NetworkPolicy monitoring tools"
            
            # Deploy Network Policy Explorer
            kubectl apply -f https://raw.githubusercontent.com/busquets/kubectl-npex/main/deploy/npex.yaml
          fi
          ;;
      esac
      
      # Deploy Node Exporter for node network statistics if not already present
      if ! kubectl get daemonset -n "$NAMESPACE" node-exporter &>/dev/null; then
        ui_log_info "Deploying Node Exporter for network metrics collection"
        helm install node-exporter prometheus-community/prometheus-node-exporter \
          --namespace "$NAMESPACE" \
          --set service.port=9100 \
          --set service.targetPort=9100 \
          --set serviceAccount.create=true \
          --set rbac.create=true \
          --set prometheus.monitor.enabled=true \
          --set prometheus.monitor.relabelings[0].targetLabel="job" \
          --set prometheus.monitor.relabelings[0].replacement="node-exporter"
      fi
      
      # Deploy Blackbox Exporter for network probing
      if ! kubectl get deployment -n "$NAMESPACE" blackbox-exporter &>/dev/null; then
        ui_log_info "Deploying Blackbox Exporter for network probing"
        helm install blackbox-exporter prometheus-community/prometheus-blackbox-exporter \
          --namespace "$NAMESPACE" \
          --set serviceAccount.create=true \
          --set pspEnabled=false \
          --set podSecurityContext.runAsUser=65534 \
          --set podSecurityContext.runAsNonRoot=true \
          --set serviceMonitor.enabled=true \
          --set serviceMonitor.defaults.module=http_2xx \
          --set serviceMonitor.defaults.interval=30s \
          --set serviceMonitor.targets[0].name="kubernetes-http" \
          --set serviceMonitor.targets[0].url="https://kubernetes.default.svc:443/healthz"
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
network_monitoring_post_deploy() {
  ui_log_info "Running Network Monitoring post-deployment tasks"
  
  # Wait for node-exporter daemonset to be ready if it exists
  if kubectl get daemonset -n "$NAMESPACE" node-exporter &>/dev/null; then
    ui_log_info "Waiting for Node Exporter daemonset to be ready"
    kubectl rollout status daemonset -n "$NAMESPACE" node-exporter --timeout=180s
  fi
  
  # Wait for blackbox-exporter deployment to be ready if it exists
  if kubectl get deployment -n "$NAMESPACE" blackbox-exporter &>/dev/null; then
    ui_log_info "Waiting for Blackbox Exporter deployment to be ready"
    kubectl rollout status deployment -n "$NAMESPACE" blackbox-exporter --timeout=180s
  fi
  
  # Check if Grafana is installed and create dashboard for network monitoring
  if kubectl get deployment -n "$NAMESPACE" grafana &>/dev/null; then
    ui_log_info "Setting up network monitoring dashboards in Grafana"
    
    # Create ConfigMap with network dashboards
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: network-dashboards
  namespace: $NAMESPACE
  labels:
    grafana_dashboard: "1"
data:
  kubernetes-network.json: |-
    $(curl -s https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-system-pod-network.json | jq -c .)
  blackbox-exporter.json: |-
    $(curl -s https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/prometheus-blackbox-exporter/values.yaml | grep -A1000 "dashboards:" | grep -m1 -B1000 "^\`\`\`" | grep -v "^\`\`\`" | grep -v "dashboards:" | sed 's/^  //' | jq -c .)
EOF
    
    # Restart Grafana to detect new dashboards
    ui_log_info "Restarting Grafana to apply new dashboards"
    kubectl rollout restart deployment -n "$NAMESPACE" grafana
    kubectl rollout status deployment -n "$NAMESPACE" grafana --timeout=180s
  fi
  
  # Set up alerting rules for network monitoring if prometheus-operator is installed
  if kubectl get crd prometheusrules.monitoring.coreos.com &>/dev/null; then
    ui_log_info "Setting up network monitoring alert rules"
    
    cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-monitoring-alerts
  namespace: $NAMESPACE
  labels:
    app: network-monitoring
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
  - name: network-monitoring
    rules:
    - alert: NodeNetworkInterfaceFlapping
      annotations:
        description: Network interface {{ \$labels.device }} on node {{ \$labels.instance }} is flapping
        summary: Network interface is flapping
      expr: |
        changes(node_network_up{device!~"lo|veth.*|docker.*|flannel.*|cali.*|cbr.*|cni.*"}[5m]) > 2
      for: 2m
      labels:
        severity: warning
    - alert: NodeNetworkReceiveErrs
      annotations:
        description: Node {{ \$labels.instance }} interface {{ \$labels.device }} has encountered {{ printf "%.0f" \$value }} receive errors in the last 5 minutes.
        summary: Node Network Receive Errors
      expr: |
        rate(node_network_receive_errs_total[5m]) > 0
      for: 15m
      labels:
        severity: warning
    - alert: NodeNetworkTransmitErrs
      annotations:
        description: Node {{ \$labels.instance }} interface {{ \$labels.device }} has encountered {{ printf "%.0f" \$value }} transmit errors in the last 5 minutes.
        summary: Node Network Transmit Errors
      expr: |
        rate(node_network_transmit_errs_total[5m]) > 0
      for: 15m
      labels:
        severity: warning
    - alert: BlackboxProbeFailed
      annotations:
        description: Blackbox probe {{ \$labels.job }} failed for {{ \$labels.instance }}.
        summary: Blackbox probe failed
      expr: |
        probe_success == 0
      for: 5m
      labels:
        severity: warning
    - alert: BlackboxSlowProbe
      annotations:
        description: Blackbox probe took more than 1s to complete for {{ \$labels.instance }}.
        summary: Blackbox probe is slow
      expr: |
        probe_duration_seconds > 1
      for: 10m
      labels:
        severity: warning
EOF
  fi
  
  return 0
}

# Verification function - verifies the component is working
network_monitoring_verify() {
  ui_log_info "Verifying Network Monitoring installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check Node Exporter
  if kubectl get daemonset -n "$NAMESPACE" node-exporter &>/dev/null; then
    local node_exporter_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus-node-exporter -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$node_exporter_pods" || "$node_exporter_pods" != *"Running"* ]]; then
      ui_log_error "Node Exporter pods are not running"
    else
      ui_log_success "Node Exporter is running"
    fi
  else
    ui_log_warning "Node Exporter is not installed in namespace $NAMESPACE"
  fi
  
  # Check Blackbox Exporter
  if kubectl get deployment -n "$NAMESPACE" blackbox-exporter &>/dev/null; then
    local blackbox_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus-blackbox-exporter -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$blackbox_pods" || "$blackbox_pods" != *"Running"* ]]; then
      ui_log_error "Blackbox Exporter pods are not running"
    else
      ui_log_success "Blackbox Exporter is running"
    fi
  else
    ui_log_warning "Blackbox Exporter is not installed in namespace $NAMESPACE"
  fi
  
  # Check Cilium Hubble if present
  if kubectl get deployment -n kube-system hubble-relay &>/dev/null; then
    local hubble_status=$(kubectl get pods -n kube-system -l k8s-app=hubble-relay -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$hubble_status" || "$hubble_status" != *"Running"* ]]; then
      ui_log_error "Hubble Relay is not running"
    else
      ui_log_success "Hubble Relay is running"
    fi
    
    if kubectl get deployment -n kube-system hubble-ui &>/dev/null; then
      local hubble_ui_status=$(kubectl get pods -n kube-system -l k8s-app=hubble-ui -o jsonpath='{.items[*].status.phase}')
      if [[ -z "$hubble_ui_status" || "$hubble_ui_status" != *"Running"* ]]; then
        ui_log_error "Hubble UI is not running"
      else
        ui_log_success "Hubble UI is running"
      fi
    fi
  fi
  
  # Check if NetworkPolicy explorer is installed
  if kubectl get deployment -n kube-system npex &>/dev/null; then
    local npex_status=$(kubectl get pods -n kube-system -l app=npex -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$npex_status" || "$npex_status" != *"Running"* ]]; then
      ui_log_error "NetworkPolicy Explorer is not running"
    else
      ui_log_success "NetworkPolicy Explorer is running"
    fi
  fi
  
  # Check if ServiceMonitors are configured
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor; then
    if kubectl get servicemonitor -n "$NAMESPACE" node-exporter &>/dev/null; then
      ui_log_success "ServiceMonitor for Node Exporter exists"
    fi
    
    if kubectl get servicemonitor -n "$NAMESPACE" blackbox &>/dev/null || kubectl get servicemonitor -n "$NAMESPACE" prometheus-blackbox-exporter &>/dev/null; then
      ui_log_success "ServiceMonitor for Blackbox Exporter exists"
    fi
    
    if kubectl get servicemonitor -n "$NAMESPACE" calico-monitoring &>/dev/null; then
      ui_log_success "ServiceMonitor for Calico monitoring exists"
    fi
    
    if kubectl get servicemonitor -n "$NAMESPACE" kube-proxy &>/dev/null; then
      ui_log_success "ServiceMonitor for kube-proxy exists"
    fi
  fi
  
  # Check if alert rules are configured
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q prometheusrule; then
    if kubectl get prometheusrule -n "$NAMESPACE" network-monitoring-alerts &>/dev/null; then
      ui_log_success "PrometheusRule for network monitoring alerts exists"
    else
      ui_log_warning "PrometheusRule for network monitoring alerts does not exist"
    fi
  fi
  
  # Check if Grafana dashboards are configured
  if kubectl get configmap -n "$NAMESPACE" network-dashboards &>/dev/null; then
    ui_log_success "Network monitoring Grafana dashboards exist"
  else
    ui_log_warning "Network monitoring Grafana dashboards do not exist"
  fi
  
  # Provide useful information for accessing network monitoring tools
  ui_log_info "Network monitoring components are available via the following endpoints:"
  
  if kubectl get service -n "$NAMESPACE" prometheus-node-exporter &>/dev/null; then
    ui_log_info "- Node Exporter: prometheus-node-exporter.$NAMESPACE.svc:9100/metrics"
  fi
  
  if kubectl get service -n "$NAMESPACE" prometheus-blackbox-exporter &>/dev/null; then
    ui_log_info "- Blackbox Exporter: prometheus-blackbox-exporter.$NAMESPACE.svc:9115/metrics"
  fi
  
  if kubectl get service -n kube-system hubble-relay &>/dev/null; then
    ui_log_info "- Hubble Relay: hubble-relay.kube-system.svc:80"
    ui_log_info "  To use Hubble CLI: kubectl port-forward -n kube-system svc/hubble-relay 4245:80"
    ui_log_info "  Then: hubble observe --server localhost:4245"
  fi
  
  if kubectl get service -n kube-system hubble-ui &>/dev/null; then
    ui_log_info "- Hubble UI: kubectl port-forward -n kube-system svc/hubble-ui 12000:80"
    ui_log_info "  Then access http://localhost:12000"
  fi
  
  if kubectl get service -n kube-system npex-app &>/dev/null; then
    ui_log_info "- NetworkPolicy Explorer: kubectl port-forward -n kube-system svc/npex-app 3000:3000"
    ui_log_info "  Then access http://localhost:3000"
  fi
  
  ui_log_success "Network Monitoring verification completed"
  return 0
}

# Cleanup function - removes the component
network_monitoring_cleanup() {
  ui_log_info "Cleaning up Network Monitoring"
  
  # Remove Grafana dashboards
  kubectl delete configmap network-dashboards -n "$NAMESPACE" --ignore-not-found
  
  # Remove alert rules
  kubectl delete prometheusrule network-monitoring-alerts -n "$NAMESPACE" --ignore-not-found
  
  # Remove ServiceMonitors
  kubectl delete servicemonitor node-exporter -n "$NAMESPACE" --ignore-not-found
  kubectl delete servicemonitor blackbox -n "$NAMESPACE" --ignore-not-found
  kubectl delete servicemonitor prometheus-blackbox-exporter -n "$NAMESPACE" --ignore-not-found
  kubectl delete servicemonitor calico-monitoring -n "$NAMESPACE" --ignore-not-found
  kubectl delete servicemonitor kube-proxy -n "$NAMESPACE" --ignore-not-found
  
  # Remove NetworkPolicy explorer if installed
  kubectl delete -f https://raw.githubusercontent.com/busquets/kubectl-npex/main/deploy/npex.yaml --ignore-not-found
  
  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "node-exporter"; then
    ui_log_info "Uninstalling Node Exporter Helm release"
    helm uninstall node-exporter -n "$NAMESPACE"
  else
    kubectl delete daemonset node-exporter -n "$NAMESPACE" --ignore-not-found
    kubectl delete service node-exporter -n "$NAMESPACE" --ignore-not-found
  fi
  
  if helm list -n "$NAMESPACE" | grep -q "blackbox-exporter"; then
    ui_log_info "Uninstalling Blackbox Exporter Helm release"
    helm uninstall blackbox-exporter -n "$NAMESPACE"
  else
    kubectl delete deployment blackbox-exporter -n "$NAMESPACE" --ignore-not-found
    kubectl delete service blackbox-exporter -n "$NAMESPACE" --ignore-not-found
  fi
  
  # Check if Hubble was deployed and clean it up if needed
  if helm list -n kube-system | grep -q "hubble-ui"; then
    ui_log_info "Uninstalling Hubble UI Helm release"
    helm uninstall hubble-ui -n kube-system
  fi
  
  # If Cilium was managed via Helm and Hubble was enabled, update to disable it
  if helm list -n kube-system | grep -q "cilium"; then
    ui_log_info "Updating Cilium Helm release to disable Hubble"
    helm upgrade cilium cilium/cilium --namespace kube-system \
      --reuse-values \
      --set hubble.enabled=false \
      --set hubble.relay.enabled=false \
      --set hubble.ui.enabled=false
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/observability/network/kustomization.yaml" --ignore-not-found
  
  # We don't delete the namespace since other monitoring components likely share it
  ui_log_info "Keeping namespace $NAMESPACE as it likely contains other monitoring components"
  
  return 0
}

# Diagnose function - provides detailed diagnostics
network_monitoring_diagnose() {
  ui_log_info "Running Network Monitoring diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check Node Exporter
  if kubectl get daemonset -n "$NAMESPACE" node-exporter &>/dev/null || kubectl get daemonset -n "$NAMESPACE" prometheus-node-exporter &>/dev/null; then
    ui_subheader "Node Exporter Status"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus-node-exporter -o wide
    
    # Sample Node Exporter metrics
    local node_exporter_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus-node-exporter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$node_exporter_pod" ]; then
      ui_subheader "Node Exporter Network Metrics (sample)"
      kubectl exec -n "$NAMESPACE" "$node_exporter_pod" -- wget -q -O- http://localhost:9100/metrics 2>/dev/null | grep -E "node_network_(receive|transmit)_(bytes|errs|drop)" | head -15
    fi
  fi
  
  # Check Blackbox Exporter
  if kubectl get deployment -n "$NAMESPACE" blackbox-exporter &>/dev/null || kubectl get deployment -n "$NAMESPACE" prometheus-blackbox-exporter &>/dev/null; then
    ui_subheader "Blackbox Exporter Status"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus-blackbox-exporter -o wide
    
    # Display Blackbox Exporter configuration
    ui_subheader "Blackbox Exporter Configuration"
    kubectl get configmap -n "$NAMESPACE" prometheus-blackbox-exporter -o yaml
    
    # Sample Blackbox Exporter metrics
    local blackbox_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus-blackbox-exporter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$blackbox_pod" ]; then
      ui_subheader "Blackbox Exporter Metrics (sample)"
      kubectl exec -n "$NAMESPACE" "$blackbox_pod" -- wget -q -O- http://localhost:9115/metrics 2>/dev/null | grep -E "probe_|(http|icmp|dns)_" | head -15
    fi
  fi
  
  # Check Hubble if installed
  if kubectl get deployment -n kube-system hubble-relay &>/dev/null; then
    ui_subheader "Hubble Status"
    kubectl get pods -n kube-system -l k8s-app=hubble-relay -o wide
    kubectl get pods -n kube-system -l k8s-app=hubble-ui -o wide 2>/dev/null
    
    # Display Hubble configuration
    ui_subheader "Hubble Configuration"
    kubectl get configmap -n kube-system hubble-relay-config -o yaml 2>/dev/null
    
    # Check Hubble connectivity
    ui_subheader "Hubble Connectivity"
    local hubble_pod=$(kubectl get pods -n kube-system -l k8s-app=hubble-relay -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$hubble_pod" ]; then
      kubectl exec -n kube-system "$hubble_pod" -- hubble status 2>/dev/null || ui_log_warning "Hubble CLI not available in the pod"
    fi
    
    # Get Hubble service status
    ui_subheader "Hubble Services"
    kubectl get service -n kube-system hubble-relay -o yaml
    kubectl get service -n kube-system hubble-ui -o yaml 2>/dev/null
  fi
  
  # Check NetworkPolicy explorer if installed
  if kubectl get deployment -n kube-system npex &>/dev/null; then
    ui_subheader "NetworkPolicy Explorer Status"
    kubectl get pods -n kube-system -l app=npex -o wide
    
    ui_subheader "NetworkPolicy Explorer Service"
    kubectl get service -n kube-system npex-app -o yaml
  fi
  
  # Check ServiceMonitors
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor; then
    ui_subheader "Network Monitoring ServiceMonitors"
    kubectl get servicemonitor -n "$NAMESPACE" -l app=network-monitoring -o yaml 2>/dev/null
    kubectl get servicemonitor -n "$NAMESPACE" node-exporter -o yaml 2>/dev/null
    kubectl get servicemonitor -n "$NAMESPACE" blackbox -o yaml 2>/dev/null || kubectl get servicemonitor -n "$NAMESPACE" prometheus-blackbox-exporter -o yaml 2>/dev/null
    kubectl get servicemonitor -n "$NAMESPACE" calico-monitoring -o yaml 2>/dev/null
    kubectl get servicemonitor -n "$NAMESPACE" kube-proxy -o yaml 2>/dev/null
  fi
  
  # Check PrometheusRules
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q prometheusrule; then
    ui_subheader "Network Monitoring Alert Rules"
    kubectl get prometheusrule -n "$NAMESPACE" network-monitoring-alerts -o yaml 2>/dev/null
  fi
  
  # Check Grafana dashboards
  ui_subheader "Network Monitoring Grafana Dashboards"
  kubectl get configmap -n "$NAMESPACE" network-dashboards -o yaml 2>/dev/null
  
  # Check network interfaces on a sample node
  ui_subheader "Node Network Interfaces (sample)"
  local sample_node=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
  if [ -n "$sample_node" ]; then
    local node_exporter_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus-node-exporter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$node_exporter_pod" ] && kubectl get pods -n "$NAMESPACE" "$node_exporter_pod" -o jsonpath='{.spec.nodeName}' | grep -q "$sample_node"; then
      kubectl exec -n "$NAMESPACE" "$node_exporter_pod" -- ip -o addr | grep -v "scope host" | grep -v "lo" || ui_log_warning "Could not retrieve network interfaces"
    else
      ui_log_warning "Could not find a Node Exporter pod on the sample node"
    fi
  fi
  
  # Check kube-proxy metrics if available
  ui_subheader "Kube-Proxy Metrics"
  local kube_proxy_pod=$(kubectl get pods -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$kube_proxy_pod" ]; then
    kubectl exec -n kube-system "$kube_proxy_pod" -- wget -q -O- http://localhost:10249/metrics 2>/dev/null | grep -E "kubeproxy_(network|sync)" | head -15 || ui_log_warning "Could not retrieve kube-proxy metrics"
  fi
  
  # Check network policies
  ui_subheader "Network Policies"
  kubectl get networkpolicies --all-namespaces
  
  return 0
}

# Export functions
export -f network_monitoring_pre_deploy
export -f network_monitoring_deploy
export -f network_monitoring_post_deploy
export -f network_monitoring_verify
export -f network_monitoring_cleanup
export -f network_monitoring_diagnose 