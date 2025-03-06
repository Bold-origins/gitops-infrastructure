# Cluster GitOps Framework

A comprehensive GitOps-based framework for managing Kubernetes clusters across **local development**, **staging**, and **production** environments.

## 🚀 Overview

This repository utilizes **GitOps** to maintain consistency across environments, enabling clear promotion paths for changes. The framework includes:

- Multi-environment configurations (Local, Staging, Production)
- Infrastructure-as-Code for Kubernetes components
- Automated deployment workflows
- Monitoring, observability, and security best practices (Sealed Secrets, Vault, OPA Gatekeeper)

The **Local Kubernetes Cluster** provides developers with an environment closely resembling production, including infrastructure and observability tools, directly on their machines.

## 🏗️ Repository Structure

```
clusters/               # Kubernetes manifests
├── local/              # Local environment overlays
├── staging/            # Staging overlays (planned)
├── production/         # Production overlays (planned)
├── base/               # Shared base configurations (planned)

charts/                 # Helm charts
└── example-app/        # Example application chart

scripts/                # Automation scripts
├── cluster-management/ # Cluster management tools
├── connectivity/       # Port-forwarding and connectivity scripts
├── diagnostics/        # Troubleshooting scripts
├── setup-minikube.sh   # Local setup script
├── verify-environment.sh # Environment validation
└── README.md           # Scripts documentation

conext/                 # Project documentation
├── APP_FLOW_DOCUMENT.md      # User journeys
├── PROGRESS_DOCUMENT.md      # Status and roadmap
├── PROJECT_REQUIREMENTS_DOCUMENT.md # Requirements
└── TECH_STACK_DOCUMENT.md    # Technical stack

.env                    # Environment variables
```

## 🛠️ Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) **v1.30+**
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) **v1.28+**
- [Helm](https://helm.sh/docs/intro/install/) **v3.12+**
- [Flux CLI](https://fluxcd.io/docs/installation/)

### System Requirements

- **Minimum**: 4GB RAM, 2 CPUs, 20GB disk space
- **Recommended**: 8GB RAM, 4 CPUs, 40GB SSD

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/cluster.git
cd cluster
```

### 2. Set Up Minikube Environment

```bash
chmod +x scripts/setup-minikube.sh
./scripts/setup-minikube.sh
```

Customize resources by editing the script if needed.

### 3. Verify Environment

```bash
chmod +x scripts/verify-environment.sh
./scripts/verify-environment.sh
```

Ensures Minikube and key resources are properly configured.

### 4. Bootstrap Flux (Optional)

```bash
flux bootstrap github \
  --owner=yourusername \
  --repository=cluster \
  --branch=main \
  --path=clusters/local
```

Update parameters (`--owner`, `--repository`, `--branch`) as necessary.

### 5. Access Local Services

Forward local cluster services:

```bash
./scripts/connectivity/port-forward.sh
```

## 🌐 Accessing Web Interfaces

- **Kubernetes Dashboard**: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
- **Vault**: https://vault.local
- **Prometheus**: https://prometheus.local
- **Grafana**: https://grafana.local
- **MinIO**: https://minio.local
- **Alertmanager**: https://alertmanager.local

> **Note**: For `.local` addresses, add entries to `/etc/hosts` or configure local DNS.

## 🌐 Environment Architecture

| Environment            | Purpose                              | Infrastructure             | Domain Pattern          |
| ---------------------- | ------------------------------------ | -------------------------- | ----------------------- |
| Local                  | Feature development & testing        | Minikube                   | `*.local`               |
| Staging _(Planned)_    | Integration & pre-production testing | K3s on VPS                 | `*.staging.example.com` |
| Production _(Planned)_ | Live environment for end users       | Kubernetes on VPS or cloud | `*.example.com`         |

## 🔄 Development Workflow

1. **Local Development**: Develop and test locally, validate with `verify-environment.sh`.
2. **Code Review**: PR to `develop`, automated tests, and review.
3. **Staging**: Automated deployment to staging upon merging to `develop`.
4. **Production**: Final testing, then merge to `main` for production deployment.

## 🚦 Project Status

**Current Status**: **Development Phase**

### Completed

- Core Infrastructure (Minikube, Vault, OPA Gatekeeper, Ingress-Nginx, MetalLB, MinIO)
- Monitoring & Observability (Prometheus, Grafana, Alertmanager, Loki, Basic OpenTelemetry)
- Automation Scripts (`setup-minikube.sh`, `verify-environment.sh`, Vault management)

### In-Progress & Planned

- Supabase integration
- Enhanced OPA policies
- Advanced observability dashboards
- CI/CD integration

## 🔧 Utility Scripts

- **setup-minikube.sh**: Configure Minikube.
- **verify-environment.sh**: Validate setup.
- **check_cluster.sh**: Diagnose cluster issues.
- **Vault scripts**: Manage Vault setup/reset.

Detailed instructions in [`scripts/README.md`](scripts/README.md).

## 🔐 Security

- **Sealed Secrets**: Encrypt secrets in Git.
- **HashiCorp Vault**: Advanced secret management.
- **OPA Gatekeeper**: Policy enforcement.
- **RBAC**: Granular Kubernetes permissions.

## 📊 Monitoring & Observability

- **Prometheus**: Metrics and alerts.
- **Grafana**: Visual dashboards.
- **Alertmanager**: Alert routing.
- **Loki**: Centralized logging.
- **OpenTelemetry**: Distributed tracing.

## 📚 Additional Documentation

- [Deployment_Workflow_Plan.md](Deployment_Workflow_Plan.md)
- [APP_FLOW_DOCUMENT.md](conext/APP_FLOW_DOCUMENT.md)
- [PROGRESS_DOCUMENT.md](conext/PROGRESS_DOCUMENT.md)
- [PROJECT_REQUIREMENTS_DOCUMENT.md](conext/PROJECT_REQUIREMENTS_DOCUMENT.md)
- [TECH_STACK_DOCUMENT.md](conext/TECH_STACK_DOCUMENT.md)

## 🤝 Contributing

1. **Fork** the repo.
2. Create a **feature branch** (`feature/your-feature`).
3. Commit and push changes.
4. Open a PR against `develop`.

## 📄 License

Licensed under **MIT License**. See [LICENSE](LICENSE).

## 🔍 Troubleshooting

- **Minikube not starting**: Check Docker or Hypervisor settings.
- **Flux not reconciling**: Run `flux reconcile`.
- **Logs**: Use `kubectl logs -n <namespace> <pod>` or Loki interface.

---

Feel free to adapt these improvements to best suit your project's specifics!
