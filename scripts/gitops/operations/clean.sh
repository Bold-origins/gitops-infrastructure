#!/bin/bash
# clean.sh: Clean up a component
# Removes a component from the cluster

set -e

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../lib/ui.sh"

# Display usage if no arguments provided
if [ $# -lt 1 ]; then
  ui_header "GitOps Component Cleanup"
  echo "Usage: $0 <component-name>"
  echo ""
  echo "Available Components:"
  
  # List available components by looking for component scripts
  for dir in infrastructure storage observability policy applications flux; do
    if [ -d "${SCRIPT_DIR}/../components/${dir}" ]; then
      echo -e "${UI_COLOR_CYAN}${dir}:${UI_COLOR_RESET}"
      for file in "${SCRIPT_DIR}/../components/${dir}"/*.sh; do
        if [ -f "$file" ]; then
          component=$(basename "$file" .sh)
          echo -e "  ${UI_COLOR_GREEN}$component${UI_COLOR_RESET}"
        fi
      done
    fi
  done
  
  exit 1
fi

COMPONENT="$1"

# Find component script
COMPONENT_SCRIPT=""
COMPONENT_TYPE=""
for dir in infrastructure storage observability policy applications flux; do
  if [ -f "${SCRIPT_DIR}/../components/${dir}/${COMPONENT}.sh" ]; then
    COMPONENT_SCRIPT="${SCRIPT_DIR}/../components/${dir}/${COMPONENT}.sh"
    COMPONENT_TYPE="$dir"
    break
  fi
done

if [ ! -f "$COMPONENT_SCRIPT" ]; then
  ui_log_error "Component script not found for: $COMPONENT"
  echo "Run $0 without arguments to see available components"
  exit 1
fi

# Source the component script
source "$COMPONENT_SCRIPT"

# Display header
ui_header "Cleaning Up Component: $COMPONENT"
ui_log_info "Component Type: $COMPONENT_TYPE"

# Confirm cleanup
if ! ui_confirm "Are you sure you want to clean up the $COMPONENT component?" "n"; then
  ui_log_info "Cleanup aborted"
  exit 0
fi

# Run cleanup
ui_subheader "Running Cleanup"
START_TIME=$(date +%s)
if "${COMPONENT}_cleanup"; then
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_success "Cleanup completed in ${ELAPSED}s"
else
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_error "Cleanup failed after ${ELAPSED}s"
  exit 1
fi

# Success message
ui_header "Cleanup of $COMPONENT Completed Successfully"
ui_log_info "Component $COMPONENT has been removed from the cluster"
ui_log_info "To redeploy the component, run: ${SCRIPT_DIR}/../deploy-component.sh $COMPONENT"

exit 0 