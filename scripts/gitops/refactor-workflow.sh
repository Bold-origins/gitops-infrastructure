#!/bin/bash
# End-to-end workflow script for refactoring local components to use base configurations

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

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}     REFACTORING WORKFLOW: $COMPONENT     ${NC}"
echo -e "${GREEN}==========================================${NC}"

# Step 1: Verify directories exist
echo -e "${YELLOW}Step 1: Verifying directories...${NC}"
if [ ! -d "$BASE_DIR" ]; then
  echo -e "${RED}Error: Base component directory not found: $BASE_DIR${NC}"
  exit 1
fi

if [ ! -d "$LOCAL_DIR" ]; then
  echo -e "${RED}Error: Local component directory not found: $LOCAL_DIR${NC}"
  exit 1
fi
echo -e "${GREEN}Directories verified successfully.${NC}"

# Step 2: Back up local directory
echo -e "${YELLOW}Step 2: Creating backup of local component...${NC}"
BACKUP_DIR="${LOCAL_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
cp -r "$LOCAL_DIR" "$BACKUP_DIR"
echo -e "${GREEN}Backup created at: $BACKUP_DIR${NC}"

# Step 3: Run refactoring script
echo -e "${YELLOW}Step 3: Running refactoring script...${NC}"
./scripts/refactor-component.sh "$COMPONENT" "$COMPONENT_TYPE"

# Step 4: Test refactored component
echo -e "${YELLOW}Step 4: Testing refactored component with kustomize...${NC}"
echo -e "Running: kubectl kustomize $LOCAL_DIR"
kubectl kustomize "$LOCAL_DIR" > /dev/null
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Kustomize test successful!${NC}"
else
  echo -e "${RED}Kustomize test failed. Please check your configuration.${NC}"
  echo -e "${YELLOW}You can restore from backup if needed: mv $BACKUP_DIR $LOCAL_DIR${NC}"
  exit 1
fi

# Step 5: Clean up redundant files
echo -e "${YELLOW}Step 5: Cleaning up redundant files...${NC}"
echo -e "This step will move redundant files to a backup directory inside the component folder."
read -p "Continue with cleanup? (y/n): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
  ./scripts/cleanup-local-refactoring.sh
else
  echo -e "${YELLOW}Skipping cleanup.${NC}"
fi

# Step 6: Update progress documents
echo -e "${YELLOW}Step 6: Updating progress tracking documents...${NC}"

# Update overall progress percentage in PROGRESS_DOCUMENT.md
local_components=$(find "clusters/local/$COMPONENT_TYPE" -maxdepth 1 -type d | grep -v "^clusters/local/$COMPONENT_TYPE$" | wc -l)
refactored_components=$(find "clusters/local/$COMPONENT_TYPE" -maxdepth 2 -path "*/patches" | wc -l)
percentage=$((refactored_components * 100 / local_components))

echo -e "${GREEN}$refactored_components out of $local_components $COMPONENT_TYPE components refactored ($percentage%)${NC}"

# Update the percentage in PROGRESS_DOCUMENT.md
if [[ "$COMPONENT_TYPE" == "infrastructure" ]]; then
  sed -i '' "s/Infrastructure components ([0-9]*% complete)/Infrastructure components ($percentage% complete)/" "conext/PROGRESS_DOCUMENT.md"
elif [[ "$COMPONENT_TYPE" == "observability" ]]; then
  sed -i '' "s/Observability components ([0-9]*% complete)/Observability components ($percentage% complete)/" "conext/PROGRESS_DOCUMENT.md"
elif [[ "$COMPONENT_TYPE" == "applications" ]]; then
  sed -i '' "s/Application components ([0-9]*% complete)/Application components ($percentage% complete)/" "conext/PROGRESS_DOCUMENT.md"
fi

# Update overall milestone progress
infrastructure_perc=$(grep "Infrastructure components" "conext/PROGRESS_DOCUMENT.md" | grep -o "[0-9]*%" | grep -o "[0-9]*")
observability_perc=$(grep "Observability components" "conext/PROGRESS_DOCUMENT.md" | grep -o "[0-9]*%" | grep -o "[0-9]*")
application_perc=$(grep "Application components" "conext/PROGRESS_DOCUMENT.md" | grep -o "[0-9]*%" | grep -o "[0-9]*")

# Calculate average, with weights for each component type
weighted_avg=$(( (infrastructure_perc * 50 + observability_perc * 30 + application_perc * 20) / 100 ))
# Adjust overall percentage based on completed phases (max 60% since we still have stages 3-5 to complete)
overall_perc=$(( weighted_avg * 60 / 100 ))

# Update overall milestone percentage
sed -i '' "s/\*\*Status:\*\* [0-9]*% Complete/\*\*Status:\*\* $overall_perc% Complete/" "conext/PROGRESS_DOCUMENT.md"

echo -e "${GREEN}Updated progress tracking documents.${NC}"

# Step 7: Add progress update to Phase0_Implementation_Tracker.md
echo -e "${YELLOW}Step 7: Adding progress update to implementation tracker...${NC}"

TODAY=$(date +"%Y-%m-%d")
PROGRESS_UPDATE="- Refactored $COMPONENT component in $COMPONENT_TYPE to use base configuration\n- Created local-specific patches for $COMPONENT\n- Cleaned up redundant files\n- Updated progress tracking"

# Check if there's already an entry for today
if grep -q "### $TODAY" "conext/Phase0_Implementation_Tracker.md"; then
  # Append to today's entry
  sed -i '' "/### $TODAY/a\\
$PROGRESS_UPDATE" "conext/Phase0_Implementation_Tracker.md"
else
  # Create new entry for today
  sed -i '' "/## Progress Updates/a\\
\\
### $TODAY\\
\\
$PROGRESS_UPDATE" "conext/Phase0_Implementation_Tracker.md"
fi

echo -e "${GREEN}Added progress update to implementation tracker.${NC}"

# Step 8: Provide next steps
echo -e "${YELLOW}Step 8: Workflow completed!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}     REFACTORING COMPLETE: $COMPONENT     ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review the refactored component in $LOCAL_DIR"
echo -e "2. Manually test the component functionality"
echo -e "3. Consider refactoring another component"

# Show remaining components to refactor
echo -e "${YELLOW}Remaining components to refactor in $COMPONENT_TYPE:${NC}"
grep -A10 "Update local $COMPONENT_TYPE to reference base" "conext/Phase0_Implementation_Tracker.md" | grep "- \[ \]" | sed 's/- \[ \]/  - /'

echo -e "${GREEN}Done!${NC}" 