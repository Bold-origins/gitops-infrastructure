# Scripts Directory

This directory contains automation scripts for managing the Kubernetes cluster infrastructure and GitOps workflow.

## Directory Structure

The scripts are organized into the following categories:

### `/scripts/gitops/`

Scripts related to GitOps workflow and component refactoring:

- `refactor-workflow.sh` - End-to-end workflow for refactoring components
- `refactor-component.sh` - Core refactoring logic
- `cleanup-local-refactoring.sh` - Cleans up redundant files after refactoring
- `verify-local-refactoring.sh` - Verifies correct refactoring of components

### `/scripts/cluster/`

Scripts for cluster management and infrastructure:

- `setup-minikube.sh` - Sets up a local Minikube cluster with required addons
- `verify-environment.sh` - Verifies the cluster environment configuration
- `check_cluster.sh` - Performs health checks on the cluster
- `reconcile-components.sh` - Forces Flux to reconcile components
- `fix-flux-system.sh` - Fixes issues with Flux system configuration

### `/scripts/components/`

Component-specific scripts:

- `generate-supabase-secrets.sh` - Generates secrets for Supabase deployment
- `initialize_vault.sh` - Initializes the Vault instance
- `reset_vault.sh` - Resets the Vault instance to a clean state

### `/scripts/legacy/`

Less frequently used or deprecated scripts:

- `copy-observability.sh` - Copies observability components (legacy)
- `fix-helm-repo-conflicts.sh` - Fixes Helm repository conflicts (one-time fix)
- `setup-observability.sh` - Sets up observability stack (pre-refactoring)

## Usage

Most scripts provide help information and usage examples when run with the `-h` or `--help` flag.

### Common Operations

#### GitOps Refactoring

```bash
# Refactor a component
./scripts/gitops/refactor-workflow.sh <component-name> <component-type>

# Verify refactoring status
./scripts/gitops/verify-local-refactoring.sh

# Clean up redundant files
./scripts/gitops/cleanup-local-refactoring.sh
```

#### Cluster Management

```bash
# Set up a new Minikube cluster
./scripts/cluster/setup-minikube.sh

# Verify environment configuration
./scripts/cluster/verify-environment.sh

# Check cluster health
./scripts/cluster/check_cluster.sh
```

#### Component Operations

```bash
# Generate Supabase secrets
./scripts/components/generate-supabase-secrets.sh

# Initialize or reset Vault
./scripts/components/initialize_vault.sh
./scripts/components/reset_vault.sh
```

# Cluster Management Scripts

This directory contains scripts for managing and refactoring the Kubernetes cluster configurations.

## GitOps Refactoring Tools

The following scripts help refactor the local environment to use the base configurations through Kustomize overlays:

### refactor-workflow.sh

**Purpose**: End-to-end workflow for refactoring a component

**Usage**:
```bash
./scripts/refactor-workflow.sh component-name [component-type]
```

**Example**:
```bash
# Refactor cert-manager (infrastructure is the default type)
./scripts/refactor-workflow.sh cert-manager

# Refactor prometheus in the observability type
./scripts/refactor-workflow.sh prometheus observability
```

**Workflow**:
1. Verifies directories exist
2. Creates a backup of the local component
3. Refactors the component to use base configuration
4. Tests the refactored component with kustomize
5. Cleans up redundant files (with user confirmation)
6. Updates progress tracking documents
7. Adds progress update to implementation tracker
8. Shows next steps and remaining components

### refactor-component.sh

**Purpose**: Core script for refactoring a single component

**Usage**:
```bash
./scripts/refactor-component.sh component-name [component-type]
```

**Example**:
```bash
./scripts/refactor-component.sh ingress infrastructure
```

**Features**:
- Creates patches directory
- Generates kustomization.yaml referencing base configuration
- Analyzes base configuration to identify potential patch points
- Creates template patch files for common resource types:
  - Deployments (with local resource limits)
  - Services (with local annotations)
  - Ingresses (with local domains)
- Preserves local-specific helm values

### cleanup-local-refactoring.sh

**Purpose**: Cleans up redundant files after refactoring

**Usage**:
```bash
./scripts/cleanup-local-refactoring.sh
```

**Features**:
- Auto-discovers refactored components across all component types
- Identifies redundant files that are now sourced from base
- Moves redundant files to a timestamped backup directory
- Preserves essential files: kustomization.yaml, patches directory, helm values
- Provides summary of cleanup operations

### verify-local-refactoring.sh

**Purpose**: Verifies that the local environment is correctly refactored

**Usage**:
```bash
./scripts/verify-local-refactoring.sh
```

**Features**:
- Checks all components across all component types
- Verifies proper references to base configurations
- Identifies redundant files in the local environment
- Validates each component with kustomize
- Detects missing or incorrect patch files
- Provides detailed summary report and recommendations
- Shows components that still need to be refactored

## Keeping the Local Environment Clean

To ensure your local environment is clean and properly refactored, follow this process:

1. **Verify current state**:
   ```bash
   ./scripts/verify-local-refactoring.sh
   ```

2. **Refactor remaining components**:
   ```bash
   # For each component that needs refactoring
   ./scripts/refactor-workflow.sh component-name component-type
   ```

3. **Clean up redundant files**:
   ```bash
   ./scripts/cleanup-local-refactoring.sh
   ```

4. **Verify again**:
   ```bash
   ./scripts/verify-local-refactoring.sh
   ```

5. **Test functionality**:
   ```bash
   # For each component
   kubectl kustomize clusters/local/component-type/component-name
   kubectl apply -k clusters/local/component-type/component-name
   ```

## Workflow Diagram

```
┌─────────────────────┐
│ Start Refactoring   │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│ refactor-workflow.sh│◄────────┐
└──────────┬──────────┘         │
           ▼                    │
┌─────────────────────┐         │
│ Backup Component    │         │
└──────────┬──────────┘         │
           ▼                    │
┌─────────────────────┐         │
│refactor-component.sh│         │
└──────────┬──────────┘         │
           ▼                    │
┌─────────────────────┐         │
│ Test with Kustomize │         │
└──────────┬──────────┘         │
           ▼                    │
┌─────────────────────┐         │
│cleanup-redundant.sh │         │
└──────────┬──────────┘         │
           ▼                    │
┌─────────────────────┐         │
│ Update Progress Docs│         │
└──────────┬──────────┘         │
           ▼                    │
┌─────────────────────┐         │
│ Next Component?     │──Yes────┘
└──────────┬──────────┘
           │No
           ▼
┌─────────────────────┐
│verify-refactoring.sh│
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│ Done                │
└─────────────────────┘
```

## Best Practices

1. **Always review generated patches** - The scripts generate template patches that should be reviewed and customized for your specific local requirements.

2. **Test before cleaning up** - Always test the refactored component with `kubectl kustomize` before cleaning up redundant files.

3. **Commit changes** - Commit your changes after each component is successfully refactored.

4. **Maintain progress tracking** - The scripts automatically update progress tracking documents, but make sure to check them.

5. **Focus on local development needs** - Ensure patches focus on local development needs: reduced resources, simplified security, local domains, etc. 