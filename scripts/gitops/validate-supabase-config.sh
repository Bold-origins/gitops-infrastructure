#!/bin/bash
set -e

# This script validates the Supabase configuration for all environments
# to ensure consistency and prevent common issues

ENVIRONMENTS=("local" "staging" "production")
BASE_DIR="clusters/base/applications/supabase"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to check if a file exists
check_file_exists() {
  if [ ! -f "$1" ]; then
    echo -e "${RED}Error: File not found: $1${NC}"
    exit 1
  fi
}

# Load base versions
check_file_exists "$BASE_DIR/versions.yaml"
echo -e "${GREEN}✓ Base versions file exists${NC}"

# Check each environment for proper configuration
for env in "${ENVIRONMENTS[@]}"; do
  ENV_DIR="clusters/$env/applications/supabase"
  
  if [ ! -d "$ENV_DIR" ]; then
    echo -e "${YELLOW}Warning: Environment $env not found, skipping...${NC}"
    continue
  fi
  
  echo -e "\n${YELLOW}Validating $env environment...${NC}"
  
  # Check if values.yaml exists
  VALUES_FILE="$ENV_DIR/helm/values.yaml"
  check_file_exists "$VALUES_FILE"
  echo -e "${GREEN}✓ Values file exists for $env${NC}"
  
  # Check if JWT secret has the correct key mapping
  if ! grep -q "jwtSecret: secret" "$VALUES_FILE"; then
    echo -e "${RED}Error: Incorrect JWT secret key mapping in $env environment${NC}"
    echo -e "${RED}       Expected: 'jwtSecret: secret' but found something else${NC}"
    echo -e "${RED}       Please update to ensure compatibility with all components${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ JWT secret key mapping is correct in $env${NC}"
  
  # Check for latest tags in image references
  if grep -q "tag: \"latest\"" "$VALUES_FILE"; then
    echo -e "${RED}Error: Found 'latest' tag in $env environment${NC}"
    echo -e "${RED}       'latest' tags are unstable and should be avoided${NC}"
    echo -e "${RED}       Please specify exact versions in versions.yaml${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ No 'latest' tags found in $env${NC}"
  
  # Check if sealed secrets directory exists
  SECRETS_DIR="$ENV_DIR/sealed-secrets"
  if [ ! -d "$SECRETS_DIR" ]; then
    echo -e "${RED}Error: Sealed secrets directory not found for $env environment${NC}"
    echo -e "${RED}       Expected at: $SECRETS_DIR${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Sealed secrets directory exists for $env${NC}"
  
  # Check if JWT sealed secret exists
  JWT_SECRET="$SECRETS_DIR/jwt-secret.yaml"
  check_file_exists "$JWT_SECRET"
  echo -e "${GREEN}✓ JWT sealed secret exists for $env${NC}"
done

echo -e "\n${GREEN}All validations passed successfully!${NC}"
echo -e "You can now proceed with deploying Supabase to any environment." 