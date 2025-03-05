# Supabase Kubernetes Deployment

This directory contains the Kubernetes manifests for deploying Supabase in a local development environment using Minikube.

## Directory Structure

- `kustomization.yaml`: Main Kustomize configuration for the deployment
- `namespace.yaml`: Defines the Supabase namespace
- `gitrepository.yaml`: Flux GitRepository for the Supabase Helm chart
- `helmrelease.yaml`: Flux HelmRelease for deploying Supabase
- `values.yaml`: Helm values for the Supabase deployment
- `secrets/`: Directory containing Kubernetes Secrets
  - `secrets/*.yaml`: Individual secret resources
- `sealed-secrets/`: Reference implementations for production environments
  - `unused/`: SealedSecret implementations for reference

## Secret Management

For local development, we use regular Kubernetes Secrets that are:
- Clear, directly defined secret files
- Easy to understand and debug
- Integrated through kustomize in a declarative manner

For production, it's recommended to use SealedSecrets which:
- Encrypt sensitive data for secure storage in Git
- Require the SealedSecrets controller in the cluster

## Environment Configuration

The deployment is optimized for Minikube by:
- Reduced resource requests and limits
- Disabled non-essential components
- External MinIO for storage

## Troubleshooting

If you encounter issues with the deployment:

1. Check pod status:
   ```bash
   kubectl get pods -n supabase
   ```

2. Check logs for failing pods:
   ```bash
   kubectl logs <pod-name> -n supabase
   ```

3. Verify secrets have all required keys:
   ```bash
   kubectl get secret <secret-name> -n supabase -o jsonpath='{.data}'
   ```

4. Common issues:
   - Missing secret keys
   - Insufficient resources for pods
   - Network connectivity issues

## Known Issues

- The HelmRelease uses the deprecated v2beta1 API version
- Some components may still reference incorrect secret names

## References

- [Supabase Kubernetes](https://github.com/supabase-community/supabase-kubernetes)
- [Kustomize documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) 