# Policy Enforcement Environment-Specific Configurations

This directory contains example configurations for policy enforcement in different environments using Kustomize overlays.

## Overview

The policies component implements OPA Gatekeeper constraints to enforce security and operational best practices across the cluster. These policies ensure that deployed workloads adhere to organizational standards, but the enforcement level varies by environment.

## Environment Examples

We provide example configurations for three environments:

1. **Local**: Relaxed policies with warning-only enforcement for development
2. **Staging**: Standard policies with dry-run enforcement for testing
3. **Production**: Strict policies with full enforcement for security

## Policy Enforcement Levels

The enforcement level differs significantly across environments:

| Environment | Enforcement | Description |
|-------------|-------------|-------------|
| Local | `warn` | Violations are reported but do not block deployments |
| Staging | `dryrun` | Violations are logged but do not block deployments |
| Production | `deny` | Violations actively block non-compliant deployments |

## Key Configuration Differences

| Feature | Local | Staging | Production |
|---------|-------|---------|------------|
| Enforcement | Warning only | Dry-run | Strict enforcement |
| Namespace Coverage | Limited | Broad with exceptions | Nearly all namespaces |
| Resource Types | Deployments only | Deployments only | Deployments and StatefulSets |
| Required Probes | ReadinessProbe only | Both probes | Both probes |
| Additional Policies | None | None | Pod Security Policies |

## Available Policies

### Required Probes Policy

This policy enforces that containers have appropriate health probes configured:

- **Local**: Only requires readinessProbe in the example namespace
- **Staging**: Requires both readinessProbe and livenessProbe in all non-system namespaces
- **Production**: Strictly enforces both probes in all non-system namespaces

### Pod Security Policy (Production Only)

This policy is only active in the production environment:

- Prohibits privileged containers
- Applies to Pods, Deployments, StatefulSets, and DaemonSets
- Excludes only system namespaces

## Usage

To apply these configurations, use Kustomize:

```bash
# For local development
kubectl apply -k clusters/base/policies/examples/local

# For staging environment
kubectl apply -k clusters/base/policies/examples/staging

# For production environment
kubectl apply -k clusters/base/policies/examples/production
```

## Customization

Each environment has its own set of configuration files:

- `require-probes-patch.yaml`: Patches for the require-probes constraint
- `pod-security-policy.yaml`: Production-only additional security policy
- `kustomization.yaml`: Kustomize configuration

To customize further, either modify these files directly or create a new overlay that references one of these environments.

## Adding New Policies

To add new policies:

1. Add the constraint template to `clusters/base/policies/templates/`
2. Add the constraint to `clusters/base/policies/constraints/`
3. Create patches for each environment under `examples/{local,staging,production}/`

For policies that should only exist in specific environments (like production), add them directly to that environment's directory and include them in the corresponding kustomization.yaml file. 