#!/bin/bash

# setup-policy-engine.sh - Configures the OPA Gatekeeper policy engine for the staging environment
# This script sets up policies for the staging environment to enforce security constraints

set -e

# Source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/ui.sh" || { echo "Error: Failed to source ui.sh"; exit 1; }

# Initialize logging
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Display header
ui_header "Policy Engine Setup for Staging Environment"
ui_log_info "This script will configure Gatekeeper policies for your staging environment"

# Check if required tools are installed
ui_log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    ui_log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v git &> /dev/null; then
    ui_log_error "git not found. Please install git first."
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

# Check if Gatekeeper is deployed
ui_log_info "Checking if Gatekeeper is deployed..."
if ! kubectl get namespace gatekeeper-system &>/dev/null; then
  ui_log_warning "Gatekeeper namespace not found. Gatekeeper might not be deployed."
  ui_log_info "Ensure Gatekeeper is deployed through your GitOps process or manually."
  ui_log_info "This script will still create the policy templates and constraints in your repo."
  
  read -p "Do you want to continue without Gatekeeper? (y/n): " CONTINUE_WITHOUT_GATEKEEPER
  if [[ "${CONTINUE_WITHOUT_GATEKEEPER}" != "y" && "${CONTINUE_WITHOUT_GATEKEEPER}" != "Y" ]]; then
    ui_log_error "Aborting setup. Please deploy Gatekeeper first."
    exit 1
  fi
fi

# Create a temporary directory
TEMP_DIR="$(mktemp -d)"
ui_log_info "Creating temporary directory for policy manifests: ${TEMP_DIR}"

# Set the target directory for policies
REPO_ROOT="$(git rev-parse --show-toplevel)"
POLICIES_DIR="${REPO_ROOT}/clusters/staging/infrastructure/gatekeeper/policies"
ui_log_info "Target policies directory: ${POLICIES_DIR}"

# Create policies directory if it doesn't exist
mkdir -p "${POLICIES_DIR}"

ui_subheader "Creating Policy Templates"

# Create the require-pod-requests-limits template
cat > "${TEMP_DIR}/template-require-resources.yaml" << EOF
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequireresources
  annotations:
    description: "Requires that all containers have resource requests and limits set."
spec:
  crd:
    spec:
      names:
        kind: K8sRequireResources
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireresources

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.requests
          msg := sprintf("Container '%v' does not have resource requests set", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits
          msg := sprintf("Container '%v' does not have resource limits set", [container.name])
        }
EOF

# Create the require-pod-probes template
cat > "${TEMP_DIR}/template-require-probes.yaml" << EOF
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequireprobes
  annotations:
    description: "Requires that all pods have liveness and readiness probes set."
spec:
  crd:
    spec:
      names:
        kind: K8sRequireProbes
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireprobes

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.livenessProbe
          msg := sprintf("Container '%v' does not have a liveness probe set", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.readinessProbe
          msg := sprintf("Container '%v' does not have a readiness probe set", [container.name])
        }
EOF

# Create the block-privileged template
cat > "${TEMP_DIR}/template-block-privileged.yaml" << EOF
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sblockprivileged
  annotations:
    description: "Blocks running privileged containers."
spec:
  crd:
    spec:
      names:
        kind: K8sBlockPrivileged
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockprivileged

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.privileged
          msg := sprintf("Privileged containers are not allowed: %v", [container.name])
        }
EOF

ui_log_success "Policy templates created successfully."

ui_subheader "Creating Policy Constraints"

# Create the require-resources constraint
cat > "${TEMP_DIR}/constraint-require-resources.yaml" << EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireResources
metadata:
  name: require-resources
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
      - flux-system
EOF

# Create the require-probes constraint
cat > "${TEMP_DIR}/constraint-require-probes.yaml" << EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireProbes
metadata:
  name: require-probes
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
      - flux-system
EOF

# Create the block-privileged constraint
cat > "${TEMP_DIR}/constraint-block-privileged.yaml" << EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockPrivileged
metadata:
  name: block-privileged
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
EOF

ui_log_success "Policy constraints created successfully."

# Copy files to the policies directory
ui_log_info "Copying policy files to the repository..."
mkdir -p "${POLICIES_DIR}/templates"
mkdir -p "${POLICIES_DIR}/constraints"

cp "${TEMP_DIR}/template-"* "${POLICIES_DIR}/templates/"
cp "${TEMP_DIR}/constraint-"* "${POLICIES_DIR}/constraints/"

ui_log_success "Policy files copied to the repository."

# Create or update the kustomization.yaml file
cat > "${POLICIES_DIR}/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - templates/template-require-resources.yaml
  - templates/template-require-probes.yaml
  - templates/template-block-privileged.yaml
  - constraints/constraint-require-resources.yaml
  - constraints/constraint-require-probes.yaml
  - constraints/constraint-block-privileged.yaml
EOF

ui_log_success "Created kustomization.yaml for policies."

# Update the main gatekeeper kustomization to include policies
GATEKEEPER_KUSTOMIZATION="${REPO_ROOT}/clusters/staging/infrastructure/gatekeeper/kustomization.yaml"

# Check if the policies are already referenced in the kustomization file
if grep -q "policies" "${GATEKEEPER_KUSTOMIZATION}"; then
  ui_log_info "Policies are already referenced in the gatekeeper kustomization.yaml."
else
  # Read the current kustomization file
  KUSTOMIZATION_CONTENT=$(cat "${GATEKEEPER_KUSTOMIZATION}")
  
  # Use awk to add policies to the resources section
  NEW_KUSTOMIZATION=$(echo "${KUSTOMIZATION_CONTENT}" | awk '
  /resources:/ {
    print $0;
    print "  - policies";
    next;
  }
  { print $0 }
  ')
  
  # Write the modified content back to the file
  echo "${NEW_KUSTOMIZATION}" > "${GATEKEEPER_KUSTOMIZATION}"
  
  ui_log_success "Updated gatekeeper kustomization.yaml to include policies."
fi

# Apply the policies if Gatekeeper is installed
if kubectl get namespace gatekeeper-system &>/dev/null; then
  ui_subheader "Applying Policies to Cluster"
  read -p "Do you want to apply these policies to the cluster now? (y/n): " APPLY_POLICIES
  
  if [[ "${APPLY_POLICIES}" == "y" || "${APPLY_POLICIES}" == "Y" ]]; then
    ui_log_info "Applying policy templates..."
    kubectl apply -f "${POLICIES_DIR}/templates/"
    
    ui_log_info "Waiting for templates to be processed..."
    sleep 5
    
    ui_log_info "Applying policy constraints..."
    kubectl apply -f "${POLICIES_DIR}/constraints/"
    
    ui_log_success "Policies applied to the cluster successfully."
    
    # Check for violations
    ui_log_info "Checking for policy violations..."
    VIOLATIONS=$(kubectl get constraint -o json | jq -r '.items[] | select(.status.totalViolations > 0) | "Constraint: " + .metadata.name + ", Violations: " + (.status.totalViolations | tostring)')
    
    if [[ -n "${VIOLATIONS}" ]]; then
      ui_log_warning "Found policy violations:"
      echo "${VIOLATIONS}"
      ui_log_info "To see details of violations, use: kubectl get constraint <constraint-name> -o yaml"
    else
      ui_log_success "No policy violations found."
    fi
  else
    ui_log_info "Skipping policy application. Policies will be applied through GitOps when changes are pushed."
  fi
else
  ui_log_warning "Skipping policy application as Gatekeeper is not installed."
  ui_log_info "Policies will be automatically applied when Gatekeeper is deployed via GitOps."
fi

# Clean up temporary files
ui_log_info "Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"

ui_header "Policy Engine Setup Complete"
ui_log_success "Gatekeeper policies have been configured for your staging environment."
ui_log_info "Policy files are located at: ${POLICIES_DIR}"
ui_log_info "Remember to commit and push these changes to apply them through GitOps."

exit 0 