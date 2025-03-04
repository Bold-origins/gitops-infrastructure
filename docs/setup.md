# Setup Guide

This guide provides detailed instructions for setting up the Kubernetes GitOps cluster from scratch.

## Prerequisites

Ensure you have the following tools installed on your local machine:

- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Flux CLI](https://fluxcd.io/docs/installation/)
- [kubeseal](https://github.com/bitnami-labs/sealed-secrets#installation)
- Git

## 1. Minikube Setup

### Installation

Follow the [official documentation](https://minikube.sigs.k8s.io/docs/start/) to install Minikube for your operating system.

### Initialize Cluster

Start a new Minikube cluster with sufficient resources:

```bash
minikube start --memory=8g --cpus=4 --driver=docker
```

### Enable Required Addons

```bash
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable registry
```

## 2. Flux Installation and Bootstrap

### Install Flux CLI

Follow the [official Flux documentation](https://fluxcd.io/docs/installation/) to install the Flux CLI.

### Bootstrap Flux with GitHub

Create a personal access token on GitHub with `repo` permissions, then:

```bash
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>
export GITHUB_REPO=<repository-name>

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/local \
  --personal
```

This will:
- Create the repository if it doesn't exist
- Generate deploy keys and add them to the repo
- Commit the Flux system components to the repository
- Deploy Flux to your cluster

## 3. Infrastructure Components Setup

### MetalLB

Create the MetalLB configuration:

```bash
cat << EOF > clusters/local/infrastructure/metallb/metallb-config.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: metallb
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/local/infrastructure/metallb/base
  prune: true
  wait: true
EOF

mkdir -p clusters/local/infrastructure/metallb/base

cat << EOF > clusters/local/infrastructure/metallb/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: metallb-system
resources:
  - namespace.yaml
  - release.yaml
  - ipaddresspool.yaml
EOF

cat << EOF > clusters/local/infrastructure/metallb/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
EOF

cat << EOF > clusters/local/infrastructure/metallb/base/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: metallb
  namespace: metallb-system
spec:
  interval: 5m
  chart:
    spec:
      chart: metallb
      version: "0.13.x"
      sourceRef:
        kind: HelmRepository
        name: metallb
        namespace: flux-system
  values:
    crds:
      enabled: true
EOF

cat << EOF > clusters/local/infrastructure/metallb/base/ipaddresspool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.49.240-192.168.49.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF

cat << EOF > clusters/local/infrastructure/metallb/metallb-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: metallb
  namespace: flux-system
spec:
  interval: 1h
  url: https://metallb.github.io/metallb
EOF
```

### NGINX Ingress Controller

```bash
cat << EOF > clusters/local/infrastructure/ingress/ingress-nginx-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ingress-nginx
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/local/infrastructure/ingress/base
  prune: true
  wait: true
EOF

mkdir -p clusters/local/infrastructure/ingress/base

cat << EOF > clusters/local/infrastructure/ingress/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ingress-nginx
resources:
  - namespace.yaml
  - release.yaml
EOF

cat << EOF > clusters/local/infrastructure/ingress/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
EOF

cat << EOF > clusters/local/infrastructure/ingress/base/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  interval: 5m
  chart:
    spec:
      chart: ingress-nginx
      version: "4.4.x"
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx
        namespace: flux-system
  values:
    controller:
      service:
        type: LoadBalancer
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
EOF

cat << EOF > clusters/local/infrastructure/ingress/ingress-nginx-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: ingress-nginx
  namespace: flux-system
spec:
  interval: 1h
  url: https://kubernetes.github.io/ingress-nginx
EOF
```

### Sealed Secrets

```bash
cat << EOF > clusters/local/infrastructure/sealed-secrets/sealed-secrets-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: sealed-secrets
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/local/infrastructure/sealed-secrets/base
  prune: true
  wait: true
EOF

mkdir -p clusters/local/infrastructure/sealed-secrets/base

cat << EOF > clusters/local/infrastructure/sealed-secrets/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: sealed-secrets
resources:
  - namespace.yaml
  - release.yaml
EOF

cat << EOF > clusters/local/infrastructure/sealed-secrets/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: sealed-secrets
EOF

cat << EOF > clusters/local/infrastructure/sealed-secrets/base/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: sealed-secrets
  namespace: sealed-secrets
spec:
  interval: 5m
  chart:
    spec:
      chart: sealed-secrets
      version: "2.8.x"
      sourceRef:
        kind: HelmRepository
        name: sealed-secrets
        namespace: flux-system
  values:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF

cat << EOF > clusters/local/infrastructure/sealed-secrets/sealed-secrets-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: sealed-secrets
  namespace: flux-system
spec:
  interval: 1h
  url: https://bitnami-labs.github.io/sealed-secrets
EOF
```

### Cert-Manager

```bash
cat << EOF > clusters/local/infrastructure/cert-manager/cert-manager-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cert-manager
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/local/infrastructure/cert-manager/base
  prune: true
  wait: true
EOF

mkdir -p clusters/local/infrastructure/cert-manager/base

cat << EOF > clusters/local/infrastructure/cert-manager/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: cert-manager
resources:
  - namespace.yaml
  - release.yaml
  - cluster-issuer.yaml
EOF

cat << EOF > clusters/local/infrastructure/cert-manager/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
EOF

cat << EOF > clusters/local/infrastructure/cert-manager/base/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  interval: 5m
  chart:
    spec:
      chart: cert-manager
      version: "v1.11.x"
      sourceRef:
        kind: HelmRepository
        name: jetstack
        namespace: flux-system
  values:
    installCRDs: true
    prometheus:
      enabled: true
      servicemonitor:
        enabled: true
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
EOF

cat << EOF > clusters/local/infrastructure/cert-manager/base/cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
EOF

cat << EOF > clusters/local/infrastructure/cert-manager/cert-manager-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: jetstack
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.jetstack.io
EOF
```

## 4. Observability Stack Setup

### Prometheus and Grafana

```bash
cat << EOF > clusters/local/observability/prometheus/prometheus-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: prometheus
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/local/observability/prometheus/base
  prune: true
  wait: true
EOF

mkdir -p clusters/local/observability/prometheus/base

cat << EOF > clusters/local/observability/prometheus/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: observability
resources:
  - namespace.yaml
  - release.yaml
EOF

cat << EOF > clusters/local/observability/prometheus/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: observability
EOF

cat << EOF > clusters/local/observability/prometheus/base/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus-stack
  namespace: observability
spec:
  interval: 5m
  chart:
    spec:
      chart: kube-prometheus-stack
      version: "44.x.x"
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
  values:
    prometheus:
      prometheusSpec:
        retention: 7d
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
    grafana:
      adminPassword: admin
      persistence:
        enabled: true
        size: 5Gi
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
    alertmanager:
      alertmanagerSpec:
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
EOF

cat << EOF > clusters/local/observability/prometheus/prometheus-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts
EOF
```

### Loki Stack

```bash
cat << EOF > clusters/local/observability/loki/loki-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: loki
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/local/observability/loki/base
  prune: true
  wait: true
EOF

mkdir -p clusters/local/observability/loki/base

cat << EOF > clusters/local/observability/loki/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: observability
resources:
  - release.yaml
EOF

cat << EOF > clusters/local/observability/loki/base/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: loki-stack
  namespace: observability
spec:
  interval: 5m
  chart:
    spec:
      chart: loki-stack
      version: "2.9.x"
      sourceRef:
        kind: HelmRepository
        name: grafana
        namespace: flux-system
  values:
    loki:
      persistence:
        enabled: true
        size: 10Gi
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
    promtail:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
EOF

cat << EOF > clusters/local/observability/loki/loki-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: grafana
  namespace: flux-system
spec:
  interval: 1h
  url: https://grafana.github.io/helm-charts
EOF
```

### OpenTelemetry

```bash
cat << EOF > clusters/local/observability/opentelemetry/opentelemetry-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: opentelemetry
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/local/observability/opentelemetry/base
  prune: true
  wait: true
EOF

mkdir -p clusters/local/observability/opentelemetry/base

cat << EOF > clusters/local/observability/opentelemetry/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: observability
resources:
  - release.yaml
EOF

cat << EOF > clusters/local/observability/opentelemetry/base/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: opentelemetry-collector
  namespace: observability
spec:
  interval: 5m
  chart:
    spec:
      chart: opentelemetry-collector
      version: "0.47.x"
      sourceRef:
        kind: HelmRepository
        name: open-telemetry
        namespace: flux-system
  values:
    mode: daemonset
    config:
      receivers:
        otlp:
          protocols:
            grpc:
            http:
      processors:
        batch:
          timeout: 10s
      exporters:
        prometheus:
          endpoint: 0.0.0.0:8889
        logging:
          verbosity: detailed
      service:
        pipelines:
          metrics:
            receivers: [otlp]
            processors: [batch]
            exporters: [prometheus, logging]
          traces:
            receivers: [otlp]
            processors: [batch]
            exporters: [logging]
EOF

cat << EOF > clusters/local/observability/opentelemetry/opentelemetry-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: open-telemetry
  namespace: flux-system
spec:
  interval: 1h
  url: https://open-telemetry.github.io/opentelemetry-helm-charts
EOF
```

## 5. Security Setup

### Network Policies

```bash
cat << EOF > clusters/local/infrastructure/security/security-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: security
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/local/infrastructure/security/base
  prune: true
  wait: true
EOF

mkdir -p clusters/local/infrastructure/security/base

cat << EOF > clusters/local/infrastructure/security/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - default-network-policy.yaml
EOF

cat << EOF > clusters/local/infrastructure/security/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security
EOF

cat << EOF > clusters/local/infrastructure/security/base/default-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
EOF
```

## 6. Creating Sealed Secrets

After the cluster is up and running, you can create sealed secrets as follows:

```bash
# Create a regular secret file
cat << EOF > regular-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
type: Opaque
data:
  username: $(echo -n "admin" | base64)
  password: $(echo -n "supersecret" | base64)
EOF

# Convert it to a sealed secret
kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets -o yaml < regular-secret.yaml > sealed-secret.yaml

# Delete the regular secret file (it contains sensitive data)
rm regular-secret.yaml

# Apply the sealed secret
kubectl apply -f sealed-secret.yaml
```

## 7. Verification

After completing the setup, verify all components are running correctly:

```bash
# Check all namespaces and pods
kubectl get pods --all-namespaces

# Verify Flux is running
flux check

# Check all Helm releases
flux get helmreleases --all-namespaces

# Check all Kustomizations
flux get kustomizations --all-namespaces
```

## 8. Accessing Services

- **Grafana**: Get the IP address with `kubectl -n observability get svc prometheus-stack-grafana`
- **Prometheus**: Access via Grafana
- **Alert Manager**: Access via Grafana 