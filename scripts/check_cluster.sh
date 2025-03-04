#!/bin/bash
# Script to check the status of all components in the cluster

set -e

echo "========================================"
echo "Checking Cluster Component Status"
echo "========================================"

echo -e "\n1. Checking Minikube Status:"
minikube status

echo -e "\n2. Checking namespaces:"
kubectl get namespaces

echo -e "\n3. Checking Flux System:"
kubectl get pods -n flux-system

echo -e "\n4. Checking Infrastructure Components:"

echo -e "\n   a. cert-manager:"
kubectl get pods -n cert-manager

echo -e "\n   b. sealed-secrets:"
kubectl get pods -n sealed-secrets

echo -e "\n   c. vault:"
kubectl get pods -n vault
echo "Vault status:"
# Improved Vault status check that doesn't fail if no pods are found
VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$VAULT_POD" ]; then
  kubectl exec -it -n vault $VAULT_POD -- \
    /bin/sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault status" || echo "Failed to get Vault status"
else
  echo "No Vault pod found"
fi

echo -e "\n   d. gatekeeper:"
kubectl get pods -n gatekeeper-system

echo -e "\n   e. minio:"
kubectl get pods -n minio
echo "MinIO buckets cannot be directly listed via kubectl, use the MinIO console or API"

echo -e "\n5. Checking Application Components:"
kubectl get pods -n example
# Check for the example app's configuration error
if kubectl get pods -n example | grep -q "CreateContainerConfigError"; then
  echo "Example app has configuration errors. Checking events:"
  kubectl get events -n example --field-selector involvedObject.name=$(kubectl get pods -n example -o jsonpath='{.items[0].metadata.name}') --sort-by='.lastTimestamp'
fi

echo -e "\n6. Checking Storage:"
kubectl get pv
kubectl get pvc --all-namespaces

echo -e "\n7. Checking ingress-nginx:"
kubectl get pods -n ingress-nginx
kubectl get ingress --all-namespaces

echo -e "\n8. Checking for any pods in error state:"
kubectl get pods --all-namespaces | grep -v "Running\|Completed" || echo "All pods are running or completed"

echo -e "\n9. Checking node resources:"
kubectl top nodes || echo "Metrics server not available"

echo -e "\n10. Checking pod resources:"
kubectl top pods --all-namespaces || echo "Metrics server not available"

echo -e "\n========================================"
echo "Cluster Component Check Complete"
echo "========================================" 