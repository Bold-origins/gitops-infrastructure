# Minikube Setup for GitOps Infrastructure

This guide explains how to set up a local Kubernetes environment using Minikube to develop and test our GitOps infrastructure.

## Prerequisites

Before setting up Minikube, ensure you have the following tools installed:

1. **Docker**: Required as the driver for Minikube
   - [Docker installation guide](https://docs.docker.com/get-docker/)

2. **kubectl**: Command-line tool for interacting with Kubernetes clusters
   - [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

3. **Minikube**: Local Kubernetes environment
   - [Minikube installation guide](https://minikube.sigs.k8s.io/docs/start/)

4. **kubeseal**: For working with Sealed Secrets
   - [kubeseal installation guide](https://github.com/bitnami-labs/sealed-secrets#installation)

5. **Helm**: For working with Helm charts (optional for local development)
   - [Helm installation guide](https://helm.sh/docs/intro/install/)

## Automated Setup

We provide a script to automate the setup process:

```bash
# Make the script executable (if not already)
chmod +x scripts/setup-minikube.sh

# Run the setup script
./scripts/setup-minikube.sh
```

The script performs the following tasks:
- Starts Minikube with appropriate resources
- Enables necessary addons (ingress, metrics-server, dashboard)
- Configures local domain names by updating `/etc/hosts`
- Deploys cert-manager, Vault, and other infrastructure components
- Deploys the example application

## Manual Setup Steps

If you prefer to set up Minikube manually, follow these steps:

### 1. Start Minikube

```bash
minikube start --memory=4096 --cpus=2 --driver=docker \
  --addons=ingress \
  --addons=metrics-server \
  --addons=dashboard \
  --kubernetes-version=v1.25.5
```

### 2. Enable Required Addons

```bash
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable registry
```

### 3. Configure Local Domain Names

```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Add entries to /etc/hosts
echo "
# Minikube domains
$MINIKUBE_IP vault.local
$MINIKUBE_IP example.local
$MINIKUBE_IP prometheus.local
$MINIKUBE_IP grafana.local
$MINIKUBE_IP minio.local
$MINIKUBE_IP alertmanager.local" | sudo tee -a /etc/hosts
```

### 4. Deploy Infrastructure Components

```bash
# Deploy cert-manager
kubectl apply -k clusters/local/infrastructure/cert-manager

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app=cert-manager --timeout=120s -n cert-manager

# Deploy Vault
kubectl apply -k clusters/local/infrastructure/vault

# Deploy policies
kubectl apply -k clusters/local/policies

# Deploy example application
kubectl apply -k clusters/local/apps/example
```

## Testing Your Setup

### Accessing the Kubernetes Dashboard

```bash
# Start the dashboard
minikube dashboard
```

Or

```bash
# Using kubectl proxy
kubectl proxy
# Access the dashboard at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
```

### Accessing Deployed Services

All services are configured with Ingress and TLS. Access them using:

- **Vault**: https://vault.local
- **Example App**: https://example.local
- **Prometheus**: https://prometheus.local (if deployed)
- **Grafana**: https://grafana.local (if deployed)
- **MinIO**: https://minio.local (if deployed)
- **Alertmanager**: https://alertmanager.local (if deployed)

Note: Since we're using self-signed certificates by default, you'll need to accept the certificate warnings in your browser.

## Working with Vault

To interact with Vault in the local environment:

```bash
# Port-forward to Vault
kubectl port-forward svc/vault 8200:8200 -n vault

# Set Vault address and token
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root  # Only in dev mode!

# Test connection
vault status
```

## Working with Sealed Secrets

To create and use Sealed Secrets in your local environment:

```bash
# Create a regular Kubernetes secret
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret \
  -n example --dry-run=client -o yaml > secret.yaml

# Encrypt the secret using kubeseal
kubeseal --controller-namespace=sealed-secrets \
  --controller-name=sealed-secrets \
  --format yaml < secret.yaml > sealed-secret.yaml

# Apply the sealed secret
kubectl apply -f sealed-secret.yaml
```

## Troubleshooting

### Unable to Access Services via Domain Names

If you cannot access services using the configured domain names:

1. Verify that the domain names are correctly added to `/etc/hosts`:
   ```bash
   cat /etc/hosts | grep Minikube
   ```

2. Ensure the Minikube IP is correct:
   ```bash
   minikube ip
   ```

3. Check if the Ingress resources are correctly configured:
   ```bash
   kubectl get ingress --all-namespaces
   ```

### Certificate Issues

If you're experiencing certificate-related issues:

1. Check the status of certificates:
   ```bash
   kubectl get certificates --all-namespaces
   ```

2. Check cert-manager logs:
   ```bash
   kubectl logs -n cert-manager -l app=cert-manager
   ```

### Pod Startup Issues

If pods are not starting correctly:

1. Check pod status:
   ```bash
   kubectl get pods --all-namespaces
   ```

2. Check detailed pod information:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

3. Check pod logs:
   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```

## Clean Up

To clean up your Minikube environment:

```bash
# Stop Minikube
minikube stop

# Delete the Minikube cluster
minikube delete
```

## Best Practices for Local Development

1. **Resource Allocation**: Adjust Minikube's memory and CPU based on your machine's capabilities
2. **Local Image Development**: Use Minikube's Docker daemon for building images
   ```bash
   eval $(minikube docker-env)
   ```
3. **Namespace Isolation**: Keep your development components in separate namespaces
4. **Port Forwarding**: Use `kubectl port-forward` to access services without Ingress
5. **Configuration Validation**: Use `kubectl apply --dry-run=client` to validate configurations 