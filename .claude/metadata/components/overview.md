# Repository Component Overview

## Core Components

### Cluster Infrastructure
- **clusters/base/infrastructure** - Base infrastructure configurations
- **clusters/base/observability** - Monitoring and observability stack
- **clusters/base/applications** - Application configurations
- **clusters/base/policies** - Cluster security policies

### GitOps
- **scripts/gitops** - GitOps automation scripts
- **scripts/cluster** - Cluster setup scripts
- **scripts/components** - Component management scripts
- **scripts/promotion** - Environment promotion scripts

### Documentation
- **conext/** - Project context and requirements
- **docs/** - User documentation

## Component Relationships

```mermaid
graph TD
    A[clusters/base] --> B[infrastructure]
    A --> C[observability]
    A --> D[applications]
    A --> E[policies]
    
    B --> B1[cert-manager]
    B --> B2[gatekeeper]
    B --> B3[ingress]
    B --> B4[metallb]
    B --> B5[minio]
    B --> B6[policy-engine]
    B --> B7[sealed-secrets]
    B --> B8[security]
    B --> B9[vault]
    
    C --> C1[common]
    C --> C2[grafana]
    C --> C3[loki]
    C --> C4[namespace]
    C --> C5[network]
    C --> C6[opentelemetry]
    C --> C7[prometheus]
    
    D --> D1[supabase]
    
    scripts --> S1[gitops]
    scripts --> S2[cluster]
    scripts --> S3[components]
    scripts --> S4[promotion]
```