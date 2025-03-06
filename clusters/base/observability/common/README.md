# Observability Common Base Configuration

This directory contains the common base configuration for the observability stack that can be used across multiple environments (local, staging, production). The configuration is designed to be used with Kustomize overlays.

## What is in the Common Observability Configuration?

The common observability configuration includes:

1. Helm repository definitions for observability components including:
   - Grafana charts repository
   - Prometheus Community charts repository

These repositories are central to installing the monitoring stack components:
- Prometheus (metrics collection and storage)
- Grafana (visualization and dashboards)
- Loki (logs aggregation)
- Tempo (distributed tracing)
- AlertManager (alerting)

## Environment-Specific Customizations

When creating environment overlays, consider customizing the following components:

### 1. Repository Sync Intervals

You might adjust sync intervals based on environment needs:

```yaml
# Development/local environment - faster updates for testing
spec:
  interval: 30m  # Shorter interval for development

# Production environment - reduced API load
spec:
  interval: 6h  # Longer interval for production
```

### 2. Repository Namespace

In some environments, repository definitions might be in different namespaces:

```yaml
# Single namespace for development
metadata:
  namespace: flux-system

# Environment-specific repository location
metadata:
  namespace: monitoring-system
```

### 3. Additional Repositories

Different environments might need additional repositories:

```yaml
# Production-only repositories
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: bitnami
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.bitnami.com/bitnami
```

## Example Overlay Structure

```
clusters/
├── base/
│   └── observability/
│       └── common/
│           ├── sources/
│           │   ├── helm-repositories.yaml
│           │   └── kustomization.yaml
│           └── kustomization.yaml
├── local/
│   └── observability/
│       └── common/
│           ├── kustomization.yaml
│           └── sources-patch.yaml
├── staging/
│   └── ...
└── production/
    └── ...
```

Example overlay `kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../../base/observability/common

patches:
  - path: sources-patch.yaml
    target:
      kind: HelmRepository
      name: all
```

## Example Environments

This directory structure allows for:
- **Local**: Fast update intervals, minimal repositories
- **Staging**: Standard configuration with moderate update intervals
- **Production**: Longer update intervals to reduce API load, additional specialized repositories

These examples demonstrate proper customization for different environments and can be used
as templates when creating your actual environment overlays. 