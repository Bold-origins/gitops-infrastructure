# Staging Environment

This directory contains the Kubernetes configurations for the staging environment, running on a VPS with k3s.

## Environment Details

- **Server IP**: 91.108.112.146
- **IP Range**: 91.108.112.0/24
- **Domain**: boldorigins.io
- **Subdomain**: staging.boldorigins.io
- **Admin Email**: rodrigo.mourey@boldorigins.io
- **Kubernetes**: k3s v1.31.6+k3s1
- **Admin User**: boldman
- **Access Method**: SSH key authentication only

## Directory Structure

- **applications/** - Application deployments for the staging environment
- **infrastructure/** - Infrastructure components (ingress, cert-manager, etc.)
- **observability/** - Monitoring and logging stack
- **policies/** - Security policies and configurations
- **flux-system/** - Flux configuration for GitOps deployments

## Getting Started

### Prerequisites

- kubectl configured with the staging kubeconfig:
  ```bash
  export KUBECONFIG=~/.kube/config.staging
  ```

### Accessing the Staging Cluster

```bash
# SSH access to the server
ssh boldman@91.108.112.146

# Kubernetes CLI access
kubectl get nodes
```

## Deployment Process

The staging environment follows GitOps principles with Flux CD. Changes to this directory are automatically synchronized with the staging cluster.

### Application Deployment

To deploy a new application to the staging environment:

1. Add the application manifests to the `/applications` directory
2. Commit and push the changes
3. Flux will automatically apply the changes to the cluster

### Infrastructure Changes

Infrastructure components are managed through their respective directories under `/infrastructure`. Any changes pushed to these directories will be automatically applied by Flux.

## Security Measures

- Root SSH access is disabled
- SSH password authentication is disabled
- Only SSH key authentication is allowed
- Firewall is enabled with only necessary ports open (22, 80, 443, 6443)
- Kubernetes API server is secured

## Monitoring and Observability

Monitoring tools are configured in the `/observability` directory, including:
- Prometheus for metrics collection
- Grafana for visualization
- Loki for log aggregation

## DNS Configuration

The following DNS records should be configured for the domain:

- A record: `staging.boldorigins.io` → `91.108.112.146`
- A record: `*.staging.boldorigins.io` → `91.108.112.146`

This allows access to applications via URLs like `app-name.staging.boldorigins.io`.

## Maintenance

### Upgrading k3s

To upgrade the k3s installation:

```bash
ssh boldman@91.108.112.146
curl -sfL https://get.k3s.io | sudo sh -
```

### Backup and Restore

Backup procedures for the cluster are defined in the infrastructure documentation. 