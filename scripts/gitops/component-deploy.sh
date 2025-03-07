#!/bin/bash

# component-deploy.sh: Deploy infrastructure components one by one
# This script takes a more granular approach to deploy each component individually
# with verification steps between each deployment

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

# Function to log messages
log() {
  local message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Display banner
log "=========================================="
log "   Component-by-Component Deployment"
log "=========================================="
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
  LAST_SUCCESSFUL_COMPONENT=$(cat "$PROGRESS_FILE")
  log "📋 Found progress file. Last successful component: $LAST_SUCCESSFUL_COMPONENT"

  # Ask if user wants to resume
  read -p "Do you want to resume from after '$LAST_SUCCESSFUL_COMPONENT'? (Y/n): " resume
  if [[ "$resume" == "n" || "$resume" == "N" ]]; then
    log "Restarting deployment from the beginning"
    LAST_SUCCESSFUL_COMPONENT=""
    # Clear progress file
    echo "" >"$PROGRESS_FILE"
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

# Function to deploy a component and verify its deployment
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
  
  # Wait for reconciliation
  log "Waiting for reconciliation (timeout: $timeout)..."
  if flux reconcile kustomization "single-$component" --with-source --timeout="$timeout"; then
    log "✅ $component reconciled successfully"
  else
    log "⚠️ Reconciliation timed out, checking component status directly..."
    
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
          log "✅ All deployments in $namespace namespace are ready"
        elif [[ "$ready_count" -gt 0 ]]; then
          log "⚠️ Some deployments in $namespace namespace are ready ($ready_count/$total_count)"
          status_ok=true
        else
          log "❌ No deployments in $namespace namespace are ready"
        fi
      else
        # Some components might not create deployments, check for any resources
        local resources=$(kubectl get all -n "$namespace" 2>/dev/null)
        if [[ -n "$resources" ]]; then
          log "⚠️ No deployments found, but namespace has resources"
          status_ok=true
        else
          log "❌ No resources found in $namespace namespace"
        fi
      fi
    else
      log "❌ Namespace $namespace does not exist"
    fi
    
    if [[ "$status_ok" == false ]]; then
      log "⚠️ Component $component may not be fully deployed"
      
      # Ask whether to continue
      read -p "Continue with the next component? (Y/n): " continue_deploy
      if [[ "$continue_deploy" == "n" || "$continue_deploy" == "N" ]]; then
        log "Deployment stopped by user after $component"
        return 1
      fi
    fi
  fi
  
  # Mark this component as successfully deployed
  echo "$component" > "$PROGRESS_FILE"
  
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
    log "❌ Deployment stopped due to failure with component: $component"
    exit 1
  fi
done

# Final verification
log "=========================================="
log "   Deployment Complete!"
log "=========================================="
log ""
log "Deployed components:"
for component in "${COMPONENTS[@]}"; do
  if grep -q "$component" "$PROGRESS_FILE" || [[ "$component" == "$LAST_SUCCESSFUL_COMPONENT" ]]; then
    log "  ✅ $component"
  else
    log "  ❌ $component"
  fi
done

log ""
log "Verify your deployment with:"
log "  kubectl get pods -A"
log "  flux get all"
log ""
log "Deployment log saved to: $LOG_FILE"
log "=========================================="
