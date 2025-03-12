#!/bin/bash

# setup-vault.sh - Configures Vault for the staging environment
# This script initializes Vault, saves the unseal keys and root token, and sets up 
# basic policies for the staging environment

set -e

# Source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "Vault Setup for Staging Environment"
ui_log_info "This script will initialize and configure Vault for the staging environment"

# Check if required tools are installed
ui_log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    ui_log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v vault &> /dev/null; then
    ui_log_error "vault CLI not found. Please install vault CLI first: https://www.vaultproject.io/downloads"
    exit 1
fi

# Check cluster connection
ui_log_info "Checking connection to staging cluster..."
if ! kubectl get nodes &>/dev/null; then
  ui_log_error "Cannot connect to the staging cluster. Please check your kubeconfig."
  ui_log_info "Make sure you're connected to the correct cluster context."
  exit 1
fi

ui_log_success "Successfully connected to the staging cluster."

# Check if Vault is deployed
ui_log_info "Checking if Vault is deployed..."
if ! kubectl get pods -n vault -l app.kubernetes.io/name=vault &>/dev/null; then
  ui_log_error "Vault is not deployed in the cluster. Please deploy Vault first."
  ui_log_info "You can deploy Vault using Flux GitOps or manually."
  exit 1
fi

ui_log_success "Vault is deployed in the cluster."

# Create a directory to store generated secrets and tokens temporarily
SECRETS_DIR="$(mktemp -d)"
ui_log_info "Creating temporary directory for secrets: ${SECRETS_DIR}"

# Set up port forwarding to the Vault service
ui_log_info "Setting up port forwarding to Vault service..."
kubectl port-forward -n vault svc/vault 8200:8200 &
PORT_FORWARD_PID=$!

# Sleep to ensure port forwarding is established
sleep 3

# Ensure port forwarding process is killed on script exit
trap "kill ${PORT_FORWARD_PID} 2>/dev/null || true" EXIT

# Set Vault address
export VAULT_ADDR="http://localhost:8200"

# Check Vault status
ui_log_info "Checking Vault status..."
VAULT_STATUS=$(vault status -format=json 2>/dev/null || echo '{"initialized":false}')
INITIALIZED=$(echo ${VAULT_STATUS} | grep -o '"initialized":[^,}]*' | grep -o '[^:]*$' | tr -d ' "')

if [[ "${INITIALIZED}" == "true" ]]; then
  ui_log_warning "Vault is already initialized. This script will not reinitialize it."
  ui_log_info "If you need to reinitialize Vault, you must first manually unseal it."
  
  # Check if we can connect to Vault
  if ! vault status &>/dev/null; then
    ui_log_error "Unable to connect to Vault. It might be sealed."
    ui_log_info "You need to unseal Vault manually using your existing unseal keys."
    exit 1
  fi
  
  ui_log_success "Connected to initialized Vault successfully."
else
  ui_subheader "Initializing Vault"
  ui_log_info "Initializing Vault with 5 key shares and 3 key threshold..."
  
  VAULT_INIT=$(vault operator init -key-shares=5 -key-threshold=3 -format=json)
  echo "${VAULT_INIT}" > "${SECRETS_DIR}/vault-init.json"
  
  ui_log_success "Vault initialized successfully."
  
  # Extract unseal keys and root token
  ui_log_info "Extracting unseal keys and root token..."
  for i in {1..5}; do
    UNSEAL_KEY=$(echo "${VAULT_INIT}" | grep -o "\"unseal_keys_b64\":\[[^]]*\]" | grep -o "\"[^\"]*\"" | sed -n "${i}p" | tr -d '"')
    echo "${UNSEAL_KEY}" > "${SECRETS_DIR}/unseal-key-${i}.txt"
  done
  
  ROOT_TOKEN=$(echo "${VAULT_INIT}" | grep -o "\"root_token\":\"[^\"]*\"" | cut -d'"' -f4)
  echo "${ROOT_TOKEN}" > "${SECRETS_DIR}/root-token.txt"
  
  # Unseal Vault
  ui_subheader "Unsealing Vault"
  ui_log_info "Unsealing Vault with 3 keys..."
  
  for i in {1..3}; do
    UNSEAL_KEY=$(cat "${SECRETS_DIR}/unseal-key-${i}.txt")
    vault operator unseal "${UNSEAL_KEY}"
  done
  
  ui_log_success "Vault unsealed successfully."
  
  # Log in to Vault
  ui_log_info "Logging in to Vault with root token..."
  vault login "${ROOT_TOKEN}"
  
  ui_subheader "Configuring Vault"
  # Enable secrets engines
  ui_log_info "Enabling secrets engines..."
  
  # Enable KV v2 secrets engine
  vault secrets enable -path=staging kv-v2
  ui_log_success "Enabled KV v2 secrets engine at path 'staging'."
  
  # Enable Transit secrets engine
  vault secrets enable transit
  ui_log_success "Enabled Transit secrets engine at path 'transit'."
  
  # Create policies
  ui_log_info "Creating policies..."
  
  # Create policy for staging applications
  cat > "${SECRETS_DIR}/staging-policy.hcl" << EOF
# Allow access to staging secrets
path "staging/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow access to transit for encryption/decryption
path "transit/*" {
  capabilities = ["create", "read", "update", "list"]
}
EOF
  
  vault policy write staging-apps "${SECRETS_DIR}/staging-policy.hcl"
  ui_log_success "Created policy 'staging-apps'."
  
  # Create policy for operations access
  cat > "${SECRETS_DIR}/ops-policy.hcl" << EOF
# Full access to staging secrets
path "staging/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Full access to transit
path "transit/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read system health
path "sys/health" {
  capabilities = ["read", "sudo"]
}

# Manage policies
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
  
  vault policy write staging-ops "${SECRETS_DIR}/ops-policy.hcl"
  ui_log_success "Created policy 'staging-ops'."
  
  # Create tokens
  ui_log_info "Creating service tokens..."
  
  # Create token for staging applications
  STAGING_TOKEN=$(vault token create -policy=staging-apps -format=json | grep -o '"client_token":"[^"]*"' | cut -d'"' -f4)
  echo "${STAGING_TOKEN}" > "${SECRETS_DIR}/staging-apps-token.txt"
  ui_log_success "Created token for staging applications."
  
  # Create token for operations
  OPS_TOKEN=$(vault token create -policy=staging-ops -format=json | grep -o '"client_token":"[^"]*"' | cut -d'"' -f4)
  echo "${OPS_TOKEN}" > "${SECRETS_DIR}/staging-ops-token.txt"
  ui_log_success "Created token for operations."
fi

# Backup secrets to a more persistent location for reference
ui_subheader "Backing Up Vault Credentials"

BACKUP_DIR="$HOME/.boldorigins/staging/vault"
mkdir -p "${BACKUP_DIR}"
ui_log_info "Backing up Vault credentials to: ${BACKUP_DIR}"

# Copy all files or just tokens if Vault was already initialized
if [[ -f "${SECRETS_DIR}/vault-init.json" ]]; then
  cp "${SECRETS_DIR}"/*.txt "${BACKUP_DIR}/"
  cp "${SECRETS_DIR}/vault-init.json" "${BACKUP_DIR}/"
elif [[ -f "${SECRETS_DIR}/staging-apps-token.txt" ]]; then
  cp "${SECRETS_DIR}"/*.txt "${BACKUP_DIR}/"
fi

chmod 600 "${BACKUP_DIR}"/*

ui_log_success "Vault credentials backed up to: ${BACKUP_DIR}"
ui_log_warning "IMPORTANT: Keep these credentials secure! They provide full access to your Vault."

# Clean up temporary secrets
ui_log_info "Cleaning up temporary secrets..."
rm -rf "${SECRETS_DIR}"

ui_header "Vault Setup Complete"
ui_log_success "Vault has been initialized and configured for the staging environment."
ui_log_info "Important credentials have been saved to: ${BACKUP_DIR}"
ui_log_info "Remember to backup these credentials to a secure location!"

exit 0 