# Memory Anchors

This file contains explicit memory anchors for key parts of the codebase.

## Cluster Structure

<!-- CLAUDE-ANCHOR:cluster-structure:a1b2c3d4 -->
- **Base configurations** in `clusters/base/`
- **Environment-specific configurations** in `clusters/[env]/`
- **Common patterns:**
  - Base defines the core resource
  - Environment overlays apply patches
  - Kustomization brings everything together
<!-- END-CLAUDE-ANCHOR:cluster-structure -->

## Infrastructure Components

<!-- CLAUDE-ANCHOR:infrastructure-components:e5f6g7h8 -->
- **cert-manager**: TLS certificate management
- **gatekeeper**: Policy enforcement
- **ingress**: External access to services
- **metallb**: Load balancing
- **minio**: S3-compatible object storage
- **sealed-secrets**: Encrypted Kubernetes secrets
- **security**: Security policies and configurations
- **vault**: Secret management
<!-- END-CLAUDE-ANCHOR:infrastructure-components -->

## Observability Stack

<!-- CLAUDE-ANCHOR:observability-stack:i9j0k1l2 -->
- **grafana**: Visualization and dashboards
- **loki**: Log aggregation
- **prometheus**: Metrics and monitoring
- **opentelemetry**: Distributed tracing
<!-- END-CLAUDE-ANCHOR:observability-stack -->

## Setup Scripts

<!-- CLAUDE-ANCHOR:setup-scripts:m3n4o5p6 -->
- `setup-minikube.sh`: Sets up local Kubernetes cluster
- `setup-flux.sh`: Sets up Flux GitOps
- `setup-core-infrastructure.sh`: Sets up core infrastructure
- `setup-networking.sh`: Sets up networking components
- `setup-observability.sh`: Sets up observability stack
- `setup-applications.sh`: Sets up applications
- `setup-all.sh`: Runs all setup scripts in sequence
<!-- END-CLAUDE-ANCHOR:setup-scripts -->

## GitOps Workflow

<!-- CLAUDE-ANCHOR:gitops-workflow:q7r8s9t0 -->
1. Create base configuration in `clusters/base/`
2. Create environment overlay in `clusters/[env]/`
3. Update kustomization.yaml files
4. Apply changes with Flux
<!-- END-CLAUDE-ANCHOR:gitops-workflow -->

## Common File Patterns

<!-- CLAUDE-ANCHOR:file-patterns:u1v2w3x4 -->
- **namespace.yaml**: Defines Kubernetes namespace
- **kustomization.yaml**: Configures Kustomize
- **helmrelease.yaml**: Defines Flux HelmRelease
- **values.yaml**: Helm chart values
- **patches/*.yaml**: Environment-specific patches
<!-- END-CLAUDE-ANCHOR:file-patterns -->

## Error Patterns

<!-- CLAUDE-ANCHOR:error-patterns:y5z6a7b8 -->
- **HelmRelease reconciliation failures**: Usually due to invalid values or missing dependencies
- **Sealed Secret failures**: Usually due to incorrect encryption or missing keys
- **Policy violations**: Usually due to missing required labels or probes
<!-- END-CLAUDE-ANCHOR:error-patterns -->