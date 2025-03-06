# OpenTelemetry Collector Environment-Specific Configurations

This directory contains example configurations for deploying OpenTelemetry Collector in different environments using Kustomize overlays.

## Overview

OpenTelemetry is a collection of tools, APIs, and SDKs used to instrument, generate, collect, and export telemetry data (metrics, logs, and traces) for analysis. The OpenTelemetry Collector is a vendor-agnostic implementation used to receive, process, and export telemetry data.

## Environment Examples

We provide example configurations for three environments:

1. **Local**: Minimal resources with simplified configuration for development
2. **Staging**: Moderate resources, daemonset mode for basic telemetry collection
3. **Production**: High-availability configuration with advanced features and integrations

## Deployment Modes

OpenTelemetry Collector can be deployed in different modes:

- **Deployment** (used in local): Simple deployment with a fixed number of replicas
- **DaemonSet** (used in staging and production): Runs one collector per node to collect node-level telemetry
- **Gateway + Agents** (used in production): Combines DaemonSet agents with centralized gateway collectors

## Key Configuration Differences

| Feature | Local | Staging | Production |
|---------|-------|---------|------------|
| Mode | Deployment | DaemonSet | DaemonSet + Gateway |
| Replicas | 1 | Per node | Per node + 2 gateways |
| Resources | Minimal | Moderate | Production-grade |
| Receivers | OTLP, Prometheus | OTLP, Prometheus, Kubeletstats | OTLP, Prometheus, Kubeletstats, Hostmetrics |
| Processors | Basic | Standard | Advanced with filtering and transformation |
| Exporters | Prometheus, S3, Logging | Prometheus, S3, Logging | Prometheus, S3, Logging, OTLP HTTP (NewRelic) |
| Extensions | None | None | Health Check, pprof, zPages |
| Credentials | Default | Secret references | Sealed Secrets |

## Usage

To apply these configurations, use Kustomize:

```bash
# For local development
kubectl apply -k clusters/base/observability/opentelemetry/examples/local

# For staging environment
kubectl apply -k clusters/base/observability/opentelemetry/examples/staging

# For production environment
kubectl apply -k clusters/base/observability/opentelemetry/examples/production
```

## Customization

Each environment has its own set of configuration files:

- `values-patch.yaml`: Helm values overrides specific to the environment
- `kustomization.yaml`: Kustomize configuration for the environment

To customize further, either modify these files directly or create a new overlay that references one of these environments.

## Security Considerations

- **Local**: Uses default credentials for simplicity
- **Staging**: Uses staged credentials for testing
- **Production**: Uses placeholders that should be replaced with a proper secret management solution like Sealed Secrets or Vault

## Integration with Other Components

OpenTelemetry Collector is integrated with:

- **Prometheus**: For metrics storage and visualization
- **Loki**: For logs storage (via OTLP HTTP in production)
- **Tempo/Jaeger**: For traces storage (via S3)
- **New Relic**: For external monitoring in production environments 