# Enhanced Setup Scripts

This directory contains enhanced setup scripts designed to make the local development workflow more streamlined and consistent.

## Available Scripts

### 1. `init-environment.sh`

**Purpose**: Initialize the local development environment with Minikube and load environment variables.

**Usage**:
```bash
./scripts/setup/init-environment.sh
```

**What it does**:
- Loads environment variables from `.env` file and verifies their presence
- Checks for prerequisites (minikube, kubectl)
- Manages Minikube cluster (creates/deletes as needed)
- Sets up Minikube with proper resources (memory, CPUs, disk space)
- Enables required addons (ingress, metrics-server, storage-provisioner)
- Verifies kubectl context is set correctly
- Provides next steps for deployment

**Parameters**: 
These can be set in the `.env` file or as environment variables:
- `MINIKUBE_MEMORY`: Memory allocation in MB (default: 6144)
- `MINIKUBE_CPUS`: Number of CPUs (default: 4)
- `MINIKUBE_DISK_SIZE`: Disk space (default: 20g)
- `MINIKUBE_DRIVER`: Virtualization driver (default: docker)

## Complete Setup Workflow

For a full local development environment setup, follow these steps:

1. **Initialize Environment**:
   ```bash
   ./scripts/setup/init-environment.sh
   ```

2. **Deploy All Components**:
   ```bash
   ./scripts/cluster/setup-all.sh
   ```

3. **Verify Environment**:
   ```bash
   ./scripts/cluster/verify-environment.sh
   ```

## Common Issues and Solutions

- **Memory/CPU Issues**: If Minikube fails to start due to resource constraints, modify the parameters in `.env` or pass them directly to the init script.

- **GitHub Authentication**: Ensure your GitHub credentials are properly set in the `.env` file for Flux GitOps to work correctly.

- **Component Deployment Failures**: If specific components fail to deploy, check logs in the 'logs/cluster-setup' directory for detailed error messages.

## Cleanup

To stop the Minikube cluster when not in use:
```bash
minikube stop
```

To completely delete the environment:
```bash
minikube delete
``` 