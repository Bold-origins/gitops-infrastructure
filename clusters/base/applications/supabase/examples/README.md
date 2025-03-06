# Supabase Environment-Specific Configurations

This directory contains example configurations for deploying Supabase in different environments using Kustomize overlays.

## Overview

Supabase is an open-source Firebase alternative providing databases, authentication, storage, and other backend services. These example configurations demonstrate how to deploy Supabase with environment-specific settings using Kustomize overlays.

## Environment Examples

We provide example configurations for three environments:

1. **Local**: Minimal resources with core components for development
2. **Staging**: Moderate resources with most components for testing
3. **Production**: High-availability configuration with all components enabled

## Key Configuration Differences

| Feature | Local | Staging | Production |
|---------|-------|---------|------------|
| Resource Limits | Minimal | Moderate | Production-grade |
| Components Enabled | Core only | Most components | All components |
| Replicas | Single replica | Moderate HA | Full HA (2-3 replicas) |
| Persistence | Disabled | Enabled (20Gi) | Enabled (100Gi + backups) |
| Health Probes | Minimal | Standard | Comprehensive |
| Security | Basic | Standard | Enhanced |
| TLS/Ingress | HTTP only | HTTPS (staging) | HTTPS with force-redirect |
| Reconciliation | 5m interval | 15m interval | 30m interval, scheduled |
| Pod Disruption Budgets | Not used | Not used | Enabled for all components |

## Component Configuration

### Database (PostgreSQL)

The database configuration varies significantly across environments:

- **Local**: Minimal resources, no persistence, basic configuration
- **Staging**: Moderate resources with 20Gi persistent storage
- **Production**: High resources with 100Gi premium SSD storage and backup annotations

### API and Studio

The API and Studio components are configured based on environment:

- **Local**: Basic setup with minimal resources
- **Staging**: Standard setup with readiness probes
- **Production**: HA setup with multiple replicas, readiness/liveness probes, and PDBs

### Optional Components

Optional components are enabled differently across environments:

- **Local**: Only core components (db, studio, auth, rest) are enabled
- **Staging**: Most components are enabled for testing
- **Production**: All components are enabled with HA configuration

## Usage

To apply these configurations, use Kustomize:

```bash
# For local development
kubectl apply -k clusters/base/applications/supabase/examples/local

# For staging environment
kubectl apply -k clusters/base/applications/supabase/examples/staging

# For production environment
kubectl apply -k clusters/base/applications/supabase/examples/production
```

## Customization

Each environment has its own set of configuration files:

- `values-patch.yaml`: Environment-specific Helm values
- `helmrelease-patch.yaml`: Environment-specific HelmRelease configurations
- `kustomization.yaml`: References the base configuration and applies patches

## Secrets Management

Secrets are referenced from existing secrets in all environments:

- **Local**: Simple secrets for development
- **Staging**: More secure secrets for testing
- **Production**: Fully secured secrets with proper rotation and management

In production, additional security measures include:
- Chart verification using GPG keys
- Security contexts for containers
- Post-rendering to enforce security policies 