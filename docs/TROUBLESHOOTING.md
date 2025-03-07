# Troubleshooting Guide

This document provides solutions for common issues encountered when setting up and using the local Kubernetes environment.

## Environment Setup Issues

### Minikube Fails to Start

**Symptoms**:
- Error about insufficient resources
- Docker driver fails to create container

**Solutions**:
1. **Adjust Resource Allocation**:
   ```bash
   # Edit .env file or set environment variables
   export MINIKUBE_MEMORY=4096  # Reduce memory allocation
   export MINIKUBE_CPUS=2       # Reduce CPU allocation
   ./scripts/setup/init-environment.sh
   ```

2. **Check Docker Resources**:
   - In Docker Desktop, go to Settings → Resources
   - Ensure sufficient memory and CPU are allocated to Docker

### Missing Prerequisites

**Symptoms**:
- "Command not found" errors for tools like kubectl, flux, helm

**Solutions**:
1. **Install Missing Tools**:
   ```bash
   # macOS with Homebrew
   brew install kubectl flux helm minikube
   
   # Other platforms - follow official docs
   # kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/
   # flux: https://fluxcd.io/docs/installation/
   # helm: https://helm.sh/docs/intro/install/
   ```

## GitOps Issues

### Flux Not Reconciling

**Symptoms**:
- Components not being deployed
- Error messages in `flux get all` output

**Solutions**:
1. **Check GitHub Credentials**:
   ```bash
   # Verify .env contains correct values
   cat .env | grep GITHUB
   ```

2. **Manual Reconciliation**:
   ```bash
   # Reconcile GitRepository
   flux reconcile source git flux-system
   
   # Reconcile Kustomization
   flux reconcile kustomization flux-system
   flux reconcile kustomization local-core-infra
   ```

3. **Check Repository Structure**:
   - Ensure the GitHub repository structure matches what's expected
   - Check that the branch specified in Flux configuration exists

### GitRepository Missing

**Symptoms**:
- `flux get sources git` shows no GitRepository resources
- Components fail to deploy through Flux

**Solutions**:
1. **Run Setup Flux Script**:
   ```bash
   ./scripts/cluster/setup-flux.sh
   ```

2. **Create GitRepository Manually**:
   ```bash
   # Create secret for repository access
   kubectl -n flux-system create secret generic flux-system \
       --from-literal=username=${GITHUB_USER} \
       --from-literal=password=${GITHUB_TOKEN}
       
   # Create GitRepository
   flux create source git flux-system \
       --url=https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
       --branch=main \
       --username=${GITHUB_USER} \
       --password=${GITHUB_TOKEN} \
       --namespace=flux-system
   ```

## Component Deployment Issues

### Components Not Being Deployed

**Symptoms**:
- Namespaces exist but no pods are running
- Kustomization shows errors in Flux output

**Solutions**:
1. **Check Kustomization Path**:
   ```bash
   # Verify the path in flux-kustomization.yaml
   cat clusters/local/flux-kustomization.yaml
   
   # Ensure path is set to ./clusters/local/infrastructure (not a specific component)
   ```

2. **Check Base References**:
   - Ensure base paths in kustomization files are correct
   - Verify all referenced files exist in the repository

### Verification Shows False Positives

**Symptoms**:
- Verification script reports components as healthy when they're not
- Empty namespaces reported as running correctly

**Solutions**:
1. **Use Manual Verification**:
   ```bash
   # Check actual pod status
   kubectl get pods -A
   
   # Check specific namespaces
   kubectl get pods -n cert-manager
   kubectl get pods -n observability
   ```

2. **Update Verification Script**:
   - Ensure check_component() function properly verifies pod existence
   - Fix any logic issues in the script

## Networking Issues

### Services Not Accessible

**Symptoms**:
- Unable to access services through ingress
- curl to service endpoints fails

**Solutions**:
1. **Check /etc/hosts File**:
   ```bash
   # Get Ingress IP
   INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   
   # Add to /etc/hosts
   echo "${INGRESS_IP} grafana.local prometheus.local vault.local supabase.local" | sudo tee -a /etc/hosts
   ```

2. **Check Ingress Resources**:
   ```bash
   # Verify ingress resources
   kubectl get ingress -A
   
   # Check ingress controller status
   kubectl get pods -n ingress-nginx
   ```

3. **Run Port Forwarding**:
   ```bash
   ./scripts/components/port-forward.sh
   ```

## Log Collection for Troubleshooting

When reporting issues, collect the following information:

```bash
# Get all resources
kubectl get all -A > all-resources.log

# Get Flux status
flux get all > flux-status.log

# Get logs for problematic pods
kubectl logs -n [namespace] [pod-name] > pod-logs.log

# Get events
kubectl get events --sort-by='.lastTimestamp' > events.log
```

## Reset and Start Over

If you encounter persistent issues, sometimes it's best to reset and start fresh:

```bash
# Delete Minikube cluster
minikube delete

# Start from scratch with our enhanced workflow
./scripts/setup/init-environment.sh
./scripts/cluster/setup-all.sh
``` 