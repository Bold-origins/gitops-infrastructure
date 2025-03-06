# Tech Stack Document

This document provides a comprehensive overview of all technical components, dependencies, and resources used in the Local Kubernetes Cluster project.

## Core Technologies

### Kubernetes (v1.28+)

Kubernetes is the foundation of this project, providing container orchestration capabilities.

- **Installation**: Via Minikube v1.30+
- **Documentation**: [Kubernetes Docs](https://kubernetes.io/docs/home/)
- **API Reference**: [Kubernetes API](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/)

### Minikube (v1.30+)

Local Kubernetes implementation for development environments.

- **Installation**: `brew install minikube` (macOS) or download from [Minikube website](https://minikube.sigs.k8s.io/docs/start/)
- **Documentation**: [Minikube Docs](https://minikube.sigs.k8s.io/docs/)
- **Resource Requirements**: 4GB RAM, 2 CPUs minimum

### Helm (v3.12+)

Package manager for Kubernetes that simplifies application deployment.

- **Installation**: `brew install helm` (macOS)
- **Documentation**: [Helm Docs](https://helm.sh/docs/)
- **Commands Reference**: [Helm Commands](https://helm.sh/docs/helm/helm/)

### Kubectl (v1.28+)

Command-line tool for interacting with Kubernetes clusters.

- **Installation**: `brew install kubectl` (macOS)
- **Documentation**: [Kubectl Docs](https://kubernetes.io/docs/reference/kubectl/)
- **Cheat Sheet**: [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

### Kustomize

Configuration management tool for Kubernetes resources.

- **Installation**: Included with kubectl v1.14+
- **Documentation**: [Kustomize Docs](https://kustomize.io/)
- **GitHub Repository**: [Kustomize GitHub](https://github.com/kubernetes-sigs/kustomize)

## Infrastructure Components

### Cert-Manager (v1.12+)

Automates certificate management within Kubernetes.

- **Helm Chart**: [cert-manager/cert-manager](https://artifacthub.io/packages/helm/cert-manager/cert-manager)
- **Documentation**: [Cert-Manager Docs](https://cert-manager.io/docs/)
- **API Reference**: [Cert-Manager API](https://cert-manager.io/docs/reference/api-docs/)

### Sealed Secrets

Allows storing encrypted Kubernetes secrets in Git.

- **Installation**: [kubeseal CLI](https://github.com/bitnami-labs/sealed-secrets#installation)
- **Documentation**: [Sealed Secrets Docs](https://github.com/bitnami-labs/sealed-secrets)
- **Architecture**: [Sealed Secrets Design](https://github.com/bitnami-labs/sealed-secrets/blob/main/docs/GKE.md)

### HashiCorp Vault (v1.13+)

Advanced secrets management platform.

- **Helm Chart**: [hashicorp/vault](https://artifacthub.io/packages/helm/hashicorp/vault)
- **Documentation**: [Vault Docs](https://developer.hashicorp.com/vault/docs)
- **API Reference**: [Vault API](https://developer.hashicorp.com/vault/api-docs)
- **CLI Reference**: [Vault CLI](https://developer.hashicorp.com/vault/docs/commands)

### OPA Gatekeeper (v3.11+)

Policy enforcement for Kubernetes.

- **Helm Chart**: [gatekeeper/gatekeeper](https://artifacthub.io/packages/helm/gatekeeper/gatekeeper)
- **Documentation**: [Gatekeeper Docs](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- **Policy Library**: [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library)

### Ingress-Nginx

Kubernetes ingress controller based on NGINX.

- **Helm Chart**: [ingress-nginx/ingress-nginx](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx)
- **Documentation**: [Ingress-Nginx Docs](https://kubernetes.github.io/ingress-nginx/)
- **Configuration Guide**: [Ingress-Nginx Configuration](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/)

### MetalLB

Load balancer implementation for bare-metal Kubernetes clusters.

- **Helm Chart**: [metallb/metallb](https://artifacthub.io/packages/helm/metallb/metallb)
- **Documentation**: [MetalLB Docs](https://metallb.universe.tf/)
- **Configuration Guide**: [MetalLB Configuration](https://metallb.universe.tf/configuration/)

### MinIO

S3-compatible object storage for Kubernetes.

- **Helm Chart**: [minio/minio](https://artifacthub.io/packages/helm/minio/minio)
- **Documentation**: [MinIO Docs](https://min.io/docs/minio/kubernetes/upstream/)
- **API Reference**: [MinIO API](https://min.io/docs/minio/linux/developers/java/API.html)

### Supabase

Open source Firebase alternative.

- **Documentation**: [Supabase Docs](https://supabase.com/docs)
- **API Reference**: [Supabase API](https://supabase.com/docs/reference)
- **Client Libraries**: [Supabase Client Libraries](https://supabase.com/docs/reference/javascript/installing)

## Monitoring & Observability Stack

### Prometheus (v2.45+)

Metrics collection, storage, and alerting system.

- **Helm Chart**: [prometheus-community/prometheus](https://artifacthub.io/packages/helm/prometheus-community/prometheus)
- **Documentation**: [Prometheus Docs](https://prometheus.io/docs/introduction/overview/)
- **Query Language**: [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- **API Reference**: [Prometheus API](https://prometheus.io/docs/prometheus/latest/querying/api/)

### Grafana (v10.0+)

Visualization and dashboards for metrics.

- **Helm Chart**: [grafana/grafana](https://artifacthub.io/packages/helm/grafana/grafana)
- **Documentation**: [Grafana Docs](https://grafana.com/docs/grafana/latest/)
- **Dashboard Reference**: [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- **API Reference**: [Grafana API](https://grafana.com/docs/grafana/latest/developers/http_api/)

### Alertmanager

Alert management and routing for Prometheus.

- **Helm Chart**: Included with Prometheus
- **Documentation**: [Alertmanager Docs](https://prometheus.io/docs/alerting/latest/alertmanager/)
- **Configuration Reference**: [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)

### Loki

Log aggregation system designed for Kubernetes.

- **Helm Chart**: [grafana/loki](https://artifacthub.io/packages/helm/grafana/loki)
- **Documentation**: [Loki Docs](https://grafana.com/docs/loki/latest/)
- **Query Language**: [LogQL](https://grafana.com/docs/loki/latest/logql/)

### OpenTelemetry

Observability framework for trace collection.

- **Helm Chart**: [open-telemetry/opentelemetry-collector](https://artifacthub.io/packages/helm/open-telemetry/opentelemetry-collector)
- **Documentation**: [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- **Components**: [Collector](https://opentelemetry.io/docs/collector/), [SDK](https://opentelemetry.io/docs/instrumentation/)

## Development Tools

### Docker

Container runtime required for Minikube.

- **Installation**: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Documentation**: [Docker Docs](https://docs.docker.com/)

### Bash Scripts

The project includes several bash scripts for automation:

- `setup-minikube.sh`: Initial cluster setup
- `verify-environment.sh`: Validates the environment
- `reset_vault.sh`: Resets Vault to initial state
- `check_cluster.sh`: Checks cluster health
- `setup-observability.sh`: Configures observability stack

## Configuration Files

### Kustomization Files

- `kustomization.yaml`: Base configuration for components
- `monitoring-kustomization.yaml`: Monitoring stack configuration
- `ingress-kustomization.yaml`: Ingress controller configuration
- `flux-kustomization.yaml`: Flux GitOps configuration

### Environment Variables

- `.env`: Contains configuration parameters and secrets

## API References

### Kubernetes API

- **Base URL**: `https://kubernetes.default.svc`
- **Documentation**: [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- **OpenAPI Spec**: Available at `/openapi/v2` endpoint within the cluster

### Prometheus API

- **Base URL**: `https://prometheus.local/api/v1`
- **Documentation**: [Prometheus HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/)
- **Key Endpoints**:
  - `/query`: Execute instant query
  - `/query_range`: Execute range query
  - `/series`: Find time series

### Vault API

- **Base URL**: `https://vault.local/v1`
- **Documentation**: [Vault HTTP API](https://developer.hashicorp.com/vault/api-docs)
- **Key Endpoints**:
  - `/sys/health`: Check Vault health
  - `/auth/token/lookup-self`: Validate token
  - `/secret/data/{path}`: Access KV secrets

### MinIO API

- **Base URL**: `https://minio.local`
- **S3 Compatibility**: Compatible with AWS S3 API
- **Documentation**: [MinIO S3 Gateway](https://min.io/docs/minio/kubernetes/upstream/administration/s3-gateway.html)

### Supabase API

- **Documentation**: [Supabase API Reference](https://supabase.com/docs/reference)
- **Client Integration**: [JavaScript Client](https://supabase.com/docs/reference/javascript)

## Package Dependencies

### Backend Dependencies

Required for scripts and server-side components:

- bash (for scripts)
- jq (JSON processing)
- curl (API requests)
- openssl (certificate operations)

### Client Tools

Required for interacting with the cluster:

- kubectl (v1.28+)
- helm (v3.12+)
- kubeseal
- vault CLI (optional)

## System Requirements

### Minimum Requirements

- 4GB RAM
- 2 CPUs
- 20GB disk space
- Docker or similar container runtime
- Linux, macOS, or Windows with WSL

### Recommended Requirements

- 8GB RAM
- 4 CPUs
- 40GB SSD
- macOS or Linux for native container support

## Additional Resources

### Learning Resources

- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [CNCF Landscape](https://landscape.cncf.io/)
- [GitOps Principles](https://www.gitops.tech/)

### Community Support

- [Kubernetes Slack](https://kubernetes.slack.com/)
- [CNCF Community](https://community.cncf.io/)
- [Stack Overflow - Kubernetes](https://stackoverflow.com/questions/tagged/kubernetes)
