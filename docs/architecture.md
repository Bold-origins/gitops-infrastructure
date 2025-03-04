# Architecture

This document outlines the architecture of our Kubernetes GitOps cluster setup.

## Overview Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                       │
│                                                               │
│  ┌─────────────┐   ┌───────────────────┐   ┌───────────────┐  │
│  │ Flux System │   │   Infrastructure   │   │ Observability │  │
│  │             │   │                   │   │               │  │
│  │ - Controllers │ │ - Ingress NGINX    │   │ - Prometheus  │  │
│  │ - Source    │   │ - MetalLB          │   │ - Grafana     │  │
│  │   controllers │ │ - Vault            │   │ - Loki        │  │
│  │ - Notification│ │ - Sealed Secrets   │   │ - OpenTelemetry│ │
│  │ - Helm      │   │ - cert-manager     │   │               │  │
│  │   controllers │ │ - Security Policies│   │               │  │
│  └─────────────┘   └───────────────────┘   └───────────────┘  │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## Component Details

### GitOps (Flux)

The entire system is managed through GitOps principles using Flux v2. This ensures:

- Declarative infrastructure
- Automated reconciliation between Git and cluster state
- Audit history for all changes
- Self-healing capabilities

### Infrastructure Components

#### Ingress NGINX

The NGINX Ingress Controller provides:
- Layer 7 load balancing for HTTP/HTTPS traffic
- TLS termination
- Path-based routing
- Rate limiting and access control

#### MetalLB

Layer 2 load balancer that allows:
- IP allocation for LoadBalancer type services
- External accessibility of services from outside the cluster

#### Secrets Management

Two-tier approach with:

1. **HashiCorp Vault**:
   - Centralized secrets management
   - Dynamic secrets generation
   - Secret rotation

2. **Sealed Secrets**:
   - Encrypted secrets in Git
   - Decryption only within the cluster
   - Secure GitOps workflow for secrets

#### Certificate Management (cert-manager)

Provides:
- Automated certificate issuance
- Certificate renewal
- Support for multiple issuers (Let's Encrypt, self-signed, etc.)

### Observability Stack

#### Prometheus & Grafana

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Data visualization and dashboarding

#### Loki & Promtail

- Centralized log aggregation solution
- Log querying and visualization via Grafana

#### OpenTelemetry

- Distributed tracing
- Application performance monitoring
- Standardized observability data collection

### Security Components

- **RBAC**: Fine-grained access control
- **NetworkPolicies**: Network segmentation and traffic control
- **OPA/Kyverno**: Policy enforcement for compliance and security

## Network Architecture

```
External Traffic
      │
      ▼
┌──────────────┐
│  Ingress NGINX │
└──────────────┘
      │
      ▼
┌──────────────┐
│   Services   │
└──────────────┘
      │
      ▼
┌──────────────┐
│     Pods     │
└──────────────┘
```

## Data Flow

### Observability Data Flow

```
┌──────────┐     metrics     ┌─────────────┐
│   Pods   │─────────────────▶ Prometheus  │
└──────────┘                 └─────────────┘
     │                             │
     │ logs                        │
     ▼                             ▼
┌──────────┐                ┌─────────────┐
│ Promtail │───────────────▶│   Grafana   │
└──────────┘                └─────────────┘
     │                             ▲
     │                             │
     ▼                             │
┌──────────┐                       │
│   Loki   │───────────────────────┘
└──────────┘
``` 