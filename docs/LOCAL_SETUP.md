# Local Minikube Environment Setup Guide

This document provides detailed instructions for setting up and testing the local Kubernetes environment using Minikube.

## Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/docs/start/) (v1.30.0+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (v1.27.0+)
- [Flux CLI](https://fluxcd.io/docs/installation/) (v2.0.0+)
- [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) (v5.0.0+)
- [Helm](https://helm.sh/docs/intro/install/) (v3.11.0+)
- At least 8GB RAM available for Minikube
- At least 4 CPU cores available for Minikube
- At least 20GB disk space available

## Environment Setup Process

The setup is organized in logical phases to ensure dependencies are properly satisfied.

### Phase 1: Minikube Initialization

```bash
# Start a fresh Minikube cluster with appropriate resources
./scripts/cluster/setup-minikube.sh
```

This script will:
1. Start Minikube with appropriate resource allocation
2. Enable required addons (ingress, metrics-server)
3. Set up necessary storage classes
4. Configure local Docker registry access
5. Verify cluster health

### Phase 2: Core Infrastructure Setup

```bash
# Install core infrastructure components
./scripts/cluster/setup-core-infrastructure.sh
```

This installs the essential infrastructure in the correct order:
1. cert-manager (for certificate management)
2. sealed-secrets (for encrypted secrets)
3. vault (for secrets management)
4. gatekeeper (for policy enforcement)
5. minio (for object storage)

### Phase 3: Networking Setup

```bash
# Set up networking components
./scripts/cluster/setup-networking.sh
```

This installs networking components:
1. metallb (for load balancing)
2. ingress (for external access)

### Phase 4: Observability Setup

```bash
# Install monitoring and observability stack
./scripts/cluster/setup-observability.sh
```

This installs the observability components:
1. prometheus (for metrics)
2. grafana (for dashboards)
3. loki (for logs)
4. opentelemetry (for tracing)

### Phase 5: Application Layer

```bash
# Install application components
./scripts/cluster/setup-applications.sh
```

This installs application components like Supabase.

## GitOps Workflow

For a GitOps-based workflow using Flux:

```bash
# Set up Flux for GitOps management
./scripts/cluster/setup-flux.sh
```

This script will:
1. Install Flux components
2. Configure Git repository synchronization
3. Set up initial kustomizations

## Verification and Testing

After setup, verify the environment is working correctly:

```bash
# Run comprehensive verification tests
./scripts/cluster/verify-environment.sh
```

This runs tests for:
- Core component health
- Networking functionality
- Observability stack
- Policy enforcement
- Application accessibility

## Common Operations

### Accessing the Environment

Access various services:
- Kubernetes Dashboard: `minikube dashboard`
- Grafana: https://grafana.local (credentials in sealed secret)
- Prometheus: https://prometheus.local
- Vault: https://vault.local (initialized during setup)

### Stopping/Starting the Environment

```bash
# Stop Minikube (preserving state)
minikube stop

# Start existing Minikube instance
minikube start
```

### Complete Reset

```bash
# Reset everything to a clean state
./scripts/cluster/reset-environment.sh
```

## Troubleshooting Guide

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## Environment Variables

The scripts use these environment variables (can be set in .env file):
- `MINIKUBE_MEMORY`: Memory allocation (default: 8192MB)
- `MINIKUBE_CPUS`: CPU allocation (default: 4)
- `MINIKUBE_DISK_SIZE`: Disk allocation (default: 20GB)
- `LOCAL_DOMAIN_SUFFIX`: Suffix for local domains (default: .local)

## Component Documentation

For detailed documentation on individual components:
- [Infrastructure Components](../clusters/base/infrastructure/README.md)
- [Observability Components](../clusters/base/observability/README.md)
- [Policy Components](../clusters/base/policies/README.md)
- [Application Components](../clusters/base/applications/README.md) 