#!/bin/bash
# Run diagnostics on remote environments (staging/production)

set -e

# Check if environment is specified
if [ $# -lt 1 ]; then
  echo "Usage: $0 <environment> [light]"
  echo "Where environment is one of: staging, production"
  echo "Add 'light' parameter for a quicker diagnostic run"
  exit 1
fi

ENVIRONMENT=$1
LIGHT_MODE=${2:-""}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPORTS_DIR="$SCRIPT_DIR/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p "$REPORTS_DIR"

echo "===== Running diagnostics for $ENVIRONMENT environment ====="

# Ensure the correct Kubernetes context is set for the environment
case $ENVIRONMENT in
  staging)
    echo "Setting context for staging environment..."
    # Replace with your actual staging context
    # kubectl config use-context your-staging-context
    ;;
  production)
    echo "Setting context for production environment..."
    # Replace with your actual production context
    # kubectl config use-context your-production-context
    ;;
  *)
    echo "Error: Unknown environment $ENVIRONMENT"
    exit 1
    ;;
esac

# Run all diagnostic scripts
echo "Running Cluster Health Check..."
"$SCRIPT_DIR/check_cluster_health.sh" $LIGHT_MODE $ENVIRONMENT

echo "Running Flux Health Check..."
"$SCRIPT_DIR/check_flux_health.sh" $LIGHT_MODE $ENVIRONMENT

echo "Running Secrets Management Check..."
"$SCRIPT_DIR/check_secrets.sh" $LIGHT_MODE $ENVIRONMENT

echo "Running Security Policy Check..."
"$SCRIPT_DIR/check_security.sh" $LIGHT_MODE $ENVIRONMENT

echo "Running Observability Check..."
"$SCRIPT_DIR/check_observability.sh" $LIGHT_MODE $ENVIRONMENT

echo "Running Backup Systems Check..."
"$SCRIPT_DIR/check_backups.sh" $LIGHT_MODE $ENVIRONMENT

echo "Running Documentation Check..."
"$SCRIPT_DIR/check_documentation.sh" $LIGHT_MODE $ENVIRONMENT

# Generate summary report
echo "Generating Phase 1 report..."
"$SCRIPT_DIR/create_phase1_report.sh" $ENVIRONMENT

echo "===== Diagnostics completed for $ENVIRONMENT environment ====="
echo "Reports are available in: $REPORTS_DIR" 