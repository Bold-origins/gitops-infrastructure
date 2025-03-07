# File Classifications

This document provides classifications for the key file types in the repository.

## Core Classification Categories

- **Interface**: Files that define interfaces between components
- **Implementation**: Files that implement specific functionality
- **Configuration**: Files that configure components
- **Documentation**: Files that document components
- **Script**: Files that automate processes

## File Type Classifications

| File Pattern | Classification | Purpose |
|--------------|---------------|---------|
| `*/kustomization.yaml` | Interface | Defines how resources are composed |
| `*/namespace.yaml` | Interface | Defines Kubernetes namespaces |
| `*/helmrelease.yaml` | Interface | Defines Helm chart deployments |
| `*/helm/values.yaml` | Configuration | Configures Helm chart parameters |
| `*/sealed-secrets/*.yaml` | Configuration | Defines encrypted secrets |
| `*/README.md` | Documentation | Documents component usage |
| `*/examples/*` | Documentation | Provides usage examples |
| `scripts/*.sh` | Script | Automates processes |
| `*/patches/*.yaml` | Implementation | Customizes base resources |
| `*/_helpers.tpl` | Implementation | Defines Helm template helpers |
| `*/templates/*.yaml` | Implementation | Defines Kubernetes resource templates |
| `*/crds/*.yaml` | Interface | Defines custom resource definitions |

## Directory Classifications

| Directory Pattern | Classification | Purpose |
|-------------------|---------------|---------|
| `clusters/base/*` | Interface | Defines base resources |
| `clusters/*/applications/*` | Implementation | Implements application deployments |
| `clusters/*/infrastructure/*` | Implementation | Implements infrastructure components |
| `clusters/*/observability/*` | Implementation | Implements observability stack |
| `scripts/cluster/*` | Script | Automates cluster setup |
| `scripts/gitops/*` | Script | Automates GitOps workflows |
| `docs/*` | Documentation | Documents repository usage |
| `conext/*` | Documentation | Provides project context |
| `charts/*` | Implementation | Contains Helm charts |

## Configuration Hierarchy

- **Base Configuration**: `clusters/base/*/`
  - Defines the core resources
  - Should be environment-agnostic
  - Uses placeholders for environment-specific values

- **Environment Configuration**: `clusters/*/`
  - Customizes base resources for specific environments
  - Provides environment-specific values
  - Uses patches to modify base resources

## Naming Conventions

| Pattern | Convention |
|---------|------------|
| Namespaces | Use kebab-case (e.g., `cert-manager`) |
| Resources | Use kebab-case (e.g., `cluster-issuer`) |
| Patches | Use kebab-case with `-patch` suffix (e.g., `helmrelease-patch.yaml`) |
| Scripts | Use kebab-case with `.sh` extension (e.g., `setup-flux.sh`) |
| Directories | Use kebab-case (e.g., `sealed-secrets`) |

## Component Types

| Component Type | Directory Pattern | Purpose |
|----------------|------------------|---------|
| Core Infrastructure | `clusters/*/infrastructure/*` | Provides core cluster functionality |
| Observability | `clusters/*/observability/*` | Provides monitoring and logging |
| Security | `clusters/*/security/*` | Provides security controls |
| Applications | `clusters/*/applications/*` | Provides business functionality |

## Special Files

| File | Purpose |
|------|---------|
| `clusters/*/flux-system/gotk-components.yaml` | Defines Flux components |
| `clusters/*/flux-system/gotk-sync.yaml` | Defines Flux synchronization |
| `clusters/*/kustomization.yaml` | Root kustomization for environment |
| `clusters/*/flux-kustomization.yaml` | Flux kustomization for environment |