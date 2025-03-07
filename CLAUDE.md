# Claude Repository Guide

This file contains key information about this repository for Claude to use when assisting with code and operations.

## Repository Purpose

This repository implements a GitOps-based Kubernetes cluster configuration using Flux. It provides:

1. Infrastructure configuration for Kubernetes clusters
2. Observability stack configuration
3. Application deployment configuration
4. Environment-specific customizations
5. Scripts for local development and cluster setup

## Common Commands

### Cluster Setup

```bash
# Set up a local Kubernetes cluster with Minikube
./scripts/cluster/setup-minikube.sh

# Set up Flux GitOps controller
./scripts/cluster/setup-flux.sh

# Set up all components
./scripts/cluster/setup-all.sh

# Verify environment setup
./scripts/cluster/verify-environment.sh
```

### Flux Commands

```bash
# Get all Flux resources
flux get all

# Get Flux kustomizations
flux get kustomizations

# Get Flux HelmReleases
flux get helmreleases -A

# Reconcile a resource
flux reconcile kustomization <name>
flux reconcile helmrelease <name> -n <namespace>
```

### Kubernetes Commands

```bash
# Get cluster status
kubectl get nodes
kubectl get pods -A

# Debug resources
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

## Code Style Preferences

1. Use kebab-case for resource names and file names
2. Follow the GitOps pattern:
   - Base configurations in clusters/base/
   - Environment overlays in clusters/[env]/
3. Use Kustomize for resource composition
4. Use Helm for application deployments
5. Use sealed-secrets for sensitive information

## Repository Structure

```
/
├── charts/                  # Helm charts
├── clusters/                # Kubernetes cluster configurations
│   ├── base/                # Base configurations (environment-agnostic)
│   └── local/               # Local environment configurations
├── conext/                  # Project context and documentation
├── docs/                    # User documentation
└── scripts/                 # Automation scripts
```

## Common Patterns

### Component Structure

```
component/
├── README.md              # Documentation
├── examples/              # Environment examples
├── helm/                  # Helm configuration
├── kustomization.yaml     # Kustomization configuration
├── namespace.yaml         # Namespace definition
└── [component].yaml       # Component-specific resources
```

### Environment Overlay Structure

```
environment/component/
├── helm/                  # Environment-specific Helm values
├── kustomization.yaml     # Kustomization configuration
├── patches/               # Patches for base resources
└── sealed-secrets/        # Environment-specific sealed secrets
```

## Special Knowledge

1. The cluster setup scripts should be run in the correct order
2. Sealed secrets are environment-specific and need to be encrypted with the correct key
3. The local environment uses Minikube for local Kubernetes development
4. Flux is used as the GitOps controller for continuous deployment
5. Components have dependencies that affect the deployment order

## Troubleshooting Tips

1. For Flux issues, check the Flux logs:
   ```bash
   kubectl logs -n flux-system deployment/source-controller
   kubectl logs -n flux-system deployment/kustomize-controller
   kubectl logs -n flux-system deployment/helm-controller
   ```

2. For application issues, check the application logs:
   ```bash
   kubectl logs -n <namespace> <pod-name>
   ```

3. For resource issues, check the resource status:
   ```bash
   kubectl describe <resource-type> <resource-name> -n <namespace>
   ```

4. For sealed secrets issues, check the sealed-secrets controller logs:
   ```bash
   kubectl logs -n sealed-secrets deployment/sealed-secrets
   ```

## Metadata Directory

For more detailed information about the repository, see the `.claude/` directory, which contains:

- Metadata about the codebase
- Code indexes and component relationships
- Debug history and common error patterns
- Workflow patterns and cheatsheets
- Q&A database for common questions