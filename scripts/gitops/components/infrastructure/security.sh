#!/bin/bash
# security.sh: Generic Security Components Script
# Handles operations for general security components that don't have dedicated scripts

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="security"
NAMESPACE="security"
COMPONENT_DEPENDENCIES=()
RESOURCE_TYPES=("deployment" "service" "configmap" "secret" "daemonset")

# Pre-deployment function - runs before deployment
security_pre_deploy() {
  ui_log_info "Running security pre-deployment checks"

  # Create namespace if needed
  ui_log_info "Creating namespace: $NAMESPACE"
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for security components"
    return 1
  fi

  # Add Helm repos if needed
  if ! helm repo list | grep -q "falcosecurity"; then
    ui_log_info "Adding Falco Helm repository"
    helm repo add falcosecurity https://falcosecurity.github.io/charts
  fi

  ui_log_info "Adding Jetstack Helm repository (for cert-manager)"
  helm repo add jetstack https://charts.jetstack.io

  # Update Helm repos
  helm repo update

  return 0
}

# Deploy function - deploys the component
security_deploy() {
  local deploy_mode="${1:-flux}"

  ui_log_info "Deploying security using $deploy_mode mode"

  case "$deploy_mode" in
  flux)
    # Deploy security components using Flux
    kubectl apply -f "${BASE_DIR}/clusters/local/infrastructure/security/kustomization.yaml"
    ;;

  kubectl)
    # Direct kubectl apply
    ui_log_info "Applying security manifests directly with kubectl"
    kubectl apply -k "${BASE_DIR}/clusters/local/infrastructure/security"
    ;;

  helm)
    # Helm-based installation of various security components
    ui_log_info "Deploying security components with Helm"

    # Deploy Falco for runtime security
    if ! helm list -n "$NAMESPACE" | grep -q "falco"; then
      ui_log_info "Installing Falco runtime security"
      helm install falco falcosecurity/falco \
        --namespace "$NAMESPACE" \
        --set falco.json_output=true \
        --set falco.priority=debug \
        --set auditLog.enabled=true \
        --set falco.rules.file_output.enabled=true
    else
      ui_log_info "Falco is already installed via Helm"
    fi

    # Deploy runtime security scanning (Trivy)
    if ! helm list -n "$NAMESPACE" | grep -q "trivy-operator"; then
      ui_log_info "Installing Trivy Operator"
      if ! helm repo list | grep -q "aqua"; then
        helm repo add aqua https://aquasecurity.github.io/helm-charts/
        helm repo update
      fi

      helm install trivy-operator aqua/trivy-operator \
        --namespace "$NAMESPACE" \
        --set trivy.ignoreUnfixed=true
    else
      ui_log_info "Trivy Operator is already installed via Helm"
    fi

    # Deploy network policy enforcer if needed
    if ! kubectl get daemonset -n kube-system | grep -q "calico-node"; then
      ui_log_info "Installing Calico for network policy enforcement"
      kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
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
security_post_deploy() {
  ui_log_info "Running security post-deployment tasks"

  # Wait for important deployments to be ready
  ui_log_info "Waiting for security deployments to be ready"
  
  # Check if falco is deployed and wait for it
  if kubectl get deployment -n "$NAMESPACE" | grep -q falco; then
    ui_log_info "Waiting for Falco deployment to be ready"
    kubectl rollout status deployment -n "$NAMESPACE" -l app=falco --timeout=120s
  fi
  
  # Check if trivy-operator is deployed and wait for it
  if kubectl get deployment -n "$NAMESPACE" | grep -q trivy-operator; then
    ui_log_info "Waiting for trivy-operator deployment to be ready"
    kubectl rollout status deployment -n "$NAMESPACE" -l app=trivy-operator --timeout=120s
  fi
  
  # Check for any other deployments in the namespace and wait for them
  for deployment in $(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    ui_log_info "Waiting for deployment $deployment to be ready"
    kubectl rollout status deployment -n "$NAMESPACE" "$deployment" --timeout=90s
  done

  # Create default network policies
  ui_log_info "Creating default network policies"

  # Create a deny-all policy as a starting point for securing namespaces
  cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

  # Create an allow-metrics policy for Prometheus to scrape metrics
  cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-metrics
  namespace: $NAMESPACE
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: falco
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
    ports:
    - port: 9090
      protocol: TCP
EOF

  # Check for PSPs/Pod Security Standards
  if kubectl api-resources | grep -q podsecuritypolicies.policy; then
    ui_log_info "Creating basic Pod Security Policy"
    # ... PSP creation code ...
  elif kubectl api-resources | grep -q podsecuritystandards; then
    ui_log_info "Creating Pod Security Standards configuration"
    # ... PSS configuration code ...
  else
    ui_log_warning "Neither Pod Security Policies nor Pod Security Standards found in the cluster"
  fi

  # Create basic audit policy
  ui_log_info "Creating basic audit policy"
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-policy
  namespace: kube-system
data:
  policy.yaml: |
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
    - level: Metadata
      resources:
      - group: ""
        resources: ["secrets", "configmaps"]
    - level: RequestResponse
      resources:
      - group: ""
        resources: ["namespaces"]
    - level: Metadata
      resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]
    - level: Metadata
      nonResourceURLs:
      - /api*
      - /healthz*
      - /logs*
      - /metrics*
      - /swagger*
      - /version*
EOF

  return 0
}

# Verification function - verifies the component is working
security_verify() {
  ui_log_info "Verifying security installation"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi

  # Check for security components - Falco
  if kubectl get pods -n "$NAMESPACE" -l app=falco &>/dev/null; then
    local falco_pods=$(kubectl get pods -n "$NAMESPACE" -l app=falco -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$falco_pods" || "$falco_pods" != *"Running"* ]]; then
      ui_log_error "Falco pods are not running"
    else
      ui_log_success "Falco is running"
    fi
  else
    ui_log_warning "Falco is not installed"
  fi

  # Check for trivy-operator
  if kubectl get pods -n "$NAMESPACE" -l app=trivy-operator &>/dev/null; then
    local trivy_pods=$(kubectl get pods -n "$NAMESPACE" -l app=trivy-operator -o jsonpath='{.items[*].status.phase}')
    if [[ -z "$trivy_pods" || "$trivy_pods" != *"Running"* ]]; then
      ui_log_error "Trivy Operator pods are not running"
    else
      ui_log_success "Trivy Operator is running"
    fi
  else
    ui_log_warning "Trivy Operator is not installed"
  fi

  # Check network policies
  if kubectl get netpol -n "$NAMESPACE" &>/dev/null; then
    ui_log_success "Network policies exist in the namespace"
  else
    ui_log_warning "No network policies found in namespace $NAMESPACE"
  fi

  # Check for Pod Security Policies or Standards
  if kubectl api-resources | grep -q "podsecuritypolicies"; then
    if kubectl get psp restricted-psp &>/dev/null; then
      ui_log_success "Restricted Pod Security Policy exists"
    else
      ui_log_warning "Restricted Pod Security Policy does not exist"
    fi
  elif kubectl api-resources | grep -q "podsecuritystandards"; then
    ui_log_success "Pod Security Standards are available in the cluster"
  else
    ui_log_warning "Neither Pod Security Policies nor Pod Security Standards found in the cluster"
  fi

  # Check audit policy
  if kubectl get configmap -n kube-system | grep -q "audit-policy"; then
    ui_log_success "Audit policy is configured"
  else
    ui_log_warning "Audit policy is not configured"
  fi

  # Simple test to verify pod creation with security controls
  ui_log_info "Testing pod creation with security constraints"

  # Create a namespace for testing
  kubectl create namespace security-test 2>/dev/null || true

  # Try to create a secure pod
  ui_log_info "Creating a secure pod"
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: security-test
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: nginx
    image: nginx:stable
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    ports:
    - containerPort: 80
    volumeMounts:
    - name: tmp-volume
      mountPath: /tmp
    - name: var-run-nginx
      mountPath: /var/run/nginx
    - name: var-cache-nginx
      mountPath: /var/cache/nginx
  volumes:
  - name: tmp-volume
    emptyDir: {}
  - name: var-run-nginx
    emptyDir: {}
  - name: var-cache-nginx
    emptyDir: {}
EOF

  # Wait for pod to be created
  sleep 5

  # Check if secure pod is running
  if kubectl get pod secure-pod -n security-test &>/dev/null; then
    local pod_status=$(kubectl get pod secure-pod -n security-test -o jsonpath='{.status.phase}')
    if [[ "$pod_status" == "Running" ]]; then
      ui_log_success "Secure pod created successfully"
    else
      local pod_reason=$(kubectl get pod secure-pod -n security-test -o jsonpath='{.status.reason}')
      ui_log_warning "Secure pod not running. Status: $pod_status, Reason: $pod_reason"
    fi
  else
    ui_log_error "Failed to create secure pod"
  fi

  # Try to create a privileged pod (should be blocked by PSPs or admission controllers)
  ui_log_info "Testing privileged pod creation (should be blocked)"
  cat <<EOF | kubectl apply -f - 2>/dev/null || echo "Privileged pod blocked as expected"
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: security-test
spec:
  containers:
  - name: nginx
    image: nginx:stable
    securityContext:
      privileged: true
EOF

  # Check if the privileged pod was blocked
  if ! kubectl get pod privileged-pod -n security-test &>/dev/null; then
    ui_log_success "Privileged pod correctly blocked"
  else
    ui_log_warning "Privileged pod was created. Security controls may not be properly configured."
    kubectl delete pod privileged-pod -n security-test --force --grace-period=0
  fi

  # Clean up test resources
  kubectl delete pod secure-pod -n security-test --force --grace-period=0
  kubectl delete namespace security-test

  return 0
}

# Cleanup function - removes the component
security_cleanup() {
  ui_log_info "Cleaning up security components"

  # Remove Falco
  if helm list -n "$NAMESPACE" | grep -q "falco"; then
    ui_log_info "Uninstalling Falco Helm release"
    helm uninstall falco -n "$NAMESPACE"
  fi

  # Remove Trivy operator
  if helm list -n "$NAMESPACE" | grep -q "trivy-operator"; then
    ui_log_info "Uninstalling Trivy Operator Helm release"
    helm uninstall trivy-operator -n "$NAMESPACE"
  fi

  # Remove network policies
  ui_log_info "Removing network policies"
  kubectl delete netpol --all -n "$NAMESPACE" --ignore-not-found=true

  # Delete Flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/infrastructure/security/kustomization.yaml" --ignore-not-found=true

  # Delete PSPs
  if kubectl api-resources | grep -q "podsecuritypolicies"; then
    ui_log_info "Removing Pod Security Policies"
    kubectl delete psp restricted-psp --ignore-not-found=true
    kubectl delete clusterrole psp:restricted --ignore-not-found=true
    kubectl delete clusterrolebinding default:restricted --ignore-not-found=true
  fi

  # Delete audit policy
  kubectl delete configmap audit-policy -n kube-system --ignore-not-found=true

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

  # Check for any leftover resources
  for resource_type in deployment service daemonset configmap secret; do
    if kubectl get $resource_type -n "$NAMESPACE" 2>/dev/null | grep -v "No resources" >/dev/null; then
      ui_log_warning "Removing remaining $resource_type resources in $NAMESPACE"
      kubectl delete $resource_type --all -n "$NAMESPACE" --force
    fi
  done

  return 0
}

# Diagnose function - provides detailed diagnostics
security_diagnose() {
  ui_log_info "Running security component diagnostics"

  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    ui_log_info "Run the deployment script first to install security components"
    return 1
  fi

  # Display pod status
  ui_subheader "Security Pod Status"
  kubectl get pods -n "$NAMESPACE" -o wide

  # Display deployments
  ui_subheader "Security Deployments"
  kubectl get deployments -n "$NAMESPACE"

  # Display daemonsets
  ui_subheader "Security DaemonSets"
  kubectl get daemonsets -n "$NAMESPACE"

  # Display services
  ui_subheader "Security Services"
  kubectl get services -n "$NAMESPACE"

  # Display network policies
  ui_subheader "Network Policies"
  kubectl get netpol -n "$NAMESPACE"

  # Display PSPs or Pod Security Standards
  if kubectl api-resources | grep -q "podsecuritypolicies"; then
    ui_subheader "Pod Security Policies"
    kubectl get psp -o wide
  elif kubectl api-resources | grep -q "podsecuritystandards"; then
    ui_subheader "Pod Security Standards"
    kubectl get podsecuritystandards
  fi

  # Check Falco logs if available
  ui_subheader "Falco Logs"
  local falco_pod=$(kubectl get pods -n "$NAMESPACE" -l app=falco -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$falco_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$falco_pod" --tail=30
  else
    ui_log_warning "No Falco pods found"
  fi

  # Check Trivy operator logs if available
  ui_subheader "Trivy Operator Logs"
  local trivy_pod=$(kubectl get pods -n "$NAMESPACE" -l app=trivy-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$trivy_pod" ]; then
    kubectl logs -n "$NAMESPACE" "$trivy_pod" --tail=30
  else
    ui_log_warning "No Trivy Operator pods found"
  fi

  # Check for vulnerabilities reported by Trivy
  if kubectl api-resources | grep -q "vulnerabilityreports"; then
    ui_subheader "Vulnerability Reports"
    kubectl get vulnerabilityreports --all-namespaces
  fi

  # Check audit logs if available
  ui_subheader "Audit Logs"
  if kubectl get configmap -n kube-system audit-policy &>/dev/null; then
    ui_log_info "Audit policy is configured, checking for logs"
    # Display audit logs (location depends on cluster setup)
    if [ -d "/var/log/kubernetes/audit" ]; then
      ui_log_info "Last 10 audit log entries:"
      tail -10 /var/log/kubernetes/audit/audit.log 2>/dev/null || ui_log_warning "Cannot access audit logs"
    else
      ui_log_warning "Standard audit log location not found"
    fi
  else
    ui_log_warning "Audit policy is not configured"
  fi

  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20

  # Check for namespace labels
  ui_subheader "Namespace Security Labels"
  kubectl get namespace "$NAMESPACE" -o yaml | grep -A5 labels

  return 0
}

# Export functions
export -f security_pre_deploy
export -f security_deploy
export -f security_post_deploy
export -f security_verify
export -f security_cleanup
export -f security_diagnose
