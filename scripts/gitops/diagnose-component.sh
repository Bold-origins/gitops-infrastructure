#!/bin/bash
# diagnose-component.sh: Diagnose a specific component
# Provides detailed diagnostic information for a component

set -e

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/lib/ui.sh"

# Create logs directory
mkdir -p logs/diagnostics

# Display usage if no arguments provided
if [ $# -lt 1 ]; then
  ui_header "GitOps Component Diagnostics"
  echo "Usage: $0 <component-name>"
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

# Prepare log file
LOG_FILE="logs/diagnostics/${COMPONENT}-$(date +"%Y-%m-%d_%H-%M-%S").log"
touch "$LOG_FILE"

# Define a function to log to both console and file
log_to_file() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Source the component script
source "$COMPONENT_SCRIPT"

# Start diagnostic session
ui_header "Component Diagnostic: $COMPONENT"
log_to_file "Component Type: $COMPONENT_TYPE"
log_to_file "Diagnostic Time: $(date)"
log_to_file "Log File: $LOG_FILE"
log_to_file ""

# Redirect all output to both console and log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Run component-specific diagnostics
ui_subheader "Component-Specific Diagnostics"
if declare -f "${COMPONENT}_diagnose" >/dev/null; then
  "${COMPONENT}_diagnose"
else
  ui_log_error "No specific diagnostic function found for $COMPONENT"
fi

# Check for related resources
ui_subheader "Related Resources"
kubectl get all -n "$NAMESPACE" 2>/dev/null || ui_log_warning "No resources found in namespace $NAMESPACE"

# Summarize findings
ui_header "Diagnostic Summary"
NAMESPACE_EXISTS=$(kubectl get namespace "$NAMESPACE" &>/dev/null && echo "Yes" || echo "No")
PODS_RUNNING=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null)
PODS_FAILED=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.phase!="Running")].metadata.name}' 2>/dev/null)

echo -e "Namespace exists: ${UI_COLOR_CYAN}$NAMESPACE_EXISTS${UI_COLOR_RESET}"

if [ -n "$PODS_RUNNING" ]; then
  echo -e "Running pods: ${UI_COLOR_GREEN}$(echo "$PODS_RUNNING" | wc -w)${UI_COLOR_RESET}"
else
  echo -e "Running pods: ${UI_COLOR_RED}0${UI_COLOR_RESET}"
fi

if [ -n "$PODS_FAILED" ]; then
  echo -e "Failed/non-running pods: ${UI_COLOR_RED}$(echo "$PODS_FAILED" | wc -w)${UI_COLOR_RESET}"
else
  echo -e "Failed/non-running pods: ${UI_COLOR_GREEN}0${UI_COLOR_RESET}"
fi

# Provide next steps
ui_subheader "Next Steps"
echo -e "1. Review the full diagnostic log: ${UI_COLOR_CYAN}$LOG_FILE${UI_COLOR_RESET}"

if [ -n "$PODS_FAILED" ]; then
  echo -e "2. Check logs for failed pods:"
  for pod in $PODS_FAILED; do
    echo -e "   ${UI_COLOR_CYAN}kubectl logs -n $NAMESPACE $pod${UI_COLOR_RESET}"
  done
fi

echo -e "3. To clean up and redeploy the component:"
echo -e "   ${UI_COLOR_CYAN}${SCRIPT_DIR}/operations/clean.sh $COMPONENT${UI_COLOR_RESET}"
echo -e "   ${UI_COLOR_CYAN}${SCRIPT_DIR}/deploy-component.sh $COMPONENT${UI_COLOR_RESET}"

echo -e "\nDiagnostic completed successfully and saved to: $LOG_FILE"

exit 0 