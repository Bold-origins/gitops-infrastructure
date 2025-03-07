#!/bin/bash

# test-all.sh: Comprehensive testing script for the entire local environment
# This script runs all tests to ensure the cluster is properly set up

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Running Comprehensive Tests"
echo "   for Local Kubernetes Environment"
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

# Function to run a test script and report the result
run_test_script() {
    local script_name=$1
    local script_path=$2
    local description=$3
    
    echo ""
    echo "========================================"
    echo "   Running Test: ${description}"
    echo "   Script: ${script_name}"
    echo "========================================"
    
    # Make sure the script is executable
    chmod +x "${script_path}"
    
    # Run the script and capture the exit code
    if "${script_path}"; then
        echo ""
        echo "✅ ${script_name} completed successfully!"
        return 0
    else
        echo ""
        echo "❌ ${script_name} failed with exit code $?."
        return 1
    fi
}

# Array to track test results
declare -a TEST_RESULTS

# Phase 1: Basic Environment Tests
echo ""
echo "Phase 1: Basic Environment Verification"
echo "--------------------------------------"

if run_test_script "test-environment.sh" "./scripts/cluster/test-environment.sh" "Basic Environment Verification"; then
    TEST_RESULTS+=("Basic Environment:success")
else
    TEST_RESULTS+=("Basic Environment:failure")
    echo "⚠️ Basic environment verification failed. Some components might not be properly set up."
    echo "This may cause subsequent tests to fail as well."
    
    read -p "Do you want to continue with remaining tests? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Phase 2: Web Interface Connectivity
echo ""
echo "Phase 2: Web Interface Connectivity"
echo "--------------------------------"

if run_test_script "test-web-interfaces.sh" "./scripts/cluster/test-web-interfaces.sh" "Web Interface Connectivity"; then
    TEST_RESULTS+=("Web Interfaces:success")
else
    TEST_RESULTS+=("Web Interfaces:failure")
    echo "⚠️ Web interface connectivity tests failed. This may indicate issues with ingress or domain configuration."
    
    read -p "Do you want to continue with remaining tests? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Phase 3: GitOps Workflow Tests (if flux is installed)
echo ""
echo "Phase 3: GitOps Workflow Verification"
echo "---------------------------------"

if kubectl get namespace flux-system &>/dev/null; then
    if command -v flux &>/dev/null; then
        if run_test_script "test-gitops-workflow.sh" "./scripts/gitops/test-gitops-workflow.sh" "GitOps Workflow Verification"; then
            TEST_RESULTS+=("GitOps Workflow:success")
        else
            TEST_RESULTS+=("GitOps Workflow:failure")
            echo "⚠️ GitOps workflow tests failed. This may indicate issues with Flux configuration or git repository setup."
        fi
    else
        echo "⚠️ flux CLI not found. Skipping GitOps workflow tests."
        TEST_RESULTS+=("GitOps Workflow:skipped")
    fi
else
    echo "⚠️ Flux is not installed. Skipping GitOps workflow tests."
    TEST_RESULTS+=("GitOps Workflow:skipped")
fi

# Phase 4: Add verification for any custom applications
echo ""
echo "Phase 4: Custom Application Verification"
echo "-------------------------------------"

# Check if Supabase is deployed
if kubectl get namespace supabase &>/dev/null; then
    echo "Verifying Supabase deployment..."
    
    # Check if all Supabase pods are running
    if kubectl get pods -n supabase --no-headers | grep -v "Running" | grep -v "Completed" | wc -l | grep -q "0"; then
        echo "✅ All Supabase pods are running."
        TEST_RESULTS+=("Supabase Application:success")
    else
        echo "❌ Some Supabase pods are not running:"
        kubectl get pods -n supabase
        TEST_RESULTS+=("Supabase Application:failure")
    fi
else
    echo "⚠️ Supabase is not deployed. Skipping application verification."
    TEST_RESULTS+=("Supabase Application:skipped")
fi

# Summary of all test results
echo ""
echo "========================================"
echo "   Comprehensive Test Results Summary"
echo "========================================"

# Count successes and failures
TOTAL_TESTS=${#TEST_RESULTS[@]}
SUCCESSFUL_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

for result in "${TEST_RESULTS[@]}"; do
    name=$(echo "${result}" | cut -d':' -f1)
    status=$(echo "${result}" | cut -d':' -f2)
    
    if [ "${status}" = "success" ]; then
        echo "✅ ${name}: Passed"
        ((SUCCESSFUL_TESTS++))
    elif [ "${status}" = "skipped" ]; then
        echo "⚠️ ${name}: Skipped"
        ((SKIPPED_TESTS++))
    else
        echo "❌ ${name}: Failed"
        ((FAILED_TESTS++))
    fi
done

echo ""
echo "Summary: ${SUCCESSFUL_TESTS}/${TOTAL_TESTS} test phases passed"
if [ ${SKIPPED_TESTS} -gt 0 ]; then
    echo "         ${SKIPPED_TESTS} test phases skipped"
fi
if [ ${FAILED_TESTS} -gt 0 ]; then
    echo "         ${FAILED_TESTS} test phases failed"
fi

echo ""
if [ ${FAILED_TESTS} -eq 0 ]; then
    echo "🎉 Congratulations! All tests passed."
    echo "Your local Kubernetes environment is properly set up and ready for use."
    echo ""
    echo "You have successfully completed the testing requirements for Milestone 0."
    echo "You can now proceed with finalizing the directory structure for staging and"
    echo "production environments, and implementing the promotion workflow scripts."
else
    echo "⚠️ Some tests failed. Please review the output above to identify and fix the issues."
    echo "Common issues include:"
    echo "  1. Missing or incorrectly configured components"
    echo "  2. Network connectivity issues"
    echo "  3. Domain name configuration problems"
    echo "  4. GitOps repository setup issues"
    echo ""
    echo "After fixing the issues, run this script again to verify your progress."
    exit 1
fi 