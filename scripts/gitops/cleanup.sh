#!/bin/bash

# cleanup.sh: Clean up resources from a failed or completed deployment
# This script helps users reset their environment for a fresh start

set -e

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Function to map component to namespace
get_namespace() {
  local component="$1"
  case "$component" in
    "cert-manager") echo "cert-manager" ;;
    "sealed-secrets") echo "kube-system" ;;
    "ingress") echo "ingress-nginx" ;;
    "metallb") echo "metallb-system" ;;
    "vault") echo "vault" ;;
    "minio") echo "minio-system" ;;
    "policy-engine") echo "policy-engine" ;;
    "security") echo "security" ;;
    "gatekeeper") echo "gatekeeper-system" ;;
    *) echo "$component" ;;
  esac
}

# Display banner
echo -e "${CYAN}=======================================================${NC}"
echo -e "${CYAN}   GitOps Environment Cleanup${NC}"
echo -e "${CYAN}=======================================================${NC}"

# Determine cleanup level
echo -e "\nThis script helps you clean up your environment to start fresh."
echo -e "Please select a cleanup level:\n"
echo -e "  1) ${GREEN}Light${NC} - Remove Flux kustomizations only (preserves deployed components)"
echo -e "  2) ${YELLOW}Moderate${NC} - Remove Flux and all component kustomizations"
echo -e "  3) ${RED}Complete${NC} - Delete Minikube and all deployment tracking"
echo -e "  4) ${RED}Custom${NC} - Select specific components to clean up"
echo -e "  q) Quit without cleaning up"

read -p "Enter your choice [1-4/q]: " cleanup_level

case "$cleanup_level" in
  1)
    echo -e "\n${CYAN}Performing Light Cleanup...${NC}"
    
    # Delete all the single- kustomizations
    for component in "${COMPONENTS[@]}"; do
      if kubectl get kustomization -n flux-system "single-$component" &>/dev/null; then
        echo -e "  ${YELLOW}Removing kustomization for $component...${NC}"
        kubectl delete kustomization -n flux-system "single-$component"
      fi
    done
    
    # Clear progress file but keep the file
    echo "" > "$PROGRESS_FILE"
    echo -e "\n${GREEN}Light cleanup complete.${NC}"
    echo -e "You can now run ${CYAN}./scripts/gitops/component-deploy.sh${NC} to deploy components again."
    ;;
    
  2)
    echo -e "\n${YELLOW}Performing Moderate Cleanup...${NC}"
    
    # Delete all the single- kustomizations first
    for component in "${COMPONENTS[@]}"; do
      if kubectl get kustomization -n flux-system "single-$component" &>/dev/null; then
        echo -e "  ${YELLOW}Removing kustomization for $component...${NC}"
        kubectl delete kustomization -n flux-system "single-$component" 2>/dev/null || true
      fi
    done
    
    # Delete other Flux resources
    if kubectl get kustomization -n flux-system local-core-infra &>/dev/null; then
      echo -e "  ${YELLOW}Removing local-core-infra kustomization...${NC}"
      kubectl delete kustomization -n flux-system local-core-infra 2>/dev/null || true
    fi
    
    if kubectl get kustomization -n flux-system local-core-infra-stage2 &>/dev/null; then
      echo -e "  ${YELLOW}Removing local-core-infra-stage2 kustomization...${NC}"
      kubectl delete kustomization -n flux-system local-core-infra-stage2 2>/dev/null || true
    fi
    
    if kubectl get gitrepository -n flux-system flux-system &>/dev/null; then
      echo -e "  ${YELLOW}Removing GitRepository...${NC}"
      kubectl delete gitrepository -n flux-system flux-system 2>/dev/null || true
    fi
    
    # Ask if user wants to uninstall Flux
    read -p "Do you want to uninstall Flux completely? (y/N): " uninstall_flux
    if [[ "$uninstall_flux" == "y" || "$uninstall_flux" == "Y" ]]; then
      echo -e "  ${YELLOW}Uninstalling Flux...${NC}"
      flux uninstall --silent || true
    fi
    
    # Clear progress file
    rm -f "$PROGRESS_FILE"
    echo -e "\n${GREEN}Moderate cleanup complete.${NC}"
    echo -e "You can now run ${CYAN}./scripts/gitops/component-deploy.sh${NC} to deploy components again."
    ;;
    
  3)
    echo -e "\n${RED}Performing Complete Cleanup...${NC}"
    
    # Ask for confirmation
    read -p "Are you sure you want to delete everything, including Minikube? (yes/N): " confirm
    if [[ "$confirm" != "yes" ]]; then
      echo -e "${YELLOW}Complete cleanup cancelled.${NC}"
      exit 0
    fi
    
    # Delete Minikube
    echo -e "  ${RED}Deleting Minikube cluster...${NC}"
    minikube delete || true
    
    # Remove all logs and progress tracking
    echo -e "  ${RED}Removing deployment logs and tracking...${NC}"
    rm -rf "$LOG_DIR"
    
    echo -e "\n${GREEN}Complete cleanup finished.${NC}"
    echo -e "Your environment has been completely reset."
    echo -e "To start fresh, run: ${CYAN}./scripts/setup/init-environment.sh${NC}"
    ;;
    
  4)
    echo -e "\n${CYAN}Custom Cleanup - Select components to clean up:${NC}\n"
    
    # List all components with numbers
    for i in "${!COMPONENTS[@]}"; do
      component="${COMPONENTS[$i]}"
      namespace=$(get_namespace "$component")
      if kubectl get namespace "$namespace" &>/dev/null; then
        if [[ "$namespace" == "kube-system" ]]; then
          # For kube-system, check specific resources
          if kubectl get deployment -n kube-system sealed-secrets-controller &>/dev/null; then
            echo -e "  $((i+1))) ${GREEN}$component${NC} - Installed"
          else
            echo -e "  $((i+1))) ${RED}$component${NC} - Not found"
          fi
        else
          echo -e "  $((i+1))) ${GREEN}$component${NC} - Installed"
        fi
      else
        echo -e "  $((i+1))) ${RED}$component${NC} - Not found"
      fi
    done
    
    echo -e "  a) All of the above"
    echo -e "  b) Back to main menu"
    
    read -p "Enter numbers (comma-separated), 'a' for all, or 'b' to go back: " selection
    
    if [[ "$selection" == "b" ]]; then
      exec "$0"  # Re-run this script
      exit 0
    fi
    
    components_to_clean=()
    
    if [[ "$selection" == "a" ]]; then
      components_to_clean=("${COMPONENTS[@]}")
    else
      # Parse comma-separated input
      IFS=',' read -ra NUMS <<< "$selection"
      for num in "${NUMS[@]}"; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#COMPONENTS[@]}" ]; then
          components_to_clean+=("${COMPONENTS[$((num-1))]}")
        fi
      done
    fi
    
    if [ ${#components_to_clean[@]} -eq 0 ]; then
      echo -e "${YELLOW}No valid components selected. Exiting.${NC}"
      exit 0
    fi
    
    echo -e "\n${CYAN}Cleaning up selected components:${NC}"
    for component in "${components_to_clean[@]}"; do
      namespace=$(get_namespace "$component")
      echo -e "  ${YELLOW}Cleaning up $component...${NC}"
      
      # Delete kustomization
      if kubectl get kustomization -n flux-system "single-$component" &>/dev/null; then
        echo -e "    ${YELLOW}Removing kustomization...${NC}"
        kubectl delete kustomization -n flux-system "single-$component" 2>/dev/null || true
      fi
      
      # If namespace exists and it's not kube-system, ask about deleting it
      if kubectl get namespace "$namespace" &>/dev/null && [[ "$namespace" != "kube-system" ]]; then
        read -p "    Do you want to delete the $namespace namespace? (y/N): " delete_ns
        if [[ "$delete_ns" == "y" || "$delete_ns" == "Y" ]]; then
          echo -e "    ${RED}Deleting namespace $namespace...${NC}"
          kubectl delete namespace "$namespace" --wait=false || true
        fi
      elif [[ "$namespace" == "kube-system" && "$component" == "sealed-secrets" ]]; then
        # For sealed-secrets in kube-system, delete controller but not namespace
        if kubectl get deployment -n kube-system sealed-secrets-controller &>/dev/null; then
          echo -e "    ${YELLOW}Removing sealed-secrets controller...${NC}"
          kubectl delete deployment -n kube-system sealed-secrets-controller || true
        fi
      fi
      
      # Remove from progress file
      if [ -f "$PROGRESS_FILE" ]; then
        sed -i.bak "/$component/d" "$PROGRESS_FILE" 2>/dev/null || true
        rm -f "${PROGRESS_FILE}.bak" 2>/dev/null || true
      fi
    done
    
    echo -e "\n${GREEN}Custom cleanup complete.${NC}"
    echo -e "You can now run ${CYAN}./scripts/gitops/component-deploy.sh${NC} to redeploy components."
    ;;
    
  q|Q|quit|exit)
    echo -e "\n${YELLOW}Exiting without cleanup.${NC}"
    exit 0
    ;;
    
  *)
    echo -e "\n${RED}Invalid option.${NC} Please run the script again and select a valid option."
    exit 1
    ;;
esac

# Show current progress after cleanup
echo -e "\nCurrent deployment status after cleanup:"
./scripts/gitops/show-progress.sh 