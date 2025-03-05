#!/bin/bash
# diagnostics/check_flux_health.sh

set -e

# Determine the environment (default to local if not specified)
ENVIRONMENT=${2:-local}
REPORTS_DIR="diagnostics/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p $REPORTS_DIR

REPORT_FILE="$REPORTS_DIR/diagnostics_report_flux_$(date +%Y%m%d_%H%M%S).md"

# Check for lightweight mode
LIGHTWEIGHT_MODE=false
if [[ "$1" == "light" ]]; then
  LIGHTWEIGHT_MODE=true
fi

echo "# Flux System Diagnostic Report - $(date)" > $REPORT_FILE
if [[ "$LIGHTWEIGHT_MODE" == "true" ]]; then
  echo "**LIGHTWEIGHT MODE** - Some resource-intensive checks skipped" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

echo "## Flux System Pods" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get pods -n flux-system >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Flux Kustomizations" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
flux get kustomizations --all-namespaces 2>/dev/null || echo "Failed to get Kustomizations" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Flux Helm Releases" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
if [[ "$LIGHTWEIGHT_MODE" == "true" ]]; then
  flux get helmreleases --all-namespaces 2>/dev/null | head -10 || echo "Failed to get HelmReleases" >> $REPORT_FILE
  HR_COUNT=$(flux get helmreleases --all-namespaces 2>/dev/null | wc -l)
  if [ $HR_COUNT -gt 10 ]; then
    echo "... (truncated, showing 10 of $HR_COUNT total HelmReleases)" >> $REPORT_FILE
  fi
else
  flux get helmreleases --all-namespaces 2>/dev/null || echo "Failed to get HelmReleases" >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Flux Sources" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
flux get sources all --all-namespaces 2>/dev/null || echo "Failed to get Sources" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Skip controller logs in lightweight mode
if [[ "$LIGHTWEIGHT_MODE" == "false" ]]; then
  echo "## Flux Controller Logs (last 20 lines)" >> $REPORT_FILE
  for controller in source-controller kustomize-controller helm-controller notification-controller; do
    echo "### $controller logs" >> $REPORT_FILE
    echo '```' >> $REPORT_FILE
    kubectl logs -n flux-system deployment/$controller --tail=20 2>/dev/null || echo "Failed to get logs for $controller" >> $REPORT_FILE
    echo '```' >> $REPORT_FILE
    echo "" >> $REPORT_FILE
  done
else
  echo "## Flux Controller Logs" >> $REPORT_FILE
  echo "Controller logs skipped in lightweight mode" >> $REPORT_FILE
  echo "" >> $REPORT_FILE
fi

echo "## Reconciliation Issues" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
flux get all --all-namespaces 2>/dev/null | grep -v "True        Ready" || echo "No reconciliation issues found" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "Diagnostic report created: $REPORT_FILE" 