#!/bin/bash
# Script to verify that the local environment has been properly refactored
# to reference the base configurations without redundancy

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Component types to check
COMPONENT_TYPES=("infrastructure" "observability" "applications" "policies")

echo -e "${GREEN}Verifying local environment refactoring...${NC}"

# Track statistics
total_components=0
refactored_components=0
correctly_refactored=0
issues_found=0
redundant_file_issues=0

# Process each component type
for component_type in "${COMPONENT_TYPES[@]}"; do
  echo -e "\n${YELLOW}Checking $component_type components...${NC}"

  # Skip if the directory doesn't exist
  if [ ! -d "clusters/local/$component_type" ]; then
    echo -e "${YELLOW}Directory clusters/local/$component_type does not exist, skipping.${NC}"
    continue
  fi

  # Skip if the base directory doesn't exist
  if [ ! -d "clusters/base/$component_type" ]; then
    echo -e "${YELLOW}Directory clusters/base/$component_type does not exist, skipping.${NC}"
    continue
  fi

  # Find all local components
  local_components=$(find "clusters/local/$component_type" -maxdepth 1 -type d | grep -v "^clusters/local/$component_type$" | xargs -n 1 basename)

  if [ -z "$local_components" ]; then
    echo -e "${YELLOW}No components found in local/$component_type, skipping.${NC}"
    continue
  fi

  # Process each component
  for component in $local_components; do
    local_dir="clusters/local/$component_type/$component"
    base_dir="clusters/base/$component_type/$component"

    total_components=$((total_components + 1))

    echo -e "\n${GREEN}Verifying $component in $component_type...${NC}"

    # Check if base component exists
    if [ ! -d "$base_dir" ]; then
      echo -e "  ${RED}❌ Base component does not exist: $base_dir${NC}"
      echo -e "  ${YELLOW}This component cannot be refactored until it's added to the base.${NC}"
      issues_found=$((issues_found + 1))
      continue
    fi

    # Check if the component has been refactored (has a patches directory)
    if [ ! -d "$local_dir/patches" ]; then
      echo -e "  ${YELLOW}⚠️ Component has not been refactored yet (no patches directory).${NC}"
      echo -e "  ${YELLOW}Consider using refactor-workflow.sh to refactor it:${NC}"
      echo -e "  ./scripts/refactor-workflow.sh $component $component_type"
      continue
    fi

    refactored_components=$((refactored_components + 1))

    # Check kustomization.yaml
    if [ -f "$local_dir/kustomization.yaml" ]; then
      # Check if kustomization references the base
      if grep -q "../../../base/$component_type/$component" "$local_dir/kustomization.yaml"; then
        echo -e "  ${GREEN}✓ kustomization.yaml correctly references base${NC}"
      else
        echo -e "  ${RED}❌ kustomization.yaml does not reference base correctly${NC}"
        echo -e "  ${YELLOW}It should contain: ../../../base/$component_type/$component${NC}"
        issues_found=$((issues_found + 1))
      fi
    else
      echo -e "  ${RED}❌ kustomization.yaml is missing${NC}"
      issues_found=$((issues_found + 1))
    fi

    # Check for redundant files
    redundant_files=$(find "$local_dir" -type f \
      -not -path "$local_dir/kustomization.yaml" \
      -not -path "$local_dir/patches/*" \
      -not -path "$local_dir/helm/values.yaml" \
      -name "*.yaml" | wc -l)

    if [ $redundant_files -gt 0 ]; then
      echo -e "  ${YELLOW}⚠️ Found $redundant_files potentially redundant files${NC}"
      echo -e "  ${YELLOW}Run cleanup script to remove them:${NC}"
      echo -e "  ./scripts/cleanup-local-refactoring.sh"
      redundant_file_issues=$((redundant_file_issues + 1))
      issues_found=$((issues_found + 1))
    else
      echo -e "  ${GREEN}✓ No redundant files found${NC}"
    fi

    # Check if patch files exist
    patch_count=$(find "$local_dir/patches" -type f -name "*.yaml" | wc -l)
    if [ $patch_count -eq 0 ]; then
      echo -e "  ${YELLOW}⚠️ No patch files found in patches directory${NC}"
      echo -e "  ${YELLOW}Consider adding local-specific patches for: deployments, services, ingresses${NC}"
    else
      echo -e "  ${GREEN}✓ Found $patch_count patch files${NC}"
    fi

    # Try to validate with kustomize
    echo -e "  ${YELLOW}Testing component with kustomize...${NC}"
    if kubectl kustomize "$local_dir" >/dev/null 2>&1; then
      echo -e "  ${GREEN}✓ Kustomize validation successful${NC}"
      correctly_refactored=$((correctly_refactored + 1))
    else
      echo -e "  ${RED}❌ Kustomize validation failed${NC}"
      echo -e "  ${YELLOW}Run kubectl kustomize $local_dir manually to see errors${NC}"
      issues_found=$((issues_found + 1))
    fi
  done
done

# Print summary
echo -e "\n${GREEN}Verification complete!${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "  - Total components: $total_components"
echo -e "  - Refactored components: $refactored_components"
echo -e "  - Correctly refactored: $correctly_refactored"
echo -e "  - Issues found: $issues_found"

# Print recommendations
if [ $issues_found -gt 0 ]; then
  echo -e "\n${YELLOW}Recommendations:${NC}"
  echo -e "  1. Fix issues identified above"
  echo -e "  2. Run cleanup script to remove redundant files: ./scripts/cleanup-local-refactoring.sh"
  echo -e "  3. Run this verification again to ensure all issues are resolved"
fi

if [ $total_components -ne $refactored_components ]; then
  echo -e "\n${YELLOW}$((total_components - refactored_components)) components still need to be refactored.${NC}"
  echo -e "${YELLOW}Use the refactor-workflow.sh script to refactor them:${NC}"
  echo -e "  ./scripts/refactor-workflow.sh component-name [component-type]"
fi

if [ $issues_found -eq 0 ] && [ $total_components -eq $refactored_components ]; then
  echo -e "\n${GREEN}Congratulations! All components are properly refactored and the local environment is clean.${NC}"
fi

# Auto-cleanup suggestion for redundant files if there are no kustomize validation issues
if [ $((issues_found - redundant_file_issues)) -eq 0 ] && [ $redundant_file_issues -gt 0 ]; then
  echo -e "\n${YELLOW}Would you like to run the cleanup script to remove redundant files? [y/N]${NC}"
  read -p "Run cleanup now? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Running cleanup script...${NC}"
    ./scripts/cleanup-local-refactoring.sh
  else
    echo -e "${YELLOW}Skipping cleanup. You can run it later with:${NC}"
    echo -e "  ./scripts/cleanup-local-refactoring.sh"
  fi
fi
