#!/bin/bash
# deploy-component.sh: Main script for deploying a single component
# This is the main entry point for deploying individual components

set -e

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/lib/ui.sh"

# Create logs directory
mkdir -p logs/deployment

# Display usage if no arguments provided
if [ $# -lt 1 ]; then
  ui_header "GitOps Component Deployment"
  echo "Usage: $0 <component-name> [deploy-mode]"
  echo "Deploy modes: flux (default), kubectl, helm"
  echo ""
  echo "Available Components:"

  # List available components by looking for component scripts
  for dir in infrastructure storage observability policy applications flux; do
    if [ -d "${SCRIPT_DIR}/components/${dir}" ]; then
      echo -e "${UI_COLOR_CYAN}${dir}:${UI_COLOR_RESET}"
      for file in "${SCRIPT_DIR}/components/${dir}"/*.sh; do
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
DEPLOY_MODE="${2:-flux}" # Default to flux deployment

# Valid deployment modes
VALID_MODES=("flux" "kubectl" "helm")
VALID_MODE=false

for mode in "${VALID_MODES[@]}"; do
  if [[ "$mode" == "$DEPLOY_MODE" ]]; then
    VALID_MODE=true
    break
  fi
done

if [[ "$VALID_MODE" == "false" ]]; then
  ui_log_error "Invalid deployment mode: $DEPLOY_MODE"
  echo "Valid modes: ${VALID_MODES[*]}"
  exit 1
fi

# Find component script
COMPONENT_SCRIPT=""
COMPONENT_TYPE=""
for dir in infrastructure storage observability policy applications flux; do
  if [ -f "${SCRIPT_DIR}/components/${dir}/${COMPONENT}.sh" ]; then
    COMPONENT_SCRIPT="${SCRIPT_DIR}/components/${dir}/${COMPONENT}.sh"
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
ui_header "Deploying Component: $COMPONENT"
ui_log_info "Component Type: $COMPONENT_TYPE"
ui_log_info "Deployment Mode: $DEPLOY_MODE"

# Run deployment sequence with timing
ui_log_info "Starting deployment sequence for $COMPONENT"

# Pre-deployment stage
ui_subheader "Pre-Deployment"
START_TIME=$(date +%s)
if "${COMPONENT}_pre_deploy"; then
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_success "Pre-deployment completed in ${ELAPSED}s"
else
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_error "Pre-deployment failed after ${ELAPSED}s"
  exit 1
fi

# Deployment stage
ui_subheader "Deployment"
START_TIME=$(date +%s)
if "${COMPONENT}_deploy" "$DEPLOY_MODE"; then
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_success "Deployment completed in ${ELAPSED}s"
else
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_error "Deployment failed after ${ELAPSED}s"
  exit 1
fi

# Post-deployment stage
ui_subheader "Post-Deployment"
START_TIME=$(date +%s)
if "${COMPONENT}_post_deploy"; then
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_success "Post-deployment completed in ${ELAPSED}s"
else
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_error "Post-deployment failed after ${ELAPSED}s"
  exit 1
fi

# Verification stage
ui_subheader "Verification"
START_TIME=$(date +%s)
if "${COMPONENT}_verify"; then
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_success "Verification completed in ${ELAPSED}s"
else
  END_TIME=$(date +%s)
  ELAPSED=$((END_TIME - START_TIME))
  ui_log_error "Verification failed after ${ELAPSED}s"

  if ui_confirm "Run diagnostics for $COMPONENT?" "y"; then
    ui_subheader "Diagnostics"
    "${COMPONENT}_diagnose"
  fi

  if ui_confirm "Continue anyway?" "n"; then
    ui_log_warning "Continuing despite verification failure"
  else
    ui_log_error "Deployment aborted due to verification failure"
    exit 1
  fi
fi

# Success message
ui_header "Deployment of $COMPONENT Completed Successfully"
ui_log_info "Component $COMPONENT has been deployed in $DEPLOY_MODE mode"
ui_log_info "To diagnose any issues, run: ${SCRIPT_DIR}/diagnose-component.sh $COMPONENT"

exit 0
