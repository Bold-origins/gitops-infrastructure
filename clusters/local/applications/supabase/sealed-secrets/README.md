# SealedSecrets for Supabase

This directory contains **encrypted template SealedSecrets** for Supabase deployment. These files serve as reference implementations for production environments, while local development uses regular Kubernetes Secrets from the `../secrets/` directory.

## Local Development vs Production

Our configuration uses two parallel approaches:

1. **Local Development**: Uses direct, unencrypted Kubernetes Secrets from `../secrets/secrets/` directory
2. **Production Environments**: Uses SealedSecrets from this directory that are decrypted by the SealedSecrets controller

The current Supabase deployment is configured to use the direct secrets approach through the main `kustomization.yaml` file.

## Available SealedSecrets

This directory contains template SealedSecrets for all necessary Supabase credentials:

| Filename                       | Secret Name          | Purpose                        |
| ------------------------------ | -------------------- | ------------------------------ |
| `sealed-jwt-secret.yaml`       | `supabase-jwt`       | JWT authentication secrets     |
| `sealed-db-secret.yaml`        | `supabase-db`        | Database credentials           |
| `sealed-dashboard-secret.yaml` | `supabase-dashboard` | Dashboard admin credentials    |
| `sealed-smtp-secret.yaml`      | `supabase-smtp`      | SMTP email service credentials |
| `sealed-analytics-secret.yaml` | `supabase-analytics` | Analytics API key              |
| `sealed-s3-secret.yaml`        | `supabase-s3`        | S3/MinIO connectivity secrets  |

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

# Supabase Secrets for Local Development

## Local Development Approach

For local development, we're using regular Kubernetes secrets instead of sealed secrets. This makes it easier to work with secrets during development and testing.

The actual secret files are stored in the `clusters/local/applications/supabase/secrets/` directory, which includes:

- analytics-secret.yaml
- db-secret.yaml
- jwt-secret.yaml
- s3-secret.yaml
- dashboard-secret.yaml
- smtp-secret.yaml

## Switching to Sealed Secrets

In non-local environments (staging, production), you would use sealed secrets instead. To create sealed secrets for these environments:

1. Start with the template files from the base configuration:

   ```
   clusters/base/applications/supabase/sealed-secrets/template-*.yaml
   ```

2. Create actual secret files with your real credentials

3. Use kubeseal to encrypt them:

   ```bash
   # Example for encrypting a db secret
   kubeseal --format yaml < my-real-db-secret.yaml > sealed-db-secret.yaml
   ```

4. Store the sealed secrets in the sealed-secrets directory of the appropriate environment

5. Update the kustomization.yaml file to reference these sealed secrets instead of plain secrets

## Differences between Local and Other Environments

| Environment | Secret Type              | Purpose                          |
| ----------- | ------------------------ | -------------------------------- |
| Local       | Plain Kubernetes Secrets | Development, ease of use         |
| Staging     | Sealed Secrets           | Testing in a secured environment |
| Production  | Sealed Secrets           | Secure production deployment     |

## Important Security Note

NEVER commit actual production secrets to Git, even in the local environment. The secrets provided in the local directory contain only dummy values suitable for development.

For more information on sealed secrets and the template approach, see the README in the base directory:
`clusters/base/applications/supabase/sealed-secrets/README.md`
