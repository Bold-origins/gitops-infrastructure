#!/bin/bash

set -e

# Source and destination directories
LOCAL_DIR="clusters/local/observability"
STAGING_DIR="clusters/vps/staging/observability"
PRODUCTION_DIR="clusters/vps/production/observability"

# Components to copy
COMPONENTS=("prometheus" "loki" "opentelemetry" "grafana")

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to copy files
copy_component() {
  local source_dir=$1
  local dest_dir=$2
  local component=$3
  local env_name=$(basename $(dirname "$dest_dir"))
  
  echo -e "${GREEN}Setting up $component in $env_name environment...${NC}"
  
  # Create component directory if it doesn't exist
  mkdir -p "$dest_dir/$component/base"
  
  # Check if source base directory exists and has files
  if [ -d "$source_dir/$component/base" ] && [ "$(ls -A "$source_dir/$component/base" 2>/dev/null)" ]; then
    echo "Copying base files..."
    cp -r "$source_dir/$component/base/"* "$dest_dir/$component/base/" 2>/dev/null || true
  else
    echo -e "${YELLOW}No base files found for $component. Creating minimal structure...${NC}"
    
    # Create basic namespace file
    cat > "$dest_dir/$component/base/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: observability
EOF

    # Create basic kustomization file for base
    cat > "$dest_dir/$component/base/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: observability
resources:
  - namespace.yaml
EOF
  fi
  
  # Copy and update source file if it exists
  if [ -f "$source_dir/$component/$component-source.yaml" ]; then
    echo "Copying $component-source.yaml..."
    cp "$source_dir/$component/$component-source.yaml" "$dest_dir/$component/"
  else
    echo -e "${YELLOW}No source file found for $component. Creating basic source file...${NC}"
    
    # Create a basic source file based on component type
    case "$component" in
      "grafana")
        cat > "$dest_dir/$component/$component-source.yaml" << EOF
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: grafana
  namespace: flux-system
spec:
  interval: 1h
  url: https://grafana.github.io/helm-charts
EOF
        ;;
      "prometheus")
        cat > "$dest_dir/$component/$component-source.yaml" << EOF
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts
EOF
        ;;
      "loki")
        cat > "$dest_dir/$component/$component-source.yaml" << EOF
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: grafana
  namespace: flux-system
spec:
  interval: 1h
  url: https://grafana.github.io/helm-charts
EOF
        ;;
      "opentelemetry")
        cat > "$dest_dir/$component/$component-source.yaml" << EOF
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: open-telemetry
  namespace: flux-system
spec:
  interval: 1h
  url: https://open-telemetry.github.io/opentelemetry-helm-charts
EOF
        ;;
    esac
  fi
  
  # Copy and update kustomization file if it exists
  if [ -f "$source_dir/$component/$component-kustomization.yaml" ]; then
    echo "Copying and updating $component-kustomization.yaml..."
    sed "s|./clusters/local/observability|./clusters/vps/$env_name/observability|g" \
      "$source_dir/$component/$component-kustomization.yaml" > \
      "$dest_dir/$component/$component-kustomization.yaml"
  else
    echo -e "${YELLOW}No kustomization file found for $component. Creating basic kustomization file...${NC}"
    
    # Create a basic kustomization file
    cat > "$dest_dir/$component/$component-kustomization.yaml" << EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: $component
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./clusters/vps/$env_name/observability/$component/base
  prune: true
  wait: true
EOF
  fi
  
  # Create component kustomization.yaml
  echo "Creating component kustomization.yaml..."
  cat > "$dest_dir/$component/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - $component-source.yaml
  - $component-kustomization.yaml
EOF

  echo -e "${GREEN}$component setup in $env_name completed successfully!${NC}"
  echo ""
}

# Function to create main kustomization file
create_main_kustomization() {
  local dest_dir=$1
  local env_name=$(basename $(dirname "$dest_dir"))
  
  echo -e "${GREEN}Creating main kustomization file for $env_name...${NC}"
  
  cat > "$dest_dir/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
EOF

  # Add each component to the resources list
  for component in "${COMPONENTS[@]}"; do
    echo "  - $component" >> "$dest_dir/kustomization.yaml"
  done
  
  echo -e "${GREEN}Main kustomization file for $env_name created successfully!${NC}"
}

# Main process
echo -e "${GREEN}Starting observability setup...${NC}"

# Process each component for staging
for component in "${COMPONENTS[@]}"; do
  copy_component "$LOCAL_DIR" "$STAGING_DIR" "$component"
done

# Create main kustomization file for staging
create_main_kustomization "$STAGING_DIR"

# Process each component for production
for component in "${COMPONENTS[@]}"; do
  copy_component "$LOCAL_DIR" "$PRODUCTION_DIR" "$component"
done

# Create main kustomization file for production
create_main_kustomization "$PRODUCTION_DIR"

echo -e "${GREEN}Observability setup completed successfully for all environments!${NC}" 