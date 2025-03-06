# Local Kubernetes Cluster

A complete GitOps-based local Kubernetes environment with pre-configured infrastructure components, monitoring, and observability. This repo provides everything you need to run a production-like Kubernetes environment locally for development and testing.

## Features

- **Complete Infrastructure Stack**: Includes essential components like cert-manager, Sealed Secrets, Vault, and OPA Gatekeeper
- **Monitoring & Observability**: Pre-configured Prometheus, Grafana, and alerting
- **GitOps Ready**: Structured for declarative configuration management
- **Security First**: Built with security best practices including policy enforcement
- **Easy Setup**: Simple scripts to get you running quickly

## Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/docs/start/) v1.30+
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) v1.28+
- [Helm](https://helm.sh/docs/intro/install/) v3.12+
- [kubeseal](https://github.com/bitnami-labs/sealed-secrets#installation)
- [Vault CLI](https://developer.hashicorp.com/vault/downloads) (optional)
- At least 4GB of available memory and 2 CPUs for Minikube

## Quick Start

1. **Clone this repository**
   ```bash
   git clone https://github.com/yourusername/cluster.git
   cd cluster
   ```

2. **Set up your local Minikube cluster**
   ```bash
   ./scripts/setup-minikube.sh
   ```
   This script will:
   - Start Minikube with appropriate resources
   - Enable necessary addons
   - Configure local domain mappings
   - Deploy core infrastructure components

3. **Verify the environment**
   ```bash
   ./scripts/verify-environment.sh
   ```

4. **Access the web interfaces**
   Visit the following URLs in your browser:
   - Vault: https://vault.local
   - Prometheus: https://prometheus.local
   - Grafana: https://grafana.local
   - MinIO: https://minio.local
   - Alertmanager: https://alertmanager.local

   Note: You'll need to accept the self-signed certificate warnings

## Architecture

This local cluster implements a multi-tier architecture:

- **Infrastructure Layer**: Core components that provide platform capabilities
  - cert-manager: Certificate management
  - Sealed Secrets: Secret encryption
  - Vault: Secrets management
  - OPA Gatekeeper: Policy enforcement
  
- **Monitoring Layer**: Observability and alerting
  - Prometheus: Metrics collection and alerting
  - Grafana: Visualization and dashboards
  - Alertmanager: Alert routing
  
- **Applications Layer**: Example applications showing how to use the infrastructure

## Directory Structure

```
.
├── charts/                      # Helm charts
├── clusters/                    # Cluster configurations
│   ├── local/                   # Local development cluster
│   │   ├── flux-system/         # Flux GitOps configuration
│   │   ├── infrastructure/      # Core infrastructure components
│   │   ├── monitoring/          # Monitoring stack
│   │   ├── observability/       # Observability tools
│   │   └── policies/            # OPA Gatekeeper policies
│   └── vps/                     # VPS deployment configuration
├── diagnostics/                 # Diagnostic tools and outputs
├── docs/                        # Documentation
│   ├── architecture/            # Architecture diagrams and details
│   ├── guides/                  # Setup and usage guides
│   │   ├── minikube-setup.md    # Minikube setup guide
│   │   ├── setup-guide.md       # Complete setup guide
│   │   └── verification-guide.md # Verification procedures
│   ├── reference/               # Reference documentation
│   ├── security/                # Security documentation
│   └── troubleshooting/         # Troubleshooting guides
├── scripts/                     # Utility scripts
│   ├── cluster-management/      # Cluster management scripts
│   ├── connectivity/            # Network and connectivity scripts
│   ├── diagnostics/             # Diagnostic scripts
│   ├── setup-minikube.sh        # Minikube setup script
│   └── verify-environment.sh    # Environment verification script
└── sealed-secrets-backup/       # Backup location for sealed secrets
```

## Component Details

### Core Infrastructure

- **cert-manager**: Automates certificate management within the cluster
- **Sealed Secrets**: Allows storing encrypted secrets in Git
- **Vault**: Advanced secrets management and dynamic credentials
- **OPA Gatekeeper**: Policy-based control and security guardrails

### Monitoring & Observability

- **Prometheus**: Metrics collection, storage, and alerting
- **Grafana**: Data visualization with pre-configured dashboards
- **Alertmanager**: Alert management and notification routing

## Common Tasks

### Reset Vault

If you need to reset Vault to its initial state:

```bash
./scripts/reset_vault.sh
```

### Check Cluster Health

Run a comprehensive check of the cluster:

```bash
./scripts/check_cluster.sh
```

### Setup Observability

Deploy or update the observability stack:

```bash
./scripts/setup-observability.sh
```

## Accessing Web Interfaces

See [docs/guides/UI-ACCESS-README.md](docs/guides/UI-ACCESS-README.md) for detailed information on accessing the web interfaces for different components.

## Troubleshooting

If you encounter issues, check the following:

1. **Check pod status**:
   ```bash
   kubectl get pods --all-namespaces
   ```

2. **View logs for a specific component**:
   ```bash
   kubectl logs -n <namespace> <pod-name>
   ```

3. **Restart Minikube if needed**:
   ```bash
   minikube stop
   minikube start
   ```

4. **Consult troubleshooting guides**:
   See [docs/troubleshooting/](docs/troubleshooting/) for specific component issues.

## Extending the Cluster

The cluster is designed to be extensible. To add a new component:

1. Create a directory under the appropriate section in `clusters/local/`
2. Add your Kubernetes manifests or Kustomize configurations
3. Update the main `kustomization.yaml` to include your new component

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 