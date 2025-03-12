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
│   ├── applications/   # Application deployments (Supabase, etc.)
│   ├── infrastructure/ # Core infrastructure components
│   ├── observability/  # Monitoring and logging stack
│   └── policies/       # Security policies and governance
├── base/               # Shared base configurations
└── staging/            # Staging overlays (planned)
└── production/         # Production overlays (planned)

charts/                 # Helm charts
└── example-app/        # Example application chart

scripts/                # Automation scripts
├── cluster/           # Cluster management tools
├── components/        # Component installation/management
├── gitops/            # GitOps workflow automation
├── promotion/         # Environment promotion scripts
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
- [kubeseal](https://github.com/bitnami-labs/sealed-secrets#installation) (for working with SealedSecrets)

### System Requirements

- **Minimum**: 4GB RAM, 2 CPUs, 20GB disk space
- **Recommended**: 8GB RAM, 4 CPUs, 40GB SSD

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/cluster.git
cd cluster
```

### 2. Initialize Environment

Use our streamlined setup script to initialize your local development environment:

```bash
chmod +x scripts/setup/init-environment.sh
./scripts/setup/init-environment.sh
```

This script will:
- Load environment variables from `.env`
- Set up Minikube with proper resources
- Enable required addons
- Verify prerequisites

### 3. Deploy Components (Recommended Approach)

For a more controlled, component-by-component deployment:

```bash
./scripts/gitops/component-deploy.sh
```

This approach provides better visibility and control over the deployment process by:
- Deploying components one at a time
- Verifying each component before proceeding
- Providing detailed logs and status information
- Tracking progress to allow resuming

### 4. Monitor Deployment Progress

Check the status of your deployment at any time:

```bash
./scripts/gitops/show-progress.sh
```

### 5. Troubleshoot Issues

If you encounter problems with specific components:

```bash
./scripts/gitops/diagnose-component.sh <component-name>
```

### 6. Access Services

Forward local cluster services:

```bash
./scripts/components/port-forward.sh
```

## 🌐 Accessing Web Interfaces

- **Kubernetes Dashboard**: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
- **Vault**: https://vault.local
- **Prometheus**: https://prometheus.local
- **Grafana**: https://grafana.local
- **MinIO**: https://minio.local
- **Alertmanager**: https://alertmanager.local
- **Supabase**: https://supabase.local

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
- Supabase integration with secrets management

### In-Progress & Planned

- Enhanced OPA policies
- Advanced observability dashboards
- CI/CD integration
- Staging and Production environments

## 💾 Applications

### Supabase

The repository includes a fully configured Supabase deployment for local development:

- **Configuration**: Located in `clusters/local/applications/supabase/`
- **Secrets Management**:
  - Local development uses regular Kubernetes Secrets
  - Production environments use SealedSecrets for secure secret management
- **Components**:
  - PostgreSQL database
  - Authentication services
  - Storage (integrated with MinIO)
  - API Gateway
  - Admin Dashboard

For more details, see [`clusters/local/applications/supabase/README.md`](clusters/local/applications/supabase/README.md).

## 🔐 Security

### Dual Secrets Approach

This project uses a dual approach to secrets management for different environments:

1. **Local Development**: Uses plain Kubernetes Secrets for easy debugging and development

   - Located in `clusters/local/applications/*/secrets/` directories

2. **Production Environments**: Uses SealedSecrets for secure, encrypted storage in Git
   - Located in `clusters/*/applications/*/sealed-secrets/` directories
   - Encrypted with the cluster's public key
   - Decrypted automatically by the SealedSecrets controller in the cluster

Additional security components:

- **HashiCorp Vault**: Advanced secret management with rotation capabilities
- **OPA Gatekeeper**: Policy enforcement and governance
- **RBAC**: Granular Kubernetes permissions
- **Cert Manager**: Automated TLS certificate management

## 📊 Monitoring & Observability

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visual dashboards for monitoring
- **Alertmanager**: Alert routing and notification
- **Loki**: Centralized logging system
- **OpenTelemetry**: Distributed tracing for applications

## 🔧 Utility Scripts

- **Cluster Management**: Configure and validate Minikube environment
- **Component Management**: Install and configure individual components
- **GitOps Workflows**: Automate GitOps processes
- **Promotion Scripts**: Safely promote changes between environments

Detailed instructions in [`scripts/README.md`](scripts/README.md).

## 📚 Additional Documentation

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
- **Flux not reconciling**: Run `flux reconcile kustomization --all`.
- **SealedSecrets issues**: Ensure the correct public key is being used.
- **Logs**: Use `kubectl logs -n <namespace> <pod>` or the Loki/Grafana interface.

---

Feel free to adapt these improvements to best suit your project's specifics!

## Documentation

- [Quick Start Guide](docs/QUICK_START.md) - Get up and running quickly
- [Local Development Guide](docs/LOCAL_DEVELOPMENT.md) - Comprehensive guide for local development
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Solutions for common issues

# Bold Origins Kubernetes Cluster Configuration

This repository contains the GitOps configuration for the Bold Origins Kubernetes clusters, including the staging environment setup.

## Repository Structure

The repository is organized as follows:

- `base/`: Base configurations for all clusters
- `clusters/`: Cluster-specific configurations
  - `staging/`: Staging environment configuration
- `scripts/`: Utility scripts for cluster management and operations

## Staging Environment

The staging environment is configured using [k3s](https://k3s.io/) and [Flux CD](https://fluxcd.io/) for GitOps. The staging environment is hosted on a VPS and is accessible at `staging.boldorigins.io`.

## Available Scripts

The following utility scripts are available to help with cluster management:

### Basic Setup

- `scripts/create-namespaces.sh`: Creates all required namespaces for the staging environment with proper labels.
- `scripts/install-flux.sh`: Installs and configures Flux CD for GitOps.

### Secret Management

- `scripts/secrets/setup-supabase-secrets.sh`: Generates and configures Supabase secrets for the staging environment.
- `scripts/secrets/setup-vault.sh`: Initializes and configures Vault for the staging environment, setting up policies and tokens.

### Infrastructure Setup

- `scripts/setup-metallb.sh`: Configures MetalLB for load balancing in the staging environment.
- `scripts/setup-policy-engine.sh`: Sets up Gatekeeper policies for the staging environment.

### Security

- `scripts/security/audit-kubernetes.sh`: Performs a security audit of the Kubernetes cluster, checking for potential security issues.

### Main Setup Script

- `scripts/setup-staging-environment.sh`: A menu-driven interface for running all the setup scripts in the correct order.

## Getting Started

To get started with the staging environment, follow these steps:

1. Clone this repository
   ```bash
   git clone https://github.com/yourusername/boldorigins-cluster.git
   cd boldorigins-cluster
   ```

2. Install the required tools:
   - `kubectl`: For interacting with the Kubernetes cluster
   - `flux`: For managing the GitOps workflow
   - `kubeseal`: For encrypting Kubernetes secrets
   - `git`: For version control
   - `vault` (optional): For managing secrets with Vault

3. Run the setup script:
   ```bash
   ./scripts/setup-staging-environment.sh
   ```

4. Follow the prompts to set up the staging environment. The recommended order is:
   - Create Required Namespaces
   - Install Flux CD
   - Set up MetalLB
   - Set up Gatekeeper Policies
   - Set up Vault
   - Set up Supabase Secrets
   - Run Security Audit

Alternatively, select option 8 to run the full setup in the correct order.

## Cluster Configuration

### Namespaces

The staging environment uses the following namespaces:

- `flux-system`: Flux GitOps system
- `metallb-system`: MetalLB load balancer
- `gatekeeper-system`: OPA Gatekeeper policy engine
- `sealed-secrets`: Sealed Secrets controller
- `vault`: HashiCorp Vault secrets management
- `cert-manager`: Certificate management
- `minio`: MinIO object storage
- `monitoring`: Monitoring tools (Prometheus, Grafana)
- `loki`: Loki logging system
- `tempo`: Tempo tracing system
- `supabase`: Supabase database platform
- `security`: Security tools

### Network Configuration

The staging environment uses [MetalLB](https://metallb.io/) for load balancing. The MetalLB configuration is stored in `clusters/staging/infrastructure/metallb`.

### Secrets Management

The staging environment uses both Sealed Secrets and Vault for managing secrets:

- **Sealed Secrets**: Used for Kubernetes secrets that need to be stored in Git
- **Vault**: Used for more sensitive secrets and dynamic secrets

Run the `scripts/secrets/setup-vault.sh` script to initialize and configure Vault.

## Security

The staging environment is configured with security best practices in mind, including:

- Network policies to restrict communication between pods
- Sealed Secrets for encrypting sensitive data
- Vault for managing secrets
- Gatekeeper policies for enforcing security constraints

Use the `scripts/security/audit-kubernetes.sh` script to check for potential security issues.

## Contributing

When contributing to this repository, please follow the GitOps workflow:

1. Make changes to the configuration files
2. Commit and push to a new branch
3. Create a pull request
4. Once approved, the changes will be automatically applied to the cluster

## License

This project is licensed under the MIT License - see the LICENSE file for details.
