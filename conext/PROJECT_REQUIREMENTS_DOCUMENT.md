# Project Requirements Document (PRD)

## App Overview

The Local Kubernetes Cluster is a complete GitOps-based Kubernetes environment that runs locally for development and testing purposes. It provides a production-like Kubernetes setup with pre-configured infrastructure components, monitoring, and observability tools. The project aims to simplify the process of setting up a robust Kubernetes environment locally, allowing developers and DevOps engineers to test deployments, configurations, and applications in an environment that closely resembles production.

The application provides a full-stack infrastructure that includes security components (Vault, Sealed Secrets), monitoring tools (Prometheus, Grafana), storage solutions (MinIO), and policy enforcement (OPA Gatekeeper). It follows GitOps principles, with all configurations stored as code in the repository, enabling declarative and version-controlled infrastructure management.

## User Flow

1. **Initial Setup**:

   - User clones the repository to their local machine
   - User runs the `setup-minikube.sh` script, which:
     - Starts a Minikube cluster with appropriate resources
     - Enables necessary Kubernetes addons
     - Configures local domain mappings
     - Deploys core infrastructure components

2. **Verification**:

   - User runs the `verify-environment.sh` script to ensure all components are running correctly
   - Script checks the health of all deployed services and provides diagnostic information

3. **Accessing Services**:

   - User accesses web interfaces for different components through local domain names:
     - Vault at https://vault.local
     - Prometheus at https://prometheus.local
     - Grafana at https://grafana.local
     - MinIO at https://minio.local
     - Alertmanager at https://alertmanager.local

4. **Deploying Applications**:

   - User creates Kubernetes manifests for their application
   - User applies the manifests to the cluster using kubectl or adds them to the GitOps workflow
   - User accesses their application through configured ingress

5. **Monitoring & Management**:

   - User monitors application performance using Grafana dashboards
   - User manages secrets using Vault or Sealed Secrets
   - User configures policies using OPA Gatekeeper
   - User uses provided scripts for common tasks (resetting Vault, checking cluster health)

6. **Cleanup**:
   - User can stop the Minikube cluster when not in use
   - User can delete the Minikube cluster when no longer needed

## Tech Stack & APIs

### Infrastructure Components:

- **Kubernetes**: Core container orchestration platform (via Minikube)
- **Helm**: Package manager for Kubernetes
- **Kustomize**: Kubernetes configuration management
- **Cert-Manager**: Certificate management for Kubernetes
- **Sealed Secrets**: Encrypted secrets management
- **Vault**: Advanced secrets management and dynamic credentials
- **OPA Gatekeeper**: Policy enforcement and security guardrails
- **Ingress-Nginx**: Ingress controller for routing external traffic
- **MetalLB**: Load balancer implementation for Kubernetes
- **MinIO**: S3-compatible object storage
- **Supabase**: Open source Firebase alternative

### Monitoring & Observability:

- **Prometheus**: Metrics collection, storage, and alerting
- **Grafana**: Data visualization with pre-configured dashboards
- **Alertmanager**: Alert management and notification routing
- **Loki**: Log aggregation system
- **OpenTelemetry**: Observability framework for trace collection

### Development Tools:

- **Bash Scripts**: Automation for setup and management
- **Docker**: Container runtime
- **kubectl**: Command-line tool for Kubernetes

### APIs:

- **Kubernetes API**: Core API for cluster management
- **Prometheus API**: For metrics querying
- **Vault API**: For secrets management
- **MinIO API**: S3-compatible API for object storage
- **Supabase API**: For database and authentication services

## Core Features

1. **Complete Infrastructure Stack**:

   - Essential components pre-configured and deployed
   - Security-focused with Vault, Sealed Secrets, and policy enforcement
   - Storage solutions with MinIO
   - Database and auth services with Supabase

2. **Monitoring & Observability**:

   - Comprehensive metrics collection with Prometheus
   - Visualization dashboards with Grafana
   - Log aggregation with Loki
   - Distributed tracing with OpenTelemetry
   - Alert management with Alertmanager

3. **GitOps-Ready Structure**:

   - Declarative configuration management
   - Version-controlled infrastructure
   - Organized directory structure for different components
   - Kustomize-based deployment strategy

4. **Security Features**:

   - Certificate management with cert-manager
   - Secrets encryption with Sealed Secrets
   - Advanced secrets management with Vault
   - Policy enforcement with OPA Gatekeeper
   - Security constraints and templates

5. **Automation & Ease of Use**:

   - Simple setup scripts for quick deployment
   - Verification tools for environment validation
   - Helper scripts for common tasks
   - Comprehensive documentation

6. **Local Domain Routing**:
   - Automatic configuration of local domains
   - Ingress setup for all web interfaces
   - Self-signed certificates for HTTPS support

## In-scope & Out-of-scope

### In-scope:

- Complete local Kubernetes environment setup
- Core infrastructure components deployment
- Monitoring and observability stack
- Security components and policies
- Local domain routing and ingress configuration
- Documentation and setup guides
- Verification and diagnostic tools
- Example applications
- Scripts for automation and management

### Out-of-scope:

- Production deployment configurations (focused on local development)
- Cloud provider-specific implementations
- CI/CD pipeline integration (though the structure supports it)
- Extensive application development (beyond examples)
- Performance tuning for production workloads
- Advanced networking configurations beyond basic ingress
- External authentication systems integration
- Multi-cluster management
- Long-term persistence and data management
- High availability configurations
