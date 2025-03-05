# SealedSecrets (Reference Only)

This directory contains reference implementations of SealedSecrets for production environments. For local development, we use regular Kubernetes Secrets with strategic merge patches (in the `../secrets/` directory).

## Purpose

SealedSecrets allow for storing encrypted secrets in Git that can only be decrypted by the SealedSecrets controller running in the Kubernetes cluster. This is ideal for production environments where secrets should be encrypted in source control.

## Structure

- `unused/`: Contains all SealedSecret implementations
  - `sealed-jwt-secret.yaml`: JWT authentication secrets 
  - `sealed-db-secret.yaml`: Database credentials
  - `sealed-dashboard-secret.yaml`: Dashboard admin credentials
  - `sealed-smtp-secret.yaml`: SMTP email service credentials
  - `sealed-analytics-secret.yaml`: Analytics secrets
  - `sealed-s3-secret.yaml`: S3/MinIO connectivity secrets

## How to Create SealedSecrets

For production environments, you'll need to:

1. Install the SealedSecrets controller in your cluster
2. Create new SealedSecrets for your sensitive information

```bash
# Create a regular secret YAML file with your data (do not commit this to Git)
kubectl create secret generic my-secret --from-literal=key1=value1 --dry-run=client -o yaml > my-secret.yaml

# Encrypt it with kubeseal
kubeseal --format yaml < my-secret.yaml > sealed-my-secret.yaml

# Delete the regular secret file for security
rm my-secret.yaml

# Now you can safely commit sealed-my-secret.yaml to Git
```

## Migrating from Local Development to Production

To use SealedSecrets in production:

1. Create new SealedSecrets using the process above
2. Update the main `kustomization.yaml` to reference these SealedSecrets instead of the `secrets/` directory
3. Remove the `patches` section that modifies these secrets

## References

- [SealedSecrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [SealedSecrets Documentation](https://github.com/bitnami-labs/sealed-secrets#overview) 