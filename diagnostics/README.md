# Kubernetes Cluster Diagnostics

This directory contains a set of diagnostic tools for analyzing and troubleshooting Kubernetes clusters. These tools are designed to work in resource-constrained environments like Minikube, as well as in production environments.

## Overview

The diagnostic tools provide comprehensive checks for:
- Cluster health
- GitOps (Flux) status
- Secrets management
- Security policies
- Observability systems
- Backup systems
- Documentation

## Usage

### Running All Diagnostics

To run all diagnostic checks and generate a summary report:

```bash
./run_diagnostics.sh [environment] [mode]
```

Parameters:
- `environment`: The environment to run diagnostics for (default: `local`)
- `mode`: Use `light` for resource-constrained environments (default: `normal`)

Example:
```bash
# Run diagnostics for local environment in lightweight mode
./run_diagnostics.sh local light

# Run diagnostics for production environment in normal mode
./run_diagnostics.sh production
```

### Running Individual Checks

You can also run individual diagnostic checks:

```bash
# Check cluster health
./diagnostics/check_cluster_health.sh [light] [environment]

# Check Flux health
./diagnostics/check_flux_health.sh [light] [environment]

# Check secrets management
./diagnostics/check_secrets.sh [environment]

# Check security policies
./diagnostics/check_security.sh [environment]

# Check observability systems
./diagnostics/check_observability.sh [environment]

# Check backup systems
./diagnostics/check_backups.sh [environment]

# Check documentation
./diagnostics/check_documentation.sh [environment]
```

### Generating a Summary Report

To generate a summary report from existing diagnostic reports:

```bash
./diagnostics/create_phase1_report.sh [environment]
```

## Report Structure

All diagnostic reports are saved in the `diagnostics/reports/[environment]/` directory with the following naming convention:
- `diagnostics_report_cluster_YYYYMMDD_HHMMSS.md`: Cluster health report
- `diagnostics_report_flux_YYYYMMDD_HHMMSS.md`: Flux health report
- `diagnostics_report_secrets_YYYYMMDD_HHMMSS.md`: Secrets management report
- `diagnostics_report_security_YYYYMMDD_HHMMSS.md`: Security policies report
- `diagnostics_report_observability_YYYYMMDD_HHMMSS.md`: Observability systems report
- `diagnostics_report_backups_YYYYMMDD_HHMMSS.md`: Backup systems report
- `diagnostics_report_documentation_YYYYMMDD_HHMMSS.md`: Documentation report
- `phase1_summary_report_YYYYMMDD_HHMMSS.md`: Summary report

## Lightweight Mode

The `light` mode is designed for resource-constrained environments like Minikube. It skips resource-intensive checks and limits the output to essential information. This is useful when running diagnostics on a system with limited resources.

## Troubleshooting

If you encounter issues with the diagnostic tools:

1. Check that the Kubernetes cluster is running:
   ```bash
   kubectl cluster-info
   ```

2. Ensure that the diagnostic scripts are executable:
   ```bash
   chmod +x run_diagnostics.sh
   chmod +x diagnostics/*.sh
   ```

3. Check for errors in the diagnostic reports in the `diagnostics/reports/[environment]/` directory.

## Extending the Diagnostics

To add a new diagnostic check:

1. Create a new script in the `diagnostics/` directory
2. Follow the pattern of existing scripts
3. Ensure the script creates a report in the `diagnostics/reports/[environment]/` directory
4. Update the `run_diagnostics.sh` script to include the new check

## System Requirements

- Bash shell
- kubectl configured to access the Kubernetes cluster
- Flux CLI (for Flux-related checks)
- jq (for JSON processing)

## License

This project is licensed under the MIT License - see the LICENSE file for details. 