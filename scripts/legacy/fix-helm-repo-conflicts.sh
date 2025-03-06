#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Fixing HelmRepository naming conflicts...${NC}"

# Fix ingress-nginx conflicts
echo -e "${YELLOW}Fixing ingress-nginx conflicts...${NC}"

# Update staging
sed -i "" "s|name: ingress-nginx|name: ingress-nginx-staging|g" clusters/vps/staging/infrastructure/ingress/ingress-nginx-source.yaml
sed -i "" "s|name: ingress-nginx|name: ingress-nginx-staging|g" clusters/vps/staging/infrastructure/ingress/ingress-nginx-kustomization.yaml

# Update production
sed -i "" "s|name: ingress-nginx|name: ingress-nginx-production|g" clusters/vps/production/infrastructure/ingress/ingress-nginx-source.yaml
sed -i "" "s|name: ingress-nginx|name: ingress-nginx-production|g" clusters/vps/production/infrastructure/ingress/ingress-nginx-kustomization.yaml

# Check for other potential conflicts
echo -e "${YELLOW}Checking for other potential conflicts...${NC}"

# Find all HelmRepository names
echo "Finding all HelmRepository names..."
find clusters/ -name '*-source.yaml' -exec grep -l "kind: HelmRepository" {} \; | xargs grep "name:" | sort | uniq -c | sort -nr

echo -e "${GREEN}HelmRepository naming conflicts fixed!${NC}" 