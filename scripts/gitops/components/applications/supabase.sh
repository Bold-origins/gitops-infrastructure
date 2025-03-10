#!/bin/bash
# supabase.sh: Supabase Component Functions
# Handles all operations for Supabase - open-source Firebase alternative with PostgreSQL

# Source shared libraries
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="${SCRIPT_DIR}/../../../../"
source "${SCRIPT_DIR}/../../../lib/ui.sh"

# Component-specific configuration
COMPONENT_NAME="supabase"
NAMESPACE="supabase"
COMPONENT_DEPENDENCIES=("cert-manager" "ingress-nginx")  # Optional dependencies for ingress and certificates
RESOURCE_TYPES=("deployment" "service" "configmap" "secret" "statefulset" "persistentvolumeclaim" "ingress")

# Pre-deployment function - runs before deployment
supabase_pre_deploy() {
  ui_log_info "Running Supabase pre-deployment checks"
  
  # Create namespace if needed
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  
  # Check if Helm is installed
  if ! command -v helm &>/dev/null; then
    ui_log_error "Helm is not installed but required for Supabase"
    return 1
  fi
  
  # Add Helm repositories if needed
  if ! helm repo list | grep -q "bitnami"; then
    ui_log_info "Adding Bitnami Helm repository for PostgreSQL"
    helm repo add bitnami https://charts.bitnami.com/bitnami
  fi
  
  # Update Helm repos
  ui_log_info "Updating Helm repositories"
  helm repo update
  
  # Check dependencies
  local missing_deps=()
  
  # Check if ingress-nginx is installed if it is a dependency
  if [[ " ${COMPONENT_DEPENDENCIES[*]} " =~ " ingress-nginx " ]]; then
    if ! kubectl get namespace ingress-nginx &>/dev/null; then
      ui_log_warning "Dependency ingress-nginx not found. You may need to install it first."
      missing_deps+=("ingress-nginx")
    fi
  fi
  
  # Check if cert-manager is installed if it is a dependency
  if [[ " ${COMPONENT_DEPENDENCIES[*]} " =~ " cert-manager " ]]; then
    if ! kubectl get namespace cert-manager &>/dev/null; then
      ui_log_warning "Dependency cert-manager not found. You may need to install it first."
      missing_deps+=("cert-manager")
    fi
  fi
  
  # Warn about missing dependencies
  if [ ${#missing_deps[@]} -gt 0 ]; then
    ui_log_warning "Some dependencies are missing: ${missing_deps[*]}"
    ui_log_warning "You can proceed, but some features may not work correctly."
    
    # Ask for confirmation if in interactive mode
    if [ -t 0 ] && [ -t 1 ]; then
      read -p "Continue anyway? [y/N] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        ui_log_info "Deployment aborted. Please install the missing dependencies first."
        return 1
      fi
    fi
  fi
  
  # Check cluster storage capability
  if ! kubectl get storageclass &>/dev/null; then
    ui_log_error "No StorageClass found in the cluster. Supabase requires persistent storage."
    ui_log_info "Please set up a StorageClass for your cluster first."
    return 1
  fi
  
  # Create the custom values file directory if it doesn't exist
  local values_dir="${BASE_DIR}/clusters/local/applications/supabase/helm"
  if [ ! -d "$values_dir" ]; then
    ui_log_info "Creating Helm values directory: $values_dir"
    mkdir -p "$values_dir"
  fi
  
  # Create a default values file if it doesn't exist
  local values_file="$values_dir/values.yaml"
  if [ ! -f "$values_file" ]; then
    ui_log_info "Creating default Helm values file for Supabase"
    cat > "$values_file" <<EOF
# Default Helm values for Supabase
global:
  storageClass: ""  # Use cluster default

# Postgres configuration
postgresql:
  auth:
    postgresPassword: postgres  # Change this in production
    database: postgres
  primary:
    persistence:
      size: 8Gi
  metrics:
    enabled: true

# Supabase services configuration
# Common settings for all services
services:
  apiGateway:
    enabled: true
    replicaCount: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    service:
      type: ClusterIP
  auth:
    enabled: true
    replicaCount: 1
    jwt:
      anon:
        # Generate with: openssl rand -base64 32
        secret: ""
      service:
        # Generate with: openssl rand -base64 32
        secret: ""
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    service:
      type: ClusterIP
  realtime:
    enabled: true
    replicaCount: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    service:
      type: ClusterIP
  storage:
    enabled: true
    replicaCount: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    service:
      type: ClusterIP
  studio:
    enabled: true
    replicaCount: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
    service:
      type: ClusterIP

# Ingress configuration
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: supabase.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: supabase-tls
      hosts:
        - supabase.example.com
EOF
  fi
  
  # Generate JWT secrets for auth service if not already set
  if grep -q 'secret: ""' "$values_file"; then
    ui_log_info "Generating JWT secrets for Supabase Auth"
    local anon_jwt_secret=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
    local service_jwt_secret=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
    
    # Update the values file with the generated secrets
    sed -i.bak "s/anon:\n        secret: \"\"/anon:\n        secret: \"$anon_jwt_secret\"/g" "$values_file"
    sed -i.bak "s/service:\n        secret: \"\"/service:\n        secret: \"$service_jwt_secret\"/g" "$values_file"
    rm -f "$values_file.bak"
    
    ui_log_success "JWT secrets generated and updated in the values file"
  fi
  
  return 0
}

# Deploy function - deploys the component
supabase_deploy() {
  local deploy_mode="${1:-flux}"
  
  ui_log_info "Deploying Supabase using $deploy_mode mode"
  
  case "$deploy_mode" in
    flux)
      # Deploy using Flux
      ui_log_info "Applying Flux kustomization for Supabase"
      kubectl apply -f "${BASE_DIR}/clusters/local/applications/supabase/kustomization.yaml"
      ;;
    
    kubectl)
      # Direct kubectl apply
      ui_log_info "Applying Supabase manifests directly with kubectl"
      kubectl apply -k "${BASE_DIR}/clusters/local/applications/supabase"
      ;;
    
    helm)
      # Helm-based installation
      ui_log_info "Deploying Supabase with Helm"
      
      # Check if already installed via Helm
      if helm list -n "$NAMESPACE" | grep -q "supabase-postgres"; then
        ui_log_info "PostgreSQL for Supabase is already installed via Helm"
      else
        # Install PostgreSQL using Bitnami chart
        ui_log_info "Installing PostgreSQL for Supabase"
        helm install supabase-postgres bitnami/postgresql \
          --namespace "$NAMESPACE" \
          --values "${BASE_DIR}/clusters/local/applications/supabase/helm/values.yaml" \
          --set serviceAccount.create=true \
          --set persistence.enabled=true
      fi
      
      # Wait for PostgreSQL to be ready
      ui_log_info "Waiting for PostgreSQL to be ready"
      kubectl rollout status statefulset supabase-postgres-postgresql -n "$NAMESPACE" --timeout=300s
      
      # Install Supabase Services
      local SUPABASE_SERVICES=("api-gateway" "auth" "realtime" "storage" "studio")
      
      for service in "${SUPABASE_SERVICES[@]}"; do
        if helm list -n "$NAMESPACE" | grep -q "supabase-$service"; then
          ui_log_info "Supabase $service is already installed, upgrading if needed"
          helm upgrade supabase-$service "${BASE_DIR}/clusters/local/applications/supabase/helm/charts/$service" \
            --namespace "$NAMESPACE" \
            --values "${BASE_DIR}/clusters/local/applications/supabase/helm/values.yaml"
        else
          ui_log_info "Installing Supabase $service"
          # First check if the chart exists
          if [ -d "${BASE_DIR}/clusters/local/applications/supabase/helm/charts/$service" ]; then
            helm install supabase-$service "${BASE_DIR}/clusters/local/applications/supabase/helm/charts/$service" \
              --namespace "$NAMESPACE" \
              --values "${BASE_DIR}/clusters/local/applications/supabase/helm/values.yaml"
          else
            ui_log_warning "Chart for $service not found. This is expected if you're using a bundled chart."
          fi
        fi
      done
      
      # Alternative: Use the bundled supabase chart if available
      if [ -d "${BASE_DIR}/clusters/local/applications/supabase/helm/charts/supabase" ]; then
        ui_log_info "Installing Supabase using bundled chart"
        if helm list -n "$NAMESPACE" | grep -q "supabase"; then
          ui_log_info "Supabase is already installed, upgrading"
          helm upgrade supabase "${BASE_DIR}/clusters/local/applications/supabase/helm/charts/supabase" \
            --namespace "$NAMESPACE" \
            --values "${BASE_DIR}/clusters/local/applications/supabase/helm/values.yaml"
        else
          helm install supabase "${BASE_DIR}/clusters/local/applications/supabase/helm/charts/supabase" \
            --namespace "$NAMESPACE" \
            --values "${BASE_DIR}/clusters/local/applications/supabase/helm/values.yaml"
        fi
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
supabase_post_deploy() {
  ui_log_info "Running Supabase post-deployment tasks"
  
  # Wait for deployments to be ready
  local SUPABASE_SERVICES=("api-gateway" "auth" "realtime" "storage" "studio")
  for service in "${SUPABASE_SERVICES[@]}"; do
    if kubectl get deployment -n "$NAMESPACE" | grep -q "$service"; then
      ui_log_info "Waiting for $service deployment to be ready"
      kubectl rollout status deployment -n "$NAMESPACE" -l app.kubernetes.io/name="$service" --timeout=300s
    fi
  done
  
  # Check if ingress is enabled and set up properly
  if kubectl get ingress -n "$NAMESPACE" 2>/dev/null | grep -q supabase; then
    ui_log_info "Supabase ingress found, checking configuration"
    local host=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}')
    
    if [ -n "$host" ]; then
      ui_log_success "Supabase is configured to be accessible at: https://$host"
    else
      ui_log_warning "Supabase ingress doesn't have a host configured"
    fi
  else
    ui_log_info "No ingress found for Supabase. If you want external access, consider setting up an ingress."
  fi
  
  # Check if there's a PostgreSQL database and it's ready
  if kubectl get statefulset -n "$NAMESPACE" | grep -q postgres; then
    ui_log_info "PostgreSQL statefulset found, checking status"
    local postgres_ready=$(kubectl get statefulset -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].status.readyReplicas}')
    
    if [ "$postgres_ready" -gt 0 ]; then
      ui_log_success "PostgreSQL is ready with $postgres_ready replicas"
      
      # Get PostgreSQL credentials from secret
      local postgres_secret=$(kubectl get secret -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')
      if [ -n "$postgres_secret" ]; then
        local postgres_user=$(kubectl get secret -n "$NAMESPACE" "$postgres_secret" -o jsonpath='{.data.postgres-user}' | base64 --decode)
        local postgres_password=$(kubectl get secret -n "$NAMESPACE" "$postgres_secret" -o jsonpath='{.data.postgres-password}' | base64 --decode)
        local postgres_database=$(kubectl get secret -n "$NAMESPACE" "$postgres_secret" -o jsonpath='{.data.postgres-database}' | base64 --decode)
        
        ui_log_info "PostgreSQL connection details:"
        ui_log_info "  Host: supabase-postgres-postgresql.$NAMESPACE.svc.cluster.local"
        ui_log_info "  User: $postgres_user"
        ui_log_info "  Password: [redacted]"
        ui_log_info "  Database: $postgres_database"
        ui_log_info "To connect to PostgreSQL from inside the cluster:"
        ui_log_info "  postgresql://$postgres_user:PASSWORD@supabase-postgres-postgresql.$NAMESPACE.svc.cluster.local:5432/$postgres_database"
      fi
    else
      ui_log_warning "PostgreSQL is not ready yet"
    fi
  fi
  
  # Configure Auth service if needed
  if kubectl get deployment -n "$NAMESPACE" | grep -q auth; then
    ui_log_info "Checking Auth service configuration"
    
    # Check if site URL is configured
    if kubectl get secret -n "$NAMESPACE" supabase-auth-config 2>/dev/null; then
      ui_log_success "Auth service is configured"
    else
      # Create default config
      local ingress_host=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null)
      local site_url="http://localhost:3000"
      
      if [ -n "$ingress_host" ]; then
        site_url="https://$ingress_host"
      fi
      
      ui_log_info "Setting up default Auth configuration with site URL: $site_url"
      kubectl create secret generic supabase-auth-config -n "$NAMESPACE" \
        --from-literal=SITE_URL="$site_url" \
        --from-literal=ADDITIONAL_REDIRECT_URLS="$site_url" \
        --dry-run=client -o yaml | kubectl apply -f -
    fi
  fi
  
  # Print helpful information
  ui_log_info "Supabase services are being deployed."
  ui_log_info "You can access the studio UI at: https://<your-ingress-host>"
  ui_log_info "Use the following command to port-forward the studio UI if you don't have an ingress:"
  ui_log_info "  kubectl port-forward -n $NAMESPACE svc/supabase-studio 3000:8080"
  ui_log_info "Then access it at: http://localhost:3000"
  
  return 0
}

# Verification function - verifies the component is working
supabase_verify() {
  ui_log_info "Verifying Supabase installation"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Verify PostgreSQL
  ui_log_info "Checking PostgreSQL status"
  if kubectl get statefulset -n "$NAMESPACE" | grep -q postgres; then
    local postgres_ready=$(kubectl get statefulset -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].status.readyReplicas}')
    local postgres_replicas=$(kubectl get statefulset -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].spec.replicas}')
    
    if [ "$postgres_ready" -eq "$postgres_replicas" ]; then
      ui_log_success "PostgreSQL is running with $postgres_ready/$postgres_replicas ready replicas"
    else
      ui_log_error "PostgreSQL is not fully ready: $postgres_ready/$postgres_replicas replicas are ready"
      return 1
    fi
    
    # Test PostgreSQL connection
    ui_log_info "Testing PostgreSQL connection"
    local postgres_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$postgres_pod" ]; then
      if kubectl exec -n "$NAMESPACE" "$postgres_pod" -- pg_isready -h localhost; then
        ui_log_success "PostgreSQL is accepting connections"
      else
        ui_log_error "PostgreSQL is not accepting connections"
        return 1
      fi
    fi
  else
    ui_log_error "PostgreSQL statefulset not found"
    return 1
  fi
  
  # Check Supabase services
  local SUPABASE_SERVICES=("api-gateway" "auth" "realtime" "storage" "studio")
  local all_services_ready=true
  
  for service in "${SUPABASE_SERVICES[@]}"; do
    ui_log_info "Checking $service service"
    
    # Check if service exists
    if kubectl get deployment -n "$NAMESPACE" | grep -q "$service"; then
      local ready_replicas=$(kubectl get deployment -n "$NAMESPACE" -l app.kubernetes.io/name="$service" -o jsonpath='{.items[0].status.readyReplicas}')
      local desired_replicas=$(kubectl get deployment -n "$NAMESPACE" -l app.kubernetes.io/name="$service" -o jsonpath='{.items[0].spec.replicas}')
      
      if [ "$ready_replicas" -eq "$desired_replicas" ]; then
        ui_log_success "$service is running with $ready_replicas/$desired_replicas ready replicas"
      else
        ui_log_warning "$service is not fully ready: $ready_replicas/$desired_replicas replicas are ready"
        all_services_ready=false
      fi
    else
      ui_log_warning "$service deployment not found"
      all_services_ready=false
    fi
    
    # Check if service is exposed
    if kubectl get service -n "$NAMESPACE" | grep -q "$service"; then
      ui_log_success "$service service exists"
    else
      ui_log_warning "$service service not found"
      all_services_ready=false
    fi
  done
  
  # Check ingress
  ui_log_info "Checking ingress"
  if kubectl get ingress -n "$NAMESPACE" 2>/dev/null | grep -q supabase; then
    local ingress_host=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}')
    ui_log_success "Ingress is configured with host: $ingress_host"
    
    # Check TLS
    if kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.tls}' | grep -q secretName; then
      ui_log_success "TLS is configured for the ingress"
    else
      ui_log_warning "TLS is not configured for the ingress"
    fi
  else
    ui_log_warning "No ingress found for Supabase"
  fi
  
  if [ "$all_services_ready" = true ]; then
    ui_log_success "All Supabase services are running"
  else
    ui_log_warning "Some Supabase services are not fully ready"
  fi
  
  # Print access information
  ui_log_info "Supabase should be accessible via:"
  
  if kubectl get ingress -n "$NAMESPACE" 2>/dev/null | grep -q supabase; then
    local ingress_host=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}')
    ui_log_info "- Browser: https://$ingress_host"
  else
    ui_log_info "- Port-forward: kubectl port-forward -n $NAMESPACE svc/supabase-studio 3000:8080"
    ui_log_info "  Then access: http://localhost:3000"
  fi
  
  ui_log_success "Supabase verification completed"
  return 0
}

# Cleanup function - removes the component
supabase_cleanup() {
  ui_log_info "Cleaning up Supabase"
  
  # Ask for confirmation if in interactive mode
  if [ -t 0 ] && [ -t 1 ]; then
    ui_log_warning "This will delete all Supabase components including the database and its data"
    read -p "Are you sure you want to proceed? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      ui_log_info "Cleanup aborted"
      return 0
    fi
  fi
  
  # Check if Helm releases exist and remove them
  if helm list -n "$NAMESPACE" | grep -q supabase; then
    ui_log_info "Uninstalling Supabase Helm releases"
    helm uninstall supabase -n "$NAMESPACE" || true
    
    local SUPABASE_SERVICES=("api-gateway" "auth" "realtime" "storage" "studio")
    for service in "${SUPABASE_SERVICES[@]}"; do
      if helm list -n "$NAMESPACE" | grep -q "supabase-$service"; then
        ui_log_info "Uninstalling supabase-$service Helm release"
        helm uninstall "supabase-$service" -n "$NAMESPACE" || true
      fi
    done
    
    if helm list -n "$NAMESPACE" | grep -q "supabase-postgres"; then
      ui_log_info "Uninstalling supabase-postgres Helm release"
      helm uninstall "supabase-postgres" -n "$NAMESPACE" || true
    fi
  else
    # Remove with kubectl if not installed with Helm
    ui_log_info "Removing Supabase resources with kubectl"
    
    # Delete all deployments
    kubectl delete deployment -n "$NAMESPACE" -l app.kubernetes.io/part-of=supabase --ignore-not-found
    
    # Delete all services
    kubectl delete service -n "$NAMESPACE" -l app.kubernetes.io/part-of=supabase --ignore-not-found
    
    # Delete all configmaps
    kubectl delete configmap -n "$NAMESPACE" -l app.kubernetes.io/part-of=supabase --ignore-not-found
    
    # Delete all secrets
    kubectl delete secret -n "$NAMESPACE" -l app.kubernetes.io/part-of=supabase --ignore-not-found
    
    # Delete statefulsets
    kubectl delete statefulset -n "$NAMESPACE" -l app.kubernetes.io/part-of=supabase --ignore-not-found
    
    # Delete ingress
    kubectl delete ingress -n "$NAMESPACE" --all --ignore-not-found
  fi
  
  # Delete PVCs
  ui_log_info "Removing persistent volume claims"
  kubectl delete pvc -n "$NAMESPACE" --all
  
  # Delete namespace if empty
  local resources=$(kubectl get all -n "$NAMESPACE" -o name)
  if [ -z "$resources" ]; then
    ui_log_info "Namespace is empty, deleting it"
    kubectl delete namespace "$NAMESPACE"
  else
    ui_log_warning "Namespace still has resources, not deleting it"
  fi
  
  # Delete flux kustomization if present
  kubectl delete -f "${BASE_DIR}/clusters/local/applications/supabase/kustomization.yaml" --ignore-not-found
  
  ui_log_success "Supabase cleanup completed"
  return 0
}

# Diagnose function - provides detailed diagnostics
supabase_diagnose() {
  ui_log_info "Running Supabase diagnostics"
  
  # Check if namespace exists
  if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    ui_log_error "Namespace $NAMESPACE does not exist"
    return 1
  fi
  
  # Display resource status
  ui_subheader "Pods Status"
  kubectl get pods -n "$NAMESPACE" -o wide
  
  ui_subheader "Deployments"
  kubectl get deployments -n "$NAMESPACE"
  
  ui_subheader "StatefulSets"
  kubectl get statefulsets -n "$NAMESPACE"
  
  ui_subheader "Services"
  kubectl get services -n "$NAMESPACE"
  
  ui_subheader "Ingress"
  kubectl get ingress -n "$NAMESPACE"
  
  ui_subheader "ConfigMaps"
  kubectl get configmaps -n "$NAMESPACE"
  
  ui_subheader "Secrets"
  kubectl get secrets -n "$NAMESPACE" | grep -v "token\|tls\|registry"
  
  ui_subheader "Persistent Volume Claims"
  kubectl get pvc -n "$NAMESPACE"
  
  # Check PostgreSQL details
  ui_subheader "PostgreSQL Status"
  local postgres_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$postgres_pod" ]; then
    ui_log_info "PostgreSQL Pod Information:"
    kubectl describe pod -n "$NAMESPACE" "$postgres_pod"
    
    ui_log_info "PostgreSQL Readiness Check:"
    kubectl exec -n "$NAMESPACE" "$postgres_pod" -- pg_isready -h localhost || echo "PostgreSQL is not ready"
    
    ui_log_info "PostgreSQL Logs:"
    kubectl logs -n "$NAMESPACE" "$postgres_pod" --tail=50
  else
    ui_log_warning "No PostgreSQL pod found"
  fi
  
  # Check each Supabase service
  local SUPABASE_SERVICES=("api-gateway" "auth" "realtime" "storage" "studio")
  for service in "${SUPABASE_SERVICES[@]}"; do
    ui_subheader "$service Status"
    local service_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$service_pod" ]; then
      ui_log_info "$service Pod Information:"
      kubectl describe pod -n "$NAMESPACE" "$service_pod"
      
      ui_log_info "$service Logs:"
      kubectl logs -n "$NAMESPACE" "$service_pod" --tail=30
    else
      ui_log_warning "No $service pod found"
    fi
  done
  
  # Check connectivity between services
  ui_subheader "Internal Service Connectivity"
  local test_pod=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$test_pod" ]; then
    for service in "${SUPABASE_SERVICES[@]}"; do
      if kubectl get service -n "$NAMESPACE" | grep -q "$service"; then
        local service_host="supabase-$service.$NAMESPACE.svc.cluster.local"
        ui_log_info "Testing connectivity to $service:"
        kubectl exec -n "$NAMESPACE" "$test_pod" -- wget -q --spider --timeout=5 "$service_host" 2>/dev/null && \
          ui_log_success "Connection to $service successful" || \
          ui_log_warning "Failed to connect to $service"
      fi
    done
  fi
  
  # Check ingress configuration
  if kubectl get ingress -n "$NAMESPACE" 2>/dev/null | grep -q supabase; then
    ui_subheader "Ingress Configuration"
    kubectl describe ingress -n "$NAMESPACE"
    
    local ingress_host=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}')
    ui_log_info "Ingress host: $ingress_host"
    
    # Check TLS secret if configured
    local tls_secret=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.tls[0].secretName}' 2>/dev/null)
    if [ -n "$tls_secret" ]; then
      ui_log_info "TLS configured with secret: $tls_secret"
      kubectl describe secret -n "$NAMESPACE" "$tls_secret"
    else
      ui_log_warning "No TLS configured for the ingress"
    fi
  fi
  
  # Check events
  ui_subheader "Recent Events"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -30
  
  ui_log_success "Supabase diagnostics completed"
  return 0
}

# Export functions
export -f supabase_pre_deploy
export -f supabase_deploy
export -f supabase_post_deploy
export -f supabase_verify
export -f supabase_cleanup
export -f supabase_diagnose 