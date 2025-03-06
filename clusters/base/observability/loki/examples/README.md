# Loki Environment-Specific Configurations

This directory contains example configurations for deploying Loki in different environments using Kustomize overlays.

## Overview

Loki is a horizontally-scalable, highly-available, multi-tenant log aggregation system. It's designed to be cost-effective and easy to operate, as it does not index the contents of the logs, but rather a set of labels for each log stream.

## Environment Examples

We provide example configurations for three environments:

1. **Local**: Minimal resources, single-instance mode with simplified configuration
2. **Staging**: Moderate resources, multi-replica setup with basic high availability
3. **Production**: High-availability configuration with microservices architecture and extended retention

## Deployment Modes

Loki can be deployed in different modes depending on your requirements:

- **Single Binary** (used in local and staging): Simple deployment with all components in a single process
- **Microservices** (used in production): Scalable deployment with separate components for ingestion, storage, and querying

## Key Configuration Differences

| Feature | Local | Staging | Production |
|---------|-------|---------|------------|
| Replicas | 1 | 2 | Multiple (component-specific) |
| Architecture | Single Binary | Single Binary | Microservices |
| Authentication | Disabled | Enabled | Enabled |
| Log Retention | 1 day | 7 days | 31 days |
| Resources | Minimal | Moderate | Production-grade |
| Object Storage | MinIO (default creds) | MinIO (staged secrets) | MinIO/S3 (sealed secrets) |
| Alerting | Disabled | Basic | Robust |

## Usage

To apply these configurations, use Kustomize:

```bash
# For local development
kubectl apply -k clusters/base/observability/loki/examples/local

# For staging environment
kubectl apply -k clusters/base/observability/loki/examples/staging

# For production environment
kubectl apply -k clusters/base/observability/loki/examples/production
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

## Monitoring Integration

Loki is integrated with Prometheus and Grafana in all environments. The configuration enables:

- Metrics scraping for Loki components
- Log visualization in Grafana (through the Loki datasource)
- Alerting through Prometheus AlertManager (in staging and production) 