# Kubernetes Cluster Testing Framework

This directory contains a comprehensive set of testing scripts to verify your local Kubernetes environment is properly set up according to the project requirements.

## Overview

The testing framework consists of several scripts that validate different aspects of your local Kubernetes cluster:

1. **test-environment.sh**: Tests the basic environment setup, checking all core infrastructure components, observability tools, and GitOps structure.
2. **test-web-interfaces.sh**: Tests connectivity to all web interfaces (Grafana, Prometheus, Vault, etc.), verifying ingress configuration.
3. **test-gitops-workflow.sh** (in scripts/gitops/): Tests the GitOps workflow with Flux, verifying that changes to the repository are properly reconciled.
4. **test-all.sh**: A comprehensive test runner that executes all the tests above in sequence.

## Prerequisites

Before running the tests, ensure you have:

1. A running Minikube cluster set up with the project components
2. kubectl installed and configured to connect to your Minikube cluster
3. Flux CLI installed (for GitOps workflow tests)
4. Proper entries in your /etc/hosts file for local domain resolution

## Usage

### Running All Tests

To run the complete test suite:

```bash
./scripts/cluster/test-all.sh
```

This will execute all tests in sequence and provide a comprehensive summary at the end.

### Running Individual Tests

You can also run individual test scripts to focus on specific areas:

```bash
# Test basic environment
./scripts/cluster/test-environment.sh

# Test web interfaces
./scripts/cluster/test-web-interfaces.sh

# Test GitOps workflow
./scripts/gitops/test-gitops-workflow.sh
```

## Test Details

### Environment Tests

The environment tests check:

- Minikube status and configuration
- Core infrastructure components (cert-manager, vault, sealed-secrets, etc.)
- Networking components (ingress-nginx, metallb)
- Observability stack (prometheus, grafana, loki)
- GitOps structure (directory organization, Flux setup)

### Web Interface Tests

The web interface tests verify:

- Ingress controller configuration
- Domain name resolution in /etc/hosts
- Connectivity to all web interfaces:
  - Grafana (https://grafana.local)
  - Prometheus (https://prometheus.local)
  - Vault (https://vault.local)
  - Supabase (https://supabase.local)
  - MinIO (if configured)

### GitOps Workflow Tests

The GitOps workflow tests validate:

1. Flux's proper synchronization with the git repository
2. Deployment of new resources through the GitOps workflow
3. Updates to existing resources
4. Proper pruning of removed resources

## Troubleshooting

If tests fail, review the output for specific error messages. Common issues include:

1. **Component Installation Issues**: Check Kubernetes logs and ensure all required components are properly installed
2. **Ingress/Network Issues**: Verify that ingress-nginx and metallb are properly configured
3. **Domain Resolution**: Ensure your /etc/hosts file has the correct entries for all local domains
4. **GitOps Workflow**: Check Flux logs and ensure your git repository is properly configured

## What's Next

After successfully passing all tests, you can proceed with:

1. Finalizing the directory structure for staging and production environments
2. Implementing the promotion workflow scripts as noted in the progress document
3. Moving on to subsequent milestones in the project roadmap

## Contributing

If you encounter specific issues or want to extend the tests, please:

1. Document the issue or enhancement clearly
2. Follow the existing code style and naming conventions
3. Add proper error handling and informative messages
4. Update this README if adding new test capabilities 