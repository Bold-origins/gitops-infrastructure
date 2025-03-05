#!/bin/bash
# diagnostics/create_phase1_report.sh

set -e

# Determine the environment (default to local if not specified)
ENVIRONMENT=${1:-local}
REPORTS_DIR="diagnostics/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p $REPORTS_DIR

# Find the most recent diagnostic reports
CLUSTER_REPORT=$(ls -t $REPORTS_DIR/diagnostics_report_cluster_* 2>/dev/null | head -1)
FLUX_REPORT=$(ls -t $REPORTS_DIR/diagnostics_report_flux_* 2>/dev/null | head -1)

# Check if reports exist in the root directory (for backward compatibility)
if [ -z "$CLUSTER_REPORT" ]; then
  ROOT_CLUSTER_REPORT=$(ls -t diagnostics_report_cluster_* 2>/dev/null | head -1)
  if [ -n "$ROOT_CLUSTER_REPORT" ]; then
    echo "Found cluster report in root directory, moving to $REPORTS_DIR..."
    mv $ROOT_CLUSTER_REPORT $REPORTS_DIR/
    CLUSTER_REPORT="$REPORTS_DIR/$(basename $ROOT_CLUSTER_REPORT)"
  fi
fi

if [ -z "$FLUX_REPORT" ]; then
  ROOT_FLUX_REPORT=$(ls -t diagnostics_report_flux_* 2>/dev/null | head -1)
  if [ -n "$ROOT_FLUX_REPORT" ]; then
    echo "Found flux report in root directory, moving to $REPORTS_DIR..."
    mv $ROOT_FLUX_REPORT $REPORTS_DIR/
    FLUX_REPORT="$REPORTS_DIR/$(basename $ROOT_FLUX_REPORT)"
  fi
fi

if [ -z "$CLUSTER_REPORT" ] || [ -z "$FLUX_REPORT" ]; then
  echo "Error: Required diagnostic reports not found. Please run diagnostic scripts first."
  echo "Run ./diagnostics/check_cluster_health.sh light $ENVIRONMENT"
  echo "Run ./diagnostics/check_flux_health.sh light $ENVIRONMENT"
  exit 1
fi

REPORT_FILE="$REPORTS_DIR/phase1_summary_report_$(date +%Y%m%d_%H%M%S).md"

echo "# Phase 1 Diagnostic Summary - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Environment Overview" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Extract Kubernetes version - updated to match the actual format in the report
KUBE_VERSION=$(grep -A 5 "Node Status" $CLUSTER_REPORT | grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
echo "- Kubernetes Version: $KUBE_VERSION" >> $REPORT_FILE

# Extract node info
NODE_COUNT=$(grep -A 5 "Node Status" $CLUSTER_REPORT | grep -c "minikube\|control-plane\|worker")
echo "- Node Count: $NODE_COUNT" >> $REPORT_FILE
echo "- Environment: $ENVIRONMENT" >> $REPORT_FILE

# Extract namespaces count
NAMESPACE_COUNT=$(grep -A 100 "Namespaces" $CLUSTER_REPORT | grep -c "Active")
echo "- Namespaces: $NAMESPACE_COUNT" >> $REPORT_FILE

echo "" >> $REPORT_FILE

# Check for issues in control plane
echo "## Control Plane Health" >> $REPORT_FILE
echo "" >> $REPORT_FILE
if grep -q "0/1" $CLUSTER_REPORT; then
  echo "⚠️ **ISSUE DETECTED**: Some control plane components are not ready." >> $REPORT_FILE
  grep -A 10 "Control Plane Components" $CLUSTER_REPORT | grep "0/1" >> $REPORT_FILE
else
  echo "✅ Control plane components appear to be running normally." >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check for issues in Flux - using case insensitive grep for more reliable pattern matching
echo "## GitOps (Flux) Status" >> $REPORT_FILE
echo "" >> $REPORT_FILE
# Use grep -i for case insensitive matching and handle the case where grep returns non-zero exit code
FLUX_ISSUES=$(grep -i "failed\|not ready\|false[[:space:]]\+false\|error" $FLUX_REPORT | wc -l | tr -d ' ')
if [ "$FLUX_ISSUES" -gt 0 ]; then
  echo "⚠️ **ISSUE DETECTED**: Flux has reconciliation issues." >> $REPORT_FILE
  echo "" >> $REPORT_FILE
  echo "Key issues:" >> $REPORT_FILE
  grep -i -B 1 -A 1 "failed\|not ready\|false[[:space:]]\+false\|error" $FLUX_REPORT | grep -v "^--$" | head -10 >> $REPORT_FILE
  echo "" >> $REPORT_FILE
else
  echo "✅ Flux system appears to be reconciling normally." >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check for issues with pods
echo "## Application Workloads" >> $REPORT_FILE
echo "" >> $REPORT_FILE
POD_ISSUES=$(kubectl get pods --all-namespaces | grep -c "Error\|CrashLoopBackOff\|ImagePullBackOff\|0/1" || echo 0)
if [ $POD_ISSUES -gt 0 ]; then
  echo "⚠️ **ISSUE DETECTED**: $POD_ISSUES pods are in an unhealthy state." >> $REPORT_FILE
  echo "" >> $REPORT_FILE
  echo "Problem pods:" >> $REPORT_FILE
  kubectl get pods --all-namespaces | grep "Error\|CrashLoopBackOff\|ImagePullBackOff\|0/1" | head -10 >> $REPORT_FILE
  if [ $POD_ISSUES -gt 10 ]; then
    echo "... (and $(($POD_ISSUES - 10)) more)" >> $REPORT_FILE
  fi
else
  echo "✅ All application pods appear to be running normally." >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Resource constraints section
echo "## Resource Constraints" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "This cluster is running on Minikube with limited resources. Some issues may be related to resource constraints:" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "- Check container resource limits if pods are being evicted or failing to start" >> $REPORT_FILE
echo "- Consider prioritizing necessary workloads by disabling non-critical applications" >> $REPORT_FILE
echo "- Monitor resource usage and adjust Minikube VM resources if needed" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Recommendations
echo "## Recommendations" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "Based on the diagnostic findings, here are the recommended next steps:" >> $REPORT_FILE
echo "" >> $REPORT_FILE

if [ $POD_ISSUES -gt 0 ]; then
  echo "1. **Troubleshoot failing pods** - Investigate the pods in error state" >> $REPORT_FILE
  echo "   \`\`\`" >> $REPORT_FILE
  echo "   kubectl describe pod POD_NAME -n NAMESPACE" >> $REPORT_FILE
  echo "   kubectl logs POD_NAME -n NAMESPACE" >> $REPORT_FILE
  echo "   \`\`\`" >> $REPORT_FILE
fi

if [ "$FLUX_ISSUES" -gt 0 ]; then
  echo "2. **Fix Flux reconciliation issues** - Several Helm repositories are not found" >> $REPORT_FILE
  echo "   \`\`\`" >> $REPORT_FILE
  echo "   # Check the Flux sources" >> $REPORT_FILE
  echo "   flux get sources all --all-namespaces" >> $REPORT_FILE
  echo "   \`\`\`" >> $REPORT_FILE
fi

echo "3. **Optimize for resource constraints** - This Minikube environment has limited resources" >> $REPORT_FILE
echo "   \`\`\`" >> $REPORT_FILE
echo "   # Consider disabling unneeded components" >> $REPORT_FILE
echo "   kubectl scale deployment DEPLOYMENT_NAME --replicas=0 -n NAMESPACE" >> $REPORT_FILE
echo "   \`\`\`" >> $REPORT_FILE

echo "" >> $REPORT_FILE
echo "For more detailed diagnostics, run the diagnostic scripts without the 'light' parameter." >> $REPORT_FILE

echo "Phase 1 summary report created: $REPORT_FILE"
chmod +x diagnostics/create_phase1_report.sh 