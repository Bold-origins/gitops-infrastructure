# Supabase Kubernetes Setup

This directory contains the Kubernetes manifests for deploying Supabase in a GitOps-friendly way.

## Structure

- `helm/values.yaml`: Clean Helm values file referenced by the ConfigMap generator
- `helmrelease.yaml`: Flux HelmRelease that points to the Supabase Helm chart
- `kustomization.yaml`: Kustomize manifest that includes all resources
- `sealed-secrets/`: Contains sealed versions of secrets for GitOps
- `secrets/`: Contains locally generated secrets (not committed to git)

## Secret Management

The setup uses external Kubernetes Secrets that are referenced in the `values.yaml`. This allows:

1. Separation of configuration from sensitive data
2. Using Kubernetes Secrets for sensitive data
3. Sealing secrets for secure GitOps with SealedSecrets

### Generating Secrets

To generate all necessary secrets for Supabase:

```bash
./scripts/generate-supabase-secrets.sh
```

This script will:
1. Generate a JWT secret
2. Create JWT tokens using that secret
3. Generate database credentials
4. Create SMTP, dashboard, and other required secrets
5. Store them in the `clusters/local/infrastructure/supabase/secrets/` directory

### Using Sealed Secrets (GitOps/Production)

For production or GitOps workflows:

1. Generate the secrets as described above using `generate-supabase-secrets.sh`
2. Seal them using kubeseal:

```bash
kubeseal -f clusters/local/infrastructure/supabase/secrets/jwt-secret.yaml -w clusters/local/infrastructure/supabase/sealed-secrets/sealed-jwt-secret.yaml
# Repeat for other secrets
```

3. Ensure the SealedSecrets resources are uncommented in `kustomization.yaml`
4. The plaintext secrets in the `secrets/` directory should not be committed to git

### Using Locally Generated Secrets (Development)

For local development, you can use the generated secrets directly:

1. Edit `kustomization.yaml`
2. Comment out the SealedSecrets resources
3. Uncomment the local secrets resources

## Helm Values

The values for the Supabase Helm chart are stored in `helm/values.yaml` and are used to generate a ConfigMap via Kustomize's `configMapGenerator`. This approach:

1. Keeps the values file in its natural format (not wrapped in a ConfigMap)
2. Allows for easy editing and validation
3. Keeps sensitive data out of the values file (via references to external secrets)

The HelmRelease references this ConfigMap for its values.

## Directory Structure

- `kustomization.yaml`: Main Kustomize configuration for the deployment
- `namespace.yaml`: Defines the Supabase namespace
- `gitrepository.yaml`: Flux GitRepository for the Supabase Helm chart
- `helmrelease.yaml`: Flux HelmRelease for deploying Supabase
- `helm/values.yaml`: Helm values for the Supabase deployment
- `secrets/`: Directory containing Kubernetes Secrets (not tracked in git)
  - `*.yaml`: Individual secret resources
- `sealed-secrets/`: SealedSecret versions for GitOps workflows
  - `sealed-*.yaml`: Sealed versions of the secrets for secure GitOps

## Secret Management

For local development, we use regular Kubernetes Secrets:
- Plaintext secret YAML files in the `secrets/` directory
- Not tracked in Git for security (in .gitignore)
- You'll need to create these secrets manually or use the generate script

For production, we use SealedSecrets:
- Implementations are provided in `sealed-secrets/`
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