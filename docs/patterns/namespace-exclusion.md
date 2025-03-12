# Namespace Exclusion Pattern

This document describes how to exclude duplicate namespace definitions when using the centralized namespace management approach.

## Overview

When using a centralized namespace management approach, components may still have their own namespace definitions. To prevent duplication and conflicts, we use the PatchTransformer to exclude the component-specific namespace definitions.

## Implementation

### Step 1: Add transformer reference to kustomization.yaml

```yaml
# clusters/staging/infrastructure/component/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../../../clusters/base/infrastructure/component
# other resources...

# Use transformers to exclude the namespace
transformers:
- transformers/remove-namespace.yaml
```

### Step 2: Create the transformer file

```yaml
# clusters/staging/infrastructure/component/transformers/remove-namespace.yaml
apiVersion: builtin
kind: PatchTransformer
metadata:
  name: remove-namespace
target:
  kind: Namespace
  name: component-namespace-name
patch: |
  $patch: delete
  apiVersion: v1
  kind: Namespace
  metadata:
    name: component-namespace-name
```

Make sure to replace `component-namespace-name` with the actual namespace name of your component.

## Testing

You can test if the namespace exclusion works by running:

```bash
kustomize build clusters/staging/infrastructure/component | grep -A 10 "kind: Namespace" || echo "No namespaces found"
```

If the output shows "No namespaces found", the exclusion is working correctly.

## Applying to Multiple Components

For each component that has a namespace definition, apply this pattern by:
1. Copying the transformer file
2. Updating the namespace name in the transformer
3. Adding the transformer reference to the component's kustomization.yaml 