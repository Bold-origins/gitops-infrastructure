#!/bin/bash
# run_diagnostics.sh
set -e

ENVIRONMENT=${1:-local}
LIGHTWEIGHT=${2:-normal}
START_TIME=$(date +%s)

echo "=== Running diagnostics for $ENVIRONMENT environment ==="
if [ "$LIGHTWEIGHT" == "light" ]; then
  echo "=== Using lightweight mode for resource-constrained environments ==="
fi

# Create diagnostics reports directory if it doesn't exist
mkdir -p diagnostics/reports/$ENVIRONMENT

# Display cluster info
echo "=== Cluster Information ==="
kubectl cluster-info

# Set light parameter if needed
LIGHT_PARAM=""
if [ "$LIGHTWEIGHT" == "light" ]; then
  LIGHT_PARAM="light"
fi

# Function to run a diagnostic check and continue even if it fails
run_check() {
  local script=$1
  local params=$2
  echo ""
  echo "=== Running $script Check ==="
  bash $script $params || {
    echo "Warning: $script check failed, but continuing with other checks"
    return 0
  }
}

run_check "diagnostics/check_cluster_health.sh" "$LIGHT_PARAM $ENVIRONMENT"
run_check "diagnostics/check_flux_health.sh" "$LIGHT_PARAM $ENVIRONMENT"
run_check "diagnostics/check_secrets.sh" "$ENVIRONMENT"
run_check "diagnostics/check_security.sh" "$ENVIRONMENT"
run_check "diagnostics/check_observability.sh" "$ENVIRONMENT"
run_check "diagnostics/check_backups.sh" "$ENVIRONMENT"
run_check "diagnostics/check_documentation.sh" "$ENVIRONMENT"

# Move any reports from root directory (for backward compatibility)
echo ""
echo "=== Cleaning up any reports in root directory ==="
for report in diagnostics_report_*.md phase1_summary_report_*.md; do
  if [ -f "$report" ]; then
    echo "Moving $report to diagnostics/reports/$ENVIRONMENT/"
    mv "$report" diagnostics/reports/$ENVIRONMENT/
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== Creating Phase 1 Summary Report ==="
bash diagnostics/create_phase1_report.sh $ENVIRONMENT || {
  echo "Warning: Failed to create Phase 1 Summary Report"
}

echo ""
echo "=== Diagnostics Complete ==="
echo "Duration: $DURATION seconds"
echo "All reports are in: diagnostics/reports/$ENVIRONMENT/"
ls -la diagnostics/reports/$ENVIRONMENT/

chmod +x run_diagnostics.sh 