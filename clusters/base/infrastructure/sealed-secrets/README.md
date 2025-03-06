# Sealed Secrets Base Configuration

This directory contains the base configuration for Sealed Secrets that can be used across multiple environments (local, staging, production). The configuration is designed to be used with Kustomize overlays.

## What is Sealed Secrets?

Sealed Secrets is a Kubernetes controller and tool that helps manage Kubernetes secrets in a secure, GitOps-friendly way. It allows you to encrypt your Secret resources so they can be safely stored in a Git repository without exposing sensitive information.

## Environment-Specific Customizations

When creating environment overlays, consider customizing the following components:

### 1. Resource Allocation

Resource requirements may vary across environments:

```yaml
# Development/local environment - smaller footprint
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"

# Production environment - larger resources for higher throughput
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### 2. Controller Configuration

Controller settings can be adjusted based on environment needs:

```yaml
# Development settings with higher log verbosity
controller:
  logLevel: 2
  args:
    - --key-prefix=sealed-secrets-key
    - --update-status
    - --log-level=debug

# Production settings
controller:
  logLevel: 0
  args:
    - --key-prefix=sealed-secrets-key
    - --update-status
```

### 3. Key Rotation and Management

Key rotation strategies may differ by environment:

```yaml
# More frequent key rotation in production
keyRenewPeriod: "720h" # 30 days

# Secret retention for key history
secretName: sealed-secrets-key
keyController:
  enabled: true
```

### 4. High Availability Configuration

For production environments, you might want to enable HA features:

```yaml
# Production HA configuration
replicas: 2
podAntiAffinity: true
```

### 5. Security Context

Tighter security settings for production:

```yaml
# Production security settings
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  fsGroup: 65534
```

### 6. Monitoring Integration

Enable monitoring for staging and production:

```yaml
# Production metrics collection
metrics:
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prometheus
```

## Example Overlay Structure

```
clusters/
├── base/
│   └── infrastructure/
│       └── sealed-secrets/
│           ├── ...
├── local/
│   └── infrastructure/
│       └── sealed-secrets/
│           ├── kustomization.yaml
│           └── values-patch.yaml
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
  - ../../../../base/infrastructure/sealed-secrets

patches:
  - patch: |-
      apiVersion: helm.toolkit.fluxcd.io/v2beta1
      kind: HelmRelease
      metadata:
        name: sealed-secrets
        namespace: sealed-secrets
      spec:
        values:
          $patch: merge
          $(cat values-patch.yaml | indent 10)
    target:
      kind: HelmRelease
      name: sealed-secrets
```

## Example Environments

This directory includes an `examples/` folder with sample overlay configurations for:
- **Local**: Minimal resources with basic configuration
- **Staging**: Medium resources with standard monitoring
- **Production**: High resources with HA configuration, enhanced security and monitoring

These examples demonstrate proper customization for different environments and can be used
as templates when creating your actual environment overlays. 