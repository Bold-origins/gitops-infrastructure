# Sealed Secrets Deployment Issue and Fix

## Problem Identified

We identified an issue with the deployment of sealed-secrets using our GitOps workflow that caused the component to stall during deployment. After investigating, we found two main issues:

1. The `--key-label` flag was being passed to the controller, but this flag doesn't exist in version v0.24.5 of the sealed-secrets controller, causing the container to crash.

2. The format of arguments in our Helm values file didn't match what Helm expects, leading to incorrect argument parsing.

## Working Solution

We successfully deployed sealed-secrets using a direct Helm installation with the following command:

```bash
helm install sealed-secrets sealed-secrets/sealed-secrets -n sealed-secrets \
  --set fullnameOverride=sealed-secrets-controller \
  --set namespace=sealed-secrets \
  --set "controller.args[0]=--key-prefix=sealed-secrets-key" \
  --set "controller.args[1]=--update-status" \
  --set "controller.args[2]=--log-level=debug"
```

The working deployment has the following arguments:
```
["--update-status","--key-prefix","sealed-secrets-key","--listen-addr",":8080","--listen-metrics-addr",":8081"]
```

## Required Fixes for GitOps Workflow

To fix the GitOps workflow, we need to update the following:

1. The `values.yaml` file in both base and local directories needs to use the correct format for Helm arguments:

```yaml
# Controller settings
controller:
  # Command line arguments
  args:
    - --update-status
    - --key-prefix=sealed-secrets-key
    - --log-level=debug  # Only for local environment
```

2. Remove any mention of `--key-label` from all configuration files.

3. Update the deployment patch to ensure it doesn't override the args with incorrect format.

4. Consider adding health checks in the component-deploy.sh script to detect and retry when containers are in crash loops.

## Why Flux Was Stalling

Flux was stalling during reconciliation because:

1. The sealed-secrets controller was continually crashing and restarting due to the invalid flag.
2. The finalizers on Flux resources were preventing proper cleanup, causing the deletion operations to hang.
3. Each reconciliation attempt was timing out, leading to a resource leak in the cluster.

## How to Prevent Similar Issues

1. Implement better validation of Helm chart values before deployment.
2. Add pre-deployment checks for flag compatibility with the target version.
3. Include more detailed error reporting in the deployment scripts.
4. Add a timeout/force option to the cleanup script to handle stuck resources.

## Next Steps

Now that we have successfully deployed sealed-secrets manually, we should:

1. **Verify the Changes**: The required changes to fix the GitOps workflow have been applied to:
   - `clusters/base/infrastructure/sealed-secrets/helm/values.yaml`
   - `clusters/local/infrastructure/sealed-secrets/helm/values.yaml`
   - `clusters/local/infrastructure/sealed-secrets/patches/deployment-patch.yaml`

2. **Test with GitOps**:
   - Wait 24 hours for the finalizers to time out completely
   - Delete the manually installed sealed-secrets deployment
   - Try deploying with the component-deploy.sh script again

3. **Add Error Detection**:
   - Enhance the component-deploy.sh script to detect container crashlooping
   - Add error checks for common Helm chart issues

4. **Update Documentation**:
   - Update the troubleshooting guide with this issue and solution
   - Add a note about proper Helm values formatting to the developer documentation 