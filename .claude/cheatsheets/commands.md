# Command Cheatsheet

## Cluster Setup

```bash
# Set up a local Kubernetes cluster with Minikube
./scripts/cluster/setup-minikube.sh

# Set up Flux GitOps controller
./scripts/cluster/setup-flux.sh

# Set up core infrastructure components
./scripts/cluster/setup-core-infrastructure.sh

# Set up networking components
./scripts/cluster/setup-networking.sh

# Set up observability stack
./scripts/cluster/setup-observability.sh

# Set up applications
./scripts/cluster/setup-applications.sh

# Run all setup scripts in sequence
./scripts/cluster/setup-all.sh

# Verify environment setup
./scripts/cluster/verify-environment.sh
```

## GitOps Workflow

```bash
# Refactor a component for GitOps
./scripts/gitops/refactor-component.sh [component-name]

# Verify local refactoring
./scripts/gitops/verify-local-refactoring.sh

# Clean up local refactoring
./scripts/gitops/cleanup-local-refactoring.sh
```

## Kubernetes Commands

```bash
# Get cluster status
kubectl get nodes
kubectl get pods -A

# Check Flux GitOps status
flux get all
flux get kustomizations

# Check HelmReleases
flux get helmreleases -A

# Debug resources
kubectl describe pod [pod-name] -n [namespace]
kubectl logs [pod-name] -n [namespace]
```

## Common Patterns

```bash
# Create a new application in base
mkdir -p clusters/base/applications/[app-name]/{helm,sealed-secrets}
touch clusters/base/applications/[app-name]/kustomization.yaml
touch clusters/base/applications/[app-name]/namespace.yaml
touch clusters/base/applications/[app-name]/helmrelease.yaml

# Create environment-specific configurations
mkdir -p clusters/[env]/applications/[app-name]/{helm,patches,sealed-secrets}
```