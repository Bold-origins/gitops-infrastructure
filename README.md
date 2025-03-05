# Kubernetes GitOps Infrastructure

A comprehensive GitOps infrastructure setup for Kubernetes clusters, focusing on security, secrets management, and policy enforcement. This repository contains configuration files and documentation to set up a complete infrastructure with cert-manager, Vault, Sealed Secrets, and OPA Gatekeeper.

## Repository Structure

This repository is organized as follows:

- **charts/** - Helm charts for deploying components
- **clusters/** - Cluster-specific configurations
- **diagnostics/** - Diagnostic tools and outputs
- **docs/** - Documentation organized by category
  - See [docs/README.md](docs/README.md) for details
- **plan/** - Planning documents and roadmaps
- **scripts/** - Operational scripts organized by function
  - See [scripts/README.md](scripts/README.md) for details
- **tmp/** - Temporary files (gitignored)

## Getting Started

Please refer to [docs/guides/setup-guide.md](docs/guides/setup-guide.md) for detailed setup instructions.

For local development using Minikube, see [docs/guides/minikube-setup.md](docs/guides/minikube-setup.md).

## Architecture

This infrastructure follows GitOps principles, with all configurations stored as code in this repository. The key components are:

- **cert-manager**: For TLS certificate management, including Let's Encrypt integration
- **HashiCorp Vault**: For secrets management and dynamic credentials
- **Sealed Secrets**: For storing encrypted secrets in Git
- **OPA Gatekeeper**: For policy enforcement and security guardrails
- **MinIO**: For S3-compatible object storage
- **Example Application**: Demonstrates how to use Vault and Sealed Secrets in a real application

The infrastructure is organized using Kustomize, allowing for environment-specific configurations while maintaining a common base.

## Directory Structure

```
.
├── clusters/
│   └── local/                      # Local development cluster
│       ├── apps/                   # Application deployments
│       │   ├── example/            # Example application using Vault and Sealed Secrets
│       │   └── minio/              # MinIO object storage
│       ├── infrastructure/         # Core infrastructure components
│       │   ├── cert-manager/       # TLS certificate management
│       │   ├── gatekeeper/         # Policy enforcement
│       │   ├── sealed-secrets/     # Encrypted secrets
│       │   └── vault/              # Secret management
│       └── kustomization.yaml      # Main kustomization file
├── docs/                           # Documentation
│   ├── setup-guide.md              # Complete setup guide
│   └── verification-guide.md       # Guide for verifying the installation
└── scripts/                        # Utility scripts
    ├── setup-minikube.sh           # Script to configure Minikube
    └── verify-environment.sh       # Script to verify the environment
```

## Prerequisites

- Minikube v1.30+ or equivalent Kubernetes environment
- kubectl v1.28+
- helm v3.12+
- kubeseal CLI (for Sealed Secrets)
- Vault CLI (optional, for Vault operations)

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/gitops-infra.git
   cd gitops-infra
   ```

2. Set up your local development environment:
   ```bash
   ./scripts/setup-minikube.sh
   ```

3. Apply the infrastructure:
   ```bash
   kubectl apply -k clusters/local
   ```

4. Verify the installation:
   ```bash
   ./scripts/verify-environment.sh
   ```

5. Access the example application:
   - Add `example.local` to your /etc/hosts file: `echo "$(minikube ip) example.local" | sudo tee -a /etc/hosts`
   - Visit https://example.local in your browser

## Detailed Setup

For a comprehensive setup guide, see [docs/setup-guide.md](docs/setup-guide.md).

## Infrastructure Components

### cert-manager

cert-manager is used for automated certificate management. It's configured with:

- Self-signed issuer for local development
- Let's Encrypt staging and production issuers for real certificates

### HashiCorp Vault

Vault provides secure secret management with:

- Development mode for local testing
- Kubernetes authentication method
- KV secrets engine
- PKI secrets engine for certificate issuance

### Sealed Secrets

Sealed Secrets allows storing encrypted secrets in Git. The controller in the cluster decrypts them for use by applications.

### OPA Gatekeeper

Gatekeeper enforces policies across the cluster, including:

- Required labels and annotations
- Pod security requirements
- Resource limits
- Network policies

### Example Application

The example application demonstrates:

- Using Vault for database credentials
- Using Sealed Secrets for API keys
- Secure ingress with TLS
- Resource limit compliance

## Verification

To verify your infrastructure is working correctly, use our verification script:

```bash
./scripts/verify-environment.sh
```

For manual verification steps, see [docs/verification-guide.md](docs/verification-guide.md).

## Security Considerations

This infrastructure includes several security best practices:

- Encrypted secrets with Sealed Secrets
- Dynamic credentials with Vault
- TLS for all ingress resources
- Policy enforcement with Gatekeeper
- Network policies for pod-to-pod communication

## Extending the Infrastructure

To add a new application:

1. Create a directory under `clusters/local/apps/`
2. Add a kustomization.yaml file
3. Configure your application resources
4. Add your application to the main kustomization.yaml

For examples, see the existing applications in `clusters/local/apps/`.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 