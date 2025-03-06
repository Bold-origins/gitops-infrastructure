#!/bin/bash
# Script to refactor a local component to reference base configuration

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if component name was provided
if [ $# -lt 1 ]; then
  echo -e "${RED}Error: Component name is required.${NC}"
  echo "Usage: $0 component-name [component-type]"
  echo "Example: $0 cert-manager infrastructure"
  exit 1
fi

COMPONENT=$1
COMPONENT_TYPE=${2:-infrastructure}  # Default to infrastructure if not specified
BASE_DIR="clusters/base/$COMPONENT_TYPE/$COMPONENT"
LOCAL_DIR="clusters/local/$COMPONENT_TYPE/$COMPONENT"

# Validate component exists
if [ ! -d "$BASE_DIR" ]; then
  echo -e "${RED}Error: Base component directory not found: $BASE_DIR${NC}"
  exit 1
fi

if [ ! -d "$LOCAL_DIR" ]; then
  echo -e "${RED}Error: Local component directory not found: $LOCAL_DIR${NC}"
  exit 1
fi

echo -e "${GREEN}Refactoring $COMPONENT component...${NC}"

# Create patches directory
mkdir -p "$LOCAL_DIR/patches"
echo -e "${GREEN}Created patches directory: $LOCAL_DIR/patches${NC}"

# Create kustomization.yaml referencing base
echo -e "${YELLOW}Generating kustomization.yaml...${NC}"

# Check if base has a configmap generator for values
base_has_values_configmap=false
if grep -q "configMapGenerator" "$BASE_DIR/kustomization.yaml"; then
  base_has_values_configmap=true
  echo -e "${YELLOW}Base component has configMapGenerator, will add merge behavior in local.${NC}"
fi

# Generate kustomization.yaml content
kustomization_content="apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference the base $COMPONENT configuration
resources:
- ../../../base/$COMPONENT_TYPE/$COMPONENT

# Apply local-specific patches
patchesStrategicMerge:
# Uncomment and add patches as needed
# - patches/deployment-patch.yaml
# - patches/service-patch.yaml"

# Add configMapGenerator only if it exists in base or if values.yaml exists in helm directory
if [ "$base_has_values_configmap" = true ] || [ -f "$LOCAL_DIR/helm/values.yaml" ]; then
  kustomization_content="$kustomization_content

# Import local-specific values
configMapGenerator:
- name: $COMPONENT-values
  behavior: merge
  files:
  - values.yaml=helm/values.yaml"
fi

# Write the kustomization.yaml
echo "$kustomization_content" > "$LOCAL_DIR/kustomization.yaml"

echo -e "${GREEN}Created kustomization.yaml referencing base component${NC}"

# Check if helm values file exists
if [ -f "$LOCAL_DIR/helm/values.yaml" ]; then
  echo -e "${GREEN}Found helm values file: $LOCAL_DIR/helm/values.yaml${NC}"
else
  # Create helm values directory if it doesn't exist
  mkdir -p "$LOCAL_DIR/helm"
  
  # Try to copy values.yaml from base if it exists
  if [ -f "$BASE_DIR/helm/values.yaml" ]; then
    cp "$BASE_DIR/helm/values.yaml" "$LOCAL_DIR/helm/values.yaml"
    echo -e "${GREEN}Copied values.yaml from base component${NC}"
  else
    # Create empty values.yaml
    echo "# Local-specific values for $COMPONENT" > "$LOCAL_DIR/helm/values.yaml"
    echo -e "${YELLOW}Created empty values.yaml. Please add local-specific values.${NC}"
  fi
fi

# Create template patch files based on base configuration
echo -e "${YELLOW}Analyzing base configuration to identify potential patches...${NC}"

# Find deployments, services, and other key resources in base directory
RESOURCES=$(find "$BASE_DIR" -name "*.yaml" -exec grep -l "kind: Deployment\|kind: Service\|kind: Ingress\|kind: HelmRelease" {} \;)

if [ -n "$RESOURCES" ]; then
  echo -e "${GREEN}Found resources that might need local patches:${NC}"
  
  for resource in $RESOURCES; do
    resource_name=$(basename "$resource")
    resource_kind=$(grep -o "kind: [A-Za-z]*" "$resource" | head -1 | cut -d' ' -f2)
    
    echo -e "  ${YELLOW}- $resource_kind from $resource_name${NC}"
    
    # Create template patch file if it doesn't exist
    resource_kind_lower=$(echo "$resource_kind" | tr '[:upper:]' '[:lower:]')
    patch_file="$LOCAL_DIR/patches/${resource_kind_lower}-patch.yaml"
    
    if [ ! -f "$patch_file" ]; then
      # Extract resource name and namespace
      resource_name=$(grep -A2 "metadata:" "$resource" | grep "name:" | head -1 | sed 's/.*name: *//' | tr -d '"')
      namespace=$(grep -A3 "metadata:" "$resource" | grep "namespace:" | head -1 | sed 's/.*namespace: *//' | tr -d '"')
      
      # Create template based on resource kind
      case "$resource_kind" in
        Deployment)
          cat > "$patch_file" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $resource_name
  namespace: $namespace
spec:
  replicas: 1  # Single replica for local development
  template:
    metadata:
      annotations:
        dev.local/environment: "local"  # Local development annotation
    spec:
      containers:
      - name: $resource_name
        # Development-specific settings
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF
          ;;
          
        Service)
          cat > "$patch_file" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $resource_name
  namespace: $namespace
  annotations:
    dev.local/environment: "local"  # Local development annotation
spec:
  # Add local-specific service customizations here if needed
EOF
          ;;
          
        Ingress)
          cat > "$patch_file" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $resource_name
  namespace: $namespace
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-cluster-issuer
    dev.local/environment: "local"  # Local development annotation
spec:
  tls:
  - hosts:
    - $resource_name.local
    secretName: $resource_name-tls
  rules:
  - host: $resource_name.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $resource_name
            port:
              number: 80  # Adjust port as needed
EOF
          ;;
          
        HelmRelease)
          cat > "$patch_file" << EOF
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: $resource_name
  namespace: $namespace
spec:
  values:
    # Add local-specific values here
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
    replicaCount: 1  # Single replica for local development
EOF
          ;;
          
        *)
          echo -e "${YELLOW}Skipping unknown resource kind: $resource_kind${NC}"
          continue
          ;;
      esac
      
      echo -e "${GREEN}Created template patch file: $patch_file${NC}"
      
      # Uncomment the relevant line in kustomization.yaml
      sed -i '' "s|# - patches/${resource_kind_lower}-patch.yaml|- patches/${resource_kind_lower}-patch.yaml|" "$LOCAL_DIR/kustomization.yaml"
    else
      echo -e "${YELLOW}Patch file already exists: $patch_file${NC}"
    fi
  done
else
  echo -e "${YELLOW}No resources found that might need patches.${NC}"
fi

echo -e "${GREEN}Refactoring complete for $COMPONENT!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review and customize the generated patch files in $LOCAL_DIR/patches/"
echo -e "2. Update the values.yaml file with local-specific configurations"
echo -e "3. Test the refactored component with: kubectl kustomize $LOCAL_DIR"
echo -e "4. Apply the refactored component with: kubectl apply -k $LOCAL_DIR"
echo -e "5. Run cleanup script to remove redundant files: ./scripts/cleanup-local-refactoring.sh"

# Update the Progress Document
echo -e "${GREEN}Updating progress tracking documents...${NC}"

# Update Phase0_Implementation_Tracker.md to mark component as refactored
if grep -q "\- \[ \] $COMPONENT" "conext/Phase0_Implementation_Tracker.md"; then
  sed -i '' "s/- \[ \] $COMPONENT/- [x] $COMPONENT/" "conext/Phase0_Implementation_Tracker.md"
  echo -e "${GREEN}Updated Phase0_Implementation_Tracker.md to mark $COMPONENT as completed${NC}"
else
  echo -e "${YELLOW}Could not find $COMPONENT in Phase0_Implementation_Tracker.md${NC}"
fi

echo -e "${GREEN}Done!${NC}" 