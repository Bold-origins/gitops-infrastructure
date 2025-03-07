#!/bin/bash

# direct-deploy.sh: Deploy infrastructure components directly using kustomize
# This script preserves your GitOps structure but bypasses Flux reconciliation

set -e

# Configuration
LOG_DIR="logs/deployment"
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

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Current timestamp for logging
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$LOG_DIR/deployment-$TIMESTAMP.log"

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
  echo -e "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Display banner
log "${CYAN}==========================================${NC}"
log "${CYAN}   Direct Component Deployment (GitOps Structure)${NC}"
log "${CYAN}==========================================${NC}"
log ""

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
  log "✅ Environment variables loaded from .env file"
else
  log "❌ Error: .env file not found"
  exit 1
fi

# Check if minikube is running
if ! minikube status &>/dev/null; then
  log "❌ Error: Minikube is not running. Please start Minikube first."
  exit 1
fi

# Check for required tools
for tool in kubectl kustomize; do
  if ! command -v $tool &>/dev/null; then
    log "❌ Error: $tool not found. Please install $tool."
    exit 1
  fi
done

# Check for progress tracking file
PROGRESS_FILE="$LOG_DIR/deployment-progress.txt"
LAST_SUCCESSFUL_COMPONENT=""

if [ -f "$PROGRESS_FILE" ]; then
  # Read the last line of the progress file
  LAST_SUCCESSFUL_COMPONENT=$(tail -1 "$PROGRESS_FILE")
  log "📋 Found progress file. Last successful component: $LAST_SUCCESSFUL_COMPONENT"

  # Ask if user wants to resume
  read -p "Do you want to resume from after '$LAST_SUCCESSFUL_COMPONENT'? (Y/n): " resume
  if [[ "$resume" == "n" || "$resume" == "N" ]]; then
    log "Restarting deployment from the beginning"
    LAST_SUCCESSFUL_COMPONENT=""
    # Clear progress file
    echo "" > "$PROGRESS_FILE"
  else
    log "Resuming deployment from after '$LAST_SUCCESSFUL_COMPONENT'"
  fi
fi

# Function to deploy a component directly
deploy_component() {
  local component="$1"
  local namespace="${2:-$component}"
  
  # Skip if we've already deployed this component successfully
  if [[ -n "$LAST_SUCCESSFUL_COMPONENT" ]]; then
    local found=false
    for c in "${COMPONENTS[@]}"; do
      if [[ "$c" == "$LAST_SUCCESSFUL_COMPONENT" ]]; then
        found=true
        continue
      fi
      if [[ "$found" == true && "$c" == "$component" ]]; then
        break
      fi
      if [[ "$found" == true ]]; then
        continue
      fi
    done
    if [[ "$found" == false || "$component" == "$LAST_SUCCESSFUL_COMPONENT" ]]; then
      log "🔄 Skipping $component as it was already deployed"
      return 0
    fi
  fi
  
  log "🚀 Deploying component: $component (namespace: $namespace)"
  
  # Create namespace if it doesn't exist
  if ! kubectl get namespace "$namespace" &>/dev/null; then
    log "Creating namespace: $namespace"
    kubectl create namespace "$namespace"
  fi
  
  # Check if component directory exists
  if [ ! -d "clusters/local/infrastructure/$component" ]; then
    log "❌ Error: Component directory not found at clusters/local/infrastructure/$component"
    return 1
  fi
  
  # FIRST PHASE: Apply only CRDs if they exist
  log "Checking for CRDs in the component..."
  
  # Check for any CRD file in the base directory
  local crds_exist=false
  if [ -f "clusters/base/infrastructure/$component/crds.yaml" ]; then
    crds_exist=true
    log "Found CRDs file, applying it first..."
    kubectl apply -f "clusters/base/infrastructure/$component/crds.yaml"
    
    # Wait a bit for CRDs to be established
    log "Waiting 10 seconds for CRDs to be established..."
    sleep 10
    
    # Verify CRDs are established
    local crd_count=$(kubectl get crds -o name | grep -c "$component" || echo "0")
    log "Found $crd_count CRDs for $component"
  else
    log "No separate CRDs file found, continuing with normal deployment"
  fi
  
  # SECOND PHASE: Apply the kustomized resources directly
  log "Building and applying kustomized resources for $component..."
  if ! kustomize build "clusters/local/infrastructure/$component" | kubectl apply -f -; then
    log "${RED}❌ Failed to apply kustomized resources for $component${NC}"
    return 1
  fi
  
  log "Waiting for resources to become ready..."
  sleep 5
  
  # For critical components, we verify their status more thoroughly
  local status_ok=false
  
  # Check if namespace exists
  if kubectl get namespace "$namespace" &>/dev/null; then
    # Check for deployments in the namespace
    local deployments=$(kubectl get deployments -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [[ -n "$deployments" ]]; then
      # Check if deployments are ready
      local ready_count=0
      local total_count=0
      
      for deployment in $deployments; do
        let total_count++
        log "Waiting for deployment $deployment to be ready..."
        if kubectl rollout status deployment "$deployment" -n "$namespace" --timeout=120s &>/dev/null; then
          let ready_count++
          log "${GREEN}✅ Deployment $deployment is ready${NC}"
        else
          log "${RED}❌ Deployment $deployment failed to become ready${NC}"
        fi
      done
      
      if [[ "$ready_count" -gt 0 && "$ready_count" == "$total_count" ]]; then
        status_ok=true
        log "${GREEN}✅ All deployments in $namespace namespace are ready${NC}"
      elif [[ "$ready_count" -gt 0 ]]; then
        log "${YELLOW}⚠️ Some deployments in $namespace namespace are ready ($ready_count/$total_count)${NC}"
        status_ok=true
      else
        log "${RED}❌ No deployments in $namespace namespace are ready${NC}"
      fi
    else
      # Some components might not create deployments, check for any resources
      local resources=$(kubectl get all -n "$namespace" 2>/dev/null)
      if [[ -n "$resources" ]]; then
        log "${YELLOW}⚠️ No deployments found, but namespace has resources${NC}"
        status_ok=true
      else
        log "${RED}❌ No resources found in $namespace namespace${NC}"
      fi
    fi
  else
    log "${RED}❌ Namespace $namespace does not exist${NC}"
  fi
  
  if [[ "$status_ok" == false ]]; then
    log "${YELLOW}⚠️ Component $component may not be fully deployed${NC}"
    
    # Ask whether to continue
    read -p "Continue with the next component? (Y/n): " continue_deploy
    if [[ "$continue_deploy" == "n" || "$continue_deploy" == "N" ]]; then
      log "Deployment stopped by user after $component"
      return 1
    fi
  else
    # Mark this component as successfully deployed
    echo "$component" > "$PROGRESS_FILE"
  fi
  
  log "-------------------------------------------"
  return 0
}

# Special case for sealed-secrets because it needs Helm
deploy_sealed_secrets() {
  if [[ -n "$LAST_SUCCESSFUL_COMPONENT" ]] && [[ "$LAST_SUCCESSFUL_COMPONENT" == "sealed-secrets" || $(grep -c "sealed-secrets" "$PROGRESS_FILE") -gt 0 ]]; then
    log "🔄 Skipping sealed-secrets as it was already deployed"
    return 0
  fi
  
  # Check if sealed-secrets is already installed
  if kubectl get pods -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets-controller &>/dev/null; then
    log "${GREEN}✅ sealed-secrets is already installed${NC}"
    echo "sealed-secrets" > "$PROGRESS_FILE"
    return 0
  fi
  
  log "🚀 Deploying component: sealed-secrets (namespace: sealed-secrets)"
  
  # Create namespace if it doesn't exist
  if ! kubectl get namespace sealed-secrets &>/dev/null; then
    log "Creating namespace: sealed-secrets"
    kubectl create namespace sealed-secrets
  fi
  
  # Add Helm repo if needed
  if ! helm repo list | grep -q "sealed-secrets"; then
    log "Adding sealed-secrets Helm repository..."
    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
    helm repo update
  fi
  
  log "Installing sealed-secrets with Helm..."
  if helm install sealed-secrets sealed-secrets/sealed-secrets -n sealed-secrets \
    --set fullnameOverride=sealed-secrets-controller \
    --set namespace=sealed-secrets \
    --set "controller.args[0]=--update-status" \
    --set "controller.args[1]=--key-prefix=sealed-secrets-key" \
    --set "controller.args[2]=--log-level=debug"; then
    
    log "${GREEN}✅ sealed-secrets installed successfully${NC}"
    
    # Wait for pod to be ready
    log "Waiting for sealed-secrets controller to be ready..."
    kubectl rollout status deployment sealed-secrets-controller -n sealed-secrets --timeout=120s
    
    # Mark as deployed
    echo "sealed-secrets" > "$PROGRESS_FILE"
    return 0
  else
    log "${RED}❌ Failed to install sealed-secrets${NC}"
    return 1
  fi
}

# Deploy components one by one
for component in "${COMPONENTS[@]}"; do
  case "$component" in
  "cert-manager")
    deploy_component "cert-manager" "cert-manager"
    ;;
  "sealed-secrets")
    deploy_sealed_secrets
    ;;
  "ingress")
    deploy_component "ingress" "ingress-nginx"
    ;;
  "metallb")
    deploy_component "metallb" "metallb-system"
    ;;
  "vault")
    deploy_component "vault" "vault"

    # Special handling for Vault - if deployment is successful, help with initialization
    if [[ $? -eq 0 ]] && kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].status.phase}' | grep -q Running; then
      echo -e "\n${CYAN}Vault has been deployed successfully.${NC}"
      echo -e "Would you like to initialize Vault now? This is required to make Vault operational."
      read -p "Initialize Vault now? (Y/n): " init_vault

      if [[ "$init_vault" != "n" && "$init_vault" != "N" ]]; then
        echo -e "\n${CYAN}Starting port-forward to Vault...${NC}"
        # Run in background
        kubectl -n vault port-forward svc/vault 8200:8200 &
        PORT_FWD_PID=$!

        # Wait for port-forward to be ready
        echo "Waiting for port-forward to be established..."
        sleep 3

        # Check if Vault is already initialized
        INIT_STATUS=$(curl -s http://localhost:8200/v1/sys/init | jq -r '.initialized')

        if [[ "$INIT_STATUS" == "false" ]]; then
          echo -e "\n${CYAN}Initializing Vault with 1 key share and 1 key threshold${NC}"
          echo -e "(This is sufficient for development; use more shares/threshold in production)"

          # Initialize vault
          INIT_RESPONSE=$(curl -s \
            --request POST \
            --data '{"secret_shares": 1, "secret_threshold": 1}' \
            http://localhost:8200/v1/sys/init)

          # Extract unseal key and root token
          UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r '.keys[0]')
          ROOT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r '.root_token')

          echo -e "\n${GREEN}Vault initialized successfully!${NC}"
          echo -e "${YELLOW}Important: Save these values securely. They will NOT be shown again.${NC}"
          echo -e "Unseal Key: ${CYAN}$UNSEAL_KEY${NC}"
          echo -e "Root Token: ${CYAN}$ROOT_TOKEN${NC}"

          # Update .env file with Vault credentials if user wants
          echo -e "\nWould you like to update your .env file with these credentials?"
          read -p "Update .env file? (Y/n): " update_env

          if [[ "$update_env" != "n" && "$update_env" != "N" ]]; then
            # Create backup
            cp .env .env.bak

            # Update .env file
            sed -i.tmp "s|VAULT_UNSEAL_KEY=.*|VAULT_UNSEAL_KEY=\"$UNSEAL_KEY\"|g" .env
            sed -i.tmp "s|VAULT_ROOT_TOKEN=.*|VAULT_ROOT_TOKEN=\"$ROOT_TOKEN\"|g" .env
            rm -f .env.tmp

            echo -e "${GREEN}Updated .env file with Vault credentials.${NC}"
            echo -e "A backup has been saved as .env.bak"
          fi

          # Unseal vault
          echo -e "\n${CYAN}Unsealing Vault...${NC}"
          curl -s \
            --request POST \
            --data "{\"key\": \"$UNSEAL_KEY\"}" \
            http://localhost:8200/v1/sys/unseal

          echo -e "\n${GREEN}Vault is now initialized and unsealed!${NC}"
          echo -e "Access the Vault UI: ${CYAN}http://localhost:8200${NC}"
          echo -e "Use the Root Token to log in: ${CYAN}$ROOT_TOKEN${NC}"
        elif [[ "$INIT_STATUS" == "true" ]]; then
          echo -e "\n${YELLOW}Vault is already initialized.${NC}"
          echo -e "If you need to unseal Vault, run:"
          echo -e "${CYAN}export VAULT_ADDR=http://localhost:8200${NC}"
          echo -e "${CYAN}vault operator unseal <your-unseal-key>${NC}"
        else
          echo -e "\n${RED}Failed to check Vault initialization status.${NC}"
          echo -e "Please ensure Vault is running and try again manually:"
          echo -e "${CYAN}kubectl -n vault port-forward svc/vault 8200:8200${NC}"
        fi

        # Kill port-forward
        kill $PORT_FWD_PID 2>/dev/null || true
      else
        echo -e "\n${YELLOW}Skipping Vault initialization.${NC}"
        echo -e "You can initialize Vault later with:"
        echo -e "${CYAN}kubectl -n vault port-forward svc/vault 8200:8200${NC}"
        echo -e "Then in another terminal:"
        echo -e "${CYAN}export VAULT_ADDR=http://localhost:8200${NC}"
        echo -e "${CYAN}vault operator init -key-shares=1 -key-threshold=1${NC}"
      fi
    fi
    ;;
  "minio")
    deploy_component "minio" "minio-system"
    ;;
  "policy-engine")
    deploy_component "policy-engine" "policy-engine"
    ;;
  "security")
    deploy_component "security" "security"
    ;;
  "gatekeeper")
    deploy_component "gatekeeper" "gatekeeper-system"
    ;;
  *)
    log "⚠️ Unknown component: $component"
    ;;
  esac

  # Exit if any deployment fails
  if [ $? -ne 0 ]; then
    log "${RED}❌ Deployment stopped due to failure with component: $component${NC}"
    exit 1
  fi
done

# Final verification
log "${CYAN}==========================================${NC}"
log "${CYAN}   Deployment Complete!${NC}"
log "${CYAN}==========================================${NC}"
log ""
log "Deployed components:"
for component in "${COMPONENTS[@]}"; do
  if grep -q "$component" "$PROGRESS_FILE" || [[ "$component" == "$LAST_SUCCESSFUL_COMPONENT" ]]; then
    log "  ${GREEN}✅ $component${NC}"
  else
    log "  ${RED}❌ $component${NC}"
  fi
done

log ""
log "Verify your deployment with:"
log "  ${CYAN}kubectl get pods -A${NC}"
log ""
log "Deployment log saved to: $LOG_FILE"
log "${CYAN}==========================================${NC}" 