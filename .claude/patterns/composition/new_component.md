# Creating a New Component Pattern

This document provides a pattern for creating a new component in the GitOps workflow.

## Base Component Structure

```
clusters/base/[category]/[component-name]/
├── README.md             # Documentation
├── kustomization.yaml    # Kustomize configuration
├── namespace.yaml        # Namespace definition
├── helmrelease.yaml      # Flux HelmRelease (if using Helm)
├── [component].yaml      # Component-specific resources
├── helm/                 # Helm values
│   ├── release.yaml      # Helm chart source
│   └── values.yaml       # Default values
└── sealed-secrets/       # Sealed secrets templates
    └── template-*.yaml   # Secret templates
```

## Environment Overlay Structure

```
clusters/[environment]/[category]/[component-name]/
├── kustomization.yaml    # Kustomize configuration
├── patches/              # Patches for base resources
│   └── *-patch.yaml      # Patch files
├── helm/                 # Environment-specific Helm values
│   └── values.yaml       # Values for this environment
└── sealed-secrets/       # Environment-specific sealed secrets
    └── *.yaml            # Actual sealed secrets
```

## Step-by-Step Guide

### 1. Create Base Component

```bash
# Create directory structure
mkdir -p clusters/base/[category]/[component-name]/helm
mkdir -p clusters/base/[category]/[component-name]/sealed-secrets

# Create kustomization.yaml
cat > clusters/base/[category]/[component-name]/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  # Add other resources here
EOF

# Create namespace.yaml
cat > clusters/base/[category]/[component-name]/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: [component-name]
EOF

# Create README.md
cat > clusters/base/[category]/[component-name]/README.md << EOF
# [Component Name]

## Overview
Brief description of the component

## Configuration
How to configure the component

## Examples
See the examples/ directory for environment-specific configurations
EOF
```

### 2. Create HelmRelease (if using Helm)

```bash
cat > clusters/base/[category]/[component-name]/helmrelease.yaml << EOF
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: [component-name]
  namespace: [component-name]
spec:
  interval: 5m
  chart:
    spec:
      chart: [chart-name]
      version: "[chart-version]"
      sourceRef:
        kind: HelmRepository
        name: [repo-name]
        namespace: flux-system
  values:
    # Default values
EOF

# Create Helm values
cat > clusters/base/[category]/[component-name]/helm/values.yaml << EOF
# Default Helm values
EOF
```

### 3. Create Component-Specific Resources

Create any additional resources needed for the component, such as:
- ConfigMaps
- Custom Resources
- Services
- etc.

### 4. Create Environment Examples

```bash
# Create example directories
mkdir -p clusters/base/[category]/[component-name]/examples/local
mkdir -p clusters/base/[category]/[component-name]/examples/staging
mkdir -p clusters/base/[category]/[component-name]/examples/production

# Create example kustomization
cat > clusters/base/[category]/[component-name]/examples/local/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../
patchesStrategicMerge:
  # Add patches here
EOF
```

### 5. Create Environment-Specific Overlays

```bash
# Create directory structure
mkdir -p clusters/[environment]/[category]/[component-name]/patches
mkdir -p clusters/[environment]/[category]/[component-name]/helm
mkdir -p clusters/[environment]/[category]/[component-name]/sealed-secrets

# Create kustomization.yaml
cat > clusters/[environment]/[category]/[component-name]/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../base/[category]/[component-name]
patchesStrategicMerge:
  # Add patches here
EOF

# Create environment-specific values
cat > clusters/[environment]/[category]/[component-name]/helm/values.yaml << EOF
# Environment-specific Helm values
EOF
```

## Complete Example: Adding a New Monitoring Tool

### Base Structure

```
clusters/base/observability/newrelic/
├── README.md
├── kustomization.yaml
├── namespace.yaml
├── helmrelease.yaml
├── helm/
│   ├── release.yaml
│   └── values.yaml
└── sealed-secrets/
    └── template-license-secret.yaml
```

### Kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrelease.yaml
  - sealed-secrets/template-license-secret.yaml
```

### HelmRelease.yaml
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: newrelic
  namespace: observability
spec:
  interval: 5m
  chart:
    spec:
      chart: newrelic-infrastructure
      version: "3.0.0"
      sourceRef:
        kind: HelmRepository
        name: newrelic
        namespace: flux-system
  valuesFrom:
    - kind: Secret
      name: newrelic-license
      valuesKey: license
      targetPath: licenseKey
  values:
    cluster: "${CLUSTER_NAME}"
```

### Environment Overlay
```
clusters/production/observability/newrelic/
├── kustomization.yaml
├── patches/
│   └── helmrelease-patch.yaml
└── sealed-secrets/
    └── license-secret.yaml
```

### Environment Kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../../base/observability/newrelic
  - sealed-secrets/license-secret.yaml
patchesStrategicMerge:
  - patches/helmrelease-patch.yaml
```