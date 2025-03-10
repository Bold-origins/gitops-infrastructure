#!/bin/bash
# opentelemetry.sh: OpenTelemetry Component Functions
# Handles all operations for the OpenTelemetry collector component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="opentelemetry"
NAMESPACE="monitoring"  # Using the same namespace as other monitoring components
COMPONENT_DEPENDENCIES=("prometheus" "tempo" "loki")  # Dependencies for full integration
RESOURCE_TYPES=("deployment" "service" "configmap" "secret" "daemonset" "serviceaccount" "clusterrole" "clusterrolebinding")

# Pre-deployment function - runs before deployment
opentelemetry_pre_deploy() {
  ui_log_info "Running OpenTelemetry pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for OpenTelemetry"
    return 1
  fi
  
  # Add Helm repo if needed
  if ! helm repo list | grep -q "open-telemetry"; then
    ui_log_info "Adding OpenTelemetry Helm repository"
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update
  fi
  
  return 0
}

# Deploy function - deploys the component
opentelemetry_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying OpenTelemetry using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      kubectl apply -f "${BASE_DIR}/clusters/local/observability/opentelemetry/kustomization.yaml"
      ;;
    
    kubectl)
      # Direct kubectl apply
      ui_log_info "Applying OpenTelemetry manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/observability/opentelemetry"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying OpenTelemetry with Helm"
      
      # Check if already installed
      if helm list -n "$NAMESPACE" | grep -q "opentelemetry-collector"; then
        ui_log_info "OpenTelemetry is already installed via Helm"
        return 0
      fi
      
      # Create a values file to customize the deployment
      cat > /tmp/otel-values.yaml <<EOF
mode: "daemonset"  # Deploy as a DaemonSet to collect on all nodes

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    jaeger:
      protocols:
        thrift_http:
          endpoint: 0.0.0.0:14268
    prometheus:
      config:
        scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
          - role: pod
          relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: \$1:\$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
    zipkin:
      endpoint: 0.0.0.0:9411

  processors:
    batch:
      timeout: 10s
    memory_limiter:
      check_interval: 5s
      limit_percentage: 80
      spike_limit_percentage: 25
    k8sattributes:
      extract:
        metadata:
          - k8s.namespace.name
          - k8s.deployment.name
          - k8s.statefulset.name
          - k8s.daemonset.name
          - k8s.cronjob.name
          - k8s.job.name
          - k8s.pod.name
          - k8s.node.name
          - k8s.pod.uid
          - k8s.pod.start_time

  exporters:
    prometheus:
      endpoint: 0.0.0.0:8889
      namespace: otel
      resource_to_telemetry_conversion:
        enabled: true
    otlp:
      endpoint: tempo.${NAMESPACE}.svc.cluster.local:4317
      tls:
        insecure: true
    loki:
      endpoint: http://loki.${NAMESPACE}.svc.cluster.local:3100/loki/api/v1/push
      format: body
      labels:
        resource:
          service.name: "service_name"
          service.namespace: "service_namespace"
          k8s.pod.name: "pod"
          k8s.namespace.name: "namespace"

  service:
    pipelines:
      traces:
        receivers: [otlp, jaeger, zipkin]
        processors: [memory_limiter, k8sattributes, batch]
        exporters: [otlp]
      metrics:
        receivers: [otlp, prometheus]
        processors: [memory_limiter, k8sattributes, batch]
        exporters: [prometheus]
      logs:
        receivers: [otlp]
        processors: [memory_limiter, k8sattributes, batch]
        exporters: [loki]

serviceAccount:
  create: true

resources:
  limits:
    cpu: 200m
    memory: 384Mi
  requests:
    cpu: 100m
    memory: 128Mi

ports:
  otlp:
    enabled: true
    containerPort: 4317
    servicePort: 4317
    hostPort: 4317
    protocol: TCP
  otlp-http:
    enabled: true
    containerPort: 4318
    servicePort: 4318
    hostPort: 4318
    protocol: TCP
  jaeger-thrift:
    enabled: true
    containerPort: 14268
    servicePort: 14268
    hostPort: 14268
    protocol: TCP
  zipkin:
    enabled: true
    containerPort: 9411
    servicePort: 9411
    hostPort: 9411
    protocol: TCP
  prometheus:
    enabled: true
    containerPort: 8889
    servicePort: 8889
    protocol: TCP

EOF
      
      # Install with Helm
      helm install opentelemetry-collector open-telemetry/opentelemetry-collector -n "$NAMESPACE" \
        -f /tmp/otel-values.yaml
      
      # Clean up temp file
      rm -f /tmp/otel-values.yaml
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
opentelemetry_post_deploy() {
  ui_log_info "Running OpenTelemetry post-deployment tasks"
  
  # Wait for daemonset/deployment to be ready
  if kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for OpenTelemetry Collector daemonset to be ready"
    kubectl rollout status daemonset opentelemetry-collector -n "$NAMESPACE" --timeout=180s
  elif kubectl get deployment opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    ui_log_info "Waiting for OpenTelemetry Collector deployment to be ready"
    kubectl rollout status deployment opentelemetry-collector -n "$NAMESPACE" --timeout=180s
  else
    ui_log_warning "OpenTelemetry Collector deployment/daemonset not found in namespace $NAMESPACE"
    return 1
  fi
  
  # Create ServiceMonitor for Prometheus if it doesn't exist and Prometheus-operator is installed
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor && \
     ! kubectl get servicemonitor -n "$NAMESPACE" | grep -q "opentelemetry-collector"; then
    ui_log_info "Creating ServiceMonitor for OpenTelemetry Collector"
    
    cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: opentelemetry-collector
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: opentelemetry-collector
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: opentelemetry-collector
  namespaceSelector:
    matchNames:
      - $NAMESPACE
  endpoints:
  - port: prometheus
    interval: 30s
    path: /metrics
EOF
    
    ui_log_success "ServiceMonitor created for OpenTelemetry Collector"
  fi
  
  # Create a ConfigMap with sample instrumentation examples
  ui_log_info "Creating ConfigMap with instrumentation examples"
  
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-examples
  namespace: $NAMESPACE
data:
  python-example.yaml: |
    # Add this to your Python application
    # pip install opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp
    
    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.resources import SERVICE_NAME, Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor
    
    # Configure the tracer
    resource = Resource(attributes={
        SERVICE_NAME: "your-service-name"
    })
    
    tracer_provider = TracerProvider(resource=resource)
    processor = BatchSpanProcessor(OTLPSpanExporter(endpoint="opentelemetry-collector:4317"))
    tracer_provider.add_span_processor(processor)
    trace.set_tracer_provider(tracer_provider)
    
    # Get a tracer
    tracer = trace.get_tracer(__name__)
    
    # Use the tracer
    with tracer.start_as_current_span("my-operation"):
        # Your code here
        pass
  
  java-example.yaml: |
    # Add this to your Java application
    # dependencies:
    # - io.opentelemetry:opentelemetry-api:1.14.0
    # - io.opentelemetry:opentelemetry-sdk:1.14.0
    # - io.opentelemetry:opentelemetry-exporter-otlp:1.14.0
    
    // Configure the OpenTelemetry SDK
    Resource resource = Resource.getDefault()
        .toBuilder()
        .put(ResourceAttributes.SERVICE_NAME, "your-service-name")
        .build();
    
    SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
        .setResource(resource)
        .addSpanProcessor(BatchSpanProcessor.builder(
            OtlpGrpcSpanExporter.builder()
                .setEndpoint("http://opentelemetry-collector:4317")
                .build())
            .build())
        .build();
    
    OpenTelemetry openTelemetry = OpenTelemetrySdk.builder()
        .setTracerProvider(tracerProvider)
        .build();
    
    // Get a tracer
    Tracer tracer = openTelemetry.getTracer("com.example.app");
    
    // Use the tracer
    Span span = tracer.spanBuilder("my-operation").startSpan();
    try (Scope scope = span.makeCurrent()) {
        // Your code here
    } finally {
        span.end();
    }
  
  nodejs-example.yaml: |
    # Add this to your Node.js application
    # npm install @opentelemetry/api @opentelemetry/sdk-node @opentelemetry/exporter-trace-otlp-proto
    
    const { NodeSDK } = require('@opentelemetry/sdk-node');
    const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-proto');
    const { Resource } = require('@opentelemetry/resources');
    const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
    
    const sdk = new NodeSDK({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: 'your-service-name',
      }),
      traceExporter: new OTLPTraceExporter({
        url: 'http://opentelemetry-collector:4317/v1/traces',
      }),
    });
    
    sdk.start();
    
    // Gracefully shut down the SDK on process exit
    process.on('SIGTERM', () => {
      sdk.shutdown()
        .then(() => console.log('Tracing terminated'))
        .catch((error) => console.log('Error terminating tracing', error))
        .finally(() => process.exit(0));
    });
    
    // Use the tracer
    const { trace } = require('@opentelemetry/api');
    const tracer = trace.getTracer('my-app');
    
    const span = tracer.startSpan('my-operation');
    // Your code here
    span.end();
EOF
  
  ui_log_success "Created OpenTelemetry examples ConfigMap"
  
  return 0
}

# Verification function - verifies the component is working
opentelemetry_verify() {
  ui_log_info "Verifying OpenTelemetry installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Check deployment or daemonset
  local deployment_exists=false
  if kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    deployment_exists=true
    ui_log_info "Found OpenTelemetry Collector as DaemonSet"
  elif kubectl get deployment opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    deployment_exists=true
    ui_log_info "Found OpenTelemetry Collector as Deployment"
  fi
  
  if [ "$deployment_exists" = false ]; then
    ui_log_error "OpenTelemetry Collector deployment or daemonset not found"
    return 1
  fi
  
  # Check if pods are running
  local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opentelemetry-collector -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$pods" || "$pods" != *"Running"* ]]; then
    ui_log_error "OpenTelemetry Collector pods are not running"
    return 1
  else
    ui_log_success "OpenTelemetry Collector pods are running"
  fi
  
  # Check if service exists
  if ! kubectl get service opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    ui_log_error "OpenTelemetry Collector service not found"
    return 1
  else
    ui_log_success "OpenTelemetry Collector service exists"
  fi
  
  # Check RBAC resources if needed
  if kubectl get clusterrole | grep -q opentelemetry-collector; then
    ui_log_success "OpenTelemetry Collector ClusterRole exists"
  else
    ui_log_warning "OpenTelemetry Collector ClusterRole not found - it might not have sufficient permissions"
  fi
  
  # Test API access
  ui_log_info "Testing OpenTelemetry Collector health"
  local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}')
  if [ -n "$pod_name" ]; then
    # Check metrics endpoint
    local metrics_available=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q -O- http://localhost:8888/metrics 2>/dev/null | wc -l)
    if [ "$metrics_available" -gt 0 ]; then
      ui_log_success "OpenTelemetry Collector metrics endpoint is accessible"
      
      # Sample some metrics
      ui_log_info "Sample metrics from OpenTelemetry Collector:"
      kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q -O- http://localhost:8888/metrics 2>/dev/null | grep -E "otelcol_process|otelcol_receiver|otelcol_exporter" | head -5
    else
      ui_log_warning "Could not access OpenTelemetry Collector metrics endpoint"
    fi
    
    # Check health endpoint
    kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q -O- http://localhost:13133 2>/dev/null | grep -q "Server available" && \
      ui_log_success "OpenTelemetry Collector health endpoint is accessible and reports server available" || \
      ui_log_warning "OpenTelemetry Collector health check failed"
  else
    ui_log_error "No OpenTelemetry Collector pod found"
    return 1
  fi
  
  # Check if ServiceMonitor exists if Prometheus-operator is installed
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor; then
    if ! kubectl get servicemonitor -n "$NAMESPACE" | grep -q "opentelemetry-collector"; then
      ui_log_warning "ServiceMonitor for OpenTelemetry Collector not found - Prometheus may not auto-discover it"
    else
      ui_log_success "ServiceMonitor for OpenTelemetry Collector exists"
    fi
  fi
  
  # Provide information about instrumentation
  ui_log_info "OpenTelemetry Collector is running and ready to receive telemetry data."
  ui_log_info "Instrumentation examples can be found in the 'opentelemetry-examples' ConfigMap."
  ui_log_info "To view example instrumentation: kubectl get configmap opentelemetry-examples -n $NAMESPACE -o yaml"
  ui_log_info ""
  ui_log_info "OpenTelemetry Collector endpoints:"
  ui_log_info "- OTLP gRPC: opentelemetry-collector.$NAMESPACE:4317"
  ui_log_info "- OTLP HTTP: opentelemetry-collector.$NAMESPACE:4318"
  ui_log_info "- Jaeger: opentelemetry-collector.$NAMESPACE:14268 (HTTP)"
  ui_log_info "- Zipkin: opentelemetry-collector.$NAMESPACE:9411"
  
  ui_log_success "OpenTelemetry verification completed"
  return 0
}

# Cleanup function - removes the component
opentelemetry_cleanup() {
  ui_log_info "Cleaning up OpenTelemetry"
  
  # Remove example ConfigMap
  kubectl delete configmap opentelemetry-examples -n "$NAMESPACE" --ignore-not-found
  
  # Remove ServiceMonitor if it exists
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor; then
    if kubectl get servicemonitor -n "$NAMESPACE" opentelemetry-collector &>/dev/null; then
      ui_log_info "Removing ServiceMonitor for OpenTelemetry Collector"
      kubectl delete servicemonitor opentelemetry-collector -n "$NAMESPACE"
    fi
  fi
  
  # Check deployment method and clean up accordingly
  if helm list -n "$NAMESPACE" | grep -q "opentelemetry-collector"; then
    ui_log_info "Uninstalling OpenTelemetry Collector Helm release"
    helm uninstall opentelemetry-collector -n "$NAMESPACE"
  else
    # For non-Helm deployments
    ui_log_info "Removing OpenTelemetry Collector resources"
    kubectl delete daemonset opentelemetry-collector -n "$NAMESPACE" --ignore-not-found
    kubectl delete deployment opentelemetry-collector -n "$NAMESPACE" --ignore-not-found
    kubectl delete service opentelemetry-collector -n "$NAMESPACE" --ignore-not-found
    kubectl delete configmap opentelemetry-collector -n "$NAMESPACE" --ignore-not-found
    kubectl delete serviceaccount opentelemetry-collector -n "$NAMESPACE" --ignore-not-found
    
    # Delete RBAC resources
    kubectl delete clusterrole opentelemetry-collector --ignore-not-found
    kubectl delete clusterrolebinding opentelemetry-collector --ignore-not-found
  fi
  
  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/observability/opentelemetry/kustomization.yaml" --ignore-not-found
  
  # We don't delete the namespace since other monitoring components likely share it
  ui_log_info "Keeping namespace $NAMESPACE as it likely contains other monitoring components"
  
  return 0
}

# Diagnose function - provides detailed diagnostics
opentelemetry_diagnose() {
  ui_log_info "Running OpenTelemetry diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Display pod status
  ui_subheader "OpenTelemetry Collector Pod Status"
  kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opentelemetry-collector -o wide
  
  # Display deployment or daemonset
  if kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "OpenTelemetry Collector DaemonSet"
    kubectl get daemonset opentelemetry-collector -n "$NAMESPACE" -o yaml
  elif kubectl get deployment opentelemetry-collector -n "$NAMESPACE" &>/dev/null; then
    ui_subheader "OpenTelemetry Collector Deployment"
    kubectl get deployment opentelemetry-collector -n "$NAMESPACE" -o yaml
  fi
  
  # Display service
  ui_subheader "OpenTelemetry Collector Service"
  kubectl get service opentelemetry-collector -n "$NAMESPACE" -o yaml
  
  # Display ConfigMap
  ui_subheader "OpenTelemetry Collector ConfigMap"
  kubectl get configmap opentelemetry-collector -n "$NAMESPACE" -o yaml
  
  # Display RBAC resources
  ui_subheader "OpenTelemetry Collector RBAC Resources"
  kubectl get clusterrole | grep opentelemetry-collector
  kubectl get clusterrolebinding | grep opentelemetry-collector
  kubectl get serviceaccount opentelemetry-collector -n "$NAMESPACE" -o yaml 2>/dev/null
  
  # Display ServiceMonitor if it exists
  if kubectl api-resources --api-group=monitoring.coreos.com | grep -q servicemonitor; then
    ui_subheader "OpenTelemetry Collector ServiceMonitor"
    kubectl get servicemonitor opentelemetry-collector -n "$NAMESPACE" -o yaml 2>/dev/null || \
      ui_log_warning "No ServiceMonitor found for OpenTelemetry Collector"
  fi
  
  # Check pod logs
  ui_subheader "OpenTelemetry Collector Logs"
  local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$pod_name" ]; then
    kubectl logs -n "$NAMESPACE" "$pod_name" --tail=50
  else
    ui_log_error "No OpenTelemetry Collector pod found"
  fi
  
  # Check metrics
  ui_subheader "OpenTelemetry Collector Metrics"
  if [ -n "$pod_name" ]; then
    ui_log_info "Metrics from OpenTelemetry Collector:"
    kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q -O- http://localhost:8888/metrics 2>/dev/null | grep -E "otelcol_processor|otelcol_receiver|otelcol_exporter" | head -20 || \
      ui_log_warning "Could not retrieve metrics from OpenTelemetry Collector"
  fi
  
  # Check health
  ui_subheader "OpenTelemetry Collector Health"
  if [ -n "$pod_name" ]; then
    ui_log_info "Health status:"
    kubectl exec -n "$NAMESPACE" "$pod_name" -- wget -q -O- http://localhost:13133 2>/dev/null || echo "Health check failed"
  fi
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp' | tail -10
  
  return 0
}

# Export functions
export -f opentelemetry_pre_deploy
export -f opentelemetry_deploy
export -f opentelemetry_post_deploy
export -f opentelemetry_verify
export -f opentelemetry_cleanup
export -f opentelemetry_diagnose 