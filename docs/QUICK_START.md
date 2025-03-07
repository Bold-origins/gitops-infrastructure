# Quick Start Guide

This guide provides the fastest path to get your local GitOps infrastructure up and running.

## Prerequisites

Ensure you have these tools installed on your machine:
- Docker
- Minikube v1.30+
- kubectl v1.28+
- Flux CLI
- Git

## 1. Clone the Repository

```bash
git clone https://github.com/yourusername/cluster.git
cd cluster
```

## 2. Set Up Environment Variables

Create or update your `.env` file with the required credentials:

```bash
# GitHub credentials for Flux GitOps
GITHUB_USER=your-github-username
GITHUB_REPO=gitops-infrastructure
GITHUB_TOKEN=your-github-token

# MinIO credentials
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# Vault credentials
VAULT_ADDR=http://localhost:8200
VAULT_UNSEAL_KEY="Replace with actual key"
VAULT_ROOT_TOKEN="Replace with actual token"
```

## 3. Initialize the Environment

Start Minikube with the recommended resource allocation:

```bash
./scripts/setup/init-environment.sh
```

## 4. Deploy Components (Recommended Approach)

Deploy components one by one with better control and visibility:

```bash
./scripts/gitops/component-deploy.sh
```

## 5. Check Progress

At any time, you can check the status of your deployment:

```bash
./scripts/gitops/show-progress.sh
```

## 6. Access Services

Add the following to your `/etc/hosts` file:

```
$(minikube ip) grafana.local prometheus.local vault.local minio.local supabase.local
```

Access services via:
- Vault: https://vault.local
- Grafana: https://grafana.local
- Prometheus: https://prometheus.local
- MinIO: https://minio.local
- Supabase: https://supabase.local

## Troubleshooting

If you encounter issues:

1. Check component status:
   ```bash
   ./scripts/gitops/diagnose-component.sh <component-name>
   ```

2. View detailed documentation:
   ```bash
   cat docs/TROUBLESHOOTING.md
   ```

3. Reset and start over if needed:
   ```bash
   ./scripts/gitops/cleanup.sh
   ```

## Next Steps

- Initialize Vault: [docs/LOCAL_DEVELOPMENT.md#vault](docs/LOCAL_DEVELOPMENT.md#vault)
- Configure applications: [docs/LOCAL_DEVELOPMENT.md#component-specific-guides](docs/LOCAL_DEVELOPMENT.md#component-specific-guides)
- Explore advanced topics: [docs/LOCAL_DEVELOPMENT.md#advanced-topics](docs/LOCAL_DEVELOPMENT.md#advanced-topics) 