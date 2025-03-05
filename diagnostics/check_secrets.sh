#!/bin/bash
# diagnostics/check_secrets.sh

set -e

# Determine the environment (default to local if not specified)
ENVIRONMENT=${1:-local}
REPORTS_DIR="diagnostics/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p $REPORTS_DIR

REPORT_FILE="$REPORTS_DIR/diagnostics_report_secrets_$(date +%Y%m%d_%H%M%S).md"

echo "# Secrets Management Diagnostic Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

# Check if Vault is deployed
echo "## Vault Status" >> $REPORT_FILE
if kubectl get namespace vault &>/dev/null; then
  echo "Vault namespace found." >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  VAULT_POD=$(kubectl get pods -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$VAULT_POD" ]; then
    echo "Vault pod found: $VAULT_POD" >> $REPORT_FILE
    kubectl exec -n vault $VAULT_POD -- vault status 2>/dev/null || echo "Failed to get Vault status - may need initialization" >> $REPORT_FILE
  else
    echo "No Vault pods found in vault namespace" >> $REPORT_FILE
  fi
  echo '```' >> $REPORT_FILE
else
  echo "Vault namespace not found." >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check Sealed Secrets
echo "## Sealed Secrets Controller" >> $REPORT_FILE
if kubectl get namespace sealed-secrets &>/dev/null || kubectl get pods --all-namespaces -l name=sealed-secrets-controller &>/dev/null; then
  echo '```' >> $REPORT_FILE
  kubectl get pods --all-namespaces -l name=sealed-secrets-controller >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  echo "### Sealed Secrets Resources" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  kubectl get sealedsecrets --all-namespaces 2>/dev/null || echo "No SealedSecrets resources found" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
else
  echo "Sealed Secrets controller not found." >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check for plaintext secrets (excluding default tokens)
echo "## Secret Inventory" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get secrets --all-namespaces | grep -v "kubernetes.io/service-account-token" | grep -v "bootstrap-token" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "Diagnostic report created: $REPORT_FILE" 