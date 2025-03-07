# Common Workflows Cheatsheet

This document provides quick-reference guides for common workflows in this repository.

## Setting Up a Local Development Environment

```bash
# 1. Set up Minikube
./scripts/cluster/setup-minikube.sh

# 2. Set up Flux
./scripts/cluster/setup-flux.sh

# 3. Set up core infrastructure
./scripts/cluster/setup-core-infrastructure.sh

# 4. Set up networking
./scripts/cluster/setup-networking.sh

# 5. Set up observability
./scripts/cluster/setup-observability.sh

# 6. Set up applications
./scripts/cluster/setup-applications.sh

# Alternatively, run all setup scripts in sequence
./scripts/cluster/setup-all.sh

# Verify the environment
./scripts/cluster/verify-environment.sh
```

## Adding a New Application

1. **Create base configuration**:
```bash
mkdir -p clusters/base/applications/new-app/{helm,sealed-secrets}
touch clusters/base/applications/new-app/kustomization.yaml
touch clusters/base/applications/new-app/namespace.yaml
touch clusters/base/applications/new-app/helmrelease.yaml
```

2. **Define base kustomization**:
```yaml
# clusters/base/applications/new-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - helmrelease.yaml
  # Add other resources here
```

3. **Create environment overlay**:
```bash
mkdir -p clusters/local/applications/new-app/{helm,patches,sealed-secrets}
touch clusters/local/applications/new-app/kustomization.yaml
```

4. **Define environment kustomization**:
```yaml
# clusters/local/applications/new-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../base/applications/new-app
patchesStrategicMerge:
  - patches/helmrelease-patch.yaml
  # Add other patches here
```

5. **Update parent kustomization**:
```yaml
# clusters/base/applications/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - supabase
  - new-app  # Add the new app here
```

## Creating a New Sealed Secret

1. **Create a plain secret**:
```bash
kubectl create secret generic my-secret \
  --namespace=my-namespace \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --dry-run=client -o yaml > plain-secret.yaml
```

2. **Seal the secret**:
```bash
cat plain-secret.yaml | kubeseal \
  --controller-name=sealed-secrets \
  --format yaml > sealed-secret.yaml
```

3. **Add the sealed secret to the repository**:
```bash
mv sealed-secret.yaml clusters/local/applications/my-app/sealed-secrets/
```

4. **Update kustomization to include the secret**:
```yaml
# clusters/local/applications/my-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../base/applications/my-app
  - sealed-secrets/sealed-secret.yaml
patchesStrategicMerge:
  # Patches here
```

## Updating a Helm Release

1. **Update the HelmRelease version**:
```yaml
# clusters/base/applications/my-app/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-app
  namespace: my-app
spec:
  chart:
    spec:
      chart: my-chart
      version: "1.2.3"  # Update version here
      sourceRef:
        kind: HelmRepository
        name: my-repo
        namespace: flux-system
```

2. **Update values if needed**:
```yaml
# clusters/base/applications/my-app/helm/values.yaml
# Update values here
```

3. **Commit and push changes**:
```bash
git add .
git commit -m "Update my-app to version 1.2.3"
git push
```

## Testing Changes Locally

1. **Build kustomization locally**:
```bash
kubectl kustomize clusters/local/applications/my-app
```

2. **Apply with dry-run**:
```bash
kubectl kustomize clusters/local/applications/my-app | kubectl apply --dry-run=client -f -
```

3. **Apply changes**:
```bash
kubectl kustomize clusters/local/applications/my-app | kubectl apply -f -
```

## Debugging a Failed Deployment

1. **Check Flux resources**:
```bash
flux get all
flux get kustomizations
flux get helmreleases -A
```

2. **Check resource status**:
```bash
kubectl get all -n my-namespace
kubectl describe pod my-pod -n my-namespace
kubectl logs my-pod -n my-namespace
```

3. **Check events**:
```bash
kubectl get events -n my-namespace --sort-by='.lastTimestamp'
```

## Promoting Changes Between Environments

1. **Test changes in local environment**

2. **Copy successful configurations to staging**:
```bash
cp -r clusters/local/applications/my-app/helm/* clusters/staging/applications/my-app/helm/
cp -r clusters/local/applications/my-app/patches/* clusters/staging/applications/my-app/patches/
```

3. **Re-encrypt secrets for staging**:
```bash
# Get the staging public key
kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=sealed-secrets > staging-pub-cert.pem

# Re-encrypt with staging key
cat plain-secret.yaml | kubeseal --cert staging-pub-cert.pem --format yaml > staging-sealed-secret.yaml

# Move to staging directory
mv staging-sealed-secret.yaml clusters/staging/applications/my-app/sealed-secrets/
```

4. **Commit and push changes**:
```bash
git add .
git commit -m "Promote my-app changes to staging"
git push
```

5. **Repeat for production**