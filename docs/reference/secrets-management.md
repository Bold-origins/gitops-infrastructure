# Secrets Management in the GitOps Cluster

This document explains how secrets are managed in our Kubernetes GitOps cluster using HashiCorp Vault and Sealed Secrets.

## Overview

Our cluster implements a dual approach to secrets management:

1. **HashiCorp Vault**: For runtime secrets management, dynamic secrets generation, and sensitive data that should never be committed to Git
2. **Sealed Secrets**: For GitOps-friendly encryption of secrets that need to be stored in Git and deployed via the GitOps pipeline

## HashiCorp Vault

### Architecture

In our cluster, Vault is deployed with the following configuration:

- **Mode**: Dev mode for simplicity (in production, use HA mode)
- **Authentication**: Kubernetes auth method enabled
- **Secret Engines**: KV v2 for static secrets
- **Injector**: Vault Agent Injector for seamless pod integration

### Use Cases

Vault is ideal for:

- Dynamic secrets (database credentials, API tokens)
- Sensitive information that requires rotation
- Secrets that should never be stored in Git
- Runtime-only secrets

### How to Use Vault

#### Directly with the Vault CLI

Access the Vault UI:
```bash
# Port-forward to Vault UI
kubectl port-forward svc/vault 8200:8200 -n vault

# Open in browser
open http://localhost:8200
```

Or use the CLI:
```bash
# Set Vault address
export VAULT_ADDR=http://localhost:8200

# Use root token (only in dev mode!)
export VAULT_TOKEN=root

# Read a secret
vault kv get kv/database/config
```

#### In Kubernetes Pods

Use Vault Agent Injector (as configured in our example):

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "app-role"
  vault.hashicorp.com/agent-inject-secret-database-config.txt: "kv/data/database/config"
  vault.hashicorp.com/agent-inject-template-database-config.txt: |
    {{- with secret "kv/data/database/config" -}}
    export DB_USERNAME={{ .Data.data.username }}
    export DB_PASSWORD={{ .Data.data.password }}
    {{- end -}}
```

## Sealed Secrets

### Architecture

Sealed Secrets uses asymmetric encryption:
- The controller in the cluster has the private key
- Developers encrypt with the public key
- Only the controller can decrypt, and only in the designated cluster

### Use Cases

Sealed Secrets are ideal for:

- Configuration that needs to be in Git
- Secrets that are part of your application deployment
- Non-sensitive enough to be in Git in encrypted form

### How to Use Sealed Secrets

1. Install the `kubeseal` CLI
2. Create a regular Kubernetes secret
3. Encrypt it with kubeseal
4. Commit the encrypted version to Git

```bash
# Create a regular secret
cat <<EOF > mysecret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: example
type: Opaque
data:
  username: $(echo -n "admin" | base64)
  password: $(echo -n "supersecret" | base64)
EOF

# Encrypt it
kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets -o yaml < mysecret.yaml > sealed-mysecret.yaml

# Apply the sealed secret
kubectl apply -f sealed-mysecret.yaml
```

## Integration Between Vault and Sealed Secrets

Both systems can work together in your GitOps workflow:

1. **Sealed Secrets**: Used for secrets that must be committed to Git
2. **Vault**: Used for more sensitive data, dynamic secrets, and secrets that require rotation

### When to Use Each

Use **Sealed Secrets** when:
- The secret is part of your GitOps deployment
- You need secret versioning in Git
- The data is appropriate to store in Git (when encrypted)

Use **Vault** when:
- The secret is highly sensitive
- The secret requires rotation
- You need dynamic secrets
- You need advanced policy control

## Example Application

See `clusters/local/apps/example` for a demonstration of using both technologies together.

## Best Practices

1. **Never** store unencrypted secrets in Git
2. Rotate Sealed Secrets controller key periodically
3. Use appropriate Vault policies to limit access
4. For production, disable Vault's dev mode and use HA configuration
5. Always use the least privilege principle for service accounts
6. Consider implementing an External Secrets Operator for better integration 