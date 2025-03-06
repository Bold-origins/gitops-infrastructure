# Supabase Sealed Secrets

This directory contains templates for sealed secrets that should be created for each environment.
Actual sealed secrets should be generated for each environment using the appropriate public key.

## Template Files

The following template files are provided to show the structure needed for each sealed secret:

- `template-jwt-secret.yaml` - JWT secrets AND API keys (contains anonKey, serviceKey, jwtSecret)
- `template-db-secret.yaml` - Database credentials
- `template-dashboard-secret.yaml` - Dashboard credentials
- `template-s3-secret.yaml` - S3 storage configuration
- `template-analytics-secret.yaml` - Analytics configuration
- `template-smtp-secret.yaml` - SMTP configuration for emails

These templates are aligned with the structure expected by the Helm chart as defined in `values.yaml`.
They are placeholders only and don't contain actual secrets. When implementing
environment-specific overlays, these templates should be used as references to create proper
sealed secrets for each environment.

## Secret Generation Process

For each environment (local, staging, production), you need to:

1. Create a plain secret with the actual values
2. Use kubeseal to encrypt it with the environment-specific public key
3. Store the resulting sealed secret in the appropriate environment directory

Example for JWT/API secret:
```bash
# Create a plain secret YAML file with actual values (do not commit this)
cat > secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: supabase-jwt
  namespace: supabase
type: Opaque
data:
  anonKey: $(echo -n "your-anon-key" | base64)
  serviceKey: $(echo -n "your-service-key" | base64)
  jwtSecret: $(echo -n "your-jwt-secret" | base64)
EOF

# Seal the secret with the environment's public key
kubeseal --format yaml --cert [environment-pubkey.pem] < secret.yaml > sealed-jwt-secret.yaml

# Securely delete the plain secret
rm secret.yaml
```

Refer to the local environment for examples of these secrets. 