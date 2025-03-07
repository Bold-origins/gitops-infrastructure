# Local Environment Cheatsheet

This document provides quick-reference for setting up and working with the local development environment.

## Environment Setup

```bash
# Verify system prerequisites
./scripts/cluster/verify-environment.sh

# Set up Minikube (local Kubernetes)
./scripts/cluster/setup-minikube.sh

# Set up Flux GitOps
./scripts/cluster/setup-flux.sh

# Set up core infrastructure
./scripts/cluster/setup-core-infrastructure.sh

# Set up networking
./scripts/cluster/setup-networking.sh

# Set up observability
./scripts/cluster/setup-observability.sh

# Set up applications
./scripts/cluster/setup-applications.sh

# Set up all components in one go
./scripts/cluster/setup-all.sh
```

## Environment Verification

```bash
# Check Minikube status
minikube status

# Check Flux status
flux get all

# Check infrastructure components
kubectl get pods -n cert-manager
kubectl get pods -n ingress-nginx
kubectl get pods -n metallb-system
kubectl get pods -n sealed-secrets
kubectl get pods -n vault

# Check observability components
kubectl get pods -n observability

# Check applications
kubectl get pods -n supabase
```

## Accessing Services

```bash
# Get ingress endpoints
kubectl get ingress -A

# Port forward to a service
kubectl port-forward -n <namespace> svc/<service-name> <local-port>:<service-port>

# Access Grafana dashboard
kubectl port-forward -n observability svc/grafana 3000:80

# Access Prometheus dashboard
kubectl port-forward -n observability svc/prometheus-server 9090:80

# Access Supabase dashboard
kubectl port-forward -n supabase svc/supabase-dashboard 3001:3000
```

## Working with Secrets

```bash
# Encrypt a secret for local environment
kubectl create secret generic my-secret \
  --namespace=my-namespace \
  --from-literal=key1=value1 \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  --format yaml > sealed-secret.yaml

# Apply a sealed secret
kubectl apply -f sealed-secret.yaml

# Verify secret was created
kubectl get secret my-secret -n my-namespace
```

## Troubleshooting Local Environment

```bash
# Check Flux logs
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
kubectl logs -n flux-system deployment/helm-controller

# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Check Flux events
kubectl get events -n flux-system

# Check resource events
kubectl describe <resource-type> <resource-name> -n <namespace>

# Restart Flux pods
kubectl rollout restart deployment -n flux-system

# Reset local environment
./scripts/cluster/setup-all.sh --reset
```

## Working with Kustomize Locally

```bash
# Build Kustomization locally
kubectl kustomize clusters/local/applications/my-app

# Apply Kustomization locally
kubectl kustomize clusters/local/applications/my-app | kubectl apply -f -

# Validate Kustomization
kubectl kustomize clusters/local/applications/my-app | kubectl apply --dry-run=client -f -
```

## Testing Changes

```bash
# Test changes in local environment
kubectl kustomize clusters/local/applications/my-app | kubectl apply -f -

# Verify changes
kubectl get pods -n my-app
kubectl describe deployment my-app -n my-app
kubectl logs -n my-app deployment/my-app

# Clean up changes
kubectl delete -f my-resource.yaml
```