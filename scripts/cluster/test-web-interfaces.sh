#!/bin/bash

# test-web-interfaces.sh: Tests connectivity to all web interfaces
# This script checks that all web interfaces are accessible through Ingress

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Testing Web Interface Connectivity"
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

# Function to check if a URL is accessible
check_url() {
    local url=$1
    local name=$2
    local expected_code=${3:-200}
    local timeout=${4:-10}
    local attempts=${5:-3}
    
    echo -n "🔍 Testing ${name} at ${url}... "
    
    for ((i=1; i<=attempts; i++)); do
        # Use curl to check if URL is accessible
        status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "${timeout}" -k "${url}")
        
        if [ "${status_code}" -eq "${expected_code}" ]; then
            echo "✅ Accessible (HTTP ${status_code})"
            return 0
        elif [ $i -lt $attempts ]; then
            echo -n "Retrying (${i}/${attempts})... "
            sleep 2
        fi
    done
    
    echo "❌ Failed (HTTP ${status_code}, expected ${expected_code})"
    return 1
}

# Get Ingress IP
echo "Getting Ingress IP..."
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "${INGRESS_IP}" ]; then
    echo "❌ Error: Could not determine Ingress IP. Make sure ingress-nginx and metallb are properly configured."
    exit 1
fi

echo "Ingress IP: ${INGRESS_IP}"

# Check if domains are in /etc/hosts
echo "Checking /etc/hosts entries..."
DOMAINS=("grafana.local" "prometheus.local" "vault.local" "supabase.local")
MISSING_DOMAINS=()

for domain in "${DOMAINS[@]}"; do
    if grep -q "${domain}" /etc/hosts; then
        host_ip=$(grep "${domain}" /etc/hosts | awk '{print $1}')
        if [ "${host_ip}" = "${INGRESS_IP}" ]; then
            echo "✅ ${domain} is properly configured in /etc/hosts with IP ${host_ip}"
        else
            echo "⚠️ ${domain} is in /etc/hosts but with IP ${host_ip}, should be ${INGRESS_IP}"
            MISSING_DOMAINS+=("${domain}")
        fi
    else
        echo "❌ ${domain} is not in /etc/hosts"
        MISSING_DOMAINS+=("${domain}")
    fi
done

# Show instructions if domains are missing
if [ ${#MISSING_DOMAINS[@]} -gt 0 ]; then
    echo ""
    echo "The following domains need to be added to /etc/hosts:"
    echo "${INGRESS_IP} ${MISSING_DOMAINS[*]}"
    echo ""
    echo "You can add them by running:"
    echo "  sudo -- sh -c \"echo '${INGRESS_IP} ${MISSING_DOMAINS[*]}' >> /etc/hosts\""
    echo ""
    
    read -p "Do you want to continue testing anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "Testing web interfaces..."
echo "------------------------"

# Array to track success status
declare -a TEST_RESULTS
declare -a FAILED_TESTS

# Function to record test result
record_result() {
    local name=$1
    local status=$2
    
    TEST_RESULTS+=("${name}:${status}")
    
    if [ "${status}" != "success" ]; then
        FAILED_TESTS+=("${name}")
    fi
}

# Test Grafana
echo "Testing Grafana..."
if check_url "https://grafana.local/login" "Grafana Login Page"; then
    record_result "Grafana" "success"
else
    record_result "Grafana" "failure"
    
    # Check if Grafana service is running
    echo "  Checking Grafana service..."
    if kubectl get svc -n observability grafana &>/dev/null; then
        echo "  ✅ Grafana service exists"
        
        # Check if Grafana pods are running
        if kubectl get pods -n observability -l app.kubernetes.io/name=grafana | grep -q "Running"; then
            echo "  ✅ Grafana pods are running"
            
            # Check if Grafana ingress is configured
            if kubectl get ingress -n observability grafana &>/dev/null; then
                echo "  ✅ Grafana ingress exists"
                echo "  📝 Ingress configuration:"
                kubectl get ingress -n observability grafana -o yaml
            else
                echo "  ❌ Grafana ingress does not exist"
            fi
        else
            echo "  ❌ Grafana pods are not running"
            kubectl get pods -n observability -l app.kubernetes.io/name=grafana
        fi
    else
        echo "  ❌ Grafana service does not exist"
    fi
fi

# Test Prometheus
echo "Testing Prometheus..."
if check_url "https://prometheus.local/graph" "Prometheus UI"; then
    record_result "Prometheus" "success"
else
    record_result "Prometheus" "failure"
    
    # Check if Prometheus service is running
    echo "  Checking Prometheus service..."
    if kubectl get svc -n observability prometheus-server &>/dev/null; then
        echo "  ✅ Prometheus service exists"
        
        # Check if Prometheus pods are running
        if kubectl get pods -n observability -l app=prometheus,component=server | grep -q "Running"; then
            echo "  ✅ Prometheus pods are running"
            
            # Check if Prometheus ingress is configured
            if kubectl get ingress -n observability prometheus &>/dev/null; then
                echo "  ✅ Prometheus ingress exists"
                echo "  📝 Ingress configuration:"
                kubectl get ingress -n observability prometheus -o yaml
            else
                echo "  ❌ Prometheus ingress does not exist"
            fi
        else
            echo "  ❌ Prometheus pods are not running"
            kubectl get pods -n observability -l app=prometheus,component=server
        fi
    else
        echo "  ❌ Prometheus service does not exist"
    fi
fi

# Test Vault
echo "Testing Vault..."
if check_url "https://vault.local/ui/" "Vault UI"; then
    record_result "Vault" "success"
else
    record_result "Vault" "failure"
    
    # Check if Vault service is running
    echo "  Checking Vault service..."
    if kubectl get svc -n vault vault &>/dev/null; then
        echo "  ✅ Vault service exists"
        
        # Check if Vault pods are running
        if kubectl get pods -n vault -l app.kubernetes.io/name=vault | grep -q "Running"; then
            echo "  ✅ Vault pods are running"
            
            # Check if Vault is sealed
            if kubectl exec -n vault vault-0 -- vault status 2>/dev/null | grep -q "Sealed: true"; then
                echo "  ⚠️ Vault is sealed. You need to unseal it first."
            fi
            
            # Check if Vault ingress is configured
            if kubectl get ingress -n vault vault &>/dev/null; then
                echo "  ✅ Vault ingress exists"
                echo "  📝 Ingress configuration:"
                kubectl get ingress -n vault vault -o yaml
            else
                echo "  ❌ Vault ingress does not exist"
            fi
        else
            echo "  ❌ Vault pods are not running"
            kubectl get pods -n vault -l app.kubernetes.io/name=vault
        fi
    else
        echo "  ❌ Vault service does not exist"
    fi
fi

# Test Supabase
echo "Testing Supabase..."
if check_url "https://supabase.local/" "Supabase UI"; then
    record_result "Supabase" "success"
else
    record_result "Supabase" "failure"
    
    # Check if Supabase pods are running
    echo "  Checking Supabase services..."
    kubectl get services -n supabase
    
    # Check if Supabase pods are running
    echo "  Checking Supabase pods..."
    kubectl get pods -n supabase
    
    # Check if Supabase ingress is configured
    if kubectl get ingress -n supabase &>/dev/null; then
        echo "  ✅ Supabase ingress exists"
        echo "  📝 Ingress configuration:"
        kubectl get ingress -n supabase -o yaml
    else
        echo "  ❌ Supabase ingress does not exist"
    fi
fi

# Test MinIO
if kubectl get ingress -n minio minio &>/dev/null; then
    echo "Testing MinIO..."
    MINIO_HOST=$(kubectl get ingress -n minio minio -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
    
    if [ -n "${MINIO_HOST}" ]; then
        if grep -q "${MINIO_HOST}" /etc/hosts || [ "${MINIO_HOST}" = "minio.local" ]; then
            if check_url "https://${MINIO_HOST}" "MinIO UI"; then
                record_result "MinIO" "success"
            else
                record_result "MinIO" "failure"
                
                # Check MinIO service
                echo "  Checking MinIO service..."
                kubectl get svc -n minio minio
                
                # Check MinIO pods
                echo "  Checking MinIO pods..."
                kubectl get pods -n minio -l app=minio
            fi
        else
            echo "⚠️ MinIO host ${MINIO_HOST} is not in /etc/hosts. Add it with:"
            echo "  sudo -- sh -c \"echo '${INGRESS_IP} ${MINIO_HOST}' >> /etc/hosts\""
            record_result "MinIO" "skipped"
        fi
    else
        echo "⚠️ MinIO ingress exists but host is not set"
        record_result "MinIO" "skipped"
    fi
else
    echo "⚠️ Skipping MinIO test - no ingress found"
    record_result "MinIO" "skipped"
fi

# Summary of test results
echo ""
echo "========================================"
echo "   Web Interface Test Results"
echo "========================================"

# Count successes and failures
TOTAL_TESTS=${#TEST_RESULTS[@]}
SUCCESSFUL_TESTS=0
FAILED_TESTS_COUNT=0
SKIPPED_TESTS=0

for result in "${TEST_RESULTS[@]}"; do
    name=$(echo "${result}" | cut -d':' -f1)
    status=$(echo "${result}" | cut -d':' -f2)
    
    if [ "${status}" = "success" ]; then
        echo "✅ ${name}: Accessible"
        ((SUCCESSFUL_TESTS++))
    elif [ "${status}" = "skipped" ]; then
        echo "⚠️ ${name}: Skipped"
        ((SKIPPED_TESTS++))
    else
        echo "❌ ${name}: Not accessible"
        ((FAILED_TESTS_COUNT++))
    fi
done

echo ""
echo "Summary: ${SUCCESSFUL_TESTS}/${TOTAL_TESTS} interfaces accessible"
if [ ${SKIPPED_TESTS} -gt 0 ]; then
    echo "         ${SKIPPED_TESTS} tests skipped"
fi

if [ ${FAILED_TESTS_COUNT} -gt 0 ]; then
    echo ""
    echo "❌ Some web interfaces are not accessible. Check the output above for details."
    echo "Common issues:"
    echo "  1. Domain names not properly configured in /etc/hosts"
    echo "  2. Ingress not properly configured"
    echo "  3. Services not running or not exposing the correct ports"
    echo "  4. Self-signed certificates causing browser issues (try accessing in incognito mode)"
    
    if [ ${FAILED_TESTS_COUNT} -eq ${TOTAL_TESTS} ]; then
        echo ""
        echo "❗ All interfaces failed. Check that ingress-nginx and metallb are properly configured."
    fi
    
    exit 1
else
    echo ""
    echo "✅ All web interfaces are accessible!"
    echo "Your local Kubernetes environment is properly configured for external access."
fi 