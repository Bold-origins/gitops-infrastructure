# GitOps Infrastructure Setup Guide

This guide provides detailed instructions for setting up the complete GitOps infrastructure, including cert-manager, Vault, Sealed Secrets, and OPA Gatekeeper.

## Prerequisites

Before you begin, ensure you have the following tools installed:

- **Minikube**: For local Kubernetes development
  - Installation: https://minikube.sigs.k8s.io/docs/start/
- **kubectl**: For interacting with Kubernetes clusters
  - Installation: https://kubernetes.io/docs/tasks/tools/install-kubectl/
- **helm**: For deploying Helm charts (used by some of our scripts)
  - Installation: https://helm.sh/docs/intro/install/
- **kubeseal**: For working with Sealed Secrets
  - Installation: https://github.com/bitnami-labs/sealed-secrets#kubeseal
- **Vault CLI** (optional): For interacting with HashiCorp Vault
  - Installation: https://www.vaultproject.io/downloads

## Local Development Setup

### Step 1: Start Minikube

Start a local Minikube cluster with sufficient resources:

```bash
minikube start --memory=4096 --cpus=2 --driver=docker
```

Enable the required addons:

```bash
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
```

### Step 2: Configure DNS for Local Development

To access services using domain names, you need to configure your local DNS. Our setup script can do this for you:

```bash
./scripts/setup-minikube.sh
```

This script:
1. Gets the Minikube IP address
2. Updates your /etc/hosts file to add entries for:
   - vault.local
   - example.local
   - and other service domains

Alternatively, you can do this manually:

```bash
echo "$(minikube ip) vault.local example.local" | sudo tee -a /etc/hosts
```

### Step 3: Deploy Infrastructure Components

Apply the infrastructure components in the following order:

#### 1. Deploy cert-manager

```bash
kubectl apply -k clusters/local/infrastructure/cert-manager
```

Wait for cert-manager to be ready:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
```

#### 2. Deploy Sealed Secrets

```bash
kubectl apply -k clusters/local/infrastructure/sealed-secrets
```

Wait for Sealed Secrets to be ready:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets -n sealed-secrets
```

#### 3. Deploy Vault

```bash
kubectl apply -k clusters/local/infrastructure/vault
```

Wait for Vault to be ready:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/vault -n vault
```

Initialize Vault (for development/testing only):

```bash
# Port-forward to Vault
kubectl port-forward svc/vault 8200:8200 -n vault &

# Set environment variables
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root

# Enable Kubernetes authentication
vault auth enable kubernetes

# Configure Kubernetes authentication
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)" \
  issuer="https://kubernetes.default.svc.cluster.local"

# Create a policy for our example application
vault policy write app-policy - <<EOF
path "kv/data/database/*" {
  capabilities = ["read"]
}
EOF

# Create a role for our example application
vault write auth/kubernetes/role/app-role \
  bound_service_account_names=example-app \
  bound_service_account_namespaces=example \
  policies=app-policy \
  ttl=1h

# Enable KV secrets engine
vault secrets enable -version=2 kv

# Create a test secret for our example
vault kv put kv/database/config username="dbuser" password="dbpassword" endpoint="db.example.com:5432"
```

#### 4. Deploy OPA Gatekeeper

```bash
kubectl apply -k clusters/local/infrastructure/gatekeeper
```

Wait for Gatekeeper to be ready:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system
```

#### 5. Deploy Constraint Templates and Constraints

```bash
kubectl apply -k clusters/local/policies/templates
kubectl apply -k clusters/local/policies/constraints
```

### Step 4: Deploy Applications

#### 1. Deploy MinIO (Object Storage)

```bash
kubectl apply -k clusters/local/apps/minio
```

Wait for MinIO to be ready:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/minio -n minio
```

#### 2. Deploy Example Application

```bash
kubectl apply -k clusters/local/apps/example
```

Wait for the example application to be ready:

```bash
kubectl wait --for=condition=available --timeout=300s deployment/example-app -n example
```

### Step 5: Verify the Installation

Run our verification script to ensure everything is working correctly:

```bash
./scripts/verify-environment.sh
```

For more detailed verification steps, see the [Verification Guide](verification-guide.md).

## Working with Sealed Secrets

Sealed Secrets allows you to encrypt your secrets and store them safely in Git.

### Creating a Sealed Secret

1. Create a regular Kubernetes Secret:

```bash
cat <<EOF > mysecret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  namespace: example
type: Opaque
stringData:
  username: admin
  password: t0p-s3cr3t
EOF
```

2. Encrypt it with kubeseal:

```bash
kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets -o yaml < mysecret.yaml > sealed-mysecret.yaml
```

3. Apply the sealed secret:

```bash
kubectl apply -f sealed-mysecret.yaml
```

### Using Sealed Secrets in Deployments

In your deployment, reference the secret as you would a regular Kubernetes secret:

```yaml
env:
  - name: USERNAME
    valueFrom:
      secretKeyRef:
        name: mysecret  # This is the name of the original secret
        key: username
  - name: PASSWORD
    valueFrom:
      secretKeyRef:
        name: mysecret
        key: password
```

## Working with Vault

### Adding a New Secret to Vault

1. Access Vault (either through port-forwarding or using the Vault UI at https://vault.local):

```bash
kubectl port-forward svc/vault 8200:8200 -n vault &
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root  # Only for development!
```

2. Create a new secret:

```bash
vault kv put kv/myapp/config api_key="my-api-key" api_secret="my-api-secret"
```

### Using Vault in Deployments

To use Vault secrets in your deployment, add annotations to your pod template:

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/agent-inject-secret-config.txt: "kv/data/myapp/config"
  vault.hashicorp.com/role: "app-role"
  vault.hashicorp.com/agent-inject-template-config.txt: |
    {{- with secret "kv/data/myapp/config" -}}
    export API_KEY="{{ .Data.data.api_key }}"
    export API_SECRET="{{ .Data.data.api_secret }}"
    {{- end -}}
```

## TLS Certificates with cert-manager

### Creating a Certificate

1. Create a namespace and TLS certificate:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp

---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: myapp
spec:
  secretName: myapp-tls
  issuerRef:
    name: letsencrypt-staging  # Use letsencrypt-prod for production
    kind: ClusterIssuer
  dnsNames:
    - myapp.example.com
```

2. Use the certificate in an Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: myapp
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

## Adding a New Application

To add a new application to the infrastructure:

1. Create a directory for your application:

```bash
mkdir -p clusters/local/apps/myapp/base
```

2. Create the base Kustomization file:

```bash
cat <<EOF > clusters/local/apps/myapp/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- deployment.yaml
- service.yaml
- ingress.yaml
EOF
```

3. Create the necessary resources (namespace, deployment, service, etc.)

4. Add your application to the main Kustomization file:

```bash
# Edit clusters/local/kustomization.yaml
# Add 'apps/myapp' to the resources section
```

5. Apply your changes:

```bash
kubectl apply -k clusters/local/apps/myapp
```

## Production Considerations

For production deployments, consider the following:

1. **Vault**: Use a proper production setup with high availability and proper initialization
2. **Certificates**: Use the `letsencrypt-prod` issuer instead of staging
3. **Resource Requirements**: Adjust resource requests and limits based on your workload
4. **Backups**: Implement backup strategies for Vault and other stateful components
5. **Monitoring**: Add proper monitoring and alerting
6. **GitOps**: Consider using Flux or ArgoCD for continuous deployment from Git

## Troubleshooting

### Common Issues

#### Pods Not Starting

Check the pod status and events:

```bash
kubectl describe pod -n <namespace> <pod-name>
```

#### Certificate Issues

Check cert-manager logs and certificate status:

```bash
kubectl logs -n cert-manager -l app=cert-manager -c cert-manager
kubectl describe certificate -n <namespace> <certificate-name>
```

#### Vault Authentication Issues

Ensure the service account and Vault role are configured correctly:

```bash
kubectl describe sa -n <namespace> <service-account-name>
vault read auth/kubernetes/role/<role-name>
```

### Getting Help

If you encounter issues, check the logs of the relevant components:

```bash
# cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -c cert-manager

# Vault logs
kubectl logs -n vault -l app.kubernetes.io/name=vault

# Sealed Secrets logs
kubectl logs -n sealed-secrets -l name=sealed-secrets-controller

# Gatekeeper logs
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

## Next Steps

After setting up the infrastructure, consider:

1. Adding your own applications
2. Creating custom policy constraints
3. Setting up continuous deployment with GitOps tools
4. Implementing monitoring and logging solutions
5. Adding backup and disaster recovery procedures

For more details on each component, refer to the official documentation:

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [OPA Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/website/docs/) 