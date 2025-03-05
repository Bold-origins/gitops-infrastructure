#!/bin/bash
# diagnostics/check_security.sh

set -e

# Determine the environment (default to local if not specified)
ENVIRONMENT=${1:-local}
REPORTS_DIR="diagnostics/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p $REPORTS_DIR

REPORT_FILE="$REPORTS_DIR/diagnostics_report_security_$(date +%Y%m%d_%H%M%S).md"

echo "# Security & Policy Diagnostic Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

# Check OPA Gatekeeper
echo "## OPA Gatekeeper Status" >> $REPORT_FILE
if kubectl get namespace gatekeeper-system &>/dev/null; then
  echo '```' >> $REPORT_FILE
  kubectl get pods -n gatekeeper-system >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  echo "### Constraint Templates" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  kubectl get constrainttemplates 2>/dev/null || echo "No ConstraintTemplates found" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  echo "### Constraints" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  kubectl get constraints --all-namespaces 2>/dev/null || echo "No Constraints found" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
else
  echo "OPA Gatekeeper not found in the cluster." >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check Network Policies
echo "## Network Policies" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get networkpolicies --all-namespaces >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check RBAC Configuration
echo "## RBAC Configuration Summary" >> $REPORT_FILE
echo "### Roles" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get roles --all-namespaces | head -20 >> $REPORT_FILE
if [ $(kubectl get roles --all-namespaces | wc -l) -gt 21 ]; then
  echo "... (truncated, $(kubectl get roles --all-namespaces | wc -l) total roles)" >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE

echo "### ClusterRoles" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get clusterroles | grep -v "system:" | head -20 >> $REPORT_FILE
if [ $(kubectl get clusterroles | grep -v "system:" | wc -l) -gt 21 ]; then
  echo "... (truncated, $(kubectl get clusterroles | grep -v "system:" | wc -l) total non-system clusterroles)" >> $REPORT_FILE
fi
echo '```' >> $REPORT_FILE

echo "Diagnostic report created: $REPORT_FILE" 