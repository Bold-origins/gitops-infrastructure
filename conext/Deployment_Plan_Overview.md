## GitOps Workflow

Our GitOps workflow follows these principles:

1. **Infrastructure as Code**:

   - All environment configurations stored in Git
   - Kustomize used for environment-specific overlays
   - Common configurations stored in base directory
   - Standardized naming across environments (observability over monitoring)

2. **Pull-Based Deployments**:

   - Flux monitors repository for changes
   - Changes to environment directories trigger deployments
   - No direct cluster modifications outside the GitOps workflow

3. **Progressive Deployment**:
   - Changes flow from local → staging → production
   - Each environment serves as validation for the next
   - Promotion scripts facilitate proper configuration transfer 