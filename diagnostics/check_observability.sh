#!/bin/bash
# diagnostics/check_observability.sh

set -e

# Determine the environment (default to local if not specified)
ENVIRONMENT=${1:-local}
REPORTS_DIR="diagnostics/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p $REPORTS_DIR

REPORT_FILE="$REPORTS_DIR/diagnostics_report_observability_$(date +%Y%m%d_%H%M%S).md"

echo "# Observability Stack Diagnostic Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

# Determine monitoring namespace - could be monitoring, observability, etc.
MONITORING_NS=""
for ns in monitoring observability prometheus grafana; do
  if kubectl get namespace $ns &>/dev/null; then
    MONITORING_NS="$ns"
    break
  fi
done

if [ -z "$MONITORING_NS" ]; then
  echo "No monitoring namespace found (checked: monitoring, observability, prometheus, grafana)." >> $REPORT_FILE
  echo "Checking for monitoring components across all namespaces..." >> $REPORT_FILE
else
  echo "Found monitoring namespace: $MONITORING_NS" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check Prometheus
echo "## Prometheus Status" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
if [ -n "$MONITORING_NS" ]; then
  kubectl get pods -n $MONITORING_NS -l app=prometheus >> $REPORT_FILE 2>/dev/null || echo "No Prometheus pods found in $MONITORING_NS namespace" >> $REPORT_FILE
else
  kubectl get pods --all-namespaces -l app=prometheus >> $REPORT_FILE 2>/dev/null || echo "No Prometheus pods found in any namespace" >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check Grafana
echo "## Grafana Status" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
if [ -n "$MONITORING_NS" ]; then
  kubectl get pods -n $MONITORING_NS -l app=grafana >> $REPORT_FILE 2>/dev/null || echo "No Grafana pods found in $MONITORING_NS namespace" >> $REPORT_FILE
else
  kubectl get pods --all-namespaces -l app=grafana >> $REPORT_FILE 2>/dev/null || echo "No Grafana pods found in any namespace" >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check Loki
echo "## Loki Status" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
if [ -n "$MONITORING_NS" ]; then
  kubectl get pods -n $MONITORING_NS -l app=loki >> $REPORT_FILE 2>/dev/null || echo "No Loki pods found in $MONITORING_NS namespace" >> $REPORT_FILE
else
  kubectl get pods --all-namespaces -l app=loki >> $REPORT_FILE 2>/dev/null || echo "No Loki pods found in any namespace" >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check OpenTelemetry
echo "## OpenTelemetry Status" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
if [ -n "$MONITORING_NS" ]; then
  kubectl get pods -n $MONITORING_NS -l app=opentelemetry >> $REPORT_FILE 2>/dev/null || echo "No OpenTelemetry pods found in $MONITORING_NS namespace" >> $REPORT_FILE
else
  kubectl get pods --all-namespaces -l app=opentelemetry >> $REPORT_FILE 2>/dev/null || echo "No OpenTelemetry pods found in any namespace" >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check ServiceMonitors (for Prometheus Operator)
echo "## ServiceMonitors" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get servicemonitors --all-namespaces 2>/dev/null || echo "No ServiceMonitors found (Prometheus Operator CRDs may not be installed)" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check for Prometheus Operator's PrometheusRules
echo "## Prometheus Rules" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get prometheusrules --all-namespaces 2>/dev/null || echo "No PrometheusRules found (Prometheus Operator CRDs may not be installed)" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "Diagnostic report created: $REPORT_FILE" 