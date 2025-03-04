#!/bin/bash

set -e

# Source and destination directories
LOCAL_DIR="clusters/local/observability"
STAGING_DIR="clusters/vps/staging/observability"
PRODUCTION_DIR="clusters/vps/production/observability"

# Components to copy
COMPONENTS=("grafana" "prometheus" "loki" "opentelemetry")

# Function to copy files
copy_files() {
  local source_dir=$1
  local dest_dir=$2
  local component=$3
  local env_name=$(basename $(dirname "$dest_dir"))
  
  echo "Copying $component from $source_dir to $dest_dir..."
  
  # Create base kustomization.yaml if it doesn't exist
  if [ -d "$source_dir/$component/base" ]; then
    cp -r "$source_dir/$component/base/"* "$dest_dir/$component/base/"
    
    # Copy source and kustomization files if they exist
    if [ -f "$source_dir/$component/$component-source.yaml" ]; then
      cp "$source_dir/$component/$component-source.yaml" "$dest_dir/$component/"
    fi
    
    if [ -f "$source_dir/$component/$component-kustomization.yaml" ]; then
      # Copy and modify the path in the kustomization file
      sed "s|./clusters/local/observability|./clusters/vps/$env_name/observability|g" \
        "$source_dir/$component/$component-kustomization.yaml" > \
        "$dest_dir/$component/$component-kustomization.yaml"
    fi
    
    # Create component kustomization.yaml
    cat > "$dest_dir/$component/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - $component-source.yaml
  - $component-kustomization.yaml
EOF
  else
    echo "Warning: $source_dir/$component/base directory does not exist"
  fi
}

# Main process
for component in "${COMPONENTS[@]}"; do
  # Copy to staging
  copy_files "$LOCAL_DIR" "$STAGING_DIR" "$component"
  
  # Copy to production
  copy_files "$LOCAL_DIR" "$PRODUCTION_DIR" "$component"
done

echo "Observability components copied successfully!" 