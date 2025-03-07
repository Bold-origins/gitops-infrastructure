#!/bin/bash

# component-deploy-safe.sh: Enhanced version of component-deploy.sh 
# with better error handling and timeout protections
# This script deploys infrastructure components one by one with additional safeguards

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
log "${CYAN}   Enhanced Component-by-Component Deployment${NC}"
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
for tool in kubectl flux kustomize; do
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

# Setup Flux if not already installed
log "Checking for Flux installation..."
if ! kubectl get namespace flux-system &>/dev/null; then
  log "Setting up Flux GitOps controllers..."
  flux install
else
  log "✅ Flux is already installed"

  # Check if GitRepository exists
  if ! kubectl get gitrepository -n flux-system flux-system &>/dev/null; then
    log "Creating GitRepository resource..."
    # Create GitRepository resource
    kubectl -n flux-system create secret generic flux-system \
      --from-literal=username=${GITHUB_USER} \
      --from-literal=password=${GITHUB_TOKEN} \
      --dry-run=client -o yaml | kubectl apply -f -

    flux create source git flux-system \
      --url=https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
      --branch=main \
      --username=${GITHUB_USER} \
      --password=${GITHUB_TOKEN} \
      --namespace=flux-system \
      --secret-ref=flux-system

    log "✅ GitRepository resource created"
  else
    log "✅ GitRepository already exists"
    # Verify URL is correct
    REPO_URL=$(kubectl get gitrepository -n flux-system flux-system -o jsonpath='{.spec.url}')
    EXPECTED_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}"

    if [ "$REPO_URL" != "$EXPECTED_URL" ]; then
      log "⚠️ GitRepository URL mismatch. Updating..."
      kubectl patch gitrepository flux-system -n flux-system --type=json \
        -p "[{\"op\": \"replace\", \"path\": \"/spec/url\", \"value\": \"$EXPECTED_URL\"}]"
      log "✅ GitRepository URL updated"
    fi
  fi
fi

# Function to check if a pod is in crash loop
check_crash_loop() {
  local namespace="$1"
  local pod_prefix="$2"
  local pods=$(kubectl get pods -n "$namespace" -o name | grep "$pod_prefix" 2>/dev/null)
  
  if [ -z "$pods" ]; then
    return 1
  fi
  
  for pod in $pods; do
    local status=$(kubectl get "$pod" -n "$namespace" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
    if [[ "$status" == "CrashLoopBackOff" ]]; then
      return 0
    fi
  done
  
  return 1
}

# Function to check if there's a timeout in Flux
check_flux_timeout() {
  local component="$1"
  if kubectl get kustomization -n flux-system "single-$component" &>/dev/null; then
    local status=$(kubectl get kustomization -n flux-system "single-$component" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
    if [[ "$status" == *"timeout"* || "$status" == *"timed out"* ]]; then
      return 0
    fi
  fi
  return 1
}

# Function to deploy a component with enhanced error handling
deploy_component() {
  local component="$1"
  local timeout="${2:-5m}"
  local namespace="${3:-$component}"
  
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
  
  # Create component directory in logs
  local component_log_dir="$LOG_DIR/$component"
  mkdir -p "$component_log_dir"
  
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
  
  # SECOND PHASE: Apply the full component
  # Create a Kustomization for this single component with longer timeouts
  local component_kust_file="$component_log_dir/kustomization.yaml"
  cat > "$component_kust_file" <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: single-$component
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/local/infrastructure/$component
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  timeout: 10m0s
  retryInterval: 2m0s
  wait: true
EOF
  
  log "Applying Kustomization for $component..."
  kubectl apply -f "$component_kust_file"
  
  # Set a timeout for the reconciliation process
  local max_wait_seconds=$(($(echo $timeout | sed 's/m//') * 60 - 30))
  log "Waiting for reconciliation with enhanced timeout protection (max: $max_wait_seconds seconds)..."
  
  local start_time=$(date +%s)
  local reconciliation_started=false
  local reconciliation_success=false
  
  # Monitor the reconciliation process with a timeout
  while [ "$reconciliation_success" = false ]; do
    # Check if we've exceeded our timeout
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    
    if [ $elapsed_time -gt $max_wait_seconds ]; then
      log "${RED}⚠️ Maximum wait time exceeded ($max_wait_seconds seconds). Moving to manual verification...${NC}"
      break
    fi
    
    # Check for crash loops every 15 seconds
    if [ $((elapsed_time % 15)) -eq 0 ]; then
      if check_crash_loop "$namespace" "$component"; then
        log "${RED}⚠️ Detected pods in CrashLoopBackOff state for $component. Checking logs...${NC}"
        kubectl get pods -n "$namespace" | grep "$component"
        local crash_pod=$(kubectl get pods -n "$namespace" -o name | grep "$component" | head -1)
        if [ -n "$crash_pod" ]; then
          log "Pod logs for $crash_pod:"
          kubectl logs -n "$namespace" "$crash_pod" | tail -20
          
          log "${YELLOW}⚠️ A pod is in CrashLoopBackOff state. Do you want to continue waiting or skip this component?${NC}"
          read -p "Continue waiting? (Y/n/skip): " crash_action
          if [[ "$crash_action" == "n" || "$crash_action" == "N" ]]; then
            log "Stopping deployment due to crash loop in $component"
            return 1
          elif [[ "$crash_action" == "skip" ]]; then
            log "Skipping $component due to crash loop"
            break
          fi
        fi
      fi
      
      # Check for timeout in Flux
      if check_flux_timeout "$component"; then
        log "${YELLOW}⚠️ Flux reconciliation timeout detected. Verifying component status directly...${NC}"
        break
      fi
    fi
    
    # Try to reconcile, but with a short timeout on the command itself
    if ! reconciliation_started; then
      if timeout 30s flux reconcile kustomization "single-$component" --with-source; then
        log "✅ Reconciliation triggered for $component"
        reconciliation_started=true
      else
        log "${YELLOW}⚠️ Failed to trigger reconciliation, will retry...${NC}"
        sleep 5
        continue
      fi
    fi
    
    # Check reconciliation status
    local ready_status=$(kubectl get kustomization -n flux-system "single-$component" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [[ "$ready_status" == "True" ]]; then
      log "${GREEN}✅ $component reconciled successfully${NC}"
      reconciliation_success=true
      break
    elif [[ "$ready_status" == "False" ]]; then
      local message=$(kubectl get kustomization -n flux-system "single-$component" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
      log "${YELLOW}⚠️ Reconciliation failed: $message${NC}"
      
      log "${YELLOW}⚠️ Do you want to retry, continue checking status directly, or abort?${NC}"
      read -p "Action (retry/continue/abort): " reconcile_action
      if [[ "$reconcile_action" == "retry" ]]; then
        log "Retrying reconciliation..."
        reconciliation_started=false
        continue
      elif [[ "$reconcile_action" == "abort" ]]; then
        log "Aborting deployment of $component"
        return 1
      else
        log "Continuing with direct status check..."
        break
      fi
    fi
    
    # Sleep for a bit before checking again
    sleep 5
    # Show progress dot every few seconds
    if [ $((elapsed_time % 5)) -eq 0 ]; then
      echo -n "." 
    fi
  done
  
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
        if kubectl rollout status deployment "$deployment" -n "$namespace" --timeout=30s &>/dev/null; then
          let ready_count++
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
  elif [[ "$reconciliation_success" == true || "$status_ok" == true ]]; then
    # Mark this component as successfully deployed
    echo "$component" > "$PROGRESS_FILE"
  fi
  
  log "-------------------------------------------"
  return 0
}

# Deploy components one by one
for component in "${COMPONENTS[@]}"; do
  case "$component" in
  "cert-manager")
    deploy_component "cert-manager" "15m" "cert-manager"
    ;;
  "sealed-secrets")
    deploy_component "sealed-secrets" "10m" "sealed-secrets"
    ;;
  "ingress")
    deploy_component "ingress" "10m" "ingress-nginx"
    ;;
  "metallb")
    deploy_component "metallb" "10m" "metallb-system"
    ;;
  "vault")
    deploy_component "vault" "15m" "vault"

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
    deploy_component "minio" "5m" "minio-system"
    ;;
  "policy-engine")
    deploy_component "policy-engine" "5m" "policy-engine"
    ;;
  "security")
    deploy_component "security" "5m" "security"
    ;;
  "gatekeeper")
    deploy_component "gatekeeper" "5m" "gatekeeper-system"
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
log "  ${CYAN}flux get all${NC}"
log ""
log "Deployment log saved to: $LOG_FILE"
log "${CYAN}==========================================${NC}" 