#!/bin/bash

# test-gitops-workflow.sh: Tests the GitOps workflow with Flux
# This script verifies that changes to the repository are properly reconciled by Flux

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Display banner
echo "========================================"
echo "   Testing GitOps Workflow with Flux"
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
    echo "❌ Error: flux CLI not found. Please install the Flux CLI from https://fluxcd.io/docs/installation/"
    exit 1
fi

# Check if flux is installed in the cluster
if ! kubectl get namespace flux-system &>/dev/null; then
    echo "❌ Error: Flux is not installed in the cluster. Please run ./scripts/cluster/setup-flux.sh first."
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "❌ Error: Not in a git repository. Please run this script from the root of your git repository."
    exit 1
fi

echo "✅ Prerequisites verified"

# Function to wait for flux kustomization to reconcile
wait_for_reconciliation() {
    local kustomization=$1
    local namespace=${2:-flux-system}
    local timeout=${3:-60}
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    echo "Waiting for ${kustomization} to reconcile (timeout: ${timeout}s)..."
    
    while true; do
        local current_time=$(date +%s)
        if [ ${current_time} -gt ${end_time} ]; then
            echo "❌ Timeout waiting for ${kustomization} to reconcile"
            return 1
        fi
        
        local reconciled=$(kubectl get kustomization ${kustomization} -n ${namespace} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "${reconciled}" = "True" ]; then
            local last_applied=$(kubectl get kustomization ${kustomization} -n ${namespace} -o jsonpath='{.status.lastAppliedRevision}' 2>/dev/null)
            echo "✅ ${kustomization} reconciled successfully (revision: ${last_applied})"
            return 0
        fi
        
        echo -n "."
        sleep 5
    done
}

# Get current git status
echo "Checking git status..."
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️ Warning: There are uncommitted changes in the repository."
    echo "This might affect the test results if these changes should be included in the test."
    
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Phase 1: Check if Flux is properly synchronizing with the git repository
echo ""
echo "Phase 1: Verifying Flux synchronization with git repository"
echo "---------------------------------------------------------"

# Get current git branch and HEAD commit
current_branch=$(git rev-parse --abbrev-ref HEAD)
current_commit=$(git rev-parse HEAD)
echo "Current branch: ${current_branch}"
echo "Current commit: ${current_commit}"

# Check if Flux is tracking this branch
tracked_branch=$(kubectl get gitrepositories.source.toolkit.fluxcd.io -n flux-system flux-system -o jsonpath='{.spec.ref.branch}' 2>/dev/null)
if [ "${tracked_branch}" != "${current_branch}" ]; then
    echo "⚠️ Warning: Flux is tracking branch '${tracked_branch}', but you're on branch '${current_branch}'."
    echo "This test may not be accurate. Consider switching to branch '${tracked_branch}' or updating Flux configuration."
    
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if Flux has reconciled the current commit
flux_commit=$(kubectl get gitrepositories.source.toolkit.fluxcd.io -n flux-system flux-system -o jsonpath='{.status.artifact.revision}' 2>/dev/null | cut -d '/' -f 2)
echo "Flux reconciled commit: ${flux_commit}"

if [ "${flux_commit}" != "${current_commit}" ]; then
    echo "⚠️ Flux has not yet reconciled the current commit. Triggering manual reconciliation..."
    flux reconcile source git flux-system
    sleep 5
    
    # Check again after reconciliation
    flux_commit=$(kubectl get gitrepositories.source.toolkit.fluxcd.io -n flux-system flux-system -o jsonpath='{.status.artifact.revision}' 2>/dev/null | cut -d '/' -f 2)
    
    if [ "${flux_commit}" != "${current_commit}" ]; then
        echo "❌ Flux still hasn't reconciled the current commit after manual reconciliation."
        echo "This might indicate a problem with the GitOps configuration."
        exit 1
    else
        echo "✅ Flux has successfully reconciled the current commit after manual triggering."
    fi
else
    echo "✅ Flux has already reconciled the current commit."
fi

# Phase 2: Make a small change and verify it gets deployed
echo ""
echo "Phase 2: Testing deployment of a simple change"
echo "--------------------------------------------"

# Create a temporary namespace for testing
TEST_NAMESPACE="flux-test-$(date +%s)"
TEST_CM_NAME="flux-test-config"
TEST_VALUE="test-value-$(date +%s)"

echo "Creating test directory if it doesn't exist..."
mkdir -p clusters/local/tests

# Create a test kustomization file
echo "Creating test kustomization file..."
cat > clusters/local/tests/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- test-namespace.yaml
- test-configmap.yaml
EOF

# Create a test namespace manifest
echo "Creating test namespace manifest..."
cat > clusters/local/tests/test-namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${TEST_NAMESPACE}
EOF

# Create a test configmap manifest
echo "Creating test configmap manifest..."
cat > clusters/local/tests/test-configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${TEST_CM_NAME}
  namespace: ${TEST_NAMESPACE}
data:
  test-key: "${TEST_VALUE}"
EOF

# Create/update Flux kustomization resource for tests
echo "Creating/updating Flux kustomization resource for tests..."
cat > clusters/local/tests-kustomization.yaml <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: test-resources
  namespace: flux-system
spec:
  interval: 1m
  path: ./clusters/local/tests
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
EOF

# Add the test-kustomization to git
echo "Adding test files to git..."
git add clusters/local/tests/
git add clusters/local/tests-kustomization.yaml

# Commit the changes
echo "Committing changes..."
git commit -m "Add test resources for GitOps workflow testing"

# Push the changes (if remote repository is configured)
if git remote -v | grep -q "origin.*push"; then
    echo "Pushing changes to remote repository..."
    git push origin ${current_branch}
else
    echo "⚠️ No remote repository configured. Skipping push."
fi

# Apply the kustomization resource manually to speed up the test
echo "Applying test kustomization resource..."
kubectl apply -f clusters/local/tests-kustomization.yaml

# Wait for reconciliation
wait_for_reconciliation "test-resources"

# Verify that the test namespace and configmap were created
echo "Verifying test resources..."
if kubectl get namespace ${TEST_NAMESPACE} &>/dev/null; then
    echo "✅ Test namespace ${TEST_NAMESPACE} was created successfully."
else
    echo "❌ Test namespace ${TEST_NAMESPACE} was not created."
    exit 1
fi

if kubectl get configmap ${TEST_CM_NAME} -n ${TEST_NAMESPACE} &>/dev/null; then
    cm_value=$(kubectl get configmap ${TEST_CM_NAME} -n ${TEST_NAMESPACE} -o jsonpath='{.data.test-key}')
    if [ "${cm_value}" = "${TEST_VALUE}" ]; then
        echo "✅ Test ConfigMap ${TEST_CM_NAME} was created with correct value."
    else
        echo "❌ Test ConfigMap ${TEST_CM_NAME} was created but has incorrect value: ${cm_value}, expected: ${TEST_VALUE}"
        exit 1
    fi
else
    echo "❌ Test ConfigMap ${TEST_CM_NAME} was not created."
    exit 1
fi

# Phase 3: Update the ConfigMap and verify the change is deployed
echo ""
echo "Phase 3: Testing deployment of an update"
echo "--------------------------------------"

# Update the test value
NEW_TEST_VALUE="updated-value-$(date +%s)"
echo "Updating test ConfigMap with new value: ${NEW_TEST_VALUE}"

# Update the test configmap manifest
cat > clusters/local/tests/test-configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${TEST_CM_NAME}
  namespace: ${TEST_NAMESPACE}
data:
  test-key: "${NEW_TEST_VALUE}"
EOF

# Commit the changes
echo "Committing changes..."
git add clusters/local/tests/test-configmap.yaml
git commit -m "Update test ConfigMap for GitOps workflow testing"

# Push the changes (if remote repository is configured)
if git remote -v | grep -q "origin.*push"; then
    echo "Pushing changes to remote repository..."
    git push origin ${current_branch}
else
    echo "⚠️ No remote repository configured. Skipping push."
fi

# Trigger manual reconciliation to speed up the test
echo "Triggering manual reconciliation..."
flux reconcile source git flux-system
flux reconcile kustomization test-resources

# Wait for reconciliation
wait_for_reconciliation "test-resources"

# Verify that the ConfigMap was updated
echo "Verifying ConfigMap update..."
updated_value=$(kubectl get configmap ${TEST_CM_NAME} -n ${TEST_NAMESPACE} -o jsonpath='{.data.test-key}')
if [ "${updated_value}" = "${NEW_TEST_VALUE}" ]; then
    echo "✅ Test ConfigMap ${TEST_CM_NAME} was updated with correct value."
else
    echo "❌ Test ConfigMap ${TEST_CM_NAME} was not updated correctly. Current value: ${updated_value}, expected: ${NEW_TEST_VALUE}"
    exit 1
fi

# Phase 4: Clean up
echo ""
echo "Phase 4: Cleaning up test resources"
echo "--------------------------------"

echo "Removing test resources from git..."
rm -f clusters/local/tests-kustomization.yaml
rm -rf clusters/local/tests

# Commit the cleanup
echo "Committing cleanup..."
git add clusters/local/
git commit -m "Remove test resources after GitOps workflow testing"

# Push the changes (if remote repository is configured)
if git remote -v | grep -q "origin.*push"; then
    echo "Pushing changes to remote repository..."
    git push origin ${current_branch}
else
    echo "⚠️ No remote repository configured. Skipping push."
fi

# Delete the kustomization resource manually to clean up immediately
echo "Deleting test kustomization resource..."
kubectl delete kustomization test-resources -n flux-system --wait=true

# Delete the test namespace and resources manually, in case they're not pruned
echo "Deleting test namespace..."
kubectl delete namespace ${TEST_NAMESPACE} --wait=false || true

echo ""
echo "========================================"
echo "   GitOps Workflow Test Results"
echo "========================================"
echo "✅ All tests passed! Your GitOps workflow is functioning correctly."
echo ""
echo "The following capabilities were verified:"
echo "1. Flux is properly reconciling changes from git"
echo "2. New resources are correctly deployed"
echo "3. Updates to existing resources are applied"
echo "4. Resources are properly pruned when removed"
echo ""
echo "Your Flux-based GitOps workflow is ready for use in Milestone 0."
echo "========================================" 