#!/bin/bash

# setup-supabase-secrets.sh - Generates and configures Supabase secrets for the staging environment

set -e

# Source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "Supabase Secrets Generator for Staging Environment"
ui_log_info "This script will generate and configure secrets for Supabase in the staging environment"

# Check if required tools are installed
ui_log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    ui_log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v kubeseal &> /dev/null; then
    ui_log_error "kubeseal not found. Please install kubeseal first: https://github.com/bitnami-labs/sealed-secrets"
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

# Create a directory to store generated secrets and tokens temporarily
SECRETS_DIR="$(mktemp -d)"
ui_log_info "Creating temporary directory for secrets: ${SECRETS_DIR}"

# Function to generate random passwords
generate_password() {
  openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

# Generate Supabase required passwords and keys
ui_subheader "Generating Supabase Secrets"

ui_log_info "Generating JWT secret..."
JWT_SECRET=$(openssl rand -base64 32)
echo "${JWT_SECRET}" > "${SECRETS_DIR}/jwt-secret.txt"

ui_log_info "Generating Postgres password..."
POSTGRES_PASSWORD=$(generate_password)
echo "${POSTGRES_PASSWORD}" > "${SECRETS_DIR}/postgres-password.txt"

ui_log_info "Generating ANON_KEY..."
ANON_KEY=$(openssl rand -base64 32)
echo "${ANON_KEY}" > "${SECRETS_DIR}/anon-key.txt"

ui_log_info "Generating SERVICE_ROLE_KEY..."
SERVICE_ROLE_KEY=$(openssl rand -base64 32)
echo "${SERVICE_ROLE_KEY}" > "${SECRETS_DIR}/service-role-key.txt"

ui_log_info "Generating dashboard admin password..."
DASHBOARD_PASSWORD=$(generate_password)
echo "${DASHBOARD_PASSWORD}" > "${SECRETS_DIR}/dashboard-password.txt"

# Create Kubernetes secret manifest
ui_subheader "Creating Kubernetes Secret"

ui_log_info "Creating Supabase secret manifest..."
cat > "${SECRETS_DIR}/supabase-secrets.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: supabase-secrets
  namespace: supabase
type: Opaque
stringData:
  jwt-secret: ${JWT_SECRET}
  postgres-password: ${POSTGRES_PASSWORD}
  anon-key: ${ANON_KEY}
  service-role-key: ${SERVICE_ROLE_KEY}
  dashboard-password: ${DASHBOARD_PASSWORD}
EOF

# Seal the secret using kubeseal
ui_subheader "Sealing Secrets with SealedSecrets"

ui_log_info "Making sure the supabase namespace exists..."
if ! kubectl get namespace supabase &>/dev/null; then
  ui_log_info "Creating supabase namespace..."
  kubectl create namespace supabase
fi

ui_log_info "Sealing Supabase secrets..."
mkdir -p "clusters/staging/applications/supabase/secrets"
kubeseal --format yaml --cert <(kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o jsonpath="{.items[0].data['tls\.crt']}" | base64 --decode) \
  < "${SECRETS_DIR}/supabase-secrets.yaml" \
  > "clusters/staging/applications/supabase/secrets/sealed-supabase-secrets.yaml"

ui_log_success "Sealed secret created at: clusters/staging/applications/supabase/secrets/sealed-supabase-secrets.yaml"

# Update kustomization to include the sealed secret
ui_log_info "Updating kustomization to include the sealed secret..."
# Check if the secrets directory is already included in the kustomization
if ! grep -q "secrets/" "clusters/staging/applications/supabase/kustomization.yaml"; then
  # Add the secrets directory to the kustomization
  sed -i.bak '/resources:/a\ \ - secrets/' "clusters/staging/applications/supabase/kustomization.yaml" && rm "clusters/staging/applications/supabase/kustomization.yaml.bak"
  ui_log_success "Updated kustomization file to include secrets directory"
else
  ui_log_info "Secrets directory already included in kustomization"
fi

# Backup secrets to a more persistent location for reference
ui_subheader "Backing Up Secrets"

BACKUP_DIR="$HOME/.boldorigins/staging/secrets"
mkdir -p "${BACKUP_DIR}"
ui_log_info "Backing up secrets to: ${BACKUP_DIR}"

cp "${SECRETS_DIR}"/*.txt "${BACKUP_DIR}/"
chmod 600 "${BACKUP_DIR}"/*.txt

ui_log_success "Secrets backed up to: ${BACKUP_DIR}"
ui_log_warning "Keep these secrets secure! They provide access to your Supabase instance."

# Clean up temporary secrets
ui_log_info "Cleaning up temporary secrets..."
rm -rf "${SECRETS_DIR}"

ui_header "Supabase Secrets Setup Complete"
ui_log_success "Supabase secrets have been generated, sealed, and backed up for the staging environment."
ui_log_info "Important secrets have been saved to: ${BACKUP_DIR}"
ui_log_info "You can apply the sealed secrets to your cluster using Flux or kubectl:"
ui_log_info "  kubectl apply -f clusters/staging/applications/supabase/secrets/sealed-supabase-secrets.yaml"

exit 0 