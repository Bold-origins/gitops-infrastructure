#!/bin/bash

# This script adds namespace transformers to all components in the staging environment
# to avoid duplicate namespace definitions with the centralized namespace approach

set -e

# Source UI library if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/lib/ui.sh" ]; then
    source "${SCRIPT_DIR}/lib/ui.sh"
    have_ui=true
else
    have_ui=false
fi

# Log function
log() {
    if [ "$have_ui" = true ]; then
        ui_log_info "$1"
    else
        echo "[INFO] $1"
    fi
}

success() {
    if [ "$have_ui" = true ]; then
        ui_log_success "$1"
    else
        echo "[SUCCESS] $1"
    fi
}

# Define the components and their namespaces
COMPONENTS=(
    "cert-manager:cert-manager"
    "gatekeeper:gatekeeper-system"
    "vault:vault"
    "minio:minio"
    "sealed-secrets:sealed-secrets"
    "security:security"
    "metallb:metallb-system"
    "ingress:ingress-nginx"
)

# Base directory for staging components
base_dir="clusters/staging/infrastructure"

# Add transformer to a component
add_transformer_to_component() {
    local component=$1
    local namespace=$2
    local component_dir="${base_dir}/${component}"
    
    # Skip if component directory doesn't exist
    if [ ! -d "$component_dir" ]; then
        log "Skipping $component, directory doesn't exist"
        return
    fi
    
    # Create transformers directory if it doesn't exist
    local transformers_dir="${component_dir}/transformers"
    mkdir -p "$transformers_dir"
    
    # Create the transformer file
    local transformer_file="${transformers_dir}/remove-namespace.yaml"
    cat > "$transformer_file" << EOF
apiVersion: builtin
kind: PatchTransformer
metadata:
  name: remove-namespace
target:
  kind: Namespace
  name: ${namespace}
patch: |
  \$patch: delete
  apiVersion: v1
  kind: Namespace
  metadata:
    name: ${namespace}
EOF
    
    log "Created transformer for $component"
    
    # Update the kustomization file
    local kustomization_file="${component_dir}/kustomization.yaml"
    if [ -f "$kustomization_file" ]; then
        # Check if transformer is already added
        if grep -q "transformers:" "$kustomization_file"; then
            log "Transformer section already exists in $component kustomization"
        else
            # Add transformer section
            echo -e "\n# Use transformers to exclude the namespace\ntransformers:\n- transformers/remove-namespace.yaml" >> "$kustomization_file"
            log "Updated kustomization for $component"
        fi
    else
        log "Kustomization file not found for $component"
    fi
}

# Main loop
log "Starting namespace transformer updates"
for comp_ns in "${COMPONENTS[@]}"; do
    component=$(echo $comp_ns | cut -d: -f1)
    namespace=$(echo $comp_ns | cut -d: -f2)
    log "Processing $component with namespace $namespace"
    add_transformer_to_component "$component" "$namespace"
done

success "Namespace transformers update completed"

# Validate the changes
log "Validating changes..."
for comp_ns in "${COMPONENTS[@]}"; do
    component=$(echo $comp_ns | cut -d: -f1)
    component_dir="${base_dir}/${component}"
    if [ -d "$component_dir" ]; then
        log "Testing $component kustomization..."
        if kustomize build "$component_dir" 2>/dev/null | grep -q "kind: Namespace"; then
            log "WARNING: $component still contains namespace definitions!"
        else
            success "$component validation passed - no namespaces found"
        fi
    fi
done

log "All updates completed" 