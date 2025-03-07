# Troubleshooting Guide for GitOps Infrastructure

This guide covers common issues you might encounter while working with the GitOps infrastructure and provides step-by-step solutions.

## Table of Contents

- [Deployment Issues](#deployment-issues)
  - [Flux Reconciliation Timeouts](#flux-reconciliation-timeouts)
  - [GitRepository Errors](#gitrepository-errors)
  - [Kustomization Failures](#kustomization-failures)
- [Component-Specific Issues](#component-specific-issues)
  - [Vault Issues](#vault-issues)
  - [Cert-Manager Issues](#cert-manager-issues)
  - [Ingress-NGINX Issues](#ingress-nginx-issues)
  - [MetalLB Issues](#metallb-issues)
- [Infrastructure Issues](#infrastructure-issues)
  - [Minikube Issues](#minikube-issues)
  - [Resource Constraints](#resource-constraints)
- [GitOps Workflow Issues](#gitops-workflow-issues)
  - [Source Controller Issues](#source-controller-issues)
  - [Kustomize Controller Issues](#kustomize-controller-issues)
- [Common Error Messages](#common-error-messages)
- [Diagnostic Procedures](#diagnostic-procedures)
- [Recovery Procedures](#recovery-procedures)

## Deployment Issues

### Flux Reconciliation Timeouts

**Symptoms:**
- "context deadline exceeded" errors
- Kustomization shows "Reconciliation failed" or stays in "Progressing" state indefinitely
- Log shows reconciliation taking too long

**Solutions:**

1. **Use component-by-component deployment**:
   ```bash
   ./scripts/gitops/component-deploy.sh
   ```
   This script handles timeouts more gracefully by deploying one component at a time.

2. **Increase timeout values**:
   ```bash
   kubectl edit kustomization -n flux-system <kustomization-name>
   ```
   Increase the `spec.timeout` value (e.g., from 3m to 10m).

3. **Check for dependency issues**:
   Some components may be waiting for others to be fully ready. Ensure components are deployed in the correct order.

4. **Verify Git source is healthy**:
   ```bash
   flux get sources git
   ```
   Make sure the GitRepository resource shows `Ready: True`.

5. **Check Flux controller logs**:
   ```bash
   kubectl -n flux-system logs -f deployment/kustomize-controller
   ```
   Look for specific errors or issues in the logs.

### GitRepository Errors

**Symptoms:**
- "Authentication failed" errors
- "failed to clone" errors
- GitRepository resource shows `Ready: False`

**Solutions:**

1. **Verify GitHub token**:
   ```bash
   curl -s -H "Authorization: token YOUR_TOKEN" https://api.github.com/user | jq .login
   ```
   This should return your GitHub username.

2. **Update GitHub credentials**:
   ```bash
   kubectl -n flux-system delete secret flux-system
   kubectl -n flux-system create secret generic flux-system \
     --from-literal=username=YOUR_GITHUB_USERNAME \
     --from-literal=password=YOUR_GITHUB_TOKEN
   ```

3. **Recreate GitRepository resource**:
   ```bash
   kubectl delete gitrepository -n flux-system flux-system
   flux create source git flux-system \
     --url=https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO \
     --branch=main \
     --username=YOUR_GITHUB_USERNAME \
     --password=YOUR_GITHUB_TOKEN \
     --namespace=flux-system \
     --secret-ref=flux-system
   ```

4. **Check repository structure**:
   Ensure your repository has the expected directory structure:
   ```
   clusters/
   ├── local/
   │   ├── infrastructure/
   │   │   ├── cert-manager/
   │   │   ├── ingress/
   │   │   ├── metallb/
   │   │   ├── vault/
   │   │   └── ...
   ```

5. **Run the resume setup script**:
   ```bash
   ./scripts/gitops/resume-setup.sh
   ```
   This automatically fixes common GitRepository issues.

### Kustomization Failures

**Symptoms:**
- "kustomize build failed" errors
- "resource not found" errors
- Kustomization shows `Ready: False` with validation errors

**Solutions:**

1. **Validate kustomization locally**:
   ```bash
   kustomize build clusters/local/infrastructure/<component>
   ```
   This helps identify syntax errors or missing references.

2. **Check for missing CRDs**:
   ```bash
   kubectl api-resources | grep <resource-name>
   ```
   Some resources require CRDs to be installed first.

3. **Inspect a specific component**:
   ```bash
   ./scripts/gitops/diagnose-component.sh <component-name>
   ```
   This provides detailed diagnostics.

4. **Check for path issues**:
   Ensure the paths in your kustomization.yaml file are correct.

5. **Deploy component directly**:
   ```bash
   kubectl apply -k clusters/local/infrastructure/<component>
   ```
   This bypasses Flux to identify if the issue is with Flux or the manifests.

## Component-Specific Issues

### Vault Issues

**Symptoms:**
- Vault pods are running but Vault is sealed
- Cannot access Vault UI
- Vault initialization fails

**Solutions:**

1. **Check if Vault is running**:
   ```bash
   kubectl get pods -n vault
   ```

2. **Initialize Vault manually**:
   ```bash
   kubectl -n vault port-forward svc/vault 8200:8200
   # In another terminal
   export VAULT_ADDR=http://localhost:8200
   vault operator init -key-shares=1 -key-threshold=1
   ```

3. **Unseal Vault**:
   ```bash
   vault operator unseal <UNSEAL_KEY>
   ```

4. **Verify storage class**:
   ```bash
   kubectl get pvc -n vault
   ```
   Ensure PVCs are bound properly.

5. **Check Vault-specific diagnostics**:
   ```bash
   ./scripts/gitops/diagnose-component.sh vault
   ```

### Cert-Manager Issues

**Symptoms:**
- Certificate issuers not created
- Certificates not being issued
- cert-manager webhook failures

**Solutions:**

1. **Verify CRDs are installed**:
   ```bash
   kubectl get crds | grep cert-manager
   ```

2. **Check webhook service**:
   ```bash
   kubectl get pods -n cert-manager
   kubectl logs -n cert-manager deployment/cert-manager-webhook
   ```

3. **Verify ClusterIssuers**:
   ```bash
   kubectl get clusterissuers
   kubectl describe clusterissuer <issuer-name>
   ```

4. **Check certificate requests**:
   ```bash
   kubectl get certificaterequests -A
   ```

5. **Restart cert-manager controller**:
   ```bash
   kubectl -n cert-manager rollout restart deployment/cert-manager
   ```

### Ingress-NGINX Issues

**Symptoms:**
- Ingress-NGINX controller not running
- Cannot access services through ingress
- "connection refused" when accessing services

**Solutions:**

1. **Check if controller is running**:
   ```bash
   kubectl get pods -n ingress-nginx
   ```

2. **Verify service**:
   ```bash
   kubectl get svc -n ingress-nginx
   ```
   Ensure the service has an external IP.

3. **Test the controller directly**:
   ```bash
   curl -k https://$(minikube ip)/healthz
   ```

4. **Check ingress resources**:
   ```bash
   kubectl get ingress -A
   ```

5. **Enable ingress addon in minikube**:
   ```bash
   minikube addons enable ingress
   ```

### MetalLB Issues

**Symptoms:**
- Services with type LoadBalancer stay in "Pending" state
- MetalLB controller pods not running
- No external IPs assigned

**Solutions:**

1. **Check MetalLB pods**:
   ```bash
   kubectl get pods -n metallb-system
   ```

2. **Verify IP address pools**:
   ```bash
   kubectl get ipaddresspools -n metallb-system
   ```

3. **Check L2 advertisements**:
   ```bash
   kubectl get l2advertisements -n metallb-system
   ```

4. **Verify Minikube's IP range**:
   ```bash
   minikube ip
   ```
   Ensure MetalLB's address pool includes IPs in the same subnet.

5. **Re-create address pools**:
   ```bash
   kubectl apply -f clusters/local/infrastructure/metallb/config
   ```

## Infrastructure Issues

### Minikube Issues

**Symptoms:**
- Minikube fails to start
- "VirtualBox/Docker driver not found" errors
- Minikube crashes or freezes

**Solutions:**

1. **Check Docker status**:
   ```bash
   docker info
   ```
   Ensure Docker is running.

2. **Reset Minikube**:
   ```bash
   minikube delete
   minikube start --driver=docker --memory=6144 --cpus=4
   ```

3. **Check resource availability**:
   ```bash
   docker system info
   ```
   Ensure you have enough memory and CPU allocated to Docker.

4. **Verify driver compatibility**:
   ```bash
   minikube config get driver
   ```
   Try a different driver if needed.

5. **Run with debug output**:
   ```bash
   minikube start --driver=docker --memory=6144 --cpus=4 --alsologtostderr -v=7
   ```

### Resource Constraints

**Symptoms:**
- Pods stuck in "Pending" state
- "Insufficient CPU/memory" errors
- Nodes show high resource usage

**Solutions:**

1. **Check resource usage**:
   ```bash
   kubectl top nodes
   kubectl top pods -A
   ```

2. **Increase Minikube resources**:
   ```bash
   minikube delete
   minikube start --memory=8192 --cpus=4 --disk-size=40g
   ```

3. **Check for resource limits/requests**:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```
   Look for resource requirements that might be too high.

4. **Scale down deployments**:
   ```bash
   kubectl scale deployment <deployment-name> -n <namespace> --replicas=1
   ```

5. **Clean up unused resources**:
   ```bash
   kubectl delete pods --field-selector status.phase=Failed -A
   ```

## GitOps Workflow Issues

### Source Controller Issues

**Symptoms:**
- GitRepository shows "failed to clone"
- Source controller pods not ready
- Missing source artifacts

**Solutions:**

1. **Check source controller logs**:
   ```bash
   kubectl -n flux-system logs -f deployment/source-controller
   ```

2. **Restart source controller**:
   ```bash
   kubectl -n flux-system rollout restart deployment/source-controller
   ```

3. **Verify controller is healthy**:
   ```bash
   kubectl -n flux-system get pods | grep source-controller
   ```

4. **Check artifact storage**:
   ```bash
   kubectl -n flux-system describe gitrepository flux-system
   ```
   Look for artifact storage issues.

5. **Recreate source**:
   ```bash
   flux create source git flux-system \
     --url=https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
     --branch=main \
     --username=${GITHUB_USER} \
     --password=${GITHUB_TOKEN} \
     --namespace=flux-system
   ```

### Kustomize Controller Issues

**Symptoms:**
- Kustomizations stay in "Progressing" state
- "kustomize build failed" errors
- Resources not being applied

**Solutions:**

1. **Check kustomize controller logs**:
   ```bash
   kubectl -n flux-system logs -f deployment/kustomize-controller
   ```

2. **Restart kustomize controller**:
   ```bash
   kubectl -n flux-system rollout restart deployment/kustomize-controller
   ```

3. **Force reconciliation**:
   ```bash
   flux reconcile kustomization <kustomization-name> --with-source
   ```

4. **Check controller is healthy**:
   ```bash
   kubectl -n flux-system get pods | grep kustomize-controller
   ```

5. **Verify kustomization resources**:
   ```bash
   kubectl get kustomizations -A
   ```

## Common Error Messages

### "context deadline exceeded"

**Explanation**: Flux has exceeded the timeout when trying to reconcile resources.

**Solutions**:
1. Increase timeout in kustomization
2. Use component-by-component deployment
3. Check for dependency issues or infinite reconciliation loops

### "failed to clone"

**Explanation**: Flux cannot clone the Git repository.

**Solutions**:
1. Verify GitHub token
2. Check repository exists
3. Ensure correct repository structure
4. Update credentials in flux-system secret

### "kustomize build failed"

**Explanation**: There's an issue with your kustomization files.

**Solutions**:
1. Validate kustomization locally
2. Check for syntax errors
3. Verify paths and references
4. Fix directories and file names

### "No matches for kind X in version Y"

**Explanation**: The CRD for a resource is missing.

**Solutions**:
1. Install missing CRDs
2. Deploy CRDs before resources
3. Check if API version is correct
4. Verify the component that provides the CRD is deployed

## Diagnostic Procedures

### Component Diagnosis

For detailed diagnosis of a specific component:

```bash
./scripts/gitops/diagnose-component.sh <component-name>
```

This runs a comprehensive set of checks and provides recommendations.

### Flux System Diagnosis

To diagnose Flux-specific issues:

```bash
flux check
flux get all
kubectl -n flux-system get events
```

### Full Cluster Diagnosis

For a complete cluster diagnosis:

```bash
# Check all pods
kubectl get pods -A

# Check node status
kubectl describe node minikube

# Check all events
kubectl get events --sort-by='.lastTimestamp'

# Check Flux status
flux get all
```

## Recovery Procedures

### Recovering from Failed Flux Setup

1. Uninstall Flux:
   ```bash
   flux uninstall
   ```

2. Clean up any lingering resources:
   ```bash
   kubectl delete namespace flux-system
   ```

3. Reinstall Flux:
   ```bash
   ./scripts/gitops/component-deploy.sh
   ```

### Recovering from Failed Component Deployment

1. Run the component diagnostic:
   ```bash
   ./scripts/gitops/diagnose-component.sh <component-name>
   ```

2. Check the recommendations from the diagnosis

3. Fix any identified issues

4. Delete the failed component's kustomization:
   ```bash
   kubectl delete kustomization -n flux-system single-<component-name>
   ```

5. Redeploy the component:
   ```bash
   ./scripts/gitops/component-deploy.sh
   ```

### Complete Reset and Restart

If you need to start completely fresh:

1. Delete Minikube:
   ```bash
   minikube delete
   ```

2. Clear the progress file:
   ```bash
   rm -f logs/deployment/deployment-progress.txt
   ```

3. Initialize a new environment:
   ```bash
   ./scripts/setup/init-environment.sh
   ```

4. Deploy components one by one:
   ```bash
   ./scripts/gitops/component-deploy.sh
   ``` 