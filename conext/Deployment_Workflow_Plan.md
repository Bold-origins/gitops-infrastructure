# Kubernetes Deployment Workflow Plan
**Local → Staging → Production**

## Executive Summary

This document outlines the complete deployment workflow from local development environments to staging and production for our Kubernetes-based application infrastructure. The plan leverages GitOps principles with separate environments while maintaining consistency and providing a clear promotion path for changes.

## Environment Architecture

### Local Development Environment
- **Purpose**: Individual developer environments for feature development and testing
- **Infrastructure**: Minikube on developer machines
- **Resources**: 2-4GB RAM, 2 CPUs (developer machine dependent)
- **Users**: Individual developers
- **Domain Pattern**: *.local

### Staging Environment 
- **Purpose**: Integration testing, pre-production verification
- **Infrastructure**: K3s on dedicated VPS
- **Resources**: 2 vCPUs, 8GB RAM
- **Users**: QA team, developers for integration testing, automated tests
- **Domain Pattern**: *.staging.example.com

### Production Environment
- **Purpose**: Live environment serving end users
- **Infrastructure**: Kubernetes on dedicated high-resource VPS
- **Resources**: 8 vCPUs, 32GB RAM
- **Users**: End users, monitored by operations team
- **Domain Pattern**: *.example.com

## GitOps Repository Structure

```
clusters/
├── base/                    # Shared base configurations
│   ├── infrastructure/      # Core infrastructure components
│   ├── monitoring/          # Monitoring and observability stack
│   └── applications/        # Application templates
├── local/                   # Local development overlays
│   ├── kustomization.yaml   # Local overrides for Minikube
│   ├── infrastructure/      # Minimal infrastructure for development
│   ├── monitoring/          # Lightweight monitoring
│   └── applications/        # Application configurations
├── staging/                 # Staging overlays
│   ├── kustomization.yaml   # Staging-specific configuration
│   ├── infrastructure/      # Adjusted for staging VPS
│   ├── monitoring/          # Scaled monitoring stack
│   └── applications/        # Pre-production applications
└── production/              # Production overlays
    ├── kustomization.yaml   # Production configuration
    ├── infrastructure/      # Full-scale infrastructure
    ├── monitoring/          # Complete monitoring
    └── applications/        # Production applications
```

## Branching Strategy

### Branch Structure
- **main**: Production-ready code
- **develop**: Integration branch for features
- **feature/[name]**: Feature development
- **release/[version]**: Preparing for release to production
- **hotfix/[issue]**: Emergency fixes for production

### Branch Protection Rules
- **main**: Requires approvals and passing CI checks; no direct commits
- **develop**: Requires CI checks; no direct commits
- **release/**: Requires approvals and passing CI checks

## Development to Deployment Workflow

### 1. Local Development
- **Setup**: Developer runs `./scripts/setup-minikube.sh` to initialize environment
- **Development Cycle**:
  - Create feature branch
  - Make code changes
  - Build and test locally
  - Deploy to local Minikube cluster using `clusters/local` configurations
  - Validate functionality

### 2. Code Review & Integration
- **Process**:
  - Push feature branch to remote repository
  - Create PR against develop branch
  - CI runs automated tests
  - Team performs code review
  - Iterate on feedback if necessary

### 3. Staging Deployment
- **Trigger**: Merge of approved PR to develop branch
- **Process**:
  - CI/CD pipeline automatically deploys to staging VPS
  - Flux syncs changes from `clusters/staging`
  - Run integration and system tests
  - QA team validates functionality
  - Gather feedback from stakeholders

### 4. Production Deployment
- **Preparation**:
  - Create release branch from develop
  - Final testing on release branch
  - Version tagging and release notes
- **Deployment**:
  - Merge release to main branch with approval
  - CI/CD pipeline deploys to production VPS
  - Flux syncs changes from `clusters/production`
  - Verify deployment with smoke tests
  - Monitor for issues

## Environment Configuration Management

### Base Configurations
- Shared components defined in `clusters/base`
- Common settings and defaults for all environments
- Template manifests for customization

### Environment-Specific Configurations
- **Local**: Development-friendly settings, reduced resources
- **Staging**: Pre-production settings, moderate resources
- **Production**: Full settings, appropriate resources for live traffic

### Configuration Strategy
- Use Kustomize overlays to modify base resources for each environment
- Store environment-specific variables in:
  - `.env.local`
  - `.env.staging`
  - `.env.production`
- ConfigMaps and Secrets generated from these files

## Secrets Management

### Sealed Secrets
- Different encryption keys for each environment
- Environment-specific `sealedsecrets-*` namespaces
- Sealed secrets stored in Git under appropriate environment directories

### Vault Integration
- Separate Vault instances for each environment
- Environment-specific authentication methods
- Kubernetes service accounts for pod authentication
- Strict access policies for each environment

## CI/CD Pipeline Architecture

### Pipeline Components
- GitHub Actions or GitLab CI for automation
- FluxCD for GitOps-based deployments
- Automated testing framework
- Notification system for deployment events

### Pipeline Stages

#### PR Validation
- Code linting and formatting
- Unit tests
- Security scans
- Build verification

#### Staging Deployment
- Build container images
- Update staging manifests
- Deploy to staging environment
- Run integration tests
- Notify team of deployment status

#### Production Deployment
- Manual approval gate
- Build production images (or promote staging images)
- Update production manifests
- Deploy to production environment
- Run smoke tests
- Verify critical services
- Notify team of deployment completion

## Rollback Strategy

### Automatic Rollbacks
- Monitor key health metrics during deployment
- Define rollback thresholds for error rates and latency
- Automated rollback for failed deployments

### Manual Rollbacks
- Historical versioning in Git
- Tagged releases for stable points
- Rollback command: `./scripts/deployment/rollback.sh [environment] [version]`

## Promotion Process

### Staging to Production Promotion
- Manual approval required
- Verification of staging tests
- Security review for sensitive changes
- Promotion command: `./scripts/deployment/promote.sh [component] [staging] [production]`

### Promotion Validation
- Configuration validation before application
- Resource requirement checks
- Security policy verification
- Connectivity testing

## Resource Management

### Local Environment
- Minimal resource configuration
- Single replicas for services
- Development-friendly resource limits

### Staging Environment
- Moderately scaled resources
- Appropriate for 2 vCPU, 8GB RAM VPS
- Reduced replica counts where appropriate

### Production Environment
- Full resource allocation
- Properly sized for 8 vCPU, 32GB RAM VPS
- Appropriate replica counts for reliability

## Monitoring and Observability

### Local Monitoring
- Basic Prometheus and Grafana
- Local log collection
- Development-focused dashboards

### Staging Monitoring
- Complete monitoring stack at reduced scale
- Full metrics collection with shorter retention
- Key alerting configured (notifications to Slack)

### Production Monitoring
- Full-scale monitoring deployment
- Extended metrics retention
- Complete alerting configuration
- Performance dashboards

## Implementation Plan

### Phase 1: Local Development Standardization (Week 1-2)
- Finalize local Minikube setup procedures
- Document local development workflow
- Create helper scripts for local environment

### Phase 2: Staging Environment Setup (Week 3-4)
- Provision staging VPS
- Install K3s and core components
- Configure Flux for staging environment
- Set up CI/CD pipeline for staging deployment

### Phase 3: Production Environment Preparation (Week 5-6)
- Provision production VPS
- Install Kubernetes and core components
- Configure Flux for production environment
- Implement production security measures

### Phase 4: Complete Workflow Implementation (Week 7-8)
- Integrate CI/CD pipeline with all environments
- Test complete deployment workflow
- Document operations procedures
- Train team on workflow

## Required Scripts and Tools

### Environment Setup Scripts
- `./scripts/setup-minikube.sh` - Local environment setup
- `./scripts/setup-staging.sh` - Staging VPS setup
- `./scripts/setup-production.sh` - Production VPS setup

### Development Helper Scripts
- `./scripts/verify-environment.sh` - Verify environment setup
- `./scripts/local-dev.sh` - Development mode with hot reloading
- `./scripts/test-local.sh` - Run tests in local environment

### Deployment Scripts
- `./scripts/deployment/promote.sh` - Promote between environments
- `./scripts/deployment/rollback.sh` - Rollback to previous version
- `./scripts/deployment/validate-deployment.sh` - Validate deployment

### CI/CD Integration Scripts
- `./scripts/ci/build-and-push.sh` - Build and push container images
- `./scripts/ci/update-manifests.sh` - Update Kubernetes manifests
- `./scripts/ci/run-tests.sh` - Run appropriate tests for environment

## Documentation Requirements

### Developer Documentation
- Local environment setup guide
- Development workflow procedures
- Testing standards
- PR and code review process

### Operations Documentation
- Environment setup procedures
- Deployment and rollback procedures
- Monitoring and alerting guide
- Incident response playbook

### Architecture Documentation
- Environment architecture diagrams
- Network flow diagrams
- Security architecture
- Data flow documentation

## Success Criteria

1. Developers can easily set up and use local environment
2. Changes can be reliably promoted from local to staging to production
3. Environments are appropriately isolated and secured
4. Rollbacks can be performed quickly and safely
5. Monitoring provides appropriate visibility into all environments
6. Complete workflow is well-documented and understood by the team

---

## Appendix A: Environment-Specific Configuration Details

### Local Environment
- Single-node Minikube cluster
- Self-signed certificates
- Local domain resolution via /etc/hosts
- Development-mode services
- Debug logging enabled

### Staging Environment
- Single-node K3s
- Let's Encrypt staging certificates
- Reduced resource requests and limits
- Full application stack at reduced scale
- Test data and non-sensitive configuration

### Production Environment
- Standard Kubernetes
- Valid TLS certificates
- Appropriate resource allocation
- Full application stack
- Production data and configuration

## Appendix B: Networking Configuration

### Domain Structure
- Local: service-name.local
- Staging: service-name.staging.example.com
- Production: service-name.example.com

### Ingress Configuration
- All environments use ingress-nginx
- Environment-specific TLS configuration
- Rate limiting in production only
- Authentication differences per environment 