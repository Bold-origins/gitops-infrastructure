#!/bin/bash

# setup-staging-environment.sh - Main script for setting up the staging environment
# This script provides a menu-based interface to run various setup scripts

set -e

# Source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "Staging Environment Setup"
ui_log_info "This script will help you set up the Bold Origins staging environment."

# Check if required tools are installed
ui_log_info "Checking prerequisites..."
MISSING_TOOLS=()

if ! command -v kubectl &> /dev/null; then
    MISSING_TOOLS+=("kubectl")
fi

if ! command -v flux &> /dev/null; then
    MISSING_TOOLS+=("flux")
fi

if ! command -v kubeseal &> /dev/null; then
    MISSING_TOOLS+=("kubeseal")
fi

if ! command -v git &> /dev/null; then
    MISSING_TOOLS+=("git")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    ui_log_error "The following required tools are missing:"
    for tool in "${MISSING_TOOLS[@]}"; do
        ui_log_error "  - $tool"
    done
    ui_log_info "Please install the missing tools and try again."
    exit 1
fi

ui_log_success "All required tools are installed."

# Check cluster connection
ui_log_info "Checking connection to staging cluster..."
if ! kubectl get nodes &>/dev/null; then
  ui_log_warning "Cannot connect to the staging cluster. Some operations may fail."
  ui_log_info "Make sure you're connected to the correct cluster context before proceeding with infrastructure setup."
else
  ui_log_success "Successfully connected to the staging cluster."
  CLUSTER_CONNECTED=1
fi

# Function to run a setup script
run_setup_script() {
    local script="$1"
    local name="$2"
    
    ui_log_info "Running $name setup..."
    if [ -x "$script" ]; then
        bash "$script"
        local status=$?
        if [ $status -eq 0 ]; then
            ui_log_success "$name setup completed successfully."
        else
            ui_log_error "$name setup failed with exit code $status."
            read -p "Press Enter to continue..."
        fi
    else
        ui_log_error "Script $script does not exist or is not executable."
        read -p "Press Enter to continue..."
    fi
}

# Main menu function
show_menu() {
    clear
    ui_header "Staging Environment Setup"
    echo ""
    echo "Please select an option:"
    echo ""
    echo "Basic Setup:"
    echo "  1) Create Required Namespaces"
    echo ""
    echo "Infrastructure Setup:"
    echo "  2) Install Flux CD"
    echo "  3) Set up MetalLB"
    echo "  4) Set up Gatekeeper Policies"
    echo ""
    echo "Secret Management:"
    echo "  5) Set up Vault"
    echo "  6) Set up Supabase Secrets"
    echo ""
    echo "Security:"
    echo "  7) Run Security Audit"
    echo ""
    echo "  8) Run Full Setup (all of the above)"
    echo "  9) Exit"
    echo ""
    read -p "Enter your choice [1-9]: " choice
    
    case $choice in
        1)
            run_setup_script "${SCRIPT_DIR}/create-namespaces.sh" "Namespace Creation"
            ;;
        2)
            run_setup_script "${SCRIPT_DIR}/install-flux.sh" "Flux CD"
            ;;
        3)
            run_setup_script "${SCRIPT_DIR}/setup-metallb.sh" "MetalLB"
            ;;
        4)
            run_setup_script "${SCRIPT_DIR}/setup-policy-engine.sh" "Gatekeeper Policies"
            ;;
        5)
            run_setup_script "${SCRIPT_DIR}/secrets/setup-vault.sh" "Vault"
            ;;
        6)
            run_setup_script "${SCRIPT_DIR}/secrets/setup-supabase-secrets.sh" "Supabase Secrets"
            ;;
        7)
            run_setup_script "${SCRIPT_DIR}/security/audit-kubernetes.sh" "Security Audit"
            ;;
        8)
            ui_log_info "Running full setup..."
            
            # First create all required namespaces
            run_setup_script "${SCRIPT_DIR}/create-namespaces.sh" "Namespace Creation"
            
            # Check if install-flux.sh exists, if not, prompt user to skip
            if [ ! -x "${SCRIPT_DIR}/install-flux.sh" ]; then
                ui_log_warning "Flux installation script not found. Do you want to skip Flux installation?"
                read -p "Skip Flux installation? (y/n): " skip_flux
                if [[ "${skip_flux}" != "y" && "${skip_flux}" != "Y" ]]; then
                    ui_log_error "Cannot continue without Flux installation script."
                    read -p "Press Enter to return to the menu..."
                    return
                fi
            else
                run_setup_script "${SCRIPT_DIR}/install-flux.sh" "Flux CD"
            fi
            
            run_setup_script "${SCRIPT_DIR}/setup-metallb.sh" "MetalLB"
            run_setup_script "${SCRIPT_DIR}/setup-policy-engine.sh" "Gatekeeper Policies"
            run_setup_script "${SCRIPT_DIR}/secrets/setup-vault.sh" "Vault"
            run_setup_script "${SCRIPT_DIR}/secrets/setup-supabase-secrets.sh" "Supabase Secrets"
            run_setup_script "${SCRIPT_DIR}/security/audit-kubernetes.sh" "Security Audit"
            
            ui_log_success "Full setup completed."
            read -p "Press Enter to return to the menu..."
            ;;
        9)
            ui_log_info "Exiting setup script."
            exit 0
            ;;
        *)
            ui_log_error "Invalid option. Please try again."
            read -p "Press Enter to continue..."
            ;;
    esac
}

# Main logic
while true; do
    show_menu
done

exit 0 