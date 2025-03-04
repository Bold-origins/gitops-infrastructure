# Example Application for Secret Management

This example application demonstrates how to use HashiCorp Vault and Sealed Secrets together in a Kubernetes environment, with TLS encryption provided by cert-manager.

## Components

This example includes the following components:

1. **Namespace** - A dedicated namespace for the example application
2. **Deployment** - An example deployment that consumes secrets from both Vault and Sealed Secrets
3. **Service** - A simple service exposing the example application
4. **Service Account** - A service account for the example application to authenticate with Vault
5. **Sealed Secret** - A demonstration of how to use Sealed Secrets for GitOps-friendly secret management
6. **Vault Secret Example** - An example of how to use Vault with an External Secrets Operator pattern
7. **Network Policy** - A network policy that restricts communication to/from the application
8. **Ingress** - An ingress resource with TLS enabled via cert-manager

## How It Works

### Vault Integration

The deployment uses Vault annotations to inject secrets into the container:

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "example"
  vault.hashicorp.com/agent-inject-secret-database-config.txt: "kv/data/database/config"
  vault.hashicorp.com/agent-inject-template-database-config.txt: |
    {{- with secret "kv/data/database/config" -}}
    export DB_USERNAME={{ .Data.data.username }}
    export DB_PASSWORD={{ .Data.data.password }}
    {{- end -}}
```

This causes Vault to:
1. Authenticate the pod using its service account
2. Fetch the requested secret
3. Format it according to the template
4. Mount it into the pod at `/vault/secrets/database-config.txt`

### Sealed Secrets Integration

The deployment also references a Sealed Secret:

```yaml
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: example-sealed-secret
        key: api-key
```

In a real environment:
1. The SealedSecret would be encrypted using `kubeseal`
2. The encrypted version would be committed to Git
3. The Sealed Secrets controller would decrypt it in the cluster
4. The deployment would access it like a regular Kubernetes secret

### TLS Configuration

The application is exposed securely via HTTPS using cert-manager for certificate management:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-app-ingress
  annotations:
    cert-manager.io/cluster-issuer: "selfsigned-cluster-issuer"
spec:
  tls:
  - hosts:
    - example.local
    secretName: example-tls
  # ... more configuration
```

This configuration:
1. Uses cert-manager to automatically issue a certificate for the domain
2. Creates a TLS secret containing the certificate and key
3. Configures the ingress to use HTTPS with the issued certificate

## Network Security

A NetworkPolicy restricts the communication to and from this application:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-app-network-policy
spec:
  # ... configuration details
```

This policy:
1. Restricts incoming traffic to only allowed sources
2. Limits outgoing traffic to only necessary services (Vault, DNS, K8s API)
3. Enforces the principle of least privilege for network communication

## Testing the Example

To see this working in your cluster:

1. Set up Minikube (if testing locally):
   ```bash
   ./scripts/setup-minikube.sh
   ```

2. Create a secret in Vault:
   ```bash
   kubectl port-forward svc/vault 8200:8200 -n vault
   export VAULT_ADDR=http://localhost:8200
   export VAULT_TOKEN=root  # Only in dev mode!
   vault kv put kv/database/config username=db_user password=db_pass
   ```

3. Create an actual sealed secret (instead of the placeholder):
   ```bash
   kubectl create secret generic example-secret --from-literal=api-key=12345 --from-literal=api-secret=abcdef -n example --dry-run=client -o yaml > temp-secret.yaml
   kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets -o yaml < temp-secret.yaml > real-sealed-secret.yaml
   # Replace the placeholder sealed-secret.yaml with real-sealed-secret.yaml
   ```

4. Apply the kustomization:
   ```bash
   kubectl apply -k clusters/local/apps/example/base
   ```

5. Access the application via HTTPS:
   ```bash
   # Add to /etc/hosts if using Minikube
   echo "$(minikube ip) example.local" | sudo tee -a /etc/hosts

   # Open in browser (accept self-signed certificate warning)
   open https://example.local
   ```

6. Check if it's working:
   ```bash
   kubectl logs -n example deployment/example-app
   ```

You should see output confirming that the application can access both the Vault secrets and the Sealed Secret.

## Notes

- This is a demonstration example only, not suitable for production use without modifications
- In a real environment, you would need to configure proper Vault policies and roles
- The service account would need appropriate RBAC permissions
- For production, use Let's Encrypt certificates instead of self-signed certificates 