#!/bin/bash

# test-environment.sh: Comprehensive testing of local Kubernetes environment
# This script tests all aspects of the local Kubernetes cluster setup including
# infrastructure components, observability, GitOps workflow, and application readiness

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Testing Local Kubernetes Environment"
echo "   GitOps Workflow and Component Health"
echo "========================================"

# Check if minikube is running
if ! minikube status &>/dev/null; then
    echo "❌ Error: Minikube is not running. Please start Minikube first with ./scripts/cluster/setup-minikube.sh"
    exit 1
fi

# Check for kubectl
if ! command -v kubectl &>/dev/null; then
    echo "❌ Error: kubectl not found. Please install kubectl."
    exit 1
fi

# Check for flux CLI
if ! command -v flux &>/dev/null; then
    echo "⚠️ Warning: flux CLI not found. Some tests will be skipped."
    FLUX_CLI_AVAILABLE=false
else
    FLUX_CLI_AVAILABLE=true
fi

# Function to run a test and report the result
run_test() {
    local test_name=$1
    local test_command=$2
    local expected_result=${3:-0}  # Default expected result is success (0)
    
    echo -n "🔍 Testing ${test_name}... "
    
    # Run the test command and capture output and return code
    output=$(eval "${test_command}" 2>&1)
    ret_val=$?
    
    if [ ${ret_val} -eq ${expected_result} ]; then
        echo "✅ Passed"
        if [ "${VERBOSE}" = "true" ] && [ -n "${output}" ]; then
            echo "   Output:"
            echo "${output}" | sed 's/^/   /'
        fi
        return 0
    else
        echo "❌ Failed"
        echo "   Output:"
        echo "${output}" | sed 's/^/   /'
        return 1
    fi
}

# Function to check if all pods in a namespace are running/completed
check_all_pods_running() {
    local namespace=$1
    local selector=${2:-""}
    
    if [ -n "${selector}" ]; then
        selector_arg="-l ${selector}"
    else
        selector_arg=""
    fi
    
    # Count total pods
    total_pods=$(kubectl get pods -n "${namespace}" ${selector_arg} --no-headers 2>/dev/null | wc -l)
    if [ "${total_pods}" -eq 0 ]; then
        echo "No pods found in namespace ${namespace} ${selector_arg}"
        return 1
    fi
    
    # Count running/completed pods
    running_pods=$(kubectl get pods -n "${namespace}" ${selector_arg} --no-headers 2>/dev/null | grep -E 'Running|Completed' | wc -l)
    
    # Check if all pods are running/completed
    if [ "${running_pods}" -eq "${total_pods}" ]; then
        return 0
    else
        echo "${running_pods}/${total_pods} pods running/completed in namespace ${namespace} ${selector_arg}"
        kubectl get pods -n "${namespace}" ${selector_arg} | grep -v -E 'Running|Completed' | grep -v "NAME"
        return 1
    fi
}

# Function to check if a URL is accessible
check_url_accessible() {
    local url=$1
    local timeout=${2:-10}
    local expected_code=${3:-200}
    
    # Use curl to check if URL is accessible, with appropriate flags
    curl_output=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "${timeout}" -k "${url}")
    
    if [ "${curl_output}" = "${expected_code}" ]; then
        return 0
    else
        echo "URL ${url} returned status ${curl_output}, expected ${expected_code}"
        return 1
    fi
}

# Function to check if flux is synced
check_flux_sync() {
    if ! kubectl get namespace flux-system &>/dev/null; then
        echo "Flux is not installed. Skipping sync check."
        return 1
    fi
    
    # Check if all kustomizations are ready
    reconcile_status=$(kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o json | jq -r '.items | map(.status.conditions | map(select(.type=="Ready" and .status=="True")) | length > 0) | all')
    
    if [ "${reconcile_status}" = "true" ]; then
        return 0
    else
        echo "Not all kustomizations are reconciled:"
        kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A
        return 1
    fi
}

echo "========== 1. Minikube Tests =========="

run_test "Minikube Status" "minikube status"
run_test "Minikube API Server Accessible" "kubectl cluster-info"
run_test "Minikube Addons Enabled" "minikube addons list | grep -E 'ingress|metrics-server|storage-provisioner' | grep -c 'enabled'" "3"
run_test "Minikube Resources" "minikube config view | grep -E 'cpus|memory|disk-size'"
run_test "Default StorageClass Exists" "kubectl get storageclass standard -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}'" "true"

echo "========== 2. Core Infrastructure Tests =========="

run_test "cert-manager Installation" "check_all_pods_running 'cert-manager' 'app=cert-manager'"
run_test "cert-manager CRDs Installed" "kubectl get crd | grep -c 'cert-manager.io'"
run_test "sealed-secrets Installation" "check_all_pods_running 'kube-system' 'app.kubernetes.io/name=sealed-secrets'"
run_test "vault Installation" "check_all_pods_running 'vault'"

# Only perform vault test if the CLI is available
if command -v vault &> /dev/null; then
    VAULT_ADDR=$(kubectl get svc -n vault vault -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "${VAULT_ADDR}" ]; then
        run_test "vault Unsealed Status" "VAULT_ADDR='http://${VAULT_ADDR}:8200' vault status -format=json | jq -r .sealed" "false"
    else
        echo "⚠️ Skipping vault seal test - could not determine vault address"
    fi
fi

run_test "gatekeeper Installation" "check_all_pods_running 'gatekeeper-system' 'control-plane=controller-manager'"
run_test "minio Installation" "check_all_pods_running 'minio' 'app=minio'"

echo "========== 3. Networking Tests =========="

run_test "ingress-nginx Installation" "check_all_pods_running 'ingress-nginx' 'app.kubernetes.io/component=controller'"
run_test "ingress-nginx External IP" "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -v ''"
run_test "metallb Installation" "check_all_pods_running 'metallb-system' 'app=metallb'"

# Get ingress IP for further tests
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "${INGRESS_IP}" ]; then
    echo "💡 Ingress IP: ${INGRESS_IP}"
else
    echo "⚠️ No Ingress IP found. Adding .local entries to hosts file and URL tests will be skipped."
fi

# Check /etc/hosts entries
if [ -n "${INGRESS_IP}" ]; then
    local_domains="grafana.local prometheus.local vault.local supabase.local"
    for domain in $local_domains; do
        if grep -q "${domain}" /etc/hosts; then
            run_test "/etc/hosts Entry for ${domain}" "grep '${domain}' /etc/hosts | grep -q '${INGRESS_IP}'"
        else
            echo "⚠️ Warning: No entry for ${domain} in /etc/hosts. Add this line:"
            echo "${INGRESS_IP} ${domain}"
        fi
    done
fi

echo "========== 4. Observability Tests =========="

run_test "prometheus Installation" "check_all_pods_running 'observability' 'app=prometheus'"
run_test "grafana Installation" "check_all_pods_running 'observability' 'app.kubernetes.io/name=grafana'"
run_test "loki Installation" "check_all_pods_running 'observability' 'app=loki'"

# Check if servicemonitors are configured correctly
run_test "ServiceMonitor CRD Installed" "kubectl get crd servicemonitors.monitoring.coreos.com"
run_test "Prometheus ServiceMonitors" "kubectl get servicemonitors.monitoring.coreos.com -A"

# Check if dashboards are imported
run_test "Grafana Dashboards" "kubectl get configmaps -n observability -l grafana_dashboard=1"

# Check if services are accessible via ingress (if IP is available)
if [ -n "${INGRESS_IP}" ]; then
    run_test "Grafana Web Interface" "check_url_accessible 'https://grafana.local/login' 5 200"
    run_test "Prometheus Web Interface" "check_url_accessible 'https://prometheus.local/graph' 5 200"
fi

echo "========== 5. Application Tests =========="

run_test "supabase Installation" "check_all_pods_running 'supabase'"

# Check if supabase is accessible via ingress (if IP is available)
if [ -n "${INGRESS_IP}" ]; then
    run_test "Supabase Web Interface" "check_url_accessible 'https://supabase.local/' 5 200"
fi

echo "========== 6. GitOps Workflow Tests =========="

# If flux CLI is available, perform more advanced flux tests
if [ "${FLUX_CLI_AVAILABLE}" = "true" ]; then
    run_test "Flux Installation" "flux check"
    run_test "Flux Source Controllers" "check_all_pods_running 'flux-system' 'app=source-controller'"
    run_test "Flux Kustomize Controllers" "check_all_pods_running 'flux-system' 'app=kustomize-controller'"
    run_test "Flux Notification Controllers" "check_all_pods_running 'flux-system' 'app=notification-controller'"
    
    # Check flux sources
    run_test "Flux Source Configured" "flux get sources git"
    
    # Check flux kustomizations
    run_test "Flux Kustomizations Configured" "flux get kustomizations"
    
    # Check flux reconciliation status
    run_test "Flux Reconciliation Status" "check_flux_sync"
    
    # Test a manual reconciliation
    run_test "Flux Manual Reconciliation" "flux reconcile kustomization --all"
else
    run_test "Flux Installation" "kubectl get namespace flux-system"
    run_test "Flux GitRepository" "kubectl get gitrepositories.source.toolkit.fluxcd.io -n flux-system"
    run_test "Flux Kustomizations" "kubectl get kustomizations.kustomize.toolkit.fluxcd.io -n flux-system"
fi

# Verify GitOps directory structure
echo "========== 7. GitOps Structure Tests =========="

run_test "clusters Directory" "[ -d 'clusters' ]"
run_test "clusters/local Directory" "[ -d 'clusters/local' ]"
run_test "Infrastructure Configs" "find kustomize -path '*/base/infrastructure/*' -type f | grep -v kustomization.yaml | wc -l | xargs test 0 -lt"
run_test "Observability Configs" "find kustomize -path '*/base/observability/*' -type f | grep -v kustomization.yaml | wc -l | xargs test 0 -lt"
run_test "Policy Configs" "find kustomize -path '*/base/policy/*' -type f | grep -v kustomization.yaml | wc -l | xargs test 0 -lt"
run_test "Application Configs" "find kustomize -path '*/base/applications/*' -type f | grep -v kustomization.yaml | wc -l | xargs test 0 -lt"

# Test for overlays structure
run_test "Local Environment Overlays" "find kustomize -path '*/overlays/local/*' -type f | grep -c kustomization.yaml"

# Summary of all test results
echo "========================================"
echo "   Test Results Summary"
echo "========================================"

# Check if any tests failed and summarize results
if [ -n "${TESTS_FAILED}" ]; then
    echo "❌ ${TESTS_FAILED} tests failed. See output above for details."
    echo "Please resolve these issues before proceeding."
    exit 1
else
    echo "✅ All tests passed! Your local environment is configured correctly."
    echo "Your GitOps workflow is functioning as expected."
    echo ""
    echo "Next steps:"
    echo "1. Ensure all components are properly configured for your specific needs"
    echo "2. Complete Milestone 0 by finalizing the directory structure for staging and production"
    echo "3. Implement the promotion workflow scripts as noted in the progress document"
    echo "4. Continue with your project roadmap for subsequent milestones"
fi 