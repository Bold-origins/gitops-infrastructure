# Codebase Model

This document provides a model-friendly documentation of the codebase.

## Purpose

This repository implements a GitOps-based Kubernetes cluster configuration. It provides:

1. Infrastructure configuration for Kubernetes clusters
2. Observability stack configuration
3. Application deployment configuration
4. Environment-specific customizations
5. Scripts for local development and cluster setup

## Schema

### Cluster Configuration

```yaml
Cluster
├── Base
│   ├── Infrastructure
│   │   ├── Component A
│   │   ├── Component B
│   │   └── ...
│   ├── Observability
│   │   ├── Component X
│   │   ├── Component Y
│   │   └── ...
│   └── Applications
│       ├── App 1
│       ├── App 2
│       └── ...
└── Environments
    ├── Local
    │   ├── Infrastructure
    │   ├── Observability
    │   └── Applications
    ├── Staging
    │   └── ...
    └── Production
        └── ...
```

### Kustomize Pattern

```yaml
Base Component
├── namespace.yaml
├── kustomization.yaml
├── helmrelease.yaml
├── helm/
│   └── values.yaml
└── sealed-secrets/
    └── template-*.yaml

Environment Overlay
├── kustomization.yaml
├── patches/
│   └── *-patch.yaml
├── helm/
│   └── values.yaml
└── sealed-secrets/
    └── actual-*.yaml
```

## Patterns

### GitOps Workflow

1. Define base configuration (clusters/base/)
2. Create environment-specific overlays (clusters/[env]/)
3. Use Kustomize to combine base and overlay
4. Flux applies the combined configuration to the cluster

### Component Structure

```
component/
├── README.md             # Documentation
├── examples/             # Environment examples
│   ├── local/
│   ├── staging/
│   └── production/
├── helm/                 # Helm chart values
│   ├── release.yaml      # Helm chart reference
│   └── values.yaml       # Default values
├── kustomization.yaml    # Kustomize configuration
├── namespace.yaml        # Namespace definition
└── [component].yaml      # Component-specific resources
```

## Interfaces

### Script Interfaces

- `./scripts/cluster/*.sh`: Setup scripts for local development
- `./scripts/gitops/*.sh`: Scripts for GitOps workflows

### Configuration Interfaces

- Kustomization files define how resources are combined
- HelmRelease files define how Helm charts are deployed
- Values files define how components are configured

## Invariants

1. Base configurations should be environment-agnostic
2. Environment overlays should only contain environment-specific customizations
3. Sealed secrets should never contain actual secrets in the base configuration
4. All components should have proper documentation

## Error States

1. **HelmRelease Reconciliation Failure**: Occurs when Helm chart values are invalid
2. **Kustomize Build Failure**: Occurs when Kustomize cannot build the configuration
3. **Secret Decryption Failure**: Occurs when sealed secrets cannot be decrypted
4. **Policy Violation**: Occurs when resources violate policy constraints