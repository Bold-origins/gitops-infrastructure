# Local Development Guide for GitOps Infrastructure

This guide provides comprehensive instructions for setting up, deploying, and managing your local GitOps infrastructure using the provided scripts and tools.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Deployment Options](#deployment-options)
  - [Complete Setup](#complete-setup)
  - [Component-by-Component Deployment](#component-by-component-deployment)
  - [Resume Failed Deployment](#resume-failed-deployment)
- [Monitoring Deployment Progress](#monitoring-deployment-progress)
- [Diagnostics and Troubleshooting](#diagnostics-and-troubleshooting)
  - [Diagnosing Specific Components](#diagnosing-specific-components)
  - [Common Issues](#common-issues)
- [Working with Flux GitOps](#working-with-flux-gitops)
- [Component-Specific Guides](#component-specific-guides)
- [Advanced Topics](#advanced-topics)

## Prerequisites

Before starting, ensure you have the following prerequisites installed:

- **Docker** - Container runtime for Minikube
- **Minikube v1.30+** - Local Kubernetes cluster
- **kubectl v1.28+** - Kubernetes command-line tool
- **Helm v3.12+** - Kubernetes package manager
- **Flux CLI** - GitOps toolkit
- **GitHub CLI** (optional) - For managing GitHub tokens and repositories
- **Git** - For repository management

Verify all prerequisites:

```bash
docker --version
minikube version
kubectl version --client
helm version
flux --version
gh --version # Optional
git --version
```

You'll also need a [GitHub Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) with `repo` scope for Flux to access your Git repository.

## Initial Setup

### Environment Configuration

1. Create or update your `.env` file with required credentials:

```bash
# GitHub credentials for Flux GitOps
GITHUB_USER=your-github-username
GITHUB_REPO=gitops-infrastructure
GITHUB_TOKEN=your-personal-access-token

# MinIO credentials
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# Vault credentials (will be updated after deployment)
VAULT_ADDR=http://localhost:8200
VAULT_UNSEAL_KEY="Replace with actual key"
VAULT_ROOT_TOKEN="Replace with actual token"
```

2. Initialize the local Minikube environment:

```bash
./scripts/setup/init-environment.sh
```

This script:
- Loads environment variables from `.env`
- Starts Minikube with appropriate resources
- Enables required addons (ingress, metrics-server)
- Verifies kubectl context

## Deployment Options

You have several options for deploying your infrastructure, depending on your needs:

### Complete Setup

For a full end-to-end setup with default options:

```bash
./scripts/setup/setup-full-environment.sh
```

This runs the entire setup process:
1. Initializes Minikube
2. Sets up Flux GitOps controllers
3. Deploys all components in stages

> **Note:** This approach may encounter timeout issues with Flux reconciliation, particularly with complex components.

### Component-by-Component Deployment

For a more controlled, granular deployment:

```bash
./scripts/gitops/component-deploy.sh
```

This script:
- Deploys components one at a time
- Verifies each component before proceeding to the next
- Provides detailed logs and status information
- Tracks progress to allow resuming

This is the **recommended approach** for most users as it provides better visibility and control.

### Resume Failed Deployment

If a deployment fails or times out, you can resume from where you left off:

```bash
./scripts/gitops/resume-setup.sh
```

This script:
- Checks what was already deployed
- Continues from the point of failure
- Fixes common issues with Git repositories or kustomizations

## Monitoring Deployment Progress

### Deployment Logs

All deployment logs are stored in the `logs/deployment/` directory:
- `deployment-TIMESTAMP.log` - Main deployment log
- `deployment-progress.txt` - Tracks successful components

### Checking Status

Check overall GitOps status:

```bash
flux get all
```

Check component status:

```bash
kubectl get pods -A
```

### Real-time Monitoring

Monitor Flux controllers during deployment:

```bash
kubectl -n flux-system logs -f deployment/kustomize-controller
```

View real-time events:

```bash
kubectl get events --sort-by='.lastTimestamp' --watch
```

## Diagnostics and Troubleshooting

### Diagnosing Specific Components

If a specific component fails or misbehaves, use the diagnostic tool:

```bash
./scripts/gitops/diagnose-component.sh <component-name>
```

For example:

```bash
./scripts/gitops/diagnose-component.sh vault
```

This provides comprehensive diagnostics for the specified component:
- Verifies the component's namespace and resources
- Checks Flux reconciliation status
- Inspects pods, deployments, and events
- Validates component-specific resources
- Provides actionable recommendations

### Common Issues

#### Flux Reconciliation Timeout

**Symptoms:**
- "context deadline exceeded" errors
- Kustomization shows "Progressing" status indefinitely

**Solutions:**
1. Use component-by-component deployment instead of full setup
2. Increase timeout values in kustomization resources
3. Check for dependency issues between components

#### Git Repository Issues

**Symptoms:**
- "failed to clone" errors
- Authentication failures with GitHub

**Solutions:**
1. Verify GitHub token has correct permissions
2. Check that the repository exists and has the expected directory structure
3. Update GitHub credentials in your `.env` file
4. Run `./scripts/gitops/resume-setup.sh` to recreate Git resources

#### Component Deployment Failures

**Symptoms:**
- Namespace exists but no pods are running
- Pods stuck in "ContainerCreating" or "Pending" state

**Solutions:**
1. Run diagnostics: `./scripts/gitops/diagnose-component.sh <component-name>`
2. Check for resource constraints: `kubectl describe pod <pod-name> -n <namespace>`
3. Verify prerequisites are deployed: `kubectl get crds`
4. Inspect specific component logs

## Working with Flux GitOps

### Manual Reconciliation

Force reconciliation of a specific component:

```bash
flux reconcile kustomization single-<component-name> --with-source
```

### Viewing Logs

```bash
flux logs
```

### Testing Resources

Validate kustomization before applying:

```bash
kustomize build clusters/local/infrastructure/<component>
```

## Component-Specific Guides

### Vault

After deploying Vault, initialize and unseal it:

```bash
kubectl -n vault port-forward svc/vault 8200:8200
# In another terminal
export VAULT_ADDR=http://localhost:8200
vault operator init -key-shares=1 -key-threshold=1
```

Update your `.env` file with the unseal key and root token.

### Cert-Manager

Verify issuers after deployment:

```bash
kubectl get clusterissuers
kubectl get issuers --all-namespaces
```

### Ingress-NGINX

Test the ingress controller:

```bash
kubectl -n ingress-nginx get pods
curl -k https://localhost/healthz
```

## Advanced Topics

### Custom Component Order

You can customize the order of component deployment by editing the `COMPONENTS` array in `scripts/gitops/component-deploy.sh`.

### Adding New Components

To add a new component:

1. Create its directory structure in `clusters/local/infrastructure/`
2. Add it to the `COMPONENTS` array in `scripts/gitops/component-deploy.sh`
3. Update the component mapping in `scripts/gitops/diagnose-component.sh`

### Debugging Kustomize Issues

For debugging complex kustomize issues:

```bash
kustomize build --enable-alpha-plugins --load-restrictor=LoadRestrictionsNone clusters/local/infrastructure/<component>
```

### Manual Deployment Fallback

If GitOps automation is consistently problematic, you can fall back to manual deployment:

```bash
kubectl apply -k clusters/local/infrastructure/<component>
```

However, this should be a last resort as it defeats the purpose of GitOps. 