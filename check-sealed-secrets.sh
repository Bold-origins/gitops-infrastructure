#!/bin/bash
# Simple script to check sealed-secrets status

echo "Checking sealed-secrets namespace..."
kubectl get namespace sealed-secrets

echo -e "\nChecking sealed-secrets deployments..."
kubectl get deployment -n sealed-secrets

echo -e "\nChecking sealed-secrets pods..."
kubectl get pods -n sealed-secrets

echo -e "\nChecking sealed-secrets services..."
kubectl get services -n sealed-secrets

echo -e "\nChecking sealed-secrets CRDs..."
kubectl get crd | grep sealed-secrets

echo -e "\nChecking sealed-secrets resources..."
kubectl get sealedsecrets --all-namespaces 2>/dev/null || echo "No SealedSecrets found" 