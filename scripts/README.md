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