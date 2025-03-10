#!/bin/bash
# purge-legacy.sh: Aggressively clean up all legacy scripts
# Keeps only the essential components of the new modular architecture

set -e

# Source UI helpers
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../lib/ui.sh"

# Create a timestamped backup directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${SCRIPT_DIR}/../../../backups/legacy_scripts_${TIMESTAMP}"

# Display header
ui_header "Complete GitOps Scripts Purge"
ui_log_info "Backing up all scripts before purging to: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR/scripts/gitops"

# First backup everything
ui_log_info "Creating complete backup of scripts/gitops directory"
cp -r "${SCRIPT_DIR}/../../"* "$BACKUP_DIR/scripts/gitops/"

# Essential components to KEEP - everything else will be removed
KEEP_PATHS=(
  # Core libraries
  "scripts/gitops/lib"
  
  # Component scripts directory and components
  "scripts/gitops/components"
  
  # Main orchestration scripts
  "scripts/gitops/deploy-component.sh"
  "scripts/gitops/diagnose-component.sh"
  
  # Operation scripts
  "scripts/gitops/operations/clean.sh"
  
  # Documentation
  "scripts/gitops/README.md"
)

# Find all files/directories in scripts/gitops
ui_log_info "Finding all files to evaluate for removal"
GITOPS_FILES=$(find "${SCRIPT_DIR}/../../" -type f -o -type d | grep -v "^${SCRIPT_DIR}/../../lib\|^${SCRIPT_DIR}/../../components\|^${SCRIPT_DIR}/../../operations" | sort)

# Function to check if path should be kept
should_keep() {
  local path="$1"
  
  # Keep the current script
  if [[ "$path" == *"purge-legacy.sh"* ]]; then
    return 0
  fi
  
  # Check if path matches any keep pattern
  for keep in "${KEEP_PATHS[@]}"; do
    if [[ "$path" == *"$keep"* ]]; then
      return 0
    fi
  done
  
  # None of the keep patterns matched
  return 1
}

ui_subheader "Files to be Removed"

# List and process each file for removal
for file in $GITOPS_FILES; do
  # Skip directories that are essential
  for keep in "${KEEP_PATHS[@]}"; do
    if [[ -d "$file" && "$file" == *"$keep"* ]]; then
      continue 2 # Skip to the next file
    fi
  done
  
  # Skip essential files
  if should_keep "$file"; then
    ui_log_info "Keeping: $file"
    continue
  fi
  
  # This file should be removed
  echo -e "${UI_COLOR_RED}$file${UI_COLOR_RESET}"
done

# Confirm before proceeding
if ! ui_confirm "Are you sure you want to remove ALL legacy scripts shown above?" "n"; then
  ui_log_info "Operation cancelled"
  exit 0
fi

# Remove non-essential files
for file in $GITOPS_FILES; do
  # Skip directories that are essential
  for keep in "${KEEP_PATHS[@]}"; do
    if [[ -d "$file" && "$file" == *"$keep"* ]]; then
      continue 2
    fi
  done
  
  # Skip essential files
  if should_keep "$file"; then
    continue
  fi
  
  # Remove this file
  if [ -f "$file" ]; then
    ui_log_warning "Removing: $file"
    rm "$file"
  elif [ -d "$file" ] && [ ! -z "$(ls -A "$file" 2>/dev/null)" ]; then
    # Skip non-empty directories for safety
    ui_log_warning "Skipping non-empty directory: $file"
  elif [ -d "$file" ]; then
    ui_log_warning "Removing empty directory: $file"
    rmdir "$file" 2>/dev/null || true
  fi
done

# Success message
ui_log_success "Cleanup complete! Removed all non-essential scripts."
ui_log_info "Backup saved to: $BACKUP_DIR"
ui_log_info "Your GitOps directory now contains only the essential components of the new modular architecture."

exit 0 