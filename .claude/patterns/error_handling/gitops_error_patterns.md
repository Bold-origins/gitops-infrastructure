# GitOps Error Handling Patterns

This document outlines common error handling patterns for GitOps workflows.

## Flux Reconciliation Errors

### Pattern: Progressive Debugging

When Flux resources fail to reconcile, follow this pattern:

1. Check resource status:
```bash
flux get <resource-type> <resource-name> -n <namespace>
```

2. Examine events:
```bash
kubectl describe <resource-type> <resource-name> -n <namespace>
```

3. Check controller logs:
```bash
kubectl logs -n flux-system deployment/<controller-name> -f
```

4. Apply changes locally to validate:
```bash
kubectl apply -k <path> --dry-run=client
```

### Pattern: Source-to-Deployment Tracing

For complex failures, trace from source to deployment:

1. Check Git source:
```bash
flux get source git <source-name>
```

2. Check Kustomization:
```bash
flux get kustomization <kustomization-name>
```

3. Check HelmRelease (if applicable):
```bash
flux get helmrelease <release-name> -n <namespace>
```

4. Check deployed resources:
```bash
kubectl get <resource-type> -n <namespace>
```

## Sealed Secrets Errors

### Pattern: Re-encryption

When sealed secrets fail to decrypt:

1. Backup the failed sealed secret

2. Re-encrypt the secret:
```bash
kubectl create secret generic <secret-name> -n <namespace> --from-literal=key=value --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets -o yaml > sealed-secret.yaml
```

3. Apply the new sealed secret:
```bash
kubectl apply -f sealed-secret.yaml
```

### Pattern: Key Rotation Safety

When rotating sealed secrets keys:

1. Backup all existing sealed secrets:
```bash
kubectl get sealedsecret -A -o yaml > sealedsecrets-backup.yaml
```

2. Backup the current keys:
```bash
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-keys.yaml
```

3. Apply key rotation with grace period:
```bash
kubectl patch deployment sealed-secrets -n sealed-secrets --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env", "value": [{"name": "SEALED_SECRETS_KEY_RENEWAL_PERIOD","value": "24h"},{"name": "SEALED_SECRETS_ACTIVE_PERIOD","value": "72h"}]}]'
```

## Kustomize Build Errors

### Pattern: Incremental Validation

When kustomize build fails:

1. Validate base resources:
```bash
kubectl kustomize <base-path> | kubectl apply --dry-run=client -f -
```

2. Add patches one by one:
```bash
kubectl kustomize <patch1-path> | kubectl apply --dry-run=client -f -
kubectl kustomize <patch2-path> | kubectl apply --dry-run=client -f -
```

3. Use kustomize build with load restrictor:
```bash
kustomize build --load-restrictor=LoadRestrictionsNone <path>
```

### Pattern: Resource Validation Loop

For validation errors:

1. Extract the problematic resource:
```bash
kustomize build <path> | grep -A50 -B50 "<resource-name>"
```

2. Validate the resource:
```bash
kubectl create -f <extracted-resource.yaml> --dry-run=client
```

3. Fix and reapply in isolation before full kustomization.

## Helm Chart Errors

### Pattern: Values Isolation

When HelmRelease values are rejected:

1. Extract current values:
```bash
flux get helmrelease <release-name> -n <namespace> -o yaml
```

2. Test values directly with Helm:
```bash
helm template <chart-name> <chart-repo>/<chart-name> --version <chart-version> -f values.yaml
```

3. Incrementally add values to identify problematic settings.

### Pattern: Chart Version Compatibility

When upgrading charts:

1. Check release notes for breaking changes

2. Test chart upgrade locally:
```bash
helm template <chart-name> <chart-repo>/<chart-name> --version <old-version> -f values.yaml > old.yaml
helm template <chart-name> <chart-repo>/<chart-name> --version <new-version> -f values.yaml > new.yaml
diff old.yaml new.yaml
```

3. Validate new values schema:
```bash
helm show values <chart-repo>/<chart-name> --version <new-version>
```

## Policy Enforcement Errors

### Pattern: Constraint Testing

When policies reject resources:

1. Check which constraint was violated:
```bash
kubectl get constraint -A
```

2. Test resource against specific constraint:
```bash
kubectl get constraint <constraint-name> -o yaml
```

3. Create a temporary namespace for testing:
```bash
kubectl create ns test-policy
kubectl label ns test-policy admission.gatekeeper.sh/ignore=true
```

4. Test fixes in isolation before applying to the main namespace.