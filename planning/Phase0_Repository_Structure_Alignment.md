# Phase 0: Repository Structure Alignment

## Executive Summary

Before proceeding to Phase 2 (Staging Environment Setup) of our Deployment Workflow Plan, we need to align our repository structure with the GitOps principles outlined in our documentation. This preparatory phase will establish the proper foundation for multi-environment deployments by creating a base configuration that all environments will reference and refactoring our existing local environment to use proper Kustomize overlays.

## Current Status

- We have a functional `clusters/local/` directory for Minikube deployments
- Documentation describes a structure with `base/`, `local/`, `staging/`, and `production/` directories
- We've implemented a single-environment GitOps workflow for local development
- We need to prepare for multi-environment deployment workflow

## Goals

1. Restructure the repository to match the documented GitOps pattern
2. Extract common configurations into a shared base directory
3. Implement proper Kustomize overlays for environment-specific configurations
4. Create the directory structure for staging and production environments
5. Establish the workflow for promoting changes between environments

## Implementation Plan

### Step 1: Create Base Configuration Directory

```bash
mkdir -p clusters/base/{infrastructure,monitoring,applications}
```

Extract common configurations from the local environment into the base directory:

- Core infrastructure components (cert-manager, sealed-secrets, vault, etc.)
- Monitoring stack base configurations (prometheus, grafana, alertmanager)
- Application templates and shared resources

### Step 2: Refactor Local Environment as Kustomize Overlay

Update `clusters/local/` to reference base configurations using Kustomize overlays:

- Keep only local-specific overrides (resource limits, local domains, etc.)
- Update `kustomization.yaml` files to reference the corresponding base components
- Test to ensure functionality remains identical to the previous structure

### Step 3: Create Staging and Production Directory Structure

```bash
mkdir -p clusters/staging/{infrastructure,monitoring,applications}
mkdir -p clusters/production/{infrastructure,monitoring,applications}
```

Create initial Kustomization files in each directory:

- Create `kustomization.yaml` files that reference base configurations
- Add environment-specific patches (resource specifications, replicas, etc.)
- Include placeholders for future components

### Step 4: Implement Promotion Workflow

Develop scripts to facilitate the promotion of configurations between environments:

```bash
mkdir -p scripts/deployment
touch scripts/deployment/promote.sh
chmod +x scripts/deployment/promote.sh
```

Design the promotion script to:
- Copy a component's configuration from one environment to another
- Apply appropriate transformations for the target environment
- Validate the resulting configuration

### Step 5: Document the Updated Structure and Workflow

Update documentation to reflect the new repository structure:

- Update README.md with accurate directory structure
- Create or update environment-specific documentation
- Document the promotion workflow process
- Add details on branching strategy and code review processes

## Branching Strategy

We will implement a single-branch GitOps model with environment separation through directories:

- Developers work in feature branches (`feature/new-component`)
- Changes that affect multiple environments are made within a single PR
- PRs are reviewed with special attention to environment-specific directories
- Branch protection rules ensure proper approvals for staging and production changes

### Branch Protection Recommendations

- `main` branch: Requires approvals and passing CI checks
- Reviews required for changes to `clusters/staging/` and `clusters/production/`
- CI checks validate Kustomize overlays for all affected environments

## Success Criteria

1. Repository structure matches the documentation
2. Local environment functions correctly with the new structure
3. Team understands the promotion workflow
4. Directory structure is ready for Phase 2 (Staging Environment Setup)

## Timeline

- Repository restructuring: 1-2 days
- Documentation updates: 1 day
- Testing and verification: 1 day
- Team onboarding: 1 day

Total estimated time: 3-5 days

## Dependencies

- Existing functional local environment
- Understanding of Kustomize overlay patterns
- Team agreement on GitOps workflow

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Disruption to local development | High | Perform changes in a feature branch and thoroughly test before merging |
| Incomplete extraction of base components | Medium | Review each component carefully and validate with Kustomize build |
| Confusion about new workflow | Medium | Document clearly and conduct a team walkthrough session |

## Next Steps After Completion

Upon successful completion of Phase 0, we will be ready to proceed with Phase 2 of our Deployment Workflow Plan:

1. Provision staging VPS
2. Install K3s and core components
3. Configure Flux for staging environment
4. Set up CI/CD pipeline for staging deployment 