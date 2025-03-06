# MinIO Base Configuration

This directory contains the base configuration for MinIO that can be used across multiple environments (local, staging, production). The configuration is designed to be used with Kustomize overlays.

## What is MinIO?

MinIO is a high-performance, S3-compatible object storage solution that can be deployed within your Kubernetes cluster to provide object storage capabilities similar to AWS S3.

## Environment-Specific Customizations

When creating environment overlays, consider customizing the following components:

### 1. Storage Configuration

Storage requirements vary significantly across environments:

```yaml
# Local environment - smaller storage
persistence:
  enabled: true
  size: 10Gi

# Production environment - larger storage
persistence:
  enabled: true
  size: 100Gi
  storageClass: "managed-premium" # Adjust to your cloud provider's storage class
```

### 2. Resource Allocation

Adjust CPU and memory based on the environment:

```yaml
# Development/local environment
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

# Production environment
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### 3. Deployment Mode

MinIO can be deployed in different modes depending on environment needs:

```yaml
# Development/local environment
mode: standalone

# Production environment with high-availability
mode: distributed
zones: 2
drivesPerNode: 4
replicas: 4
```

### 4. Ingress & TLS Configuration

Configure ingress and domain settings according to your environment:

```yaml
# Local environment
ingress:
  enabled: true
  hosts:
    - minio.local
  tls: []

# Production environment
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - minio.example.com
  tls:
    - secretName: minio-tls
      hosts:
        - minio.example.com
```

### 5. Buckets & Lifecycle Policies

Bucket configuration should reflect environment needs:

```yaml
# Different retention periods for different environments
buckets:
  - name: logs
    policy: none
    purge: false

# In the bucket-setup job:
# Local/Dev: shorter retention
mc ilm add --expiry-days 7 myminio/logs

# Production: longer retention
mc ilm add --expiry-days 90 myminio/logs
```

### 6. Monitoring Configuration

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
│       └── minio/
│           ├── ...
├── local/
│   └── infrastructure/
│       └── minio/
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
  - ../../../../base/infrastructure/minio

configMapGenerator:
  - name: minio-values
    behavior: merge
    files:
      - values.yaml=values-patch.yaml
```

## Example Environments

This directory includes an `examples/` folder with sample overlay configurations for:
- **Local**: Minimal resources with local domain and smaller storage
- **Staging**: Medium resources with staging domain and moderate storage
- **Production**: High resources with production domain, larger storage, and HA configuration

These examples demonstrate proper customization for different environments and can be used
as templates when creating your actual environment overlays. 