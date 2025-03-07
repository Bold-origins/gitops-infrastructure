# Memory Anchors

This file provides a centralized reference of memory anchors throughout the repository documentation.

## Repository Structure

<!-- CLAUDE-ANCHOR:repo-structure-overview:1a2b3c4d -->
- **charts/**: Helm charts for applications
- **clusters/**: Kubernetes cluster configurations
  - **base/**: Base configurations (environment-agnostic)
  - **local/**: Local environment configurations
- **conext/**: Project context and documentation
- **docs/**: User documentation
- **scripts/**: Automation scripts
<!-- END-CLAUDE-ANCHOR:repo-structure-overview -->

## GitOps Structure

<!-- CLAUDE-ANCHOR:gitops-structure:5e6f7g8h -->
- **Base configurations** in `clusters/base/`
  - Environment-agnostic
  - Define core resources
  - Use placeholders for environment-specific values
- **Environment overlays** in `clusters/[env]/`
  - Environment-specific customizations
  - Patch base resources
  - Provide environment-specific values
<!-- END-CLAUDE-ANCHOR:gitops-structure -->

## Component Categories

<!-- CLAUDE-ANCHOR:component-categories:9i0j1k2l -->
- **Infrastructure**: Core components that provide cluster functionality
  - cert-manager, sealed-secrets, metallb, ingress, gatekeeper, etc.
- **Observability**: Monitoring and logging components
  - prometheus, loki, grafana, opentelemetry, etc.
- **Applications**: Business functionality
  - supabase, etc.
<!-- END-CLAUDE-ANCHOR:component-categories -->

## Deployment Order

<!-- CLAUDE-ANCHOR:deployment-order:3m4n5o6p -->
1. **Flux GitOps controllers**
2. **Core infrastructure**
   - sealed-secrets
   - cert-manager
   - metallb
   - ingress
3. **Security components**
   - gatekeeper
   - policy-engine
   - security
4. **Storage**
   - minio
   - vault
5. **Observability**
   - prometheus
   - loki
   - opentelemetry
   - grafana
6. **Applications**
<!-- END-CLAUDE-ANCHOR:deployment-order -->

## Component Dependencies

<!-- CLAUDE-ANCHOR:component-dependencies:7q8r9s0t -->
- **cert-manager** depends on: flux-system
- **sealed-secrets** depends on: flux-system
- **metallb** depends on: flux-system
- **ingress** depends on: flux-system, metallb, cert-manager
- **gatekeeper** depends on: flux-system
- **policy-engine** depends on: gatekeeper
- **minio** depends on: flux-system, metallb
- **vault** depends on: flux-system, cert-manager, sealed-secrets
- **supabase** depends on: minio, ingress, cert-manager, sealed-secrets
<!-- END-CLAUDE-ANCHOR:component-dependencies -->

## Common Patterns

<!-- CLAUDE-ANCHOR:common-patterns:1u2v3w4x -->
- **Kustomization Pattern**: Base + Overlays
- **HelmRelease Pattern**: Chart reference + Values
- **Sealed Secrets Pattern**: Template + Encrypted data
- **Policy Pattern**: Template + Constraint
<!-- END-CLAUDE-ANCHOR:common-patterns -->

## Script Categories

<!-- CLAUDE-ANCHOR:script-categories:5y6z7a8b -->
- **Cluster Scripts**: Setup and configuration of the cluster
- **GitOps Scripts**: Automation for GitOps workflows
- **Promotion Scripts**: Promotion between environments
<!-- END-CLAUDE-ANCHOR:script-categories -->

## Error Patterns

<!-- CLAUDE-ANCHOR:error-patterns:9c0d1e2f -->
- **HelmRelease Errors**: Chart not found, values validation, etc.
- **Kustomize Errors**: Resource not found, patch target not found, etc.
- **Sealed Secrets Errors**: Decryption failed, etc.
- **Policy Violations**: Missing required labels, missing probes, etc.
- **Flux Errors**: Git repository not found, reconciliation failed, etc.
<!-- END-CLAUDE-ANCHOR:error-patterns -->

## Common Operations

<!-- CLAUDE-ANCHOR:common-operations:3g4h5i6j -->
- **Check component status**: `kubectl get pods -n <namespace>`
- **View component logs**: `kubectl logs -n <namespace> <pod-name>`
- **View component events**: `kubectl get events -n <namespace>`
- **Describe resources**: `kubectl describe <resource-type> <resource-name> -n <namespace>`
- **Port forward to service**: `kubectl port-forward -n <namespace> svc/<service-name> <local-port>:<service-port>`
<!-- END-CLAUDE-ANCHOR:common-operations -->

## Flux Commands

<!-- CLAUDE-ANCHOR:flux-commands:7k8l9m0n -->
- **Get all resources**: `flux get all`
- **Get kustomizations**: `flux get kustomizations`
- **Get HelmReleases**: `flux get helmreleases -A`
- **Get sources**: `flux get sources all`
- **Reconcile a resource**: `flux reconcile kustomization <name>`
<!-- END-CLAUDE-ANCHOR:flux-commands -->