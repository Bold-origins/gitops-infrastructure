# Scripts Directory

This directory contains all the scripts used to maintain, diagnose, and interact with the cluster.

## Directory Structure

- **cluster-management/** - Scripts for setting up, configuring, and cleaning up clusters
  - `setup-cluster.sh` - Sets up a new cluster
  - `cleanup-cluster.sh` - Cleans up a cluster when no longer needed

- **connectivity/** - Scripts for establishing connectivity to cluster services
  - `port-forward.sh` - Sets up port forwarding for accessing cluster services
  - `kubefwd-setup.sh` - Configures kubefwd for accessing services
  - `fix-tunnel.sh` - Troubleshooting script for tunnel issues

- **diagnostics/** - Scripts for diagnosing and troubleshooting issues
  - `run_diagnostics.sh` - Run diagnostics on the cluster
  - `create_phase1_report.sh` - Creates a diagnostic report

## Usage

Most scripts can be run directly from the command line:

```bash
./scripts/cluster-management/setup-cluster.sh
```

Make sure to make the scripts executable if needed:

```bash
chmod +x scripts/cluster-management/setup-cluster.sh
```

# Cluster Management Scripts

This directory contains scripts for managing the local Kubernetes cluster infrastructure.

## Available Scripts

- `setup-minikube.sh` - Sets up a local Minikube cluster with required addons and configurations
- `verify-environment.sh` - Verifies the cluster environment configuration and prerequisites
- `check_cluster.sh` - Performs health checks on the cluster components
- `reconcile-components.sh` - Forces Flux to reconcile components
- `fix-flux-system.sh` - Fixes issues with Flux system configuration

## Usage Examples

### Setting Up a New Minikube Cluster

```bash
./setup-minikube.sh
```

This script will:
- Install Minikube if not already installed
- Configure necessary resources
- Set up Kubernetes with the correct version
- Enable required addons
- Prepare the environment for GitOps

### Verifying Environment

```bash
./verify-environment.sh
```

This script checks:
- Required tools are installed
- Kubernetes version compatibility
- Flux installation status
- Required namespaces existence
- CRD installations

### Checking Cluster Health

```bash
./check_cluster.sh
```

Performs health checks on:
- Node status
- Control plane components
- Critical infrastructure pods
- Storage provisioners
- Networking components

### Reconciling Components

```bash
./reconcile-components.sh [component-name]
```

Forces Flux to reconcile specific or all GitOps components.

### Fixing Flux System

```bash
./fix-flux-system.sh
```

Fixes common issues with Flux system configuration and reconciliation.

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