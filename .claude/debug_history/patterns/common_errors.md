# Common Errors and Solutions

This document catalogs common errors encountered in this codebase and their solutions.

## HelmRelease Errors

### Reconciliation Failed

**Error:**
```
HelmRelease reconciliation failed: failed to reconcile HelmChart 'namespace/name': chart 'chart-name' not found in HelmRepository 'namespace/repo-name'
```

**Causes:**
1. HelmRepository is not correctly defined
2. HelmRepository has not been reconciled yet
3. Chart name is incorrect

**Solutions:**
1. Verify HelmRepository exists and is correctly defined
2. Check HelmRepository status with `flux get helmrepositories`
3. Verify chart name in HelmRelease matches the chart in the repository

### Values Validation Failed

**Error:**
```
HelmRelease reconciliation failed: install failed: values don't meet the specifications of the schema(s) in the values.schema.json
```

**Causes:**
1. Values provided in values.yaml are invalid
2. Required values are missing

**Solutions:**
1. Check the Helm chart's values.schema.json for required values
2. Validate values.yaml against the schema

## Kustomize Errors

### Resource Not Found

**Error:**
```
Error: accumulating resources: accumulation err='accumulating resources from 'path/to/file.yaml': error reading file: file does not exist
```

**Causes:**
1. Referenced file doesn't exist
2. Path to file is incorrect

**Solutions:**
1. Verify file exists at the specified path
2. Check kustomization.yaml for correct paths

### Patch Target Not Found

**Error:**
```
Error: accumulating patches: accumulating patches from 'path/to/patch.yaml': reading file: file declares a patch with target resource 'kind/name' that is not in the accumulated set of resources
```

**Causes:**
1. Target resource doesn't exist
2. Target resource selector in patch is incorrect

**Solutions:**
1. Verify target resource exists
2. Check patch selector matches the target resource

## Sealed Secrets Errors

### Decryption Failed

**Error:**
```
Error: error decrypting sealed secret: no key could decrypt secret
```

**Causes:**
1. Secret was encrypted with a different key
2. SealedSecret controller doesn't have the right key

**Solutions:**
1. Re-encrypt the secret with the correct key
2. Ensure SealedSecret controller has the right key

## Policy Violations

### Missing Required Labels

**Error:**
```
Error: admission webhook "validation.gatekeeper.sh" denied the request: [require-labels] you must provide labels: {"app.kubernetes.io/name"}
```

**Causes:**
1. Required labels are missing from the resource

**Solutions:**
1. Add the required labels to the resource

### Missing Required Probes

**Error:**
```
Error: admission webhook "validation.gatekeeper.sh" denied the request: [require-probes] Container 'container-name' is missing required probes: liveness, readiness
```

**Causes:**
1. Container doesn't have required health probes

**Solutions:**
1. Add liveness and readiness probes to the container

## Flux Errors

### Git Repository Not Found

**Error:**
```
GitRepository reconciliation failed: failed to checkout and determine revision: unable to clone 'https://github.com/org/repo.git'
```

**Causes:**
1. Git repository URL is incorrect
2. Flux doesn't have access to the repository

**Solutions:**
1. Verify repository URL
2. Check Flux has the correct credentials for private repositories