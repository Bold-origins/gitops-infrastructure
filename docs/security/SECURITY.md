# Security Practices

This document outlines the security practices implemented in this GitOps infrastructure.

## Credentials Management

All sensitive information such as credentials, tokens, and passwords are managed using one of the following methods:

### 1. Sealed Secrets

We use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to encrypt sensitive information that needs to be stored in Git. This allows us to:

- Store encrypted credentials safely in Git
- Automatically decrypt secrets when deployed to the cluster
- Maintain GitOps practices without compromising security

Example usage:
```bash
# Create a regular Kubernetes Secret
kubectl create secret generic mysecret --dry-run=client --from-literal=username=admin --from-literal=password=supersecret -o yaml > secret.yaml

# Encrypt the Secret using kubeseal
kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets < secret.yaml > sealed-secret.yaml

# Apply the SealedSecret to the cluster
kubectl apply -f sealed-secret.yaml
```

### 2. HashiCorp Vault

For highly sensitive secrets and dynamic credentials:

- Vault is used for managing database credentials, API keys, and other sensitive information
- Applications authenticate to Vault using Kubernetes Service Accounts
- Credentials are delivered securely to applications at runtime
- Vault enables credential rotation without application downtime

### 3. Local Environment Variables

For local development and non-committed configurations:

- A `.env` file is used to store local configuration and credentials
- This file is explicitly excluded from Git via `.gitignore`
- Sensitive information like Vault tokens and unseal keys are stored here

## Credentials Storage Locations

- **Sealed Secrets**: Located in `clusters/*/infrastructure/*/sealed-secrets/` directories
- **Vault Scripts**: Located in `scripts/` directory
- **Local Environment**: `.env` file in the root directory (never committed to Git)
- **Documentation**: Centralized in this `SECURITY.md` file

## Reset and Initialization

Scripts are provided to initialize and reset sensitive components:

- `scripts/initialize_vault.sh`: Initializes Vault and saves credentials locally
- `scripts/reset_vault.sh`: Resets Vault for development purposes

## Best Practices

1. **Never commit plaintext secrets to Git**
2. **Always use SealedSecrets for Kubernetes Secrets**
3. **Use Vault for dynamic credentials and highly sensitive information**
4. **Keep the `.env` file secure and never commit it**
5. **Regularly rotate credentials**
6. **Use specific versions (never 'latest') for security-critical components**
7. **Implement least-privilege RBAC for all components** 