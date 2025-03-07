# Testing the Fixes

Follow these steps to test the fixes we've implemented:

## 1. Reset the Environment

Start with a clean slate:

```bash
# Delete the minikube cluster
minikube delete

# Start minikube with appropriate resources
export MINIKUBE_MEMORY=6144
export MINIKUBE_CPUS=4
export MINIKUBE_DISK_SIZE=20g
export MINIKUBE_DRIVER=docker
minikube start --memory=${MINIKUBE_MEMORY} --cpus=${MINIKUBE_CPUS} --disk-size=${MINIKUBE_DISK_SIZE} --driver=${MINIKUBE_DRIVER}
```

## 2. Run the Setup Script

```bash
# Make sure the environment variables are loaded from .env
source .env

# Run the setup script
./scripts/cluster/setup-all.sh
```

## 3. Verify the Environment

### Check Flux resources:

```bash
# Check GitRepository
kubectl get gitrepository -A

# Check Kustomizations
kubectl get kustomization -A

# Check Flux reconciliation status
flux get all
```

### Check component deployments:

```bash
# Check all pods
kubectl get pods -A

# Run the verification script
./scripts/cluster/verify-environment.sh
```

## 4. Test Component Functionality

### Access the services:

```bash
# Get the Ingress IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Add entries to /etc/hosts file
echo "${INGRESS_IP} grafana.local prometheus.local vault.local supabase.local" | sudo tee -a /etc/hosts

# Test service endpoints
curl -k https://grafana.local
curl -k https://prometheus.local
curl -k https://vault.local
curl -k https://supabase.local
```

## 5. Documentation Update

- Update README with any additional steps or troubleshooting tips
- Document the issues that were fixed for future reference
- Create a troubleshooting guide for common issues 