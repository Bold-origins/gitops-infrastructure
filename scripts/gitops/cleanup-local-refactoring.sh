#!/bin/bash
# Script to clean up redundant files after refactoring local environment
# to reference base configuration through Kustomize overlays

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Component types to check
COMPONENT_TYPES=("infrastructure" "observability" "applications" "policies")

echo -e "${GREEN}Starting comprehensive cleanup of local environment...${NC}"

# Track overall statistics
total_cleaned=0
total_skipped=0

# Process each component type
for component_type in "${COMPONENT_TYPES[@]}"; do
  echo -e "${YELLOW}Processing $component_type components...${NC}"

  # Skip if the directory doesn't exist
  if [ ! -d "clusters/local/$component_type" ]; then
    echo -e "${YELLOW}Directory clusters/local/$component_type does not exist, skipping.${NC}"
    continue
  fi

  # Find all component directories
  components=$(find "clusters/local/$component_type" -maxdepth 1 -type d | grep -v "^clusters/local/$component_type$" | xargs -n 1 basename)

  if [ -z "$components" ]; then
    echo -e "${YELLOW}No components found in $component_type, skipping.${NC}"
    continue
  fi

  # Process each component
  for component in $components; do
    component_dir="clusters/local/$component_type/$component"
    echo -e "${GREEN}Processing $component in $component_type...${NC}"

    # Check if the component has been refactored (has a patches directory)
    if [ -d "$component_dir/patches" ]; then
      echo -e "  ${GREEN}Found patches directory, component appears to be refactored.${NC}"

      # Files that should be kept
      echo -e "  ${GREEN}Preserving kustomization.yaml and patches directory...${NC}"

      # Files that are now redundant and can be removed
      # excluding kustomization.yaml, helm directory and patches directory
      redundant_files=$(find "$component_dir" -type f \
        -not -path "$component_dir/kustomization.yaml" \
        -not -path "$component_dir/patches/*" \
        -not -path "$component_dir/helm/values.yaml" \
        -name "*.yaml")

      if [ -n "$redundant_files" ]; then
        count=$(echo "$redundant_files" | wc -l)
        echo -e "  ${YELLOW}Found $count redundant files to clean up:${NC}"
        echo "$redundant_files" | sed 's/^/    - /'

        # Move redundant files to backup directory
        backup_dir="$component_dir/.backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"

        echo -e "  ${GREEN}Moving redundant files to $backup_dir${NC}"
        for file in $redundant_files; do
          mv "$file" "$backup_dir/"
        done

        total_cleaned=$((total_cleaned + count))
      else
        echo -e "  ${GREEN}No redundant files found.${NC}"
      fi

      # Also back up the base directory if it exists (as it's now redundant)
      if [ -d "$component_dir/base" ]; then
        echo -e "  ${GREEN}Backing up redundant base directory...${NC}"
        mv "$component_dir/base" "$backup_dir/"
        total_cleaned=$((total_cleaned + 1))
      fi

      echo -e "  ${GREEN}Cleanup complete for $component.${NC}"
    else
      echo -e "  ${YELLOW}Component does not appear to be refactored yet (no patches directory).${NC}"
      total_skipped=$((total_skipped + 1))
    fi

    echo ""
  done
done

# Print summary
echo -e "${GREEN}Cleanup script completed successfully.${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "  - Total redundant files cleaned up: $total_cleaned"
echo -e "  - Components skipped (not yet refactored): $total_skipped"

if [ $total_skipped -gt 0 ]; then
  echo -e "\n${YELLOW}There are still $total_skipped components that have not been refactored.${NC}"
  echo -e "${YELLOW}Consider using the refactor-workflow.sh script to refactor them:${NC}"
  echo -e "  ./scripts/refactor-workflow.sh component-name [component-type]"
fi
