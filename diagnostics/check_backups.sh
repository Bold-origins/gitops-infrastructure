#!/bin/bash
# diagnostics/check_backups.sh

set -e

# Determine the environment (default to local if not specified)
ENVIRONMENT=${1:-local}
REPORTS_DIR="diagnostics/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p $REPORTS_DIR

REPORT_FILE="$REPORTS_DIR/diagnostics_report_backups_$(date +%Y%m%d_%H%M%S).md"

echo "# Backup Systems Diagnostic Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

# Check for Velero
echo "## Velero Status" >> $REPORT_FILE
if kubectl get namespace velero &>/dev/null; then
  echo "Velero namespace found." >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  kubectl get pods -n velero >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  echo "### Backup Resources" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  kubectl get backups -n velero 2>/dev/null || echo "No backups found" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  echo "### Backup Schedules" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  kubectl get schedules -n velero 2>/dev/null || echo "No backup schedules found" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
else
  echo "Velero not found in the cluster." >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check for Stateful Applications
echo "## Stateful Applications" >> $REPORT_FILE

echo "### Databases" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get pods --all-namespaces -l app=postgres 2>/dev/null || echo "No Postgres pods found" >> $REPORT_FILE
kubectl get pods --all-namespaces -l app=mysql 2>/dev/null || echo "No MySQL pods found" >> $REPORT_FILE
kubectl get pods --all-namespaces -l app=mongodb 2>/dev/null || echo "No MongoDB pods found" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "### Storage Systems" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get pods --all-namespaces -l app=minio 2>/dev/null || echo "No MinIO pods found" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "Diagnostic report created: $REPORT_FILE" 