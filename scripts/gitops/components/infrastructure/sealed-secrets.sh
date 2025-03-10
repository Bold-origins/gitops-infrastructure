#!/bin/bash
# sealed-secrets.sh: Sealed Secrets Component Functions
# Handles all operations specific to sealed-secrets component

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="sealed-secrets"
NAMESPACE="sealed-secrets"
COMPONENT_DEPENDENCIES=() # No dependencies
RESOURCE_TYPES=("deployment" "service" "secret" "sealedsecrets")

# Pre-deployment function - runs before deployment
sealed_secrets_pre_deploy() {
    ui_log_info "Running sealed-secrets pre-deployment checks"

    # Create namespace if needed
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Check if Helm is installed
    if ! command -v helm &>/dev/null; then
        ui_log_error "Helm is not installed but required for sealed-secrets"
        return 1
    fi

    # Add Helm repo if needed
    if ! helm repo list | grep -q "sealed-secrets"; then
        ui_log_info "Adding sealed-secrets Helm repository"
        helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
        helm repo update
    fi

    return 0
}

# Deploy function - deploys the component
sealed_secrets_deploy() {
    local deploy_mode="${1:-flux}"

    ui_log_info "Deploying sealed-secrets using $deploy_mode mode"

    case "$deploy_mode" in
    flux)
        # Deploy using Flux
        kubectl apply -f "${BASE_DIR}/clusters/local/infrastructure/sealed-secrets/kustomization.yaml"
        ;;

    kubectl)
        # Direct kubectl apply
        ui_log_info "Applying sealed-secrets manifests directly with kubectl"
        kubectl apply -k "${BASE_DIR}/clusters/local/infrastructure/sealed-secrets"
        ;;

    helm)
        # Helm-based installation
        ui_log_info "Deploying sealed-secrets with Helm"

        # Check if already installed
        if helm list -n "$NAMESPACE" | grep -q "sealed-secrets"; then
            ui_log_info "sealed-secrets is already installed via Helm"
            return 0
        fi

        # Install with Helm
        helm install sealed-secrets sealed-secrets/sealed-secrets -n "$NAMESPACE" \
            --set fullnameOverride=sealed-secrets-controller \
            --set namespace="$NAMESPACE" \
            --set "controller.args[0]=--update-status" \
            --set "controller.args[1]=--key-prefix=sealed-secrets-key" \
            --set "controller.args[2]=--log-level=debug"
        ;;

    *)
        ui_log_error "Invalid deployment mode: $deploy_mode"
        return 1
        ;;
    esac

    return $?
}

# Post-deployment function - runs after deployment
sealed_secrets_post_deploy() {
    ui_log_info "Running sealed-secrets post-deployment tasks"

    # Wait for deployment to be ready
    ui_log_info "Waiting for sealed-secrets controller to be ready"
    kubectl rollout status deployment sealed-secrets-controller -n "$NAMESPACE" --timeout=120s

    # Sleep to allow the controller to initialize properly
    sleep 5

    # Check the CRD
    if kubectl get crd sealedsecrets.bitnami.com &>/dev/null; then
        ui_log_success "SealedSecret CRD is installed"
    else
        ui_log_warning "SealedSecret CRD is not installed, sealed-secrets might not function correctly"
    fi

    return 0
}

# Verification function - verifies the component is working
sealed_secrets_verify() {
    ui_log_info "Verifying sealed-secrets installation"

    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        ui_log_error "Namespace $NAMESPACE does not exist"
        return 1
    fi

    # Check if controller is running
    if ! kubectl get deployment sealed-secrets-controller -n "$NAMESPACE" &>/dev/null; then
        ui_log_error "sealed-secrets controller deployment not found"
        return 1
    fi

    # Check if pods are running
    local pods=$(kubectl get pods -n "$NAMESPACE" -l name=sealed-secrets-controller -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$pods" || "$pods" != "Running" ]]; then
        ui_log_error "sealed-secrets controller pod is not running"
        return 1
    fi

    # Check if CRD exists
    if ! kubectl get crd sealedsecrets.bitnami.com &>/dev/null; then
        ui_log_error "SealedSecret CRD is not installed"
        return 1
    fi

    ui_log_success "sealed-secrets verification successful"
    return 0
}

# Cleanup function - removes the component
sealed_secrets_cleanup() {
    ui_log_info "Cleaning up sealed-secrets"

    # Check deployment method and clean up accordingly
    if helm list -n "$NAMESPACE" | grep -q "sealed-secrets"; then
        ui_log_info "Uninstalling sealed-secrets Helm release"
        helm uninstall sealed-secrets -n "$NAMESPACE"
    fi

    # Delete Flux kustomization if present
    kubectl delete -f "${BASE_DIR}/clusters/local/infrastructure/sealed-secrets/kustomization.yaml" --ignore-not-found

    # Delete namespace
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        ui_log_info "Deleting namespace: $NAMESPACE"
        kubectl delete namespace "$NAMESPACE" --wait=false

        # Remove finalizers if needed
        sleep 2
        if kubectl get namespace "$NAMESPACE" &>/dev/null; then
            ui_log_warning "Removing finalizers from namespace: $NAMESPACE"
            kubectl patch namespace "$NAMESPACE" --type json \
                -p='[{"op": "remove", "path": "/spec/finalizers"}]'
        fi
    fi

    # Clean up CRD
    if kubectl get crd sealedsecrets.bitnami.com &>/dev/null; then
        ui_log_info "Deleting SealedSecret CRD"
        kubectl delete crd sealedsecrets.bitnami.com
    fi

    return 0
}

# Diagnose function - provides detailed diagnostics
sealed_secrets_diagnose() {
    ui_log_info "Running sealed-secrets diagnostics"

    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        ui_log_error "Namespace $NAMESPACE does not exist"
        return 1
    fi

    # Display component status
    ui_subheader "Sealed Secrets Pod Status"
    kubectl get pods -n "$NAMESPACE" -o wide

    # Display deployment
    ui_subheader "Sealed Secrets Deployment"
    kubectl get deployment sealed-secrets-controller -n "$NAMESPACE" -o yaml

    # Display services
    ui_subheader "Sealed Secrets Services"
    kubectl get services -n "$NAMESPACE"

    # Display CRD
    ui_subheader "Sealed Secrets CRD"
    kubectl get crd sealedsecrets.bitnami.com -o yaml 2>/dev/null ||
        ui_log_error "SealedSecret CRD not found"

    # Check for SealedSecrets
    ui_subheader "SealedSecret Resources"
    kubectl get sealedsecrets --all-namespaces 2>/dev/null ||
        ui_log_warning "No SealedSecrets found"

    # Check for pod logs
    ui_subheader "Controller Logs"
    local pod=$(kubectl get pods -n "$NAMESPACE" -l name=sealed-secrets-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod" ]; then
        kubectl logs -n "$NAMESPACE" "$pod" --tail=50
    else
        ui_log_error "No sealed-secrets controller pod found"
    fi

    # Check events
    ui_subheader "Recent Events"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20

    return 0
}

# Export functions
export -f sealed_secrets_pre_deploy
export -f sealed_secrets_deploy
export -f sealed_secrets_post_deploy
export -f sealed_secrets_verify
export -f sealed_secrets_cleanup
export -f sealed_secrets_diagnose
