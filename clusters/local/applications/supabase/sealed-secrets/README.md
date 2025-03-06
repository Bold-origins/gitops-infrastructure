# SealedSecrets for Supabase

This directory contains **encrypted template SealedSecrets** for Supabase deployment. These files serve as reference implementations for production environments, while local development uses regular Kubernetes Secrets from the `../secrets/` directory.

## Local Development vs Production

Our configuration uses two parallel approaches:

1. **Local Development**: Uses direct, unencrypted Kubernetes Secrets from `../secrets/secrets/` directory
2. **Production Environments**: Uses SealedSecrets from this directory that are decrypted by the SealedSecrets controller

The current Supabase deployment is configured to use the direct secrets approach through the main `kustomization.yaml` file.

## Available SealedSecrets

This directory contains template SealedSecrets for all necessary Supabase credentials:

| Filename | Secret Name | Purpose |
|----------|-------------|---------|
| `sealed-jwt-secret.yaml` | `supabase-jwt` | JWT authentication secrets |
| `sealed-db-secret.yaml` | `supabase-db` | Database credentials |
| `sealed-dashboard-secret.yaml` | `supabase-dashboard` | Dashboard admin credentials |
| `sealed-smtp-secret.yaml` | `supabase-smtp` | SMTP email service credentials |
| `sealed-analytics-secret.yaml` | `supabase-analytics` | Analytics API key |
| `sealed-s3-secret.yaml` | `supabase-s3` | S3/MinIO connectivity secrets |

## Important Notes

1. **Name Consistency**: The secret name in the SealedSecret's template metadata **must match** the name referenced in the ConfigMap (`values.yaml`). For example, if `values.yaml` references `supabase-jwt`, the SealedSecret's template name must be `supabase-jwt` (not `supabase-jwt-secret`).

2. **Field Consistency**: The secret fields inside both direct secrets and SealedSecrets must use identical field names (e.g., `jwt_secret`, `anonKey`, `password`, etc.).

3. **Backup Directory**: The `backup/` directory contains previous versions of SealedSecrets before field name corrections were applied. These are kept for reference only.

## Using SealedSecrets in Production

To use SealedSecrets in a production environment:

1. Install the SealedSecrets controller in your cluster
2. Update the main `kustomization.yaml` to reference these SealedSecrets instead of using the `secrets/` directory
3. Ensure all required fields are properly defined in each SealedSecret

## Creating New SealedSecrets

```bash
# Create a regular secret YAML file with your data (do not commit this to Git)
kubectl create secret generic my-secret --from-literal=key1=value1 --dry-run=client -o yaml > my-secret.yaml

# Encrypt it with kubeseal
kubeseal --format yaml < my-secret.yaml > sealed-my-secret.yaml

# Delete the regular secret file for security
rm my-secret.yaml

# Now you can safely commit sealed-my-secret.yaml to Git
```

## References

- [SealedSecrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [SealedSecrets Documentation](https://github.com/bitnami-labs/sealed-secrets#overview) 