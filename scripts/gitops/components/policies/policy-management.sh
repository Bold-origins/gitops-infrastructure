#!/bin/bash
# policy-management.sh: Policy Management Component Functions
# Handles all operations for managing and applying policy templates and constraints

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="policy-management"
POLICY_TEMPLATES_DIR="${BASE_DIR}/clusters/local/policies/templates"
POLICY_CONSTRAINTS_DIR="${BASE_DIR}/clusters/local/policies/constraints"
POLICY_ENGINE_TYPES=("kyverno" "opa" "gatekeeper")  # Supported policy engines
RESOURCE_TYPES=("clusterpolicy" "policy" "constraint" "constrainttemplate")

# Pre-deployment function - runs before deployment
policy_management_pre_deploy() {
  ui_log_info "Running Policy Management pre-deployment checks"
  
  # Check if a supported policy engine is installed
  local policy_engine_installed=false
  
  for engine in "${POLICY_ENGINE_TYPES[@]}"; do
    if kubectl api-resources | grep -q "$engine"; then
      ui_log_info "Detected policy engine: $engine"
      policy_engine_installed=true
      break
    fi
  done
  
  if [ "$policy_engine_installed" = false ]; then
    ui_log_warning "No supported policy engine detected. Please install a policy engine like Kyverno or OPA/Gatekeeper first."
    ui_log_warning "You can use our policy-engine.sh or gatekeeper.sh scripts in the infrastructure components."
    return 1
  fi
  
  # Check if policy directories exist
  if [ ! -d "$POLICY_TEMPLATES_DIR" ]; then
    ui_log_warning "Policy templates directory not found at $POLICY_TEMPLATES_DIR"
    ui_log_info "Creating directory structure"
    mkdir -p "$POLICY_TEMPLATES_DIR/helm" "$POLICY_TEMPLATES_DIR/patches"
  fi
  
  if [ ! -d "$POLICY_CONSTRAINTS_DIR" ]; then
    ui_log_warning "Policy constraints directory not found at $POLICY_CONSTRAINTS_DIR"
    ui_log_info "Creating directory structure"
    mkdir -p "$POLICY_CONSTRAINTS_DIR/helm" "$POLICY_CONSTRAINTS_DIR/patches"
  fi
  
  # Check if kustomization.yaml files exist
  if [ ! -f "$POLICY_TEMPLATES_DIR/kustomization.yaml" ]; then
    ui_log_info "Creating template kustomization.yaml"
    cat > "$POLICY_TEMPLATES_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference base policy templates
resources:
- ../../../base/policies/templates

# Apply local-specific patches
patchesStrategicMerge:
# Uncomment and add patches as needed
# - patches/template-patch.yaml
EOF
  fi
  
  if [ ! -f "$POLICY_CONSTRAINTS_DIR/kustomization.yaml" ]; then
    ui_log_info "Creating constraint kustomization.yaml"
    cat > "$POLICY_CONSTRAINTS_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference base policy constraints
resources:
- ../../../base/policies/constraints

# Apply local-specific patches
patchesStrategicMerge:
# Uncomment and add patches as needed
# - patches/constraint-patch.yaml
EOF
  fi
  
  return 0
}

# Deploy function - deploys policies
policy_management_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Policy Management using $deploy_mode mode"
  
  # Determine policy engine type for appropriate deployment method
  local policy_engine_type=""
  if kubectl api-resources | grep -q "kyverno"; then
    policy_engine_type="kyverno"
  elif kubectl api-resources | grep -q "gatekeeper"; then
    policy_engine_type="gatekeeper"
  elif kubectl api-resources | grep -q "constrainttemplate"; then
    policy_engine_type="opa"
  else
    ui_log_error "No supported policy engine detected."
    return 1
  fi
  
  ui_log_info "Using policy engine: $policy_engine_type"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      ui_log_info "Applying templates kustomization via Flux"
      kubectl apply -f "$POLICY_TEMPLATES_DIR/kustomization.yaml"
      
      ui_log_info "Applying constraints kustomization via Flux"
      kubectl apply -f "$POLICY_CONSTRAINTS_DIR/kustomization.yaml"
      ;;
    
    kubectl)
      # Direct kubectl apply
      ui_log_info "Applying policy templates with kubectl"
      kubectl apply -k "$POLICY_TEMPLATES_DIR"
      
      ui_log_info "Applying policy constraints with kubectl"
      kubectl apply -k "$POLICY_CONSTRAINTS_DIR"
      ;;
    
    helm)
      # Helm-based installation - for policies defined via Helm values
      ui_log_info "Deploying policies with Helm"
      
      # Apply templates via Helm if values file exists
      if [ -f "$POLICY_TEMPLATES_DIR/helm/values.yaml" ]; then
        case "$policy_engine_type" in
          kyverno)
            ui_log_info "Applying Kyverno policy templates"
            if helm list | grep -q "kyverno-policies"; then
              helm upgrade kyverno-policies kyverno/kyverno-policies \
                -f "$POLICY_TEMPLATES_DIR/helm/values.yaml"
            else
              helm install kyverno-policies kyverno/kyverno-policies \
                -f "$POLICY_TEMPLATES_DIR/helm/values.yaml"
            fi
            ;;
            
          gatekeeper|opa)
            ui_log_info "Applying Gatekeeper/OPA constraint templates"
            # Gatekeeper templates are usually applied directly as CRDs
            kubectl apply -f "$POLICY_TEMPLATES_DIR/helm/templates"
            ;;
            
          *)
            ui_log_error "Unsupported policy engine type: $policy_engine_type"
            return 1
            ;;
        esac
      else
        ui_log_warning "No Helm values file found for policy templates."
      fi
      
      # Apply constraints via Helm if values file exists
      if [ -f "$POLICY_CONSTRAINTS_DIR/helm/values.yaml" ]; then
        ui_log_info "Applying policy constraints via Helm"
        # Constraints are usually custom to the environment, so we apply directly
        kubectl apply -f "$POLICY_CONSTRAINTS_DIR/helm/constraints"
      else
        ui_log_warning "No Helm values file found for policy constraints."
      fi
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
policy_management_post_deploy() {
  ui_log_info "Running Policy Management post-deployment tasks"
  
  # Determine policy engine type
  local policy_engine_type=""
  if kubectl api-resources | grep -q "kyverno"; then
    policy_engine_type="kyverno"
  elif kubectl api-resources | grep -q "gatekeeper"; then
    policy_engine_type="gatekeeper"
  elif kubectl api-resources | grep -q "constrainttemplate"; then
    policy_engine_type="opa"
  else
    ui_log_error "No supported policy engine detected."
    return 1
  fi
  
  # Wait for policies to be ready based on the policy engine
  case "$policy_engine_type" in
    kyverno)
      # Wait for ClusterPolicies to be ready
      ui_log_info "Waiting for Kyverno policies to be ready"
      local policies=$(kubectl get clusterpolicy -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      
      if [ -n "$policies" ]; then
        for policy in $policies; do
          ui_log_info "Checking status of policy: $policy"
          local ready_status=$(kubectl get clusterpolicy "$policy" -o jsonpath='{.status.ready}' 2>/dev/null)
          
          if [ "$ready_status" == "true" ]; then
            ui_log_success "Policy $policy is ready"
          else
            ui_log_warning "Policy $policy is not ready yet. Current status: $ready_status"
          fi
        done
      else
        ui_log_warning "No Kyverno ClusterPolicies found"
      fi
      ;;
      
    gatekeeper|opa)
      # Wait for ConstraintTemplates to be ready
      ui_log_info "Waiting for Gatekeeper/OPA constraint templates to be ready"
      local templates=$(kubectl get constrainttemplate -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      
      if [ -n "$templates" ]; then
        for template in $templates; do
          ui_log_info "Checking status of template: $template"
          local created_status=$(kubectl get constrainttemplate "$template" -o jsonpath='{.status.created}' 2>/dev/null)
          
          if [ "$created_status" == "true" ]; then
            ui_log_success "Template $template is ready"
          else
            ui_log_warning "Template $template is not ready yet. Current status: $created_status"
          fi
        done
      else
        ui_log_warning "No ConstraintTemplates found"
      fi
      
      # Check constraints
      ui_log_info "Checking constraints status"
      # This is a bit tricky as constraints are of different kinds based on templates
      local constraints=$(kubectl get constraints --all-namespaces -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}{"\n"}{end}' 2>/dev/null)
      
      if [ -n "$constraints" ]; then
        echo "$constraints" | while IFS='/' read -r kind name; do
          ui_log_info "Checking status of constraint: $kind/$name"
          local enforced_status=$(kubectl get "$kind" "$name" -o jsonpath='{.status.enforcementAction}' 2>/dev/null)
          
          if [ -n "$enforced_status" ]; then
            ui_log_success "Constraint $kind/$name is enforced with action: $enforced_status"
          else
            ui_log_warning "Constraint $kind/$name enforcement status unknown"
          fi
        done
      else
        ui_log_warning "No constraints found"
      fi
      ;;
      
    *)
      ui_log_error "Unsupported policy engine type: $policy_engine_type"
      return 1
      ;;
  esac
  
  # Apply any additional custom policies not covered by templates/constraints
  local custom_policies_dir="${BASE_DIR}/clusters/local/policies/custom"
  if [ -d "$custom_policies_dir" ]; then
    ui_log_info "Applying custom policies from $custom_policies_dir"
    kubectl apply -f "$custom_policies_dir"
  else
    ui_log_info "No custom policies directory found at $custom_policies_dir"
  fi
  
  return 0
}

# Verification function - verifies policies are working
policy_management_verify() {
  ui_log_info "Verifying Policy Management installation"
  
  # Determine policy engine type
  local policy_engine_type=""
  if kubectl api-resources | grep -q "kyverno"; then
    policy_engine_type="kyverno"
  elif kubectl api-resources | grep -q "gatekeeper"; then
    policy_engine_type="gatekeeper"
  elif kubectl api-resources | grep -q "constrainttemplate"; then
    policy_engine_type="opa"
  else
    ui_log_error "No supported policy engine detected."
    return 1
  fi
  
  # Verify policies based on the policy engine
  case "$policy_engine_type" in
    kyverno)
      # Check Kyverno policies
      ui_log_info "Verifying Kyverno policies"
      
      # Check ClusterPolicies
      local cluster_policies=$(kubectl get clusterpolicy -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      if [ -n "$cluster_policies" ]; then
        ui_log_success "Found $(echo "$cluster_policies" | wc -w) ClusterPolicies"
        
        # Display policy names
        for policy in $cluster_policies; do
          local policy_rules=$(kubectl get clusterpolicy "$policy" -o jsonpath='{.spec.rules[*].name}')
          ui_log_info "ClusterPolicy: $policy (Rules: $policy_rules)"
        done
      else
        ui_log_warning "No ClusterPolicies found"
      fi
      
      # Check namespaced Policies
      local namespaced_policies=$(kubectl get policy --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null)
      if [ -n "$namespaced_policies" ]; then
        ui_log_success "Found namespaced Policies"
        
        # Display policy names
        echo "$namespaced_policies" | while IFS='/' read -r namespace name; do
          local policy_rules=$(kubectl get policy -n "$namespace" "$name" -o jsonpath='{.spec.rules[*].name}')
          ui_log_info "Policy: $namespace/$name (Rules: $policy_rules)"
        done
      else
        ui_log_info "No namespaced Policies found"
      fi
      
      # Check policy reports if available
      if kubectl api-resources | grep -q "policyreport"; then
        ui_log_info "Checking PolicyReports"
        local policy_reports=$(kubectl get policyreport --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null)
        
        if [ -n "$policy_reports" ]; then
          echo "$policy_reports" | while IFS='/' read -r namespace name; do
            local pass_count=$(kubectl get policyreport -n "$namespace" "$name" -o jsonpath='{.summary.pass}')
            local fail_count=$(kubectl get policyreport -n "$namespace" "$name" -o jsonpath='{.summary.fail}')
            local warn_count=$(kubectl get policyreport -n "$namespace" "$name" -o jsonpath='{.summary.warn}')
            
            ui_log_info "PolicyReport $namespace/$name: Pass=$pass_count, Fail=$fail_count, Warn=$warn_count"
          done
        else
          ui_log_info "No PolicyReports found"
        fi
      fi
      ;;
      
    gatekeeper|opa)
      # Check Gatekeeper templates and constraints
      ui_log_info "Verifying Gatekeeper/OPA templates and constraints"
      
      # Check ConstraintTemplates
      local templates=$(kubectl get constrainttemplate -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      if [ -n "$templates" ]; then
        ui_log_success "Found $(echo "$templates" | wc -w) ConstraintTemplates"
        
        # Display template names and kinds
        for template in $templates; do
          local kind=$(kubectl get constrainttemplate "$template" -o jsonpath='{.spec.crd.spec.names.kind}')
          ui_log_info "Template: $template (Kind: $kind)"
        done
      else
        ui_log_warning "No ConstraintTemplates found"
      fi
      
      # Check Constraints
      # This command lists all constraints across all constraint kinds
      local all_kinds=$(kubectl api-resources --api-group=constraints.gatekeeper.sh -o name 2>/dev/null)
      
      if [ -n "$all_kinds" ]; then
        local constraint_count=0
        
        for kind in $all_kinds; do
          local constraints=$(kubectl get "$kind" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
          if [ -n "$constraints" ]; then
            for constraint in $constraints; do
              ((constraint_count++))
              local violations=$(kubectl get "$kind" "$constraint" -o jsonpath='{.status.totalViolations}' 2>/dev/null)
              ui_log_info "Constraint: $kind/$constraint (Violations: ${violations:-unknown})"
            done
          fi
        done
        
        if [ "$constraint_count" -gt 0 ]; then
          ui_log_success "Found $constraint_count active constraints"
        else
          ui_log_warning "No active constraints found"
        fi
      else
        ui_log_warning "No constraint kinds found"
      fi
      
      # Check audit results if available
      if kubectl get ns gatekeeper-system &>/dev/null; then
        ui_log_info "Checking Gatekeeper audit"
        local audit_timestamp=$(kubectl get configmap -n gatekeeper-system gatekeeper-audit -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
        
        if [ -n "$audit_timestamp" ]; then
          ui_log_info "Last audit timestamp: $audit_timestamp"
        else
          ui_log_warning "No audit information found"
        fi
      fi
      ;;
      
    *)
      ui_log_error "Unsupported policy engine type: $policy_engine_type"
      return 1
      ;;
  esac
  
  # Test policy enforcement with a sample violation if in interactive mode
  if [ -t 0 ] && [ -t 1 ]; then  # Check if running in interactive terminal
    ui_log_info "Would you like to test policy enforcement with a sample violation? [y/N]"
    read -r -n 1 response
    echo
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
      ui_log_info "Testing policy enforcement with a sample violation"
      
      # Create a temporary namespace
      kubectl create ns policy-test
      
      # Create a test deployment that should violate common policies
      cat <<EOF | kubectl apply -f - 2>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: policy-violation-test
  namespace: policy-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        securityContext:
          privileged: true
          runAsUser: 0
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 64Mi
EOF
      
      sleep 5  # Give the policy engine time to evaluate
      
      # Check for violations based on policy engine
      case "$policy_engine_type" in
        kyverno)
          if kubectl get policyreport -n policy-test &>/dev/null; then
            kubectl get policyreport -n policy-test -o yaml
          else
            kubectl get clusterpolicyreport -o yaml
          fi
          ;;
          
        gatekeeper|opa)
          # For Gatekeeper, check the events or violation status
          kubectl get events -n policy-test | grep violation
          ;;
      esac
      
      # Clean up test resources
      kubectl delete ns policy-test
    fi
  fi
  
  ui_log_success "Policy Management verification completed"
  return 0
}

# Cleanup function - removes policies
policy_management_cleanup() {
  ui_log_info "Cleaning up Policy Management"
  
  # Determine policy engine type
  local policy_engine_type=""
  if kubectl api-resources | grep -q "kyverno"; then
    policy_engine_type="kyverno"
  elif kubectl api-resources | grep -q "gatekeeper"; then
    policy_engine_type="gatekeeper"
  elif kubectl api-resources | grep -q "constrainttemplate"; then
    policy_engine_type="opa"
  else
    ui_log_error "No supported policy engine detected."
    return 1
  fi
  
  # Clean up based on policy engine type
  case "$policy_engine_type" in
    kyverno)
      # Delete all Kyverno policies
      ui_log_info "Removing Kyverno policies"
      
      # Delete cluster policies
      local cluster_policies=$(kubectl get clusterpolicy -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      if [ -n "$cluster_policies" ]; then
        for policy in $cluster_policies; do
          ui_log_info "Deleting ClusterPolicy: $policy"
          kubectl delete clusterpolicy "$policy"
        done
      fi
      
      # Delete namespaced policies
      local namespaced_policies=$(kubectl get policy --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null)
      if [ -n "$namespaced_policies" ]; then
        echo "$namespaced_policies" | while IFS='/' read -r namespace name; do
          ui_log_info "Deleting Policy: $namespace/$name"
          kubectl delete policy -n "$namespace" "$name"
        done
      fi
      
      # Delete policy reports if present
      if kubectl api-resources | grep -q "policyreport"; then
        local policy_reports=$(kubectl get policyreport --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null)
        if [ -n "$policy_reports" ]; then
          echo "$policy_reports" | while IFS='/' read -r namespace name; do
            ui_log_info "Deleting PolicyReport: $namespace/$name"
            kubectl delete policyreport -n "$namespace" "$name"
          done
        fi
        
        # Delete cluster policy reports
        local cluster_policy_reports=$(kubectl get clusterpolicyreport -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        if [ -n "$cluster_policy_reports" ]; then
          for report in $cluster_policy_reports; do
            ui_log_info "Deleting ClusterPolicyReport: $report"
            kubectl delete clusterpolicyreport "$report"
          done
        fi
      fi
      ;;
      
    gatekeeper|opa)
      # Delete Gatekeeper constraints and templates
      ui_log_info "Removing Gatekeeper/OPA constraints and templates"
      
      # Delete constraints
      local all_kinds=$(kubectl api-resources --api-group=constraints.gatekeeper.sh -o name 2>/dev/null)
      if [ -n "$all_kinds" ]; then
        for kind in $all_kinds; do
          local constraints=$(kubectl get "$kind" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
          if [ -n "$constraints" ]; then
            for constraint in $constraints; do
              ui_log_info "Deleting constraint: $kind/$constraint"
              kubectl delete "$kind" "$constraint"
            done
          fi
        done
      fi
      
      # Delete constraint templates
      local templates=$(kubectl get constrainttemplate -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      if [ -n "$templates" ]; then
        for template in $templates; do
          ui_log_info "Deleting ConstraintTemplate: $template"
          kubectl delete constrainttemplate "$template"
        done
      fi
      ;;
      
    *)
      ui_log_error "Unsupported policy engine type: $policy_engine_type"
      return 1
      ;;
  esac
  
  # Delete Flux kustomizations
  ui_log_info "Deleting policy Flux kustomizations"
  kubectl delete -f "$POLICY_TEMPLATES_DIR/kustomization.yaml" --ignore-not-found
  kubectl delete -f "$POLICY_CONSTRAINTS_DIR/kustomization.yaml" --ignore-not-found
  
  ui_log_success "Policy Management cleanup completed"
  return 0
}

# Diagnose function - provides detailed diagnostics
policy_management_diagnose() {
  ui_log_info "Running Policy Management diagnostics"
  
  # Determine policy engine type
  local policy_engine_type=""
  if kubectl api-resources | grep -q "kyverno"; then
    policy_engine_type="kyverno"
  elif kubectl api-resources | grep -q "gatekeeper"; then
    policy_engine_type="gatekeeper"
  elif kubectl api-resources | grep -q "constrainttemplate"; then
    policy_engine_type="opa"
  else
    ui_log_error "No supported policy engine detected."
    return 1
  fi
  
  ui_log_info "Detected policy engine: $policy_engine_type"
  
  # Check policy engine status
  case "$policy_engine_type" in
    kyverno)
      # Check Kyverno controller status
      ui_subheader "Kyverno Controller Status"
      kubectl get pods -n kyverno -o wide
      
      # Check Kyverno webhook configuration
      ui_subheader "Kyverno Webhook Configuration"
      kubectl get validatingwebhookconfigurations | grep -i kyverno
      kubectl get mutatingwebhookconfigurations | grep -i kyverno
      
      # Get all cluster policies and details
      ui_subheader "Kyverno ClusterPolicies"
      kubectl get clusterpolicy
      
      local cluster_policies=$(kubectl get clusterpolicy -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      if [ -n "$cluster_policies" ]; then
        for policy in $cluster_policies; do
          ui_subheader "ClusterPolicy Detail: $policy"
          kubectl get clusterpolicy "$policy" -o yaml
        done
      fi
      
      # Check namespaced policies
      ui_subheader "Kyverno Namespaced Policies"
      kubectl get policy --all-namespaces
      
      # Check policy reports
      if kubectl api-resources | grep -q "policyreport"; then
        ui_subheader "Kyverno Policy Reports"
        kubectl get policyreport --all-namespaces
        kubectl get clusterpolicyreport
      fi
      
      # Check Kyverno logs
      ui_subheader "Kyverno Controller Logs"
      local kyverno_pod=$(kubectl get pods -n kyverno -l app.kubernetes.io/name=kyverno -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -n "$kyverno_pod" ]; then
        kubectl logs -n kyverno "$kyverno_pod" --tail=50
      fi
      ;;
      
    gatekeeper|opa)
      # Check Gatekeeper/OPA controller status
      ui_subheader "Gatekeeper/OPA Controller Status"
      kubectl get pods -n gatekeeper-system -o wide 2>/dev/null
      
      # Check Gatekeeper webhook configuration
      ui_subheader "Gatekeeper Webhook Configuration"
      kubectl get validatingwebhookconfigurations | grep -i gatekeeper
      
      # Get all constraint templates
      ui_subheader "Constraint Templates"
      kubectl get constrainttemplate
      
      local templates=$(kubectl get constrainttemplate -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      if [ -n "$templates" ]; then
        for template in $templates; do
          ui_subheader "Constraint Template Detail: $template"
          kubectl get constrainttemplate "$template" -o yaml
        done
      fi
      
      # Get all constraints across all kinds
      ui_subheader "Constraints Status"
      local all_kinds=$(kubectl api-resources --api-group=constraints.gatekeeper.sh -o name 2>/dev/null)
      if [ -n "$all_kinds" ]; then
        for kind in $all_kinds; do
          ui_log_info "Constraint Kind: $kind"
          kubectl get "$kind"
          
          local constraints=$(kubectl get "$kind" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
          if [ -n "$constraints" ]; then
            for constraint in $constraints; do
              ui_subheader "Constraint Detail: $kind/$constraint"
              kubectl get "$kind" "$constraint" -o yaml
            done
          fi
        done
      fi
      
      # Check Gatekeeper audit logs
      ui_subheader "Gatekeeper Audit Logs"
      local audit_pod=$(kubectl get pods -n gatekeeper-system -l control-plane=audit-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -n "$audit_pod" ]; then
        kubectl logs -n gatekeeper-system "$audit_pod" --tail=50
      fi
      ;;
      
    *)
      ui_log_error "Unsupported policy engine type: $policy_engine_type"
      return 1
      ;;
  esac
  
  # Check policy directories content
  ui_subheader "Policy Templates Directory"
  ls -la "$POLICY_TEMPLATES_DIR"
  
  ui_subheader "Policy Constraints Directory"
  ls -la "$POLICY_CONSTRAINTS_DIR"
  
  # Get recent events related to policy violations
  ui_subheader "Recent Policy Violation Events"
  kubectl get events --all-namespaces | grep -i "policy\|constraint\|violation" | tail -20
  
  ui_log_success "Policy Management diagnostics completed"
  return 0
}

# Export functions
export -f policy_management_pre_deploy
export -f policy_management_deploy
export -f policy_management_post_deploy
export -f policy_management_verify
export -f policy_management_cleanup
export -f policy_management_diagnose 