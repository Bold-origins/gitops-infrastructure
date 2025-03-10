#!/bin/bash
# unify-infrastructure.sh: Script to unify infrastructure and infrastructure-stage2
# This script creates backups and removes redundant files

set -e

# Source UI helpers
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../lib/ui.sh"

# Create a timestamped backup directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${SCRIPT_DIR}/../../../backups/infrastructure_unification_${TIMESTAMP}"

# Display header
ui_header "Infrastructure Unification"
ui_log_info "Backing up files before unification to: $BACKUP_DIR"

# Create backup directories
mkdir -p "$BACKUP_DIR/clusters/local"

# Backup files
ui_log_info "Creating backups of infrastructure configuration"
cp -r "${SCRIPT_DIR}/../../../clusters/local/infrastructure-stage2" "$BACKUP_DIR/clusters/local/"
cp "${SCRIPT_DIR}/../../../clusters/local/infrastructure-stage2.yaml" "$BACKUP_DIR/clusters/local/"

# Check if files exist before proceeding
if [ ! -f "${SCRIPT_DIR}/../../../clusters/local/infrastructure-stage2.yaml" ] || [ ! -d "${SCRIPT_DIR}/../../../clusters/local/infrastructure-stage2" ]; then
  ui_log_warning "Infrastructure stage2 files not found - they may have already been removed"
  exit 0
fi

# Confirm removal
if ! ui_confirm "Are you sure you want to remove infrastructure-stage2 files?" "n"; then
  ui_log_info "Operation cancelled"
  exit 0
fi

# Remove infrastructure-stage2 files
ui_log_warning "Removing infrastructure-stage2.yaml"
rm "${SCRIPT_DIR}/../../../clusters/local/infrastructure-stage2.yaml"

ui_log_warning "Removing infrastructure-stage2 directory"
rm -rf "${SCRIPT_DIR}/../../../clusters/local/infrastructure-stage2"

# Success message
ui_log_success "Infrastructure unification complete!"
ui_log_info "The main infrastructure kustomization now contains all components in proper order."
ui_log_info "Backup saved to: $BACKUP_DIR"
ui_log_info "You can now use Flux to deploy all infrastructure components in a single reconciliation."

exit 0 