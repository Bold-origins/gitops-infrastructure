# Codebase Structure

This document provides an overview of the codebase structure with memory anchors for key components.

## Repository Overview

<!-- CLAUDE-ANCHOR:repo-structure:a1b2c3d4 -->
```
/
├── charts/                  # Helm charts
├── clusters/                # Kubernetes cluster configurations
│   ├── base/                # Base configurations (environment-agnostic)
│   └── local/               # Local environment configurations
├── conext/                  # Project context and documentation
├── docs/                    # User documentation
└── scripts/                 # Automation scripts
```
<!-- END-CLAUDE-ANCHOR:repo-structure -->

## Clusters Structure

<!-- CLAUDE-ANCHOR:clusters-structure:e5f6g7h8 -->
```
clusters/
├── base/                    # Base configurations (environment-agnostic)
│   ├── applications/        # Application configurations
│   ├── infrastructure/      # Infrastructure configurations
│   ├── observability/       # Observability configurations
│   └── policies/            # Policy configurations
└── local/                   # Local environment configurations
    ├── applications/        # Environment-specific application configurations
    ├── infrastructure/      # Environment-specific infrastructure configurations
    └── observability/       # Environment-specific observability configurations
```
<!-- END-CLAUDE-ANCHOR:clusters-structure -->

## Applications Structure

<!-- CLAUDE-ANCHOR:applications-structure:i9j0k1l2 -->
```
applications/
└── supabase/               # Supabase application
    ├── examples/           # Environment examples
    ├── gitrepository.yaml  # Git repository source
    ├── helm/               # Helm values
    ├── helmrelease.yaml    # Helm release definition
    ├── kustomization.yaml  # Kustomization configuration
    ├── namespace.yaml      # Namespace definition
    └── sealed-secrets/     # Sealed secrets templates
```
<!-- END-CLAUDE-ANCHOR:applications-structure -->

## Infrastructure Structure

<!-- CLAUDE-ANCHOR:infrastructure-structure:m3n4o5p6 -->
```
infrastructure/
├── cert-manager/           # Certificate management
├── gatekeeper/             # Policy enforcement
├── ingress/                # Ingress controller
├── kustomization.yaml      # Kustomization configuration
├── metallb/                # Load balancer
├── minio/                  # Object storage
├── policy-engine/          # Policy engine
├── sealed-secrets/         # Sealed secrets controller
├── security/               # Security configuration
└── vault/                  # Secret management
```
<!-- END-CLAUDE-ANCHOR:infrastructure-structure -->

## Observability Structure

<!-- CLAUDE-ANCHOR:observability-structure:q7r8s9t0 -->
```
observability/
├── common/                 # Common configurations
├── grafana/                # Visualization and dashboards
├── kustomization.yaml      # Kustomization configuration
├── loki/                   # Log aggregation
├── namespace.yaml          # Namespace definition
├── network/                # Network monitoring
├── opentelemetry/          # Distributed tracing
└── prometheus/             # Metrics and monitoring
```
<!-- END-CLAUDE-ANCHOR:observability-structure -->

## Scripts Structure

<!-- CLAUDE-ANCHOR:scripts-structure:u1v2w3x4 -->
```
scripts/
├── cluster/               # Cluster setup scripts
│   ├── setup-all.sh       # Run all setup scripts
│   ├── setup-applications.sh # Set up applications
│   ├── setup-core-infrastructure.sh # Set up core infrastructure
│   ├── setup-flux.sh      # Set up Flux GitOps
│   ├── setup-minikube.sh  # Set up Minikube
│   ├── setup-networking.sh # Set up networking
│   ├── setup-observability.sh # Set up observability
│   └── verify-environment.sh # Verify environment setup
├── gitops/                # GitOps workflow scripts
│   ├── cleanup-local-refactoring.sh # Clean up local refactoring
│   ├── refactor-component.sh # Refactor a component for GitOps
│   ├── refactor-workflow.sh # Refactor workflow
│   └── verify-local-refactoring.sh # Verify local refactoring
└── promotion/             # Environment promotion scripts
```
<!-- END-CLAUDE-ANCHOR:scripts-structure -->

## Component Template Structure

<!-- CLAUDE-ANCHOR:component-template:y5z6a7b8 -->
```
component/
├── README.md              # Documentation
├── examples/              # Environment examples
│   ├── local/             # Local environment example
│   ├── production/        # Production environment example
│   └── staging/           # Staging environment example
├── helm/                  # Helm configuration
│   ├── release.yaml       # Helm release definition
│   └── values.yaml        # Helm values
├── kustomization.yaml     # Kustomization configuration
├── namespace.yaml         # Namespace definition
└── [component].yaml       # Component-specific resources
```
<!-- END-CLAUDE-ANCHOR:component-template -->

## Environment Overlay Template Structure

<!-- CLAUDE-ANCHOR:environment-overlay-template:c9d0e1f2 -->
```
environment/component/
├── helm/                  # Environment-specific Helm values
│   └── values.yaml        # Helm values
├── kustomization.yaml     # Kustomization configuration
├── patches/               # Patches for base resources
│   └── *-patch.yaml       # Patch files
└── sealed-secrets/        # Environment-specific sealed secrets
    └── *.yaml             # Sealed secret files
```
<!-- END-CLAUDE-ANCHOR:environment-overlay-template -->

## Configuration Patterns

<!-- CLAUDE-ANCHOR:configuration-patterns:g3h4i5j6 -->
### Kustomization Pattern
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - other-resource.yaml
```

### HelmRelease Pattern
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: component-name
  namespace: component-namespace
spec:
  interval: 5m
  chart:
    spec:
      chart: chart-name
      version: "chart-version"
      sourceRef:
        kind: HelmRepository
        name: repo-name
        namespace: flux-system
  values:
    # Default values
```

### Patch Pattern
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: component-name
  namespace: component-namespace
spec:
  values:
    # Environment-specific values that override base values
```
<!-- END-CLAUDE-ANCHOR:configuration-patterns -->