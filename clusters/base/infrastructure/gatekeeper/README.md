# OPA Gatekeeper Base Configuration

This directory contains the base configuration for OPA Gatekeeper that can be used across multiple environments (local, staging, production). The configuration is designed to be used with Kustomize overlays.

## Environment-Specific Customizations

When creating environment overlays, consider customizing the following components:

### 1. Resource Allocation

In `helm/values.yaml`:
- Adjust CPU and memory limits/requests based on environment needs:
  - Local: Lower resources
  - Staging: Medium resources
  - Production: Higher resources, possibly multiple replicas

Example production values overlay:
```yaml
# values-production.yaml
replicas: 3

controllerManager:
  resources:
    limits:
      cpu: 2000m
      memory: 1024Mi
    requests:
      cpu: 200m
      memory: 512Mi

audit:
  resources:
    limits:
      cpu: 2000m
      memory: 1024Mi
    requests:
      cpu: 200m
      memory: 512Mi
```

### 2. Exempt Namespaces

In different environments, you might need to exempt different namespaces from policy enforcement:

```yaml
# Local environment might exempt more namespaces
exemptNamespaces:
  - kube-system
  - gatekeeper-system
  - local-dev
  - flux-system

# Production environment might be more restrictive
exemptNamespaces:
  - kube-system
  - gatekeeper-system
```

### 3. Audit Interval

The audit interval determines how frequently Gatekeeper checks for policy violations:
- Local: Longer intervals to reduce resource usage (60s+)
- Staging: Medium intervals (30s)
- Production: Shorter intervals for faster detection (15-30s)

```yaml
# Adjust based on environment needs
auditInterval: 15  # seconds
```

### 4. Monitoring Integration

For environments with proper monitoring setup, you might want to adjust metrics settings:

```yaml
# Enhanced metrics for production
emitAdmissionEvents: true
emitAuditEvents: true

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8888"
```

### 5. Flux/GitOps Integration

The base configuration includes Flux HelmRelease and HelmRepository custom resources. If your environment:
- Uses Flux: Ensure the correct namespace references and repositories
- Doesn't use Flux: Create an alternative installation method in your overlay

## Example Overlay Structure

```
clusters/
├── base/
│   └── infrastructure/
│       └── gatekeeper/
│           ├── ...
├── local/
│   └── infrastructure/
│       └── gatekeeper/
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
  - ../../../../base/infrastructure/gatekeeper

configMapGenerator:
  - name: gatekeeper-values
    behavior: merge
    files:
      - values.yaml=values-patch.yaml
```

## Example Environments

This directory includes an `examples/` folder with sample overlay configurations for:
- **Local**: Minimal resources, longer audit intervals, more exempt namespaces
- **Staging**: Medium resources with 2 replicas, standard configuration
- **Production**: High resources with 3 replicas, shorter audit intervals, minimal exemptions

Each example includes:
- Environment-specific values adjustments
- Appropriate resource scaling
- Environment-specific namespace exemptions
- Environment-specific monitoring configurations

These examples demonstrate proper customization for different environments and can be used
as templates when creating your actual environment overlays.
