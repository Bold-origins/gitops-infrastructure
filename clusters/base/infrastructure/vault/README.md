# HashiCorp Vault Base Configuration

This directory contains the base configuration for HashiCorp Vault that can be used across multiple environments (local, staging, production). The configuration is designed to be used with Kustomize overlays.

## What is Vault?

HashiCorp Vault is a secrets management, encryption as a service, and privileged access management tool. It securely stores and controls access to tokens, passwords, certificates, API keys, and other secrets.

## Environment-Specific Customizations

When creating environment overlays, consider customizing the following components:

### 1. Development Mode vs Production Mode

Development mode is useful for local testing but should never be used in staging or production:

```yaml
# Local/Development environment
server:
  dev:
    enabled: true
    devRootToken: "root"

# Production environment
server:
  dev:
    enabled: false
  standalone:
    enabled: false
  ha:
    enabled: true
    replicas: 3
    config: |
      ui = true
      
      listener "tcp" {
        tls_disable = 0
        tls_cert_file = "/vault/tls/tls.crt"
        tls_key_file = "/vault/tls/tls.key"
        address = "[::]:8200"
      }
      
      storage "file" {
        path = "/vault/data"
      }
```

### 2. Storage Configuration

Development uses in-memory storage, while production should use persistent storage:

```yaml
# Production storage configuration
dataStorage:
  enabled: true
  size: "10Gi"
  storageClass: "standard"
  accessMode: "ReadWriteOnce"
```

### 3. Resource Allocation

Adjust CPU and memory based on the environment:

```yaml
# Development environment
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

# Production environment
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "1024Mi"
    cpu: "500m"
```

### 4. Ingress Configuration

The domain name will vary by environment:

```yaml
# Local environment
spec:
  tls:
  - hosts:
    - vault.local
    secretName: vault-tls
  rules:
  - host: vault.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vault
            port:
              number: 8200

# Production environment
spec:
  tls:
  - hosts:
    - vault.example.com
    secretName: vault-tls
  rules:
  - host: vault.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vault
            port:
              number: 8200
```

### 5. UI Configuration

UI settings may differ between environments:

```yaml
# Production UI settings
ui:
  enabled: true
  serviceType: "ClusterIP"
  externalPort: 8200
  # Additional security settings
  serviceNodePort: null
```

### 6. Injector and CSI Provider

These components may be enabled in production environments:

```yaml
# Production injector configuration
injector:
  enabled: true
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"

# Production CSI provider
csi:
  enabled: true
  image:
    repository: hashicorp/vault-csi-provider
    tag: "1.4.0"
```

## Example Overlay Structure

```
clusters/
├── base/
│   └── infrastructure/
│       └── vault/
│           ├── ...
├── local/
│   └── infrastructure/
│       └── vault/
│           ├── kustomization.yaml
│           └── values-patch.yaml
│           └── ingress-patch.yaml
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
  - ../../../../base/infrastructure/vault

configMapGenerator:
  - name: vault-values
    behavior: merge
    files:
      - values.yaml=values-patch.yaml

patchesStrategicMerge:
  - ingress-patch.yaml
```

## Example Environments

This directory includes an `examples/` folder with sample overlay configurations for:
- **Local**: Development mode with in-memory storage and minimal resources
- **Staging**: Standard configuration with persistent storage and moderate resources
- **Production**: HA configuration with persistent storage, multiple replicas, and more resources

These examples demonstrate proper customization for different environments and can be used
as templates when creating your actual environment overlays. 