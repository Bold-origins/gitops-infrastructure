# Network Monitoring Environment-Specific Configurations

This directory contains example configurations for network monitoring and policies in different environments using Kustomize overlays.

## Overview

The network component in the observability stack focuses on monitoring network traffic, particularly for Flux GitOps controllers, and enforcing appropriate network policies. It includes service monitors for Prometheus, alerting rules, and network policies.

## Environment Examples

We provide example configurations for three environments:

1. **Local**: Simplified monitoring with relaxed network policies for development
2. **Staging**: Standard monitoring with reasonable network policies for testing
3. **Production**: Comprehensive monitoring with strict network policies for security

## Key Configuration Differences

| Feature | Local | Staging | Production |
|---------|-------|---------|------------|
| Service Monitors | Basic, longer intervals | Standard | Comprehensive with TLS and auth |
| Alert Thresholds | Relaxed, info severity | Standard, warning severity | Strict, critical severity with PagerDuty |
| Network Policies | Very permissive | Standard restrictions | Strict restrictions, both ingress and egress |
| Metrics Collection | Minimal | Standard | Comprehensive, additional metrics |
| Alert Responsiveness | Slow (high thresholds) | Medium | Fast (low thresholds) |

## Network Policies

The network policies differ significantly across environments:

- **Local**: Minimal restrictions to simplify development
- **Staging**: Standard restrictions that block access to private networks
- **Production**: Strict policies with explicit allowlists for both ingress and egress

## Service Monitors

The service monitors collect metrics from Flux components:

- **Local**: Basic monitoring with longer intervals to reduce resource usage
- **Staging**: Standard monitoring with regular intervals
- **Production**: Comprehensive monitoring with additional monitors for all Flux components

## Alerting Rules

The alerting rules are configured for different environments:

- **Local**: Relaxed rules with "info" severity and longer evaluation periods
- **Staging**: Standard rules with "warning" severity and runbook links
- **Production**: Strict rules with "critical" severity, PagerDuty integration, and additional alerts

## Usage

To apply these configurations, use Kustomize:

```bash
# For local development
kubectl apply -k clusters/base/observability/network/examples/local

# For staging environment
kubectl apply -k clusters/base/observability/network/examples/staging

# For production environment
kubectl apply -k clusters/base/observability/network/examples/production
```

## Customization

Each environment has its own set of configuration files:

- `flux-service-monitor-patch.yaml`: Patches for service monitors
- `flux-alerts-patch.yaml`: Patches for alerting rules
- `flux-network-policy-patch.yaml`: Patches for network policies
- `kustomization.yaml`: Kustomize configuration

To customize further, either modify these files directly or create a new overlay that references one of these environments.

## Integration with Other Components

The network component is integrated with:

- **Prometheus**: For collecting and storing metrics
- **Alertmanager**: For alert handling and routing
- **Flux**: For monitoring the GitOps controllers
- **Network Policies**: For enforcing network security 