#!/bin/bash
# network-policies.sh: Network Policy Management Component Functions
# Handles all operations for managing and applying Kubernetes Network Policies

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="network-policies"
NETWORK_POLICIES_DIR="${BASE_DIR}/clusters/local/policies/network"
NAMESPACES_DIR="${BASE_DIR}/clusters/local/namespaces"
RESOURCE_TYPES=("networkpolicy")

# Pre-deployment function - runs before deployment
network_policies_pre_deploy() {
  ui_log_info "Running Network Policy Management pre-deployment checks"
  
  # Check if NetworkPolicy API is available
  if ! kubectl api-resources | grep -q "networkpolicy"; then
    ui_log_error "NetworkPolicy API is not available in the cluster"
    ui_log_error "Make sure your cluster has a network plugin that supports NetworkPolicies (e.g., Calico, Cilium, etc.)"
    return 1
  fi
  
  # Create network policies directory if it doesn't exist
  if [ ! -d "$NETWORK_POLICIES_DIR" ]; then
    ui_log_warning "Network policies directory not found at $NETWORK_POLICIES_DIR"
    ui_log_info "Creating directory"
    mkdir -p "$NETWORK_POLICIES_DIR"
    
    # Create a basic kustomization file
    cat > "$NETWORK_POLICIES_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Network policies for the cluster
resources:
# Uncomment or add your network policy files here
# - default-deny-all.yaml
# - allow-dns.yaml
# - allow-monitoring.yaml
EOF
  fi
  
  # Create default network policies if they don't exist
  if [ ! -f "$NETWORK_POLICIES_DIR/default-deny-all.yaml" ]; then
    ui_log_info "Creating default deny-all network policy template"
    cat > "$NETWORK_POLICIES_DIR/default-deny-all.yaml" <<EOF
# Default deny all ingress and egress traffic
# Apply this to namespaces where you want to enforce strict isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: REPLACE_WITH_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
  fi
  
  if [ ! -f "$NETWORK_POLICIES_DIR/allow-dns.yaml" ]; then
    ui_log_info "Creating allow DNS network policy template"
    cat > "$NETWORK_POLICIES_DIR/allow-dns.yaml" <<EOF
# Allow DNS resolution
# Apply this to namespaces where you have default-deny policies but need DNS resolution
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: REPLACE_WITH_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
  fi
  
  if [ ! -f "$NETWORK_POLICIES_DIR/allow-monitoring.yaml" ]; then
    ui_log_info "Creating allow monitoring network policy template"
    cat > "$NETWORK_POLICIES_DIR/allow-monitoring.yaml" <<EOF
# Allow monitoring tools to scrape metrics
# Apply this to namespaces where you want to allow monitoring tools to access metrics
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: REPLACE_WITH_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
    ports:
    - protocol: TCP
      port: 9090
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 10254
    - protocol: TCP
      port: 10249
    - protocol: TCP
      port: 9100
    - protocol: TCP
      port: 9091
EOF
  fi
  
  return 0
}

# Deploy function - deploys network policies
network_policies_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Network Policies using $deploy_mode mode"
  
  # Get list of all namespaces
  local all_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux if kustomization file exists
      if [ -f "$NETWORK_POLICIES_DIR/kustomization.yaml" ]; then
        ui_log_info "Applying network policies via Flux"
        kubectl apply -f "$NETWORK_POLICIES_DIR/kustomization.yaml"
      else
        ui_log_warning "No kustomization.yaml found in $NETWORK_POLICIES_DIR"
        ui_log_info "Creating and applying individual network policies"
        
        # Find all yaml files in the policies directory
        for policy_file in "$NETWORK_POLICIES_DIR"/*.yaml; do
          if [ -f "$policy_file" ] && [[ "$policy_file" != *"kustomization.yaml"* ]]; then
            ui_log_info "Applying network policy file: $(basename "$policy_file")"
            kubectl apply -f "$policy_file"
          fi
        done
      fi
      ;;
    
    kubectl)
      # Direct kubectl apply
      if [ -d "$NETWORK_POLICIES_DIR" ]; then
        ui_log_info "Applying network policies with kubectl"
        
        # Find all yaml files in the policies directory
        for policy_file in "$NETWORK_POLICIES_DIR"/*.yaml; do
          if [ -f "$policy_file" ] && [[ "$policy_file" != *"kustomization.yaml"* ]]; then
            ui_log_info "Applying network policy file: $(basename "$policy_file")"
            kubectl apply -f "$policy_file"
          fi
        done
      else
        ui_log_warning "Network policies directory not found at $NETWORK_POLICIES_DIR"
      fi
      ;;
    
    namespace)
      # Deploy network policies per namespace
      ui_log_info "Applying network policies per namespace"
      
      # Check if namespaces directory exists
      if [ ! -d "$NAMESPACES_DIR" ]; then
        ui_log_warning "Namespaces directory not found at $NAMESPACES_DIR"
        return 1
      fi
      
      # Find all namespace directories
      for namespace_dir in "$NAMESPACES_DIR"/*; do
        if [ -d "$namespace_dir" ]; then
          local namespace=$(basename "$namespace_dir")
          
          # Check if network policies directory exists for this namespace
          local ns_policies_dir="$namespace_dir/network-policies"
          if [ -d "$ns_policies_dir" ]; then
            ui_log_info "Applying network policies for namespace: $namespace"
            
            # Apply all policy files in this namespace's network policies directory
            for policy_file in "$ns_policies_dir"/*.yaml; do
              if [ -f "$policy_file" ]; then
                ui_log_info "Applying network policy: $(basename "$policy_file")"
                
                # Check if namespace exists and create if needed
                if ! echo "$all_namespaces" | grep -q "\b$namespace\b"; then
                  ui_log_info "Creating namespace: $namespace"
                  kubectl create namespace "$namespace"
                fi
                
                kubectl apply -f "$policy_file"
              fi
            done
          fi
        fi
      done
      ;;
    
    template)
      # Apply templated policies to specified namespaces
      ui_log_info "Applying templated network policies to specified namespaces"
      
      # Get list of namespaces that should have network policies applied
      local target_namespaces=$(kubectl get namespace -l network-policy=enabled -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      
      if [ -z "$target_namespaces" ]; then
        ui_log_warning "No namespaces with label 'network-policy=enabled' found"
        ui_log_info "Applying to all non-system namespaces instead"
        
        target_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | \
          tr ' ' '\n' | grep -v "kube-system\|kube-public\|kube-node-lease" | tr '\n' ' ')
      fi
      
      # Loop through each namespace and apply policies
      for namespace in $target_namespaces; do
        ui_log_info "Applying network policies to namespace: $namespace"
        
        # Apply default deny policy if it exists
        if [ -f "$NETWORK_POLICIES_DIR/default-deny-all.yaml" ]; then
          ui_log_info "Applying default-deny-all policy to namespace: $namespace"
          sed "s/REPLACE_WITH_NAMESPACE/$namespace/g" "$NETWORK_POLICIES_DIR/default-deny-all.yaml" | kubectl apply -f -
        fi
        
        # Apply DNS policy if it exists
        if [ -f "$NETWORK_POLICIES_DIR/allow-dns.yaml" ]; then
          ui_log_info "Applying allow-dns policy to namespace: $namespace"
          sed "s/REPLACE_WITH_NAMESPACE/$namespace/g" "$NETWORK_POLICIES_DIR/allow-dns.yaml" | kubectl apply -f -
        fi
        
        # Apply monitoring policy if it exists
        if [ -f "$NETWORK_POLICIES_DIR/allow-monitoring.yaml" ]; then
          ui_log_info "Applying allow-monitoring policy to namespace: $namespace"
          sed "s/REPLACE_WITH_NAMESPACE/$namespace/g" "$NETWORK_POLICIES_DIR/allow-monitoring.yaml" | kubectl apply -f -
        fi
        
        # Apply any other template policies
        for policy_file in "$NETWORK_POLICIES_DIR"/*.yaml; do
          if [ -f "$policy_file" ] && \
             [[ "$policy_file" != *"kustomization.yaml"* ]] && \
             [[ "$policy_file" != *"default-deny-all.yaml"* ]] && \
             [[ "$policy_file" != *"allow-dns.yaml"* ]] && \
             [[ "$policy_file" != *"allow-monitoring.yaml"* ]]; then
            
            local policy_name=$(basename "$policy_file" .yaml)
            ui_log_info "Applying $policy_name policy to namespace: $namespace"
            sed "s/REPLACE_WITH_NAMESPACE/$namespace/g" "$policy_file" | kubectl apply -f -
          fi
        done
      done
      ;;
    
    *)
      ui_log_error "Invalid deployment mode: $deploy_mode"
      ui_log_info "Valid modes are: flux, kubectl, namespace, template"
      return 1
      ;;
  esac
  
  return $?
}

# Post-deployment function - runs after deployment
network_policies_post_deploy() {
  ui_log_info "Running Network Policy Management post-deployment tasks"
  
  # Check for any unlabeled namespaces that should have network policies
  local all_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | \
    tr ' ' '\n' | grep -v "kube-system\|kube-public\|kube-node-lease" | tr '\n' ' ')
  
  local labeled_namespaces=$(kubectl get namespace -l network-policy -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  
  ui_log_info "Checking namespaces without network policy labels"
  for namespace in $all_namespaces; do
    if ! echo "$labeled_namespaces" | grep -q "\b$namespace\b"; then
      ui_log_warning "Namespace '$namespace' has no network policy label. Consider adding one with:"
      ui_log_info "kubectl label namespace $namespace network-policy=enabled"
    fi
  done
  
  # Check for namespaces without any network policies
  ui_log_info "Checking namespaces without any network policies"
  for namespace in $all_namespaces; do
    local policy_count=$(kubectl get networkpolicy -n "$namespace" -o name 2>/dev/null | wc -l)
    
    if [ "$policy_count" -eq 0 ]; then
      ui_log_warning "Namespace '$namespace' has no network policies defined"
      ui_log_info "Consider deploying network policies to secure this namespace"
    else
      ui_log_success "Namespace '$namespace' has $policy_count network policies"
    fi
  done
  
  return 0
}

# Verification function - verifies network policies are working
network_policies_verify() {
  ui_log_info "Verifying Network Policy Management installation"
  
  # Get list of all namespaces
  local all_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | \
    tr ' ' '\n' | grep -v "kube-system\|kube-public\|kube-node-lease" | tr '\n' ' ')
  
  # Check network policies in each namespace
  for namespace in $all_namespaces; do
    ui_subheader "Network Policies in namespace: $namespace"
    
    # Get policies in this namespace
    local policies=$(kubectl get networkpolicy -n "$namespace" -o name 2>/dev/null)
    
    if [ -z "$policies" ]; then
      ui_log_warning "No network policies found in namespace '$namespace'"
    else
      local policy_count=$(echo "$policies" | wc -l)
      ui_log_success "Found $policy_count network policies in namespace '$namespace'"
      
      # Print details for each policy
      echo "$policies" | while read -r policy; do
        local policy_name=$(echo "$policy" | cut -d'/' -f2)
        
        # Get policy type (ingress/egress)
        local policy_types=$(kubectl get networkpolicy "$policy_name" -n "$namespace" -o jsonpath='{.spec.policyTypes}' | tr -d '[]"' | tr ',' ' ')
        
        # Get pod selector
        local pod_selector=$(kubectl get networkpolicy "$policy_name" -n "$namespace" -o jsonpath='{.spec.podSelector}')
        
        ui_log_info "Policy: $policy_name (Types: $policy_types, Pod Selector: $pod_selector)"
        
        # Print ingress rules if present
        if echo "$policy_types" | grep -q "Ingress"; then
          local ingress_rules=$(kubectl get networkpolicy "$policy_name" -n "$namespace" -o jsonpath='{.spec.ingress}' 2>/dev/null)
          if [ -n "$ingress_rules" ] && [ "$ingress_rules" != "[]" ]; then
            ui_log_info "  Ingress: $(echo "$ingress_rules" | tr -d '\n' | cut -c1-100)..."
          else
            ui_log_info "  Ingress: No specific rules (deny all)"
          fi
        fi
        
        # Print egress rules if present
        if echo "$policy_types" | grep -q "Egress"; then
          local egress_rules=$(kubectl get networkpolicy "$policy_name" -n "$namespace" -o jsonpath='{.spec.egress}' 2>/dev/null)
          if [ -n "$egress_rules" ] && [ "$egress_rules" != "[]" ]; then
            ui_log_info "  Egress: $(echo "$egress_rules" | tr -d '\n' | cut -c1-100)..."
          else
            ui_log_info "  Egress: No specific rules (deny all)"
          fi
        fi
      done
    fi
  done
  
  # Check for default deny policies
  ui_log_info "Checking for default deny policies in namespaces"
  for namespace in $all_namespaces; do
    local default_deny=$(kubectl get networkpolicy -n "$namespace" -o name 2>/dev/null | grep "default-deny\|deny-all")
    
    if [ -n "$default_deny" ]; then
      ui_log_success "Default deny policy found in namespace '$namespace'"
    else
      ui_log_warning "No default deny policy found in namespace '$namespace'"
      ui_log_info "Consider adding a default deny policy to improve security"
    fi
  done
  
  # Test network policies if in interactive mode
  if [ -t 0 ] && [ -t 1 ]; then  # Check if running in interactive terminal
    ui_log_info "Would you like to test network policy enforcement with a sample test? [y/N]"
    read -r -n 1 response
    echo
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
      ui_log_info "Testing network policy enforcement"
      
      # Create test namespaces
      kubectl create namespace netpol-test-source
      kubectl create namespace netpol-test-target
      
      # Create test pods
      ui_log_info "Creating test pods"
      
      # Create client pod in source namespace
      cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-client
  namespace: netpol-test-source
  labels:
    app: test-client
spec:
  containers:
  - name: alpine
    image: alpine:latest
    command: ["sleep", "3600"]
EOF
      
      # Create server pod in target namespace
      cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-server
  namespace: netpol-test-target
  labels:
    app: test-server
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-server
  namespace: netpol-test-target
spec:
  selector:
    app: test-server
  ports:
  - port: 80
    targetPort: 80
EOF
      
      # Wait for pods to be ready
      ui_log_info "Waiting for test pods to be ready"
      kubectl wait --for=condition=Ready pod/test-client -n netpol-test-source --timeout=60s
      kubectl wait --for=condition=Ready pod/test-server -n netpol-test-target --timeout=60s
      
      # Test connectivity without network policy
      ui_log_info "Testing connectivity without network policy"
      kubectl exec -n netpol-test-source test-client -- wget -T 5 -qO- test-server.netpol-test-target.svc.cluster.local && \
        ui_log_success "Connection successful without network policy" || \
        ui_log_error "Connection failed without network policy"
      
      # Apply default deny policy to target namespace
      ui_log_info "Applying default deny policy to target namespace"
      cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: netpol-test-target
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
      
      # Test connectivity with network policy
      sleep 5  # Give time for policy to take effect
      ui_log_info "Testing connectivity with deny network policy"
      kubectl exec -n netpol-test-source test-client -- wget -T 5 -qO- test-server.netpol-test-target.svc.cluster.local && \
        ui_log_error "Connection successful despite network policy - policy not enforced!" || \
        ui_log_success "Connection blocked by network policy - working as expected"
      
      # Apply allow policy to target namespace
      ui_log_info "Applying allow policy from source namespace"
      cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-test-source
  namespace: netpol-test-target
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: netpol-test-source
EOF
      
      # Label the source namespace
      kubectl label namespace netpol-test-source kubernetes.io/metadata.name=netpol-test-source --overwrite
      
      # Test connectivity with allow policy
      sleep 5  # Give time for policy to take effect
      ui_log_info "Testing connectivity with allow network policy"
      kubectl exec -n netpol-test-source test-client -- wget -T 5 -qO- test-server.netpol-test-target.svc.cluster.local && \
        ui_log_success "Connection successful with allow policy - working as expected" || \
        ui_log_error "Connection still blocked despite allow policy"
      
      # Clean up test resources
      ui_log_info "Cleaning up test resources"
      kubectl delete namespace netpol-test-source netpol-test-target
    fi
  fi
  
  ui_log_success "Network Policy Management verification completed"
  return 0
}

# Cleanup function - removes network policies
network_policies_cleanup() {
  ui_log_info "Cleaning up Network Policy Management"
  
  # Get list of all namespaces
  local all_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
  
  # Ask user for confirmation if in interactive mode
  if [ -t 0 ] && [ -t 1 ]; then  # Check if running in interactive terminal
    ui_log_warning "This will remove ALL network policies from ALL namespaces"
    ui_log_warning "This can leave your cluster in an insecure state"
    ui_log_info "Would you like to proceed? [y/N]"
    read -r -n 1 response
    echo
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      ui_log_info "Cleanup aborted"
      return 0
    fi
  fi
  
  # Remove all network policies from all namespaces
  for namespace in $all_namespaces; do
    local policies=$(kubectl get networkpolicy -n "$namespace" -o name 2>/dev/null)
    
    if [ -n "$policies" ]; then
      ui_log_info "Removing network policies from namespace: $namespace"
      
      # Delete each policy
      echo "$policies" | while read -r policy; do
        ui_log_info "Deleting policy: $policy"
        kubectl delete "$policy" -n "$namespace"
      done
    fi
  done
  
  # Delete Flux kustomization if present
  if [ -f "$NETWORK_POLICIES_DIR/kustomization.yaml" ]; then
    ui_log_info "Deleting network policy Flux kustomization"
    kubectl delete -f "$NETWORK_POLICIES_DIR/kustomization.yaml" --ignore-not-found
  fi
  
  ui_log_success "Network Policy Management cleanup completed"
  return 0
}

# Diagnose function - provides detailed diagnostics
network_policies_diagnose() {
  ui_log_info "Running Network Policy Management diagnostics"
  
  # Check if NetworkPolicy API is available
  ui_subheader "Network Policy API Status"
  if kubectl api-resources | grep -q "networkpolicy"; then
    ui_log_success "NetworkPolicy API is available"
    kubectl api-resources | grep networkpolicy
  else
    ui_log_error "NetworkPolicy API is not available in the cluster"
    ui_log_error "Make sure your cluster has a network plugin that supports NetworkPolicies (e.g., Calico, Cilium, etc.)"
    return 1
  fi
  
  # Check network plugin
  ui_subheader "Network Plugin"
  if kubectl get pods -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[0].spec.containers[0].args}' | grep -q "network-plugin"; then
    local network_plugin=$(kubectl get pods -n kube-system -l k8s-app=kube-proxy -o jsonpath='{.items[0].spec.containers[0].args}' | grep "network-plugin" | sed 's/.*network-plugin=\([^ ]*\).*/\1/')
    ui_log_info "Network plugin: $network_plugin"
  else
    ui_log_warning "Could not determine network plugin"
  fi
  
  # Check for CNI plugins
  if kubectl get pods -n kube-system -l k8s-app=calico-node -o name &>/dev/null; then
    ui_log_info "Calico CNI detected (supports Network Policies)"
  elif kubectl get pods -n kube-system -l k8s-app=cilium -o name &>/dev/null || kubectl get pods -n cilium -l app=cilium-agent -o name &>/dev/null; then
    ui_log_info "Cilium CNI detected (supports Network Policies)"
  elif kubectl get pods -n kube-system -l app=weave-net -o name &>/dev/null; then
    ui_log_info "Weave Net CNI detected (supports Network Policies)"
  elif kubectl get pods -n kube-system -l app=flannel -o name &>/dev/null; then
    ui_log_warning "Flannel CNI detected (does NOT support Network Policies on its own)"
  else
    ui_log_warning "Could not identify CNI plugin"
  fi
  
  # Get list of all namespaces
  local all_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
  
  # Count total network policies
  local total_policies=0
  for namespace in $all_namespaces; do
    local policy_count=$(kubectl get networkpolicy -n "$namespace" -o name 2>/dev/null | wc -l)
    total_policies=$((total_policies + policy_count))
  done
  
  ui_subheader "Network Policy Summary"
  ui_log_info "Total network policies across all namespaces: $total_policies"
  
  # List network policies per namespace
  for namespace in $all_namespaces; do
    local policies=$(kubectl get networkpolicy -n "$namespace" -o name 2>/dev/null)
    
    if [ -n "$policies" ]; then
      local policy_count=$(echo "$policies" | wc -l)
      ui_log_info "Namespace '$namespace': $policy_count network policies"
      
      # Display each policy
      echo "$policies" | while read -r policy; do
        local policy_name=$(echo "$policy" | cut -d'/' -f2)
        ui_subheader "Network Policy: $namespace/$policy_name"
        kubectl get networkpolicy "$policy_name" -n "$namespace" -o yaml
      done
    fi
  done
  
  # Check for namespaces without network policies
  ui_subheader "Namespaces Without Network Policies"
  local unprotected_count=0
  for namespace in $all_namespaces; do
    local policy_count=$(kubectl get networkpolicy -n "$namespace" -o name 2>/dev/null | wc -l)
    
    if [ "$policy_count" -eq 0 ] && [[ "$namespace" != "kube-system" && "$namespace" != "kube-public" && "$namespace" != "kube-node-lease" ]]; then
      ui_log_warning "Namespace '$namespace' has no network policies"
      unprotected_count=$((unprotected_count + 1))
    fi
  done
  
  if [ "$unprotected_count" -eq 0 ]; then
    ui_log_success "All non-system namespaces have network policies"
  else
    ui_log_warning "Found $unprotected_count namespaces without network policies"
  fi
  
  # Check for default deny policies
  ui_subheader "Default Deny Policy Check"
  local namespaces_without_default_deny=0
  for namespace in $all_namespaces; do
    if [[ "$namespace" != "kube-system" && "$namespace" != "kube-public" && "$namespace" != "kube-node-lease" ]]; then
      local default_deny=$(kubectl get networkpolicy -n "$namespace" -o name 2>/dev/null | grep "default-deny\|deny-all")
      
      if [ -z "$default_deny" ]; then
        ui_log_warning "Namespace '$namespace' has no default deny policy"
        namespaces_without_default_deny=$((namespaces_without_default_deny + 1))
      else
        ui_log_success "Namespace '$namespace' has a default deny policy"
      fi
    fi
  done
  
  if [ "$namespaces_without_default_deny" -eq 0 ]; then
    ui_log_success "All non-system namespaces have default deny policies"
  else
    ui_log_warning "Found $namespaces_without_default_deny namespaces without default deny policies"
  fi
  
  # Check network policy directory
  ui_subheader "Network Policy Directory"
  if [ -d "$NETWORK_POLICIES_DIR" ]; then
    ui_log_success "Network policies directory exists at: $NETWORK_POLICIES_DIR"
    ls -la "$NETWORK_POLICIES_DIR"
  else
    ui_log_warning "Network policies directory not found at: $NETWORK_POLICIES_DIR"
  fi
  
  ui_log_success "Network Policy Management diagnostics completed"
  return 0
}

# Export functions
export -f network_policies_pre_deploy
export -f network_policies_deploy
export -f network_policies_post_deploy
export -f network_policies_verify
export -f network_policies_cleanup
export -f network_policies_diagnose 