# Supabase VPS Deployment

This directory contains Kubernetes manifests for deploying Supabase to a VPS using Flux CD and GitOps principles.

## VPS Specifications

- **CPU**: 8 cores
- **Memory**: 32GB RAM
- **Disk**: 400GB storage

## Environment Structure

The deployment is structured into two environments:

1. **Production** (`clusters/vps/production/`)
   - Highest priority workloads
   - Allocated up to 5 CPU cores and 16GB memory
   - Domain: `supabase.boldorigin.io`

2. **Staging** (`clusters/vps/staging/`)
   - Lightweight deployment with reduced resources
   - Allocated up to 3 CPU cores and 8GB memory
   - Domain: `supabase.staging.boldorigin.io`

## Platform Configuration

Common platform configurations are stored in `clusters/vps/platform-config/`, including:

- Priority classes for workload prioritization
- Resource quotas for each namespace
- Namespace definitions

## Deployment Instructions

### 1. Set up Kubernetes on your VPS

```bash
# Install k3s on your VPS
curl -sfL https://get.k3s.io | sh -

# Get the kubeconfig file for remote access
sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config-vps
# Replace localhost with your VPS IP
sed -i '' "s/127.0.0.1/YOUR_VPS_IP/g" ~/.kube/config-vps
# Set the kubeconfig for use
export KUBECONFIG=~/.kube/config-vps
```

### 2. Install Flux on your VPS

```bash
# Install Flux CLI locally
brew install fluxcd/tap/flux

# Bootstrap Flux with your GitHub repository
flux bootstrap github \
  --owner=Bold-origins \
  --repository=gitops-infrastructure \
  --branch=main \
  --path=clusters/vps \
  --personal
```

### 3. Verify installation

```bash
# Check that Flux components are running
kubectl -n flux-system get pods

# Check that your infrastructure is being reconciled
flux get kustomizations
```

### 4. Set up DNS

Make sure to set up these DNS records:

- `supabase.boldorigin.io` → Points to your VPS IP address
- `supabase.staging.boldorigin.io` → Points to your VPS IP address

## Resource Allocation

| Component | Environment | CPU Request | Memory Request | Storage |
|-----------|------------|-------------|---------------|---------|
| Database  | Production | 500m        | 2Gi           | 100Gi   |
| Database  | Staging    | 100m        | 512Mi         | 10Gi    |
| Auth      | Production | 200m        | 750Mi         | -       |
| Auth      | Staging    | 50m         | 256Mi         | -       |
| Storage   | Production | 200m        | 750Mi         | 50Gi    |
| Storage   | Staging    | 50m         | 256Mi         | 5Gi     |

## Priority Classes

Workloads are assigned priorities to ensure critical services get resources:

- `production-critical`: Critical production services (DB, Auth, Kong)
- `production-high`: Important production services
- `production-medium`: Standard production services
- `staging-high`: Critical staging services
- `staging-low`: Non-critical staging services 