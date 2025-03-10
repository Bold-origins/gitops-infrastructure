#!/bin/bash
# Simple script to check cert-manager status

echo "Checking cert-manager namespace..."
kubectl get namespace cert-manager

echo -e "\nChecking cert-manager deployments..."
kubectl get deployment -n cert-manager

echo -e "\nChecking cert-manager pods..."
kubectl get pods -n cert-manager

echo -e "\nChecking cert-manager CRDs..."
kubectl get crd | grep cert-manager.io

echo -e "\nChecking cert-manager services..."
kubectl get services -n cert-manager

echo -e "\nChecking cert-manager issuers..."
kubectl get issuers --all-namespaces 2>/dev/null || echo "No Issuers found"

echo -e "\nChecking cert-manager cluster issuers..."
kubectl get clusterissuers 2>/dev/null || echo "No ClusterIssuers found"

echo -e "\nChecking cert-manager certificates..."
kubectl get certificates --all-namespaces 2>/dev/null || echo "No Certificates found" 