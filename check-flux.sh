#!/bin/bash
# Simple script to check Flux status

echo "Checking flux-system namespace..."
kubectl get namespace flux-system

echo -e "\nChecking Flux deployments..."
kubectl get deployment -n flux-system

echo -e "\nChecking Flux pods..."
kubectl get pods -n flux-system

echo -e "\nChecking Flux sources..."
kubectl get gitrepositories -n flux-system

echo -e "\nChecking Flux kustomizations..."
kubectl get kustomizations -n flux-system

echo -e "\nChecking Flux helmreleases..."
kubectl get helmreleases --all-namespaces 2>/dev/null || echo "No HelmReleases found"

echo -e "\nChecking Flux helmrepositories..."
kubectl get helmrepositories --all-namespaces 2>/dev/null || echo "No HelmRepositories found" 