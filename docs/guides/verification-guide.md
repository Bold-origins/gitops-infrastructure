# GitOps Infrastructure Verification Guide

This guide provides step-by-step instructions for manually verifying that your GitOps infrastructure is working correctly. It covers all key components, including cert-manager, Vault, Sealed Secrets, and the example application.

## Automated Verification

For quick verification, run our automated verification script:

```bash
./scripts/verify-environment.sh
```

This script checks all components and provides a detailed report. For a deeper understanding or troubleshooting, follow the manual verification steps below.

## Manual Verification Steps

### 1. Verify Minikube Setup

First, check that Minikube is running with the correct configuration:

```bash
# Check Minikube status
minikube status

# Check Minikube IP
minikube ip

# Check enabled addons
minikube addons list
```

Ensure that the following addons are enabled:

- ingress
- metrics-server
- dashboard

### 2. Verify Core Infrastructure Components

#### cert-manager

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Verify that all pods are in Running state with 1/1 containers ready

# Check ClusterIssuers
kubectl get clusterissuers

# You should see the following issuers:
# - selfsigned-cluster-issuer
# - letsencrypt-staging
# - letsencrypt-prod

# Check issuer details
kubectl describe clusterissuer selfsigned-cluster-issuer
kubectl describe clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-prod
```

#### Vault

```bash
# Check Vault pods
kubectl get pods -n vault

# Verify that the pods are in Running state

# Check Vault services
kubectl get svc -n vault

# Check Vault ingress
kubectl get ingress -n vault

# Access Vault UI (after adding entry to /etc/hosts)
# Open in browser: https://vault.local
```

#### OPA Gatekeeper

```bash
# Check Gatekeeper pods
kubectl get pods -n gatekeeper-system

# Check ConstraintTemplates
kubectl get constrainttemplates

# Check Constraints (specific to your configuration)
kubectl get constraints --all-namespaces
```

### 3. Verify Example Application

```bash
# Check example namespace
kubectl get namespace example

# Check all resources in example namespace
kubectl get all -n example

# Check the deployment
kubectl describe deployment -n example example-app

# Check the pod
kubectl get pods -n example

# Check if the pod is running and ready
kubectl describe pod -n example $(kubectl get pods -n example -o jsonpath='{.items[0].metadata.name}')

# Check logs to ensure application is working correctly
kubectl logs -n example deployment/example-app

# Check service
kubectl get svc -n example

# Check sealed secret
kubectl get sealedsecret -n example

# Check ingress
kubectl get ingress -n example

# Check certificates
kubectl get certificate -n example
```

### 4. Verify TLS Certificates

```bash
# List all certificates
kubectl get certificates --all-namespaces

# Check the status of specific certificates
kubectl describe certificate -n example example-tls

# Verify that certificates are in Ready state
```

### 5. Test End-to-End Functionality

#### Test Vault Integration

```bash
# Port-forward to Vault
kubectl port-forward svc/vault 8200:8200 -n vault

# In another terminal, set Vault address and token
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root  # Only for dev mode

# Create a test secret
vault kv put kv/test/secret username=testuser password=testpassword

# Verify that the secret was created
vault kv get kv/test/secret

# Check if the example app can access secrets from Vault
kubectl logs -n example deployment/example-app | grep "Connected to database"
```

#### Test Sealed Secrets

```bash
# Create a test secret
cat <<EOF > test-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: test-secret
  namespace: example
type: Opaque
stringData:
  username: admin
  password: supersecret
EOF

# Encrypt it with kubeseal
kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets -o yaml < test-secret.yaml > test-sealed-secret.yaml

# Apply the sealed secret
kubectl apply -f test-sealed-secret.yaml

# Verify that the secret was created and decrypted
kubectl get secret -n example test-secret
```

#### Test Ingress with TLS

```bash
# Check that DNS resolution works for the local domains
# Add entries to /etc/hosts if necessary:
# <minikube-ip> vault.local example.local

# Test HTTPS access to example app
curl -k https://example.local

# Test HTTPS access to Vault
curl -k https://vault.local
```

### 6. Verify Network Policies

```bash
# Check network policies
kubectl get networkpolicy -n example

# Test network policy by attempting to access from unauthorized pods
# (This is more complex and requires creating test pods in different namespaces)
```

## Troubleshooting Common Issues

### Certificate Issues

If certificates are not issued correctly:

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -c cert-manager

# Check certificate events
kubectl describe certificate -n example example-tls
```

### Pod Startup Issues

If pods are not starting or are crashing:

```bash
# Check pod status and events
kubectl describe pod -n <namespace> <pod-name>

# Check container logs
kubectl logs -n <namespace> <pod-name> -c <container-name>
```

### Vault Authentication Issues

If the application can't authenticate with Vault:

```bash
# Check Vault authentication status
kubectl exec -it -n example $(kubectl get pods -n example -o jsonpath='{.items[0].metadata.name}') -- cat /vault/secrets/database-config.txt

# Check Vault logs
kubectl logs -n vault $(kubectl get pods -n vault -o jsonpath='{.items[0].metadata.name}') -c vault

# Verify Kubernetes auth configuration in Vault
vault auth list
vault read auth/kubernetes/config
vault read auth/kubernetes/role/app-role
```

### Ingress Issues

If ingress resources are not working:

```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress status
kubectl describe ingress -n example example-app-ingress
```

## Next Steps

After verifying that all components are working correctly, you can:

1. Deploy your own applications using the same patterns
2. Customize policies to match your security requirements
3. Set up additional monitoring and logging
4. Configure automated deployments with GitOps tools like Flux or ArgoCD

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [OPA Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/website/docs/)
