#!/bin/bash

# audit-kubernetes.sh - Security audit script for Kubernetes clusters
# This script performs security checks on a Kubernetes cluster

set -e

# Source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "Kubernetes Security Audit"
ui_log_info "This script will audit your Kubernetes cluster for security issues"

# Check if required tools are installed
ui_log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    ui_log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Optional tools
MISSING_TOOLS=()
if ! command -v jq &> /dev/null; then
    MISSING_TOOLS+=("jq")
fi

if ! command -v kubesec &> /dev/null; then
    MISSING_TOOLS+=("kubesec (optional for security scanning)")
fi

if ! command -v trivy &> /dev/null; then
    MISSING_TOOLS+=("trivy (optional for vulnerability scanning)")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    ui_log_warning "The following tools are missing but recommended:"
    for tool in "${MISSING_TOOLS[@]}"; do
        ui_log_info "  - $tool"
    done
fi

# Check cluster connection
ui_log_info "Checking connection to cluster..."
if ! kubectl get nodes &>/dev/null; then
  ui_log_error "Cannot connect to the Kubernetes cluster. Please check your kubeconfig."
  ui_log_info "Make sure you're connected to the correct cluster context."
  exit 1
fi

CLUSTER_INFO=$(kubectl cluster-info | head -n 1)
ui_log_success "Successfully connected to ${CLUSTER_INFO}"

# Create a directory for audit results
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
AUDIT_DIR="${HOME}/.boldorigins/security-audits/${TIMESTAMP}"
mkdir -p "${AUDIT_DIR}"
ui_log_info "Audit results will be saved to: ${AUDIT_DIR}"

# Function to run a check and log results
run_check() {
    local title="$1"
    local command="$2"
    local output_file="${AUDIT_DIR}/${3}"
    
    ui_log_info "Running check: ${title}"
    eval "${command}" > "${output_file}" 2>&1
    if [ $? -eq 0 ]; then
        ui_log_success "Check completed: ${title}"
    else
        ui_log_warning "Check may have issues: ${title}"
    fi
}

ui_subheader "Cluster Information"

# Get basic cluster info
run_check "Cluster Info" "kubectl cluster-info" "cluster-info.txt"
run_check "Nodes" "kubectl get nodes -o wide" "nodes.txt"
run_check "Namespaces" "kubectl get namespaces" "namespaces.txt"
run_check "API Resources" "kubectl api-resources" "api-resources.txt"

ui_subheader "RBAC Checks"

# Check RBAC settings
run_check "Cluster Roles" "kubectl get clusterroles" "cluster-roles.txt"
run_check "Cluster Role Bindings" "kubectl get clusterrolebindings" "cluster-role-bindings.txt"

# Check for overly permissive RBAC rules
if command -v jq &> /dev/null; then
    ui_log_info "Checking for overly permissive RBAC rules..."
    kubectl get clusterroles -o json | jq '.items[] | select(.rules[] | select(.verbs[] == "*" and .resources[] == "*" and .apiGroups[] == "*")) | .metadata.name' > "${AUDIT_DIR}/permissive-cluster-roles.txt"
    
    if [ -s "${AUDIT_DIR}/permissive-cluster-roles.txt" ]; then
        ui_log_warning "Found overly permissive cluster roles that grant '*' permissions across all resources:"
        cat "${AUDIT_DIR}/permissive-cluster-roles.txt"
    else
        ui_log_success "No overly permissive cluster roles found."
    fi
else
    ui_log_warning "Skipping permissive RBAC check as jq is not installed."
fi

ui_subheader "Pod Security Checks"

# Check for pods with privileged security context
ui_log_info "Checking for privileged containers..."
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.containers[] | select(.securityContext.privileged == true)) | .metadata.namespace + "/" + .metadata.name' > "${AUDIT_DIR}/privileged-pods.txt"

if [ -s "${AUDIT_DIR}/privileged-pods.txt" ]; then
    ui_log_warning "Found pods running with privileged containers:"
    cat "${AUDIT_DIR}/privileged-pods.txt"
else
    ui_log_success "No pods running with privileged containers found."
fi

# Check for pods with hostNetwork, hostPID, hostIPC
ui_log_info "Checking for pods with host namespace access..."
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.hostNetwork == true or .spec.hostPID == true or .spec.hostIPC == true) | .metadata.namespace + "/" + .metadata.name + " (hostNetwork: " + (.spec.hostNetwork | tostring) + ", hostPID: " + (.spec.hostPID | tostring) + ", hostIPC: " + (.spec.hostIPC | tostring) + ")"' > "${AUDIT_DIR}/host-namespace-pods.txt"

if [ -s "${AUDIT_DIR}/host-namespace-pods.txt" ]; then
    ui_log_warning "Found pods with host namespace access:"
    cat "${AUDIT_DIR}/host-namespace-pods.txt"
else
    ui_log_success "No pods with host namespace access found."
fi

# Check for pods with hostPath volumes
ui_log_info "Checking for pods with hostPath volumes..."
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.volumes[] | select(.hostPath != null)) | .metadata.namespace + "/" + .metadata.name' > "${AUDIT_DIR}/hostpath-pods.txt"

if [ -s "${AUDIT_DIR}/hostpath-pods.txt" ]; then
    ui_log_warning "Found pods with hostPath volumes:"
    cat "${AUDIT_DIR}/hostpath-pods.txt"
else
    ui_log_success "No pods with hostPath volumes found."
fi

ui_subheader "Network Policy Checks"

# Check for network policies
ui_log_info "Checking for network policies..."
kubectl get networkpolicies --all-namespaces > "${AUDIT_DIR}/network-policies.txt"

# Count namespaces without network policies
NAMESPACES_WITH_NETPOL=$(kubectl get networkpolicies --all-namespaces -o jsonpath='{.items[*].metadata.namespace}' | tr ' ' '\n' | sort -u)
ALL_NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | sort)
NAMESPACES_WITHOUT_NETPOL=$(comm -23 <(echo "$ALL_NAMESPACES") <(echo "$NAMESPACES_WITH_NETPOL"))

echo "$NAMESPACES_WITHOUT_NETPOL" > "${AUDIT_DIR}/namespaces-without-netpol.txt"

if [ -s "${AUDIT_DIR}/namespaces-without-netpol.txt" ]; then
    ui_log_warning "Found namespaces without network policies:"
    cat "${AUDIT_DIR}/namespaces-without-netpol.txt"
else
    ui_log_success "All namespaces have network policies defined."
fi

ui_subheader "Secret Management Checks"

# Check for unencrypted secrets
ui_log_info "Checking for unencrypted secrets..."
TOTAL_SECRETS=$(kubectl get secrets --all-namespaces | grep -v "kubernetes.io/service-account-token" | wc -l)
SEALED_SECRETS=$(kubectl get sealedsecrets --all-namespaces 2>/dev/null | wc -l || echo "0")
VAULT_SECRETS=$(kubectl get vaultsecret --all-namespaces 2>/dev/null | wc -l || echo "0")

echo "Total regular secrets (excluding service account tokens): $TOTAL_SECRETS" > "${AUDIT_DIR}/secrets-summary.txt"
echo "SealedSecrets: $SEALED_SECRETS" >> "${AUDIT_DIR}/secrets-summary.txt"
echo "Vault secrets: $VAULT_SECRETS" >> "${AUDIT_DIR}/secrets-summary.txt"

ui_log_info "Secrets summary:"
cat "${AUDIT_DIR}/secrets-summary.txt"

# Advanced scanning with optional tools
ui_subheader "Advanced Security Scans"

# If trivy is installed, perform vulnerability scanning
if command -v trivy &> /dev/null; then
    ui_log_info "Running Trivy vulnerability scans on namespaces..."
    
    # Get a list of deployments to scan (limit to 5 per namespace for performance)
    for namespace in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        ui_log_info "Scanning namespace: $namespace"
        mkdir -p "${AUDIT_DIR}/trivy-scans/${namespace}"
        
        # Get deployments in namespace
        DEPLOYMENTS=$(kubectl get deployments -n "$namespace" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | head -5)
        
        for deployment in $DEPLOYMENTS; do
            ui_log_info "  Scanning deployment: $deployment"
            # Get image from deployment
            IMAGE=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].image}')
            trivy image --no-progress --output "${AUDIT_DIR}/trivy-scans/${namespace}/${deployment}.txt" "$IMAGE" || true
        done
    done
    
    ui_log_success "Vulnerability scanning completed. Results saved to ${AUDIT_DIR}/trivy-scans/"
else
    ui_log_warning "Trivy not installed. Skipping vulnerability scanning."
    ui_log_info "Consider installing Trivy for vulnerability scanning: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
fi

# If kubesec is installed, perform security scanning
if command -v kubesec &> /dev/null; then
    ui_log_info "Running kubesec security scans on deployments..."
    mkdir -p "${AUDIT_DIR}/kubesec-scans"
    
    for namespace in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | head -5); do
        # Get deployments in namespace
        DEPLOYMENTS=$(kubectl get deployments -n "$namespace" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | head -5)
        
        for deployment in $DEPLOYMENTS; do
            ui_log_info "Scanning deployment: $namespace/$deployment"
            kubectl get deployment "$deployment" -n "$namespace" -o yaml | kubesec scan - > "${AUDIT_DIR}/kubesec-scans/${namespace}-${deployment}.json" || true
        done
    done
    
    ui_log_success "Security scanning completed. Results saved to ${AUDIT_DIR}/kubesec-scans/"
else
    ui_log_warning "kubesec not installed. Skipping security scanning."
    ui_log_info "Consider installing kubesec for Kubernetes security scanning: https://github.com/controlplaneio/kubesec"
fi

ui_subheader "Generating Summary Report"

# Generate a summary report
cat > "${AUDIT_DIR}/summary.md" << EOF
# Kubernetes Security Audit Summary
**Date:** $(date)
**Cluster:** ${CLUSTER_INFO}

## Key Findings

### RBAC
$(if [ -s "${AUDIT_DIR}/permissive-cluster-roles.txt" ]; then
    echo "⚠️ **WARNING:** Found $(wc -l < "${AUDIT_DIR}/permissive-cluster-roles.txt") overly permissive cluster roles."
else
    echo "✅ No overly permissive cluster roles found."
fi)

### Pod Security
$(if [ -s "${AUDIT_DIR}/privileged-pods.txt" ]; then
    echo "⚠️ **WARNING:** Found $(wc -l < "${AUDIT_DIR}/privileged-pods.txt") pods running with privileged containers."
else
    echo "✅ No pods running with privileged containers."
fi)

$(if [ -s "${AUDIT_DIR}/host-namespace-pods.txt" ]; then
    echo "⚠️ **WARNING:** Found $(wc -l < "${AUDIT_DIR}/host-namespace-pods.txt") pods with host namespace access."
else
    echo "✅ No pods with host namespace access."
fi)

$(if [ -s "${AUDIT_DIR}/hostpath-pods.txt" ]; then
    echo "⚠️ **WARNING:** Found $(wc -l < "${AUDIT_DIR}/hostpath-pods.txt") pods with hostPath volumes."
else
    echo "✅ No pods with hostPath volumes."
fi)

### Network Policies
$(if [ -s "${AUDIT_DIR}/namespaces-without-netpol.txt" ]; then
    echo "⚠️ **WARNING:** Found $(wc -l < "${AUDIT_DIR}/namespaces-without-netpol.txt") namespaces without network policies."
else
    echo "✅ All namespaces have network policies."
fi)

### Secret Management
Total regular secrets: $TOTAL_SECRETS
SealedSecrets: $SEALED_SECRETS
Vault secrets: $VAULT_SECRETS

## Recommendations

1. Review any privileged containers and consider alternatives
2. Implement network policies for all namespaces
3. Use encrypted secrets (SealedSecrets or Vault) instead of plain Kubernetes secrets
4. Review RBAC permissions and follow principle of least privilege
5. Run regular vulnerability scans on container images

## Full Audit Results
The full audit results are available in: \`${AUDIT_DIR}\`
EOF

ui_log_success "Generated summary report: ${AUDIT_DIR}/summary.md"

ui_header "Security Audit Complete"
ui_log_success "Kubernetes security audit completed successfully."
ui_log_info "Audit results have been saved to: ${AUDIT_DIR}"
ui_log_info "Review the summary report at: ${AUDIT_DIR}/summary.md"

# If there are any warnings, highlight them
if grep -q "WARNING" "${AUDIT_DIR}/summary.md"; then
    ui_log_warning "Security issues were found during the audit. Please review the summary report."
else
    ui_log_success "No major security issues were found during the audit."
fi

exit 0 