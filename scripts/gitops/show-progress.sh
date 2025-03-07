#!/bin/bash

# show-progress.sh: Display the current status of all components
# This script provides a visual overview of what's deployed and what's pending

set -e

# Configuration
LOG_DIR="logs/deployment"
PROGRESS_FILE="$LOG_DIR/deployment-progress.txt"
COMPONENTS=(
  "cert-manager"
  "sealed-secrets"
  "ingress"
  "metallb"
  "vault"
  "minio"
  "policy-engine"
  "security"
  "gatekeeper"
)

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to get status of a component
get_component_status() {
  local component="$1"
  local namespace="$2"
  
  # Check if component is in progress file
  if grep -q "$component" "$PROGRESS_FILE" 2>/dev/null; then
    # It's in the progress file, but verify resources actually exist
    local resources_exist=false
    
    # Check if namespace exists
    if kubectl get namespace "$namespace" &>/dev/null; then
      # Check for any resources in the namespace
      if [[ $(kubectl get all -n "$namespace" 2>/dev/null | wc -l) -gt 1 ]]; then
        resources_exist=true
      fi
    fi
    
    if [[ "$resources_exist" == true ]]; then
      # Check for Flux kustomization status
      if kubectl get kustomization -n flux-system "single-$component" &>/dev/null; then
        local kust_status=$(kubectl get kustomization -n flux-system "single-$component" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [[ "$kust_status" == "True" ]]; then
          echo "deployed"
        else
          echo "reconciling"
        fi
      else
        echo "deployed"
      fi
    else
      echo "partial"
    fi
  else
    # Check if Flux kustomization exists but not in progress file
    if kubectl get kustomization -n flux-system "single-$component" &>/dev/null; then
      echo "in-progress"
    else
      echo "pending"
    fi
  fi
}

# Check for progress tracking file
if [ ! -f "$PROGRESS_FILE" ]; then
  # Create logs directory if it doesn't exist
  mkdir -p "$LOG_DIR"
  touch "$PROGRESS_FILE"
  echo "📋 Created new progress tracking file"
fi

# Display banner
echo -e "${CYAN}=======================================================${NC}"
echo -e "${CYAN}   GitOps Deployment Progress Status${NC}"
echo -e "${CYAN}=======================================================${NC}"

# Display components and their status
echo -e "\n${CYAN}Component Status:${NC}\n"
for component in "${COMPONENTS[@]}"; do
  # Map component to its namespace
  namespace=""
  case "$component" in
    "cert-manager") namespace="cert-manager" ;;
    "sealed-secrets") namespace="sealed-secrets" ;;
    "ingress") namespace="ingress-nginx" ;;
    "metallb") namespace="metallb-system" ;;
    "vault") namespace="vault" ;;
    "minio") namespace="minio-system" ;;
    "policy-engine") namespace="policy-engine" ;;
    "security") namespace="security" ;;
    "gatekeeper") namespace="gatekeeper-system" ;;
    *) namespace="$component" ;;
  esac
  
  status=$(get_component_status "$component" "$namespace")
  
  case "$status" in
    "deployed")
      echo -e "  ${GREEN}✅ $component${NC} - Fully deployed and reconciled"
      ;;
    "reconciling")
      echo -e "  ${YELLOW}🔄 $component${NC} - Deployed but still reconciling"
      ;;
    "partial")
      echo -e "  ${YELLOW}⚠️ $component${NC} - Partially deployed (may need attention)"
      ;;
    "in-progress")
      echo -e "  ${CYAN}🔨 $component${NC} - Deployment in progress"
      ;;
    "pending")
      echo -e "  ${RED}⏳ $component${NC} - Not yet deployed"
      ;;
  esac
done

# Display next steps
echo -e "\n${CYAN}Deployment Summary:${NC}"
deployed_count=$(grep -c . "$PROGRESS_FILE" 2>/dev/null || echo 0)
total_count=${#COMPONENTS[@]}
percent=0
if [ "$total_count" -gt 0 ] && [ "$deployed_count" -gt 0 ]; then
  percent=$((deployed_count * 100 / total_count))
fi

echo -e "  Progress: ${deployed_count}/${total_count} components (${percent}%)"

# Display progress bar
progress_bar=""
for ((i=0; i<total_count; i++)); do
  if [ "$i" -lt "$deployed_count" ]; then
    progress_bar="${progress_bar}${GREEN}▓${NC}"
  else
    progress_bar="${progress_bar}${RED}░${NC}"
  fi
done
echo -e "  [${progress_bar}]"

# Check Flux system health
echo -e "\n${CYAN}GitOps System Health:${NC}"
if kubectl get namespace flux-system &>/dev/null; then
  echo -e "  ${GREEN}✅ Flux namespace exists${NC}"
  
  # Check GitRepository
  if kubectl get gitrepository -n flux-system flux-system &>/dev/null; then
    git_ready=$(kubectl get gitrepository -n flux-system flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [[ "$git_ready" == "True" ]]; then
      echo -e "  ${GREEN}✅ GitRepository is healthy${NC}"
    else
      echo -e "  ${RED}❌ GitRepository has issues - Run ./scripts/gitops/resume-setup.sh${NC}"
    fi
  else
    echo -e "  ${RED}❌ GitRepository missing - Run ./scripts/gitops/resume-setup.sh${NC}"
  fi
  
  # Check controllers
  controllers=("source-controller" "kustomize-controller" "helm-controller" "notification-controller")
  for controller in "${controllers[@]}"; do
    if kubectl get deployment -n flux-system "$controller" &>/dev/null; then
      ready=$(kubectl get deployment -n flux-system "$controller" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
      if [[ "$ready" == "1" ]]; then
        echo -e "  ${GREEN}✅ $controller is running${NC}"
      else
        echo -e "  ${RED}❌ $controller is not ready${NC}"
      fi
    else
      echo -e "  ${RED}❌ $controller is missing${NC}"
    fi
  done
else
  echo -e "  ${RED}❌ Flux system not installed${NC}"
fi

# Display next steps
echo -e "\n${CYAN}Next Steps:${NC}"
if [ "$deployed_count" -eq "$total_count" ]; then
  echo -e "  ${GREEN}🎉 All components deployed!${NC}"
  echo -e "  📊 Run verification: ${CYAN}kubectl get pods -A${NC}"
  echo -e "  🔍 Access services: Add the following to /etc/hosts: ${CYAN}$(minikube ip) grafana.local prometheus.local vault.local${NC}"
  echo "  🚀 Start using your local environment!"
elif [ "$deployed_count" -eq 0 ]; then
  echo -e "  🏁 Start deployment: ${CYAN}./scripts/gitops/component-deploy.sh${NC}"
  echo -e "  🛠️ Initialize environment: ${CYAN}./scripts/setup/init-environment.sh${NC}"
else
  echo -e "  🔄 Continue deployment: ${CYAN}./scripts/gitops/component-deploy.sh${NC}"
  if grep -q "vault" "$PROGRESS_FILE" 2>/dev/null && [ "$deployed_count" -gt 0 ]; then
    echo -e "  🔐 Initialize Vault: ${CYAN}kubectl -n vault port-forward svc/vault 8200:8200${NC}"
  fi
  echo -e "  🔍 Diagnose issues: ${CYAN}./scripts/gitops/diagnose-component.sh <component-name>${NC}"
fi

echo -e "\n${CYAN}=======================================================${NC}"
echo -e "${CYAN}For detailed deployment guide: docs/LOCAL_DEVELOPMENT.md${NC}"
echo -e "${CYAN}For troubleshooting help: docs/TROUBLESHOOTING.md${NC}"
echo -e "${CYAN}=======================================================${NC}" 