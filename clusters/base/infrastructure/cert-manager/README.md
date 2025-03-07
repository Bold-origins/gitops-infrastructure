# Cert-Manager Base Configuration

This directory contains the base configuration for cert-manager that can be used across multiple environments (local, staging, production). The configuration is designed to be used with Kustomize overlays.

## Environment-Specific Customizations

When creating environment overlays, consider customizing the following components:

### 1. Cluster Issuers

In `cluster-issuers.yaml`:

- Replace the placeholder email (`placeholder@example.com`) with a real email address for ACME notifications
- For production, ensure Let's Encrypt production issuer is properly configured
- For development/staging, you might want to use only the self-signed issuer or Let's Encrypt staging

Example overlay patch:

```yaml
# patches/cluster-issuers-patch.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: real-email@yourdomain.com
```

### 2. Resource Allocation

In `helm/values.yaml`:

- Adjust CPU and memory limits/requests based on environment needs:
  - Local: Lower resources (current defaults are suitable)
  - Staging: Medium resources
  - Production: Higher resources, possibly multiple replicas

Example production values overlay:

```yaml
# values-production.yaml
replicaCount: 2

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 300m
    memory: 256Mi

webhook:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

cainjector:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
```

### 3. Prometheus Integration

- For environments with proper monitoring setup, you might want to enable ServiceMonitor:

```yaml
prometheus:
  enabled: true
  servicemonitor:
    enabled: true
```

### 4. Flux/GitOps Integration

The base configuration includes Flux HelmRelease and HelmRepository custom resources. If your environment:

- Uses Flux: Ensure the correct namespace references and repositories
- Doesn't use Flux: Create an alternative installation method in your overlay

## Example Overlay Structure

```
clusters/
├── base/
│   └── infrastructure/
│       └── cert-manager/
│           ├── ...
├── local/
│   └── infrastructure/
│       └── cert-manager/
│           ├── kustomization.yaml
│           └── patches/
│               ├── cluster-issuers-patch.yaml
│               └── values-patch.yaml
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
  - ../../../../base/infrastructure/cert-manager

patchesStrategicMerge:
  - patches/cluster-issuers-patch.yaml

configMapGenerator:
  - name: cert-manager-values
    behavior: merge
    files:
      - values.yaml=values-patch.yaml
```

## Example Environments

This directory includes an `examples/` folder with sample overlay configurations for:

- **Local**: Minimal resources, no production issuer
- **Staging**: Medium resources, both staging and production issuers
- **Production**: High resources with high availability (multiple replicas)

These examples demonstrate proper customization for different environments and can be used
as templates when creating your actual environment overlays.
