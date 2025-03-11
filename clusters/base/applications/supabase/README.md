# Supabase GitOps Deployment

This directory contains the base configuration for deploying Supabase across different environments using GitOps principles.

## Architecture

The deployment follows a scalable, multi-environment pattern:

- **Base Configuration**: Common settings shared across all environments
- **Environment-Specific Overrides**: Values specific to each environment (local, staging, production)
- **Centralized Versioning**: Component versions are defined in a single file
- **Declarative Secret Management**: SealedSecrets with consistent key structure

## Key Files

- `versions.yaml`: The single source of truth for component versions
- `helm/values.yaml`: Base configuration for the Helm chart
- `gitrepository.yaml`: Points to the Supabase Kubernetes community chart
- `helmrelease.yaml`: Defines how the Helm chart is deployed

## Components

Supabase consists of several components:

1. **Postgres**: Database that stores all Supabase data
2. **Auth (GoTrue)**: Authentication and authorization service
3. **REST (PostgREST)**: RESTful API for Postgres
4. **Meta**: Postgres metadata service
5. **Storage**: File storage service
6. **Studio**: Admin dashboard
7. **Kong**: API Gateway
8. **Functions** (optional): Edge functions runtime
9. **Realtime** (optional): Realtime subscriptions
10. **Analytics** (optional): Usage analytics
11. **Vector** (optional): Log collection

## Configuration Structure

```
clusters/
├── base/
│   └── applications/
│       └── supabase/                 # Base configuration
│           ├── versions.yaml         # Centralized version definitions
│           ├── helm/
│           │   └── values.yaml       # Base values
│           ├── helmrelease.yaml      # HelmRelease definition
│           └── gitrepository.yaml    # Reference to chart repository
├── local/
│   └── applications/
│       └── supabase/                 # Local environment config
│           ├── helm/
│           │   └── values.yaml       # Local overrides
│           ├── kustomization.yaml    # Kustomize definition
│           ├── transformers/         # Transformers for variables
│           │   └── versions.yaml     # Versions transformer
│           ├── patches/              # Patches for resources
│           │   └── helmrelease-patch.yaml
│           └── sealed-secrets/       # Sealed secrets
│               ├── jwt-secret.yaml   # JWT authentication
│               ├── smtp-secret.yaml  # SMTP credentials
│               ├── etc...
└── [staging/production similar to local]
```

## JWT Secret Structure

The JWT secret must use the following key structure:

```yaml
stringData:
  anonKey: "..."    # JWT for anonymous access
  serviceKey: "..." # JWT for service role access
  secret: "..."     # The actual JWT secret key
```

**IMPORTANT**: The key `secret` (not `jwtSecret`) must be used for compatibility with all components.

## Adding a New Environment

To add a new environment (e.g., staging):

1. Create the directory structure: `clusters/staging/applications/supabase/`
2. Copy the kustomization.yaml from local as a template
3. Create environment-specific values in `helm/values.yaml`
4. Generate sealed secrets: `./scripts/gitops/generate-jwt-secret.sh staging`
5. Validate the configuration: `./scripts/gitops/validate-supabase-config.sh`

## Updating Component Versions

To update component versions:

1. Edit `clusters/base/applications/supabase/versions.yaml`
2. Run validation: `./scripts/gitops/validate-supabase-config.sh`
3. Deploy using normal GitOps workflow

## Troubleshooting

Common issues:

1. **Secret key structure mismatch**: Ensure JWT secret uses the key `secret` not `jwtSecret`
2. **Image pull failures**: Check versions in `versions.yaml` for compatibility
3. **SMTP configuration**: Auth service requires numeric port as a string (e.g., "587")

For detailed logs: `kubectl logs -n supabase <pod-name>` 