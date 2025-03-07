#!/bin/bash

# commit-and-deploy.sh: Helper script to commit changes and deploy components
# This script maintains GitOps principles by ensuring changes are in Git before deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to log messages
log() {
  local message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] $message"
}

# Display banner
log "${CYAN}==========================================${NC}"
log "${CYAN}   GitOps Commit and Deploy Helper${NC}"
log "${CYAN}==========================================${NC}"
log ""

# Check for component argument
if [ $# -ne 1 ]; then
  log "${YELLOW}Usage: $0 <component-name>${NC}"
  log "Example: $0 ingress"
  log "Available components: cert-manager, sealed-secrets, ingress, metallb, vault, minio, policy-engine, security, gatekeeper"
  exit 1
fi

COMPONENT="$1"

# Validate the component
VALID_COMPONENTS=("cert-manager" "sealed-secrets" "ingress" "metallb" "vault" "minio" "policy-engine" "security" "gatekeeper")
VALID=false

for c in "${VALID_COMPONENTS[@]}"; do
  if [[ "$c" == "$COMPONENT" ]]; then
    VALID=true
    break
  fi
done

if [[ "$VALID" == "false" ]]; then
  log "${RED}Error: '$COMPONENT' is not a valid component.${NC}"
  log "Valid components are: ${CYAN}${VALID_COMPONENTS[*]}${NC}"
  exit 1
fi

# Check for Git changes
log "Checking for uncommitted changes..."
if ! git diff --quiet; then
  log "${YELLOW}Uncommitted changes detected.${NC}"
  
  # Show the changes
  log "Changes to be committed:"
  git diff --stat
  
  # Ask for commit message
  read -p "Enter commit message (or leave empty to abort): " COMMIT_MSG
  
  if [[ -z "$COMMIT_MSG" ]]; then
    log "${RED}Aborted. No changes were committed.${NC}"
    exit 1
  fi
  
  # Stage and commit changes
  git add .
  git commit -m "$COMMIT_MSG"
  
  # Push changes if remote exists
  if git remote -v | grep -q origin; then
    log "Pushing changes to remote..."
    git push
    
    # Wait for Flux to sync
    log "Waiting 10 seconds for Flux to sync changes..."
    sleep 10
  else
    log "${YELLOW}No remote repository found. Changes were committed locally only.${NC}"
    log "${YELLOW}Note: Flux may not be able to pull these changes.${NC}"
  fi
else
  log "${GREEN}No uncommitted changes. Ready to deploy.${NC}"
fi

# Deploy the component
log "Deploying component: ${CYAN}$COMPONENT${NC}"
if [ "$COMPONENT" = "all" ]; then
  # Deploy all components
  ./scripts/gitops/component-deploy.sh
else
  # Deploy specific component
  ./scripts/gitops/component-deploy.sh "$COMPONENT"
fi

log "${CYAN}==========================================${NC}"
log "Deployment process completed for $COMPONENT"
log "${CYAN}==========================================${NC}" 