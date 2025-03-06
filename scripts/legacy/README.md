# Legacy Scripts

This directory contains scripts that are either deprecated, superseded by newer scripts, or only occasionally needed for specific one-time operations.

## Available Scripts

- `copy-observability.sh` - Copies observability components (superseded by GitOps refactoring)
- `fix-helm-repo-conflicts.sh` - Fixes Helm repository conflicts (one-time fix script)
- `setup-observability.sh` - Sets up observability stack (pre-refactoring approach)

## Usage Notes

These scripts are maintained for reference or occasional use but are not part of the primary workflow.

### When to Use Legacy Scripts

You might need these scripts when:

1. Troubleshooting historical issues
2. Working with components that haven't been fully refactored
3. Performing specialized operations that aren't part of the standard GitOps workflow

### Observability Setup (Legacy)

The observability setup has been refactored into the GitOps workflow, but if needed:

```bash
./setup-observability.sh
```

### Fixing Helm Repository Conflicts

If you encounter conflicts with duplicate Helm repositories:

```bash
./fix-helm-repo-conflicts.sh
```

## Maintenance

Before using these scripts:

1. Check if there's a newer alternative in the main script directories
2. Make sure you understand the potential impact on the refactored GitOps structure
3. Consider updating the script to work with the current architecture if it's needed frequently

## Future Plans

Scripts in this directory may be:

- Refactored to work with the new GitOps structure
- Incorporated into other scripts as functions
- Deprecated and eventually removed when no longer needed 