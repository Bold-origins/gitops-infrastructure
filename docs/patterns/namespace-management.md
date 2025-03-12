# Namespace Management Pattern

This document describes the pattern used for namespace management in the GitOps infrastructure repository.

## Overview

The namespace management pattern follows a hybrid approach that:
1. Maintains component ownership of namespace definitions
2. Provides a centralized reference point for all namespaces
3. Enables environment-specific customizations
4. Follows GitOps and kustomize best practices

## Directory Structure

```
clusters/
├── base/
│   ├── infrastructure/
│   │   ├── namespaces/                 # Centralized namespace reference
│   │   │   ├── kustomization.yaml      # References all namespaces
│   │   │   └── namespaces.yaml         # Consolidated namespace definitions
│   │   ├── component-a/
│   │   │   ├── namespace.yaml          # Component-owned namespace
│   │   │   └── kustomization.yaml      # References its namespace
│   │   └── component-b/
│   │       ├── namespace.yaml          # Component-owned namespace
│   │       └── kustomization.yaml      # References its namespace
│   └── ...
└── environments/
    ├── staging/
    │   ├── infrastructure/
    │   │   ├── namespaces/
    │   │   │   └── kustomization.yaml  # References base namespaces with environment labels
    │   │   └── ...
    │   └── ...
    └── ...
```

## Pattern Implementation

### 1. Component-Owned Namespace Definitions

Each component continues to own its namespace definition:

```yaml
# clusters/base/infrastructure/component-a/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: component-a
  labels:
    tier: infrastructure
```

And references it in its kustomization:

```yaml
# clusters/base/infrastructure/component-a/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
# other component resources...
```

### 2. Centralized Namespace References

The central namespace directory contains a consolidated definition of all namespaces:

```yaml
# clusters/base/infrastructure/namespaces/namespaces.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: component-a
  labels:
    tier: infrastructure
---
apiVersion: v1
kind: Namespace
metadata:
  name: component-b
  labels:
    tier: infrastructure
# ... other namespaces
```

With a kustomization that references this consolidated file:

```yaml
# clusters/base/infrastructure/namespaces/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespaces.yaml

# Common labels for all namespaces
commonLabels:
  managed-by: kustomize
```

### 3. Environment-Specific Customizations

Each environment references the centralized namespace definitions and adds environment-specific labels:

```yaml
# clusters/environments/staging/infrastructure/namespaces/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../../../../clusters/base/infrastructure/namespaces

# Environment-specific labels
commonLabels:
  environment: staging
```

## Workflow for Adding New Namespaces

1. Add the namespace definition to the component directory
2. Update the component's kustomization to reference this namespace
3. Add the namespace to the centralized namespace definition in `clusters/base/infrastructure/namespaces/namespaces.yaml`
4. Verify the namespace is correctly created with all labels using `kustomize build`

## Best Practices

1. **Ownership**: Components always own their namespace definitions
2. **Labeling**: Use the centralized reference for common labels
3. **Environment-Specific**: Add environment-specific configurations through environment overlays
4. **Verification**: Always test changes with `kustomize build` before committing

## Tips and Troubleshooting

- If kustomize complains about file references outside of directories, verify path references are correct
- When removing a component, ensure its namespace is also removed from the centralized definition
- Use `kubectl diff` to preview changes before applying them to the cluster 