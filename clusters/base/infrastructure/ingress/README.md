# NGINX Ingress Controller Base Configuration

This directory contains the base configuration for NGINX Ingress Controller that can be used across multiple environments (local, staging, production). The configuration is designed to be used with Kustomize overlays.

## Environment-Specific Customizations

When creating environment overlays, consider customizing the following components:

### 1. Resource Allocation

In the `release.yaml` values section:
- Adjust CPU and memory limits/requests based on environment needs:
  - Local: Lower resources
  - Staging: Medium resources
  - Production: Higher resources, possibly multiple replicas

Example production values patch:
```yaml
# values-production.yaml
controller:
  resources:
    limits:
      cpu: 1000m
      memory: 1024Mi
    requests:
      cpu: 200m
      memory: 512Mi
  replicaCount: 2
```

### 2. Service Type

The service type may need to be different based on environment:
```yaml
# Local environment might use NodePort
controller:
  service:
    type: NodePort

# Production environment typically uses LoadBalancer
controller:
  service:
    type: LoadBalancer
```

### 3. Metrics & Monitoring

For environments with proper monitoring setup:

```yaml
# Enhanced metrics for production
controller:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        release: prometheus
```

### 4. SSL Configuration

Different environments may have different SSL requirements:

```yaml
# Production SSL configuration
controller:
  config:
    ssl-protocols: "TLSv1.2 TLSv1.3"
    ssl-ciphers: "HIGH:!aNULL:!MD5"
    use-forwarded-headers: "true"
  extraArgs:
    default-ssl-certificate: "cert-manager/wildcard-tls"
```

### 5. Flux/GitOps Integration

The base configuration includes Flux HelmRelease custom resources. If your environment:
- Uses Flux: Ensure the correct namespace references and repositories
- Doesn't use Flux: Create an alternative installation method in your overlay

## Example Overlay Structure

```
clusters/
├── base/
│   └── infrastructure/
│       └── ingress/
│           ├── ...
├── local/
│   └── infrastructure/
│       └── ingress/
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
  - ../../../../base/infrastructure/ingress

patches:
  - path: values-patch.yaml
    target:
      kind: HelmRelease
      name: ingress-nginx
```

## Example Environments

This directory includes an `examples/` folder with sample overlay configurations for:
- **Local**: Minimal resources with NodePort service type
- **Staging**: Medium resources with LoadBalancer service type
- **Production**: High resources with multiple replicas, LoadBalancer service type, and enhanced metrics

These examples demonstrate proper customization for different environments and can be used
as templates when creating your actual environment overlays.