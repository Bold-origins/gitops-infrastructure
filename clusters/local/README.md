# Local Environment Kustomize Overlay

This directory contains the Kustomize overlays for the local Kubernetes environment. It extends the base configurations found in `clusters/base/` with environment-specific settings for local development.

## Refactoring Guide

This environment is being refactored to use the base configurations through Kustomize overlays. You can refactor components manually or use the provided automation scripts.

### Automated Refactoring

For a streamlined experience, use the refactoring workflow script:

```bash
# Refactor a component (infrastructure is the default type)
./scripts/refactor-workflow.sh cert-manager

# Refactor a component with explicit type
./scripts/refactor-workflow.sh prometheus observability
```

The workflow script will:
1. Back up your existing component
2. Refactor it to use the base configuration
3. Create template patch files
4. Test the new configuration
5. Clean up redundant files
6. Update progress tracking documents

### Manual Refactoring

If you prefer to refactor manually, follow these steps:

#### Step 1: Update Component Kustomization

For each component directory (e.g., `infrastructure/cert-manager`), update the `kustomization.yaml` file to reference the base:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference the base configuration
resources:
- ../../../../base/infrastructure/[component-name]

# Apply local-specific patches
patchesStrategicMerge:
- patches/[resource-name]-patch.yaml

# Import local-specific values (if applicable)
configMapGenerator:
- name: [component-name]-values
  behavior: merge
  files:
  - values.yaml=helm/values.yaml
```

#### Step 2: Create Patches Directory

Create a `patches` directory for each component:

```bash
mkdir -p infrastructure/[component-name]/patches
```

#### Step 3: Create Patch Files

Create patch files for each resource that needs local-specific configurations:

```yaml
# Example patches/ingress-patch.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: [component-name]
  namespace: [namespace]
spec:
  # Only include fields that need to be modified
  tls:
  - hosts:
    - [component-name].local
```

#### Step 4: Clean Up Redundant Files

After refactoring, you can clean up redundant files using:

```bash
./scripts/cleanup-local-refactoring.sh
```

This script backs up redundant files to a timestamped directory within the component folder.

## Local Development Patch Guidelines

When creating patches for the local environment, focus on the following local-specific modifications:

### Resource Optimization

- **Reduce resource requirements**: Lower CPU/memory requests and limits
- **Decrease replica counts**: Use single replicas instead of HA configurations
- **Simplify configurations**: Remove production-only features

```yaml
# Example: Reducing resources for local development
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 1 # Single replica for local
  template:
    spec:
      containers:
        - name: app
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
```

### Local Networking

- **Use .local domains**: Replace production domains with .local TLDs
- **Use self-signed certificates**: Simplify TLS for local testing
- **Configure local IPs/ports**: Adjust network settings for local access

```yaml
# Example: Local domain ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-app
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
spec:
  tls:
    - hosts:
        - example.local
```

### Development Convenience

- **Simplified credentials**: Use development tokens/passwords
- **Debug-friendly settings**: Enable verbose logging
- **Faster startup**: Reduce health check periods
- **Local persistence**: Use emptyDir or hostPath instead of PVCs

```yaml
# Example: Development-friendly settings
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: LOG_LEVEL
              value: "debug"
            - name: DEV_MODE
              value: "true"
```

### Security Simplifications

- **Reduced security constraints**: Simplify security context for local development
- **Skip production security measures**: Omit complex auth for local testing
- **Local-only secrets**: Use simplified secret management

## Validation and Testing

After refactoring a component, validate that it functions correctly:

```bash
# Test with kustomize
kubectl kustomize clusters/local/infrastructure/[component-name]

# Apply to the cluster
kubectl apply -k clusters/local/infrastructure/[component-name]
```

## Completed Components

The following components have been refactored to use the base configurations:

- [x] cert-manager
- [x] vault
- [x] sealed-secrets
- [ ] gatekeeper
- [ ] minio
- [ ] ingress
- [ ] metallb
- [ ] observability components

## Implementation Notes

### Flux Integration

The local environment uses Flux for GitOps automation. The `flux-system` directory and related configuration files remain at this level because Flux is environment-specific and not part of the base configuration.

### Local-Specific Resources

Some resources are specific to the local environment (like local domain ingresses). These are maintained directly in this directory rather than in the base.

## Testing

After refactoring a component, validate that it functions identically to the previous configuration by checking:

1. All resources are created correctly
2. No errors or warnings in logs
3. Services function as expected
4. Configuration values are applied correctly
