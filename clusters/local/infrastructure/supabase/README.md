# Supabase Kubernetes Deployment

This directory contains the Kubernetes manifests for deploying Supabase in a local development environment using Minikube.

## Directory Structure

- `kustomization.yaml`: Main Kustomize configuration for the deployment
- `namespace.yaml`: Defines the Supabase namespace
- `gitrepository.yaml`: Flux GitRepository for the Supabase Helm chart
- `helmrelease.yaml`: Flux HelmRelease for deploying Supabase
- `values.yaml`: Helm values for the Supabase deployment
- `secrets/`: Directory containing Kubernetes Secrets (not tracked in git)
  - `secrets/*.yaml`: Individual secret resources
- `sealed-secrets/`: Reference implementations for production environments
  - `unused/`: SealedSecret implementations for reference

## Secret Management

For local development, we use regular Kubernetes Secrets:
- Direct secret YAML files in the `secrets/secrets/` directory
- Not tracked in Git for security (in .gitignore)
- You'll need to create these secrets manually when setting up a new environment

For production, it's recommended to use SealedSecrets:
- Reference implementations are provided in `sealed-secrets/unused/`
- Encrypts sensitive data for secure storage in Git
- Requires the SealedSecrets controller in the cluster

## Required Secrets

The following secrets need to be created for Supabase to function:

- `supabase-db`: Database credentials
- `supabase-jwt`: JWT authentication tokens
- `supabase-smtp`: Email service credentials
- `supabase-dashboard`: Admin dashboard credentials
- `supabase-analytics`: Analytics service credentials
- `supabase-s3`: Object storage credentials

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

3. Verify secrets exist with required fields:
   ```bash
   kubectl get secrets -n supabase
   kubectl get secret <secret-name> -n supabase -o jsonpath='{.data}'
   ```

4. Common issues:
   - Missing secrets or secret fields
   - Incorrect secret names in values.yaml
   - Insufficient resources for pods

## Setting Up a New Environment

For a new environment, you'll need to:

1. Create the required secrets manually:
   ```bash
   # Example for creating a basic secret
   kubectl create secret generic supabase-db \
     --namespace supabase \
     --from-literal=username=postgres \
     --from-literal=password=postgres \
     --from-literal=database=postgres \
     --from-literal=password_encoded=postgres
   ```

2. Or restore from SealedSecrets (for production):
   ```bash
   # Apply the SealedSecrets from the sealed-secrets directory
   kubectl apply -f sealed-secrets/sealed-*.yaml
   ```

## References

- [Supabase Kubernetes](https://github.com/supabase-community/supabase-kubernetes)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets)
- [Kustomize documentation](https://kubectl.docs.kubernetes.io/references/kustomize/) 