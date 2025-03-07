# Component Intent Classifications

This document classifies the intent of different components in the codebase.

## Infrastructure Components

### cert-manager
**Intent:** Manage TLS certificates for secure communication
- Automate certificate issuance and renewal
- Configure certificate issuers (Let's Encrypt, self-signed, etc.)
- Provide TLS termination for ingress resources

### gatekeeper
**Intent:** Enforce security policies and governance
- Validate resources against policy constraints
- Prevent non-compliant resources from being created
- Implement custom admission control rules

### ingress
**Intent:** Manage external access to cluster services
- Configure ingress controllers for HTTP/HTTPS traffic
- Define routing rules for services
- Integrate with cert-manager for TLS

### metallb
**Intent:** Provide network load balancing
- Allocate external IPs to services
- Configure BGP or Layer 2 mode for IP allocation
- Enable LoadBalancer service type in bare-metal clusters

### minio
**Intent:** Provide S3-compatible object storage
- Store application data in a cloud-native way
- Configure buckets for different applications
- Integrate with applications that need object storage

### sealed-secrets
**Intent:** Securely manage Kubernetes secrets
- Encrypt secrets for safe storage in Git
- Allow automatic decryption in the cluster
- Enable GitOps workflows with secrets

### vault
**Intent:** Advanced secret management
- Centralize secret management
- Provide dynamic secrets
- Enable secret rotation and audit

## Observability Components

### grafana
**Intent:** Visualize metrics and logs
- Create dashboards for monitoring
- Configure data sources for metrics and logs
- Set up alerts based on visualizations

### loki
**Intent:** Aggregate and query logs
- Collect logs from all applications
- Enable structured log queries
- Integrate with Grafana for visualization

### prometheus
**Intent:** Collect and store metrics
- Scrape metrics from applications
- Store time-series data
- Enable alerting based on metrics

### opentelemetry
**Intent:** Distributed tracing
- Collect trace data from applications
- Correlate requests across services
- Visualize request flow and performance

## Application Components

### supabase
**Intent:** Provide backend services
- Manage database access
- Provide authentication and authorization
- Enable real-time subscriptions
- Store and retrieve files

## Script Components

### setup scripts
**Intent:** Automate environment setup
- Configure local development environment
- Install and configure Kubernetes components
- Ensure consistent environment across team

### gitops scripts
**Intent:** Manage GitOps workflows
- Refactor components for GitOps
- Verify local refactoring
- Clean up temporary resources