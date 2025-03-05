#!/bin/bash
# diagnostics/check_cluster_health.sh

set -e

# Determine the environment (default to local if not specified)
ENVIRONMENT=${2:-local}
REPORTS_DIR="diagnostics/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p $REPORTS_DIR

REPORT_FILE="$REPORTS_DIR/diagnostics_report_cluster_$(date +%Y%m%d_%H%M%S).md"

# Check for lightweight mode
LIGHTWEIGHT_MODE=false
if [[ "$1" == "light" ]]; then
  LIGHTWEIGHT_MODE=true
fi

echo "# Cluster Health Diagnostic Report - $(date)" > $REPORT_FILE
if [[ "$LIGHTWEIGHT_MODE" == "true" ]]; then
  echo "**LIGHTWEIGHT MODE** - Some resource-intensive checks skipped" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

echo "## Kubernetes Version" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl version 2>/dev/null || kubectl version --client
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Node Status" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get nodes -o wide >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Only get basic pod info in lightweight mode
echo "## Control Plane Components" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
if [[ "$LIGHTWEIGHT_MODE" == "true" ]]; then
  kubectl get pods -n kube-system --no-headers | head -5 >> $REPORT_FILE
  NUM_PODS=$(kubectl get pods -n kube-system --no-headers | wc -l)
  if [ $NUM_PODS -gt 5 ]; then
    echo "... (truncated, $NUM_PODS total pods in kube-system)" >> $REPORT_FILE
  fi
else
  kubectl get pods -n kube-system >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Skip resource usage metrics in lightweight mode
if [[ "$LIGHTWEIGHT_MODE" == "false" ]]; then
  echo "## Resource Usage" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  echo "NODE RESOURCE USAGE:" >> $REPORT_FILE
  kubectl top nodes 2>/dev/null || echo "Node metrics not available" >> $REPORT_FILE
  echo "" >> $REPORT_FILE
  echo "POD RESOURCE USAGE (TOP 10):" >> $REPORT_FILE
  kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -11 || echo "Pod metrics not available" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
else
  echo "## Resource Usage" >> $REPORT_FILE
  echo "Resource usage metrics skipped in lightweight mode" >> $REPORT_FILE
  echo "" >> $REPORT_FILE
fi

echo "## Storage Classes" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get storageclasses >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Get condensed PV/PVC info in lightweight mode
echo "## Persistent Volumes" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
if [[ "$LIGHTWEIGHT_MODE" == "true" ]]; then
  kubectl get pv --no-headers | wc -l | xargs echo "Total Persistent Volumes:" >> $REPORT_FILE
  kubectl get pvc --all-namespaces --no-headers | wc -l | xargs echo "Total Persistent Volume Claims:" >> $REPORT_FILE
else
  kubectl get pv,pvc --all-namespaces >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Namespaces" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get namespaces >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Diagnostic report created: $REPORT_FILE" 