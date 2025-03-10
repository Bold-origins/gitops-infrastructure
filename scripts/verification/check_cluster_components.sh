#!/bin/bash
# check_cluster_components.sh: Comprehensive verification for GitOps components
# This script checks the status of all deployed components in the local cluster
# It verifies that components are running properly and identifies any issues

# Colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to print section headers
print_header() {
  echo -e "\n${BOLD}${BLUE}==== $1 ====${NC}"
}

# Function to print section subheaders
print_subheader() {
  echo -e "\n${BOLD}${BLUE}--- $1 ---${NC}"
}

# Function to check status with colored output
check_status() {
  if [ "$1" == "OK" ]; then
    echo -e "${GREEN}✓ $2${NC}"
  elif [ "$1" == "WARNING" ]; then
    echo -e "${YELLOW}⚠ $2${NC}"
  else
    echo -e "${RED}✗ $2${NC}"
  fi
}

# Check if a namespace exists
check_namespace() {
  local namespace=$1
  if kubectl get namespace "$namespace" &>/dev/null; then
    check_status "OK" "Namespace $namespace exists"
    return 0
  else
    check_status "ERROR" "Namespace $namespace does not exist"
    return 1
  fi
}

# Check if a deployment exists and is ready
check_deployment() {
  local namespace=$1
  local deployment=$2
  local min_ready=${3:-1}

  if ! kubectl get deployment -n "$namespace" "$deployment" &>/dev/null; then
    check_status "ERROR" "Deployment $deployment in namespace $namespace not found"
    return 1
  fi
  
  local ready=$(kubectl get deployment -n "$namespace" "$deployment" -o jsonpath='{.status.readyReplicas}')
  if [ -z "$ready" ]; then ready=0; fi
  
  if [ "$ready" -ge "$min_ready" ]; then
    check_status "OK" "Deployment $deployment in namespace $namespace has $ready ready replicas"
    return 0
  else
    check_status "ERROR" "Deployment $deployment in namespace $namespace has only $ready ready replicas (expected at least $min_ready)"
    return 1
  fi
}

# Check if a pod exists and is running
check_pod_status() {
  local namespace=$1
  local label=$2
  
  local pods=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].status.phase}')
  if [ -z "$pods" ]; then
    check_status "ERROR" "No pods found in namespace $namespace with label $label"
    return 1
  fi
  
  if [[ "$pods" == *"Running"* ]]; then
    check_status "OK" "Pods with label $label in namespace $namespace are running"
    kubectl get pods -n "$namespace" -l "$label"
    return 0
  else
    check_status "ERROR" "Pods with label $label in namespace $namespace are not all running"
    kubectl get pods -n "$namespace" -l "$label"
    return 1
  fi
}

# Check if a CRD exists
check_crd() {
  local crd=$1
  if kubectl get crd "$crd" &>/dev/null; then
    check_status "OK" "CRD $crd exists"
    return 0
  else
    check_status "ERROR" "CRD $crd does not exist"
    return 1
  fi
}

# Check if a Helm release exists
check_helm_release() {
  local namespace=$1
  local release=$2
  if helm list -n "$namespace" | grep -q "$release"; then
    check_status "OK" "Helm release $release in namespace $namespace exists"
    return 0
  else
    check_status "ERROR" "Helm release $release in namespace $namespace does not exist"
    return 1
  fi
}

# Check if a service exists
check_service() {
  local namespace=$1
  local service=$2
  
  if kubectl get service -n "$namespace" "$service" &>/dev/null; then
    check_status "OK" "Service $service in namespace $namespace exists"
    return 0
  else
    check_status "ERROR" "Service $service in namespace $namespace not found"
    return 1
  fi
}

# Check if an ingress exists
check_ingress() {
  local namespace=$1
  local ingress=$2
  
  if kubectl get ingress -n "$namespace" "$ingress" &>/dev/null; then
    local host=$(kubectl get ingress -n "$namespace" "$ingress" -o jsonpath='{.spec.rules[0].host}')
    check_status "OK" "Ingress $ingress in namespace $namespace exists (host: $host)"
    return 0
  else
    check_status "ERROR" "Ingress $ingress in namespace $namespace not found"
    return 1
  fi
}

#===============================================================================
# INFRASTRUCTURE COMPONENTS
#===============================================================================

# Check cert-manager component
check_cert_manager() {
  print_header "Checking cert-manager Component"
  
  # Check namespace
  check_namespace "cert-manager" || return 1
  
  # Check deployments
  check_deployment "cert-manager" "cert-manager" || return 1
  check_deployment "cert-manager" "cert-manager-webhook" || return 1
  check_deployment "cert-manager" "cert-manager-cainjector" || return 1
  
  # Check pods
  check_pod_status "cert-manager" "app=cert-manager" || return 1
  
  # Check CRDs
  check_crd "certificates.cert-manager.io" || return 1
  check_crd "issuers.cert-manager.io" || return 1
  check_crd "clusterissuers.cert-manager.io" || return 1
  
  print_subheader "Checking for ClusterIssuers"
  kubectl get clusterissuers

  print_subheader "Checking for Certificates"
  kubectl get certificates --all-namespaces
  
  echo -e "\n${GREEN}${BOLD}✓ cert-manager is properly installed and running${NC}"
  return 0
}

# Check sealed-secrets component
check_sealed_secrets() {
  print_header "Checking sealed-secrets Component"
  
  # Check namespace
  check_namespace "sealed-secrets" || return 1
  
  # Check controller deployment
  check_deployment "sealed-secrets" "sealed-secrets-controller" || return 1
  
  # Check pods
  check_pod_status "sealed-secrets" "app.kubernetes.io/name=sealed-secrets" || return 1
  
  # Check CRD
  check_crd "sealedsecrets.bitnami.com" || return 1
  
  print_subheader "Checking for SealedSecrets"
  kubectl get sealedsecrets --all-namespaces
  
  echo -e "\n${GREEN}${BOLD}✓ sealed-secrets is properly installed and running${NC}"
  return 0
}

# Check ingress-nginx component
check_ingress_nginx() {
  print_header "Checking ingress-nginx Component"
  
  # Check namespace
  check_namespace "ingress-nginx" || return 1
  
  # Check controller deployment
  check_deployment "ingress-nginx" "ingress-nginx-controller" || return 1
  
  # Check pods
  check_pod_status "ingress-nginx" "app.kubernetes.io/component=controller" || return 1
  
  # Check services
  check_service "ingress-nginx" "ingress-nginx-controller" || return 1
  
  print_subheader "Checking for Ingresses"
  kubectl get ingress --all-namespaces
  
  echo -e "\n${GREEN}${BOLD}✓ ingress-nginx is properly installed and running${NC}"
  return 0
}

# Check metallb component if installed
check_metallb() {
  print_header "Checking MetalLB Component"
  
  # Check namespace
  if ! check_namespace "metallb-system"; then
    check_status "WARNING" "MetalLB is not installed (this may be expected in some environments)"
    return 0
  fi
  
  # Check controller deployment
  check_deployment "metallb-system" "controller" || return 1
  
  # Check speaker daemonset
  local speaker_pods=$(kubectl get pods -n metallb-system -l app=metallb,component=speaker -o jsonpath='{.items[*].status.phase}')
  if [[ -z "$speaker_pods" || "$speaker_pods" != *"Running"* ]]; then
    check_status "ERROR" "MetalLB speaker pods are not running"
    kubectl get pods -n metallb-system -l app=metallb,component=speaker
    return 1
  else
    check_status "OK" "MetalLB speaker pods are running"
    kubectl get pods -n metallb-system -l app=metallb,component=speaker
  fi
  
  print_subheader "Checking for MetalLB IPAddressPools"
  kubectl get ipaddresspools -A
  
  print_subheader "Checking for MetalLB L2Advertisements"
  kubectl get l2advertisements -A
  
  echo -e "\n${GREEN}${BOLD}✓ MetalLB is properly installed and running${NC}"
  return 0
}

# Check vault component if installed
check_vault() {
  print_header "Checking Vault Component"
  
  # Check namespace
  if ! check_namespace "vault"; then
    check_status "WARNING" "Vault is not installed (this may be expected in some environments)"
    return 0
  fi
  
  # Check deployments
  check_deployment "vault" "vault" || return 1
  
  # Check pods
  check_pod_status "vault" "app.kubernetes.io/name=vault" || return 1
  
  # Check services
  check_service "vault" "vault" || return 1
  
  echo -e "\n${GREEN}${BOLD}✓ Vault is properly installed and running${NC}"
  return 0
}

# Check minio component if installed
check_minio() {
  print_header "Checking MinIO Component"
  
  # Check namespace
  if ! check_namespace "minio"; then
    check_status "WARNING" "MinIO is not installed (this may be expected in some environments)"
    return 0
  fi
  
  # Check deployments
  check_deployment "minio" "minio" || return 1
  
  # Check pods
  check_pod_status "minio" "app=minio" || return 1
  
  # Check services
  check_service "minio" "minio" || return 1
  
  # Check for MinIO Client job or pod
  local mc_pod=$(kubectl get pods -n minio -l app=minio-mc -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$mc_pod" ]; then
    check_status "OK" "MinIO Client pod exists: $mc_pod"
  else
    check_status "WARNING" "No MinIO Client pod found"
  fi
  
  echo -e "\n${GREEN}${BOLD}✓ MinIO is properly installed and running${NC}"
  return 0
}

# Check policy-engine component if installed
check_policy_engine() {
  print_header "Checking Policy Engine Component"
  
  # Detect which policy engine is installed (Kyverno or OPA/Gatekeeper)
  if check_namespace "kyverno"; then
    print_subheader "Kyverno Policy Engine detected"
    
    # Check deployments
    check_deployment "kyverno" "kyverno" || return 1
    
    # Check pods
    check_pod_status "kyverno" "app.kubernetes.io/name=kyverno" || return 1
    
    # Check CRDs
    check_crd "policies.kyverno.io" || return 1
    check_crd "clusterpolicies.kyverno.io" || return 1
    
    print_subheader "Checking for Kyverno Policies"
    kubectl get clusterpolicies
    
    echo -e "\n${GREEN}${BOLD}✓ Kyverno Policy Engine is properly installed and running${NC}"
    return 0
    
  elif check_namespace "gatekeeper-system"; then
    print_subheader "OPA/Gatekeeper Policy Engine detected"
    
    # Check deployments
    check_deployment "gatekeeper-system" "gatekeeper-controller-manager" || return 1
    
    # Check pods
    check_pod_status "gatekeeper-system" "control-plane=controller-manager" || return 1
    
    # Check CRDs
    check_crd "constraints.gatekeeper.sh" || return 1
    check_crd "constrainttemplates.gatekeeper.sh" || return 1
    
    print_subheader "Checking for Gatekeeper ConstraintTemplates"
    kubectl get constrainttemplates
    
    print_subheader "Checking for Gatekeeper Constraints"
    kubectl get constraints --all-namespaces
    
    echo -e "\n${GREEN}${BOLD}✓ OPA/Gatekeeper Policy Engine is properly installed and running${NC}"
    return 0
    
  else
    check_status "WARNING" "No Policy Engine (Kyverno or OPA/Gatekeeper) installed"
    return 0
  fi
}

#===============================================================================
# OBSERVABILITY COMPONENTS
#===============================================================================

# Check prometheus component if installed
check_prometheus() {
  print_header "Checking Prometheus Component"
  
  # Check namespace
  if ! check_namespace "monitoring"; then
    check_status "WARNING" "Prometheus is not installed (this may be expected in some environments)"
    return 0
  fi
  
  # Check deployments
  check_deployment "monitoring" "prometheus-server" && \
  check_status "OK" "Prometheus server deployment found" || \
  check_status "WARNING" "Prometheus server deployment not found"
  
  # Check pods
  kubectl get pods -n monitoring -l "app=prometheus" && \
  check_status "OK" "Prometheus pods found" || \
  check_status "WARNING" "No Prometheus pods found"
  
  # Check services
  check_service "monitoring" "prometheus-server" && \
  check_status "OK" "Prometheus server service found" || \
  check_status "WARNING" "Prometheus server service not found"
  
  # Check for Prometheus operator if installed
  if kubectl get deployment -n monitoring -l "app.kubernetes.io/name=prometheus-operator" &>/dev/null; then
    check_status "OK" "Prometheus Operator found"
    
    # Check CRDs
    check_crd "prometheuses.monitoring.coreos.com" && \
    check_crd "servicemonitors.monitoring.coreos.com" && \
    check_crd "podmonitors.monitoring.coreos.com" && \
    check_crd "alertmanagers.monitoring.coreos.com" && \
    check_status "OK" "Prometheus Operator CRDs found" || \
    check_status "WARNING" "Some Prometheus Operator CRDs are missing"
  fi
  
  echo -e "\n${GREEN}${BOLD}✓ Prometheus check completed${NC}"
  return 0
}

# Check loki component if installed
check_loki() {
  print_header "Checking Loki Component"
  
  # Check namespace (typically in monitoring)
  if ! check_namespace "monitoring"; then
    check_status "WARNING" "Loki is not installed (this may be expected in some environments)"
    return 0
  fi
  
  # Check deployments
  check_deployment "monitoring" "loki" && \
  check_status "OK" "Loki deployment found" || \
  check_status "WARNING" "Loki deployment not found"
  
  # Check pods
  kubectl get pods -n monitoring -l "app=loki" &>/dev/null && \
  check_status "OK" "Loki pods found" || \
  check_status "WARNING" "No Loki pods found"
  
  # Check services
  check_service "monitoring" "loki" && \
  check_status "OK" "Loki service found" || \
  check_status "WARNING" "Loki service not found"
  
  # Check for Promtail (Loki agent) if installed
  if kubectl get daemonset -n monitoring -l "app=promtail" &>/dev/null; then
    check_status "OK" "Promtail daemonset found"
    kubectl get pods -n monitoring -l "app=promtail"
  else
    check_status "WARNING" "Promtail daemonset not found (log collection may not be working)"
  fi
  
  echo -e "\n${GREEN}${BOLD}✓ Loki check completed${NC}"
  return 0
}

# Check grafana component if installed
check_grafana() {
  print_header "Checking Grafana Component"
  
  # Check namespace (typically in monitoring)
  if ! check_namespace "monitoring"; then
    check_status "WARNING" "Grafana is not installed (this may be expected in some environments)"
    return 0
  fi
  
  # Check deployments
  check_deployment "monitoring" "grafana" && \
  check_status "OK" "Grafana deployment found" || \
  check_status "WARNING" "Grafana deployment not found"
  
  # Check pods
  kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana" &>/dev/null && \
  check_status "OK" "Grafana pods found" || \
  check_status "WARNING" "No Grafana pods found"
  
  # Check services
  check_service "monitoring" "grafana" && \
  check_status "OK" "Grafana service found" || \
  check_status "WARNING" "Grafana service not found"
  
  # Check for ingress
  kubectl get ingress -n monitoring -l "app.kubernetes.io/name=grafana" &>/dev/null && \
  check_status "OK" "Grafana ingress found" || \
  check_status "WARNING" "Grafana ingress not found (UI may not be externally accessible)"
  
  echo -e "\n${GREEN}${BOLD}✓ Grafana check completed${NC}"
  return 0
}

# Check tempo component if installed
check_tempo() {
  print_header "Checking Tempo Component"
  
  # Check namespace (typically in monitoring)
  if ! check_namespace "monitoring"; then
    check_status "WARNING" "Tempo is not installed (this may be expected in some environments)"
    return 0
  fi
  
  # Check deployments
  check_deployment "monitoring" "tempo" && \
  check_status "OK" "Tempo deployment found" || \
  check_status "WARNING" "Tempo deployment not found"
  
  # Check pods
  kubectl get pods -n monitoring -l "app.kubernetes.io/name=tempo" &>/dev/null && \
  check_status "OK" "Tempo pods found" || \
  check_status "WARNING" "No Tempo pods found"
  
  # Check services
  check_service "monitoring" "tempo" && \
  check_status "OK" "Tempo service found" || \
  check_status "WARNING" "Tempo service not found"
  
  echo -e "\n${GREEN}${BOLD}✓ Tempo check completed${NC}"
  return 0
}

#===============================================================================
# APPLICATION COMPONENTS
#===============================================================================

# Check supabase component if installed
check_supabase() {
  print_header "Checking Supabase Component"
  
  # Check namespace
  if ! check_namespace "supabase"; then
    check_status "WARNING" "Supabase is not installed (this may be expected in some environments)"
    return 0
  fi
  
  # Check PostgreSQL statefulset
  if kubectl get statefulset -n supabase -l "app.kubernetes.io/name=postgresql" &>/dev/null; then
    check_status "OK" "PostgreSQL statefulset found"
    kubectl get pods -n supabase -l "app.kubernetes.io/name=postgresql"
  else
    check_status "ERROR" "PostgreSQL statefulset not found"
    return 1
  fi
  
  # Check Supabase services
  local SUPABASE_SERVICES=("api-gateway" "auth" "realtime" "storage" "studio")
  
  for service in "${SUPABASE_SERVICES[@]}"; do
    if kubectl get deployment -n supabase -l "app.kubernetes.io/name=$service" &>/dev/null; then
      check_status "OK" "Supabase $service deployment found"
    else
      check_status "WARNING" "Supabase $service deployment not found"
    fi
  done
  
  # Check services
  check_service "supabase" "supabase-studio" && \
  check_status "OK" "Supabase Studio service found" || \
  check_status "WARNING" "Supabase Studio service not found"
  
  # Check for ingress
  kubectl get ingress -n supabase &>/dev/null && \
  check_status "OK" "Supabase ingress found" || \
  check_status "WARNING" "Supabase ingress not found (UI may not be externally accessible)"
  
  echo -e "\n${GREEN}${BOLD}✓ Supabase check completed${NC}"
  return 0
}

#===============================================================================
# MAIN FUNCTION
#===============================================================================

# Main function
main() {
  print_header "Checking Kubernetes Cluster"
  kubectl cluster-info
  kubectl get nodes
  
  print_header "Component Verification"
  
  # Infrastructure Components
  echo -e "\n${BOLD}Infrastructure Components:${NC}"
  check_cert_manager
  check_sealed_secrets
  check_ingress_nginx
  check_metallb
  check_vault
  check_minio
  check_policy_engine
  
  # Observability Components
  echo -e "\n${BOLD}Observability Components:${NC}"
  check_prometheus
  check_loki
  check_grafana
  check_tempo
  
  # Application Components
  echo -e "\n${BOLD}Application Components:${NC}"
  check_supabase
  
  print_header "Verification Summary"
  echo -e "${GREEN}${BOLD}Cluster verification complete!${NC}"
  echo -e "To deploy missing components, use the component scripts in scripts/gitops/components/"
  echo -e "To troubleshoot issues, use the diagnose function in each component script"
  echo -e "Example: ./scripts/gitops/components/infrastructure/cert-manager.sh cert_manager_diagnose"
}

# Run the main function
main 