# End-to-End Testing Framework

This directory contains the `e2e-test.sh` script, which provides a comprehensive end-to-end testing workflow for your Local Kubernetes Cluster. The script creates a fresh Minikube cluster, sets up all components, tests everything, and then optionally deletes the cluster.

## Overview

The `e2e-test.sh` script is designed to validate that your entire local Kubernetes environment works correctly from scratch. It:

1. Creates a fresh Minikube cluster with the specified resources
2. Sets up all core infrastructure components (cert-manager, vault, sealed-secrets, etc.)
3. Sets up networking components (ingress-nginx, metallb)
4. Sets up the observability stack (prometheus, grafana, loki)
5. Sets up applications (supabase)
6. Configures GitOps with Flux (if credentials are available)
7. Runs all tests to verify everything is working
8. Optionally deletes the cluster or keeps it running for further use

This is ideal for:
- CI/CD pipelines where you want to validate changes
- Verifying a clean installation of your environment
- Testing after significant updates to any component
- Ensuring development environments are correctly set up

## Prerequisites

Before running the script, ensure you have:

1. Minikube installed
2. kubectl installed
3. Helm installed
4. Sufficient system resources (default: 8GB RAM, 4 CPUs, 20GB disk)
5. (Optional) Flux CLI installed if you want to test GitOps workflow
6. (Optional) GitHub credentials (GITHUB_USER, GITHUB_REPO, GITHUB_TOKEN) for Flux setup

## Usage

### Basic Usage

To run the script with default settings (which will delete the cluster after testing):

```bash
./scripts/e2e-test.sh
```

### Keep the Cluster Running

If you want to keep the cluster running after tests complete:

```bash
./scripts/e2e-test.sh --keep-cluster
```

### Customize Resource Allocation

You can customize the resources allocated to Minikube:

```bash
./scripts/e2e-test.sh --memory=4096 --cpus=2 --disk-size=40g
```

### Verbose Output

For more detailed output during the process:

```bash
./scripts/e2e-test.sh --verbose
```

### Skip Tests

If you just want to set up the environment without running tests:

```bash
./scripts/e2e-test.sh --skip-tests --keep-cluster
```

### Set Custom Timeout

Set a custom timeout for component setup (default is 600 seconds):

```bash
./scripts/e2e-test.sh --timeout=1200
```

### All Options

```
Usage: ./scripts/e2e-test.sh [options]

Options:
  --memory=SIZE      Set Minikube memory in MB (default: 8192)
  --cpus=COUNT       Set Minikube CPU count (default: 4)
  --disk-size=SIZE   Set Minikube disk size (default: 20g)
  --driver=NAME      Set Minikube driver (default: docker)
  --keep-cluster     Keep the cluster after tests (default: false)
  --verbose          Enable verbose output (default: false)
  --skip-tests       Skip running tests (default: false)
  --timeout=SECONDS  Set timeout for component setup (default: 600)
  --help             Show this help message
```

## Setting Up GitOps with Flux

To include Flux GitOps in the testing, you'll need to export the following environment variables before running the script:

```bash
export GITHUB_USER="your-github-username"
export GITHUB_REPO="your-repository-name"
export GITHUB_TOKEN="your-personal-access-token"
./scripts/e2e-test.sh
```

If these variables are not set, the script will skip the Flux setup but continue with the rest of the components.

## Accessing Services

After running the script with the `--keep-cluster` option, you can access the following services:

- Grafana: https://grafana.local
- Prometheus: https://prometheus.local
- Vault: https://vault.local
- Supabase: https://supabase.local
- MinIO: https://minio.local

Make sure these domain names are properly configured in your `/etc/hosts` file. The script will attempt to add them if run with sudo privileges, or will provide instructions on how to add them manually.

## Troubleshooting

If the script fails during execution, you can:

1. Run with the `--verbose` flag to see more detailed output
2. Use the `--keep-cluster` flag to prevent cluster deletion on failure, allowing for manual inspection
3. Check specific component logs by running `kubectl logs -n <namespace> <pod-name>`
4. Look for errors in the script output, which will indicate which component failed
5. Run individual setup scripts for specific components to debug issues:
   - `./scripts/cluster/setup-core-infrastructure.sh`
   - `./scripts/cluster/setup-networking.sh`
   - `./scripts/cluster/setup-observability.sh`
   - `./scripts/cluster/setup-applications.sh`
   - `./scripts/cluster/setup-flux.sh`

## Integration with CI/CD

This script is designed to be easily integrated into CI/CD pipelines. For example, in a GitHub Actions workflow:

```yaml
name: End-to-End Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  e2e-test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Minikube
      uses: medyagh/setup-minikube@master
    - name: Install Helm
      uses: azure/setup-helm@v3
    - name: Install Flux CLI
      run: curl -s https://fluxcd.io/install.sh | sudo bash
    - name: Run End-to-End Test
      run: |
        export GITHUB_USER=${{ secrets.FLUX_GITHUB_USER }}
        export GITHUB_REPO=${{ secrets.FLUX_GITHUB_REPO }}
        export GITHUB_TOKEN=${{ secrets.FLUX_GITHUB_TOKEN }}
        ./scripts/e2e-test.sh --memory=4096 --cpus=2 --verbose
```

## Contributing

When extending or modifying this script, please follow these guidelines:

1. Maintain backward compatibility with existing command-line options
2. Add clear error messages and proper error handling
3. Use the logging functions for consistent output formatting
4. Test thoroughly with different configurations before submitting changes 