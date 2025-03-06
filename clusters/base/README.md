# Kubernetes Cluster Base Configuration

This directory contains the foundational Kubernetes resources and configurations that form the base of our cluster architecture. These components are designed to be extended or customized through Kustomize overlays for specific environments (development, staging, production).

## Directory Structure

The `base` directory is organized into the following key areas:

### 📂 Infrastructure

Core infrastructure components necessary for cluster operations:

- **cert-manager**: Certificate management for TLS
- **sealed-secrets**: Secure management of Kubernetes secrets
- **vault**: Secrets management and encryption
- **ingress**: Ingress controllers and related configurations
- **gatekeeper**: Policy enforcement and governance
- **minio**: S3-compatible object storage
- **metallb**: Load balancer implementation for bare metal Kubernetes

### 📂 Observability

Monitoring, logging, and observability stack:

- **prometheus**: Metrics collection and alerting
- **grafana**: Visualization and dashboards
- **loki**: Log aggregation system
- **opentelemetry**: Distributed tracing
- **network**: Network monitoring tools
- **common**: Shared resources for observability components

### 📂 Policies

Policy definitions and constraints:

- **templates**: Policy templates for Gatekeeper
- **constraints**: Specific policy constraints
- **examples**: Example policy implementations

### 📂 Applications

Application workloads and services:

- **supabase**: Open-source Firebase alternative with various environment configurations

## GitOps Implementation Note

This base directory intentionally does not contain a `flux-system` directory. Flux is implemented at the environment level (local, staging, production) rather than in the base configuration. Each environment has its own Flux instance that pulls from the Git repository and applies the base configurations with environment-specific overlays. This follows GitOps best practices by separating the core configurations from the mechanism that applies them.

## Usage

This base configuration is designed to be used with Kustomize. Environment-specific overlays should reference these base components and apply patches as needed.

### Example Usage

```bash
# Apply the entire base configuration
kubectl apply -k clusters/base

# Apply specific component
kubectl apply -k clusters/base/infrastructure/cert-manager
```

## Environment-Specific Configurations

For environment-specific configurations (development, staging, production), create overlay directories that reference these base components and apply appropriate patches. See the Supabase examples in `applications/supabase/examples` for reference implementations.

## Key Features

- **Modular Design**: Each component is isolated in its own directory
- **Kustomize Integration**: All resources are organized to work with Kustomize
- **Progressive Enhancement**: Start with minimal base configurations that can be enhanced in overlays
- **Separation of Concerns**: Clear separation between infrastructure, observability, policies, and applications

## Best Practices

When extending or modifying these base configurations:

1. Keep base configurations minimal and universally applicable
2. Implement environment-specific configurations in overlays
3. Use patches rather than duplicating configuration
4. Document significant deviations from base configurations
