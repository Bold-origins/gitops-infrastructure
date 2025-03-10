#!/bin/bash
# Simple script to check ingress-nginx status

echo "Checking ingress-nginx namespace..."
kubectl get namespace ingress-nginx

echo -e "\nChecking ingress-nginx deployments..."
kubectl get deployment -n ingress-nginx

echo -e "\nChecking ingress-nginx pods..."
kubectl get pods -n ingress-nginx

echo -e "\nChecking ingress-nginx services..."
kubectl get services -n ingress-nginx

echo -e "\nChecking ingress resources..."
kubectl get ingress --all-namespaces

echo -e "\nChecking ingress-nginx controller version..."
POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD" ]; then
  kubectl exec -n ingress-nginx $POD -- /nginx-ingress-controller --version
else
  echo "No ingress-nginx controller pod found"
fi 