#!/bin/bash

# Script to set up and use kubefwd for accessing Kubernetes services
# This script will:
# 1. Install kubefwd if not present
# 2. Forward all services from specified namespaces

# Check if kubefwd is installed
if ! command -v kubefwd &> /dev/null; then
    echo "kubefwd is not installed. Installing now..."
    brew install txn2/tap/kubefwd
fi

# Check if sudo is available (required for kubefwd)
if ! command -v sudo &> /dev/null; then
    echo "Error: sudo command is required for kubefwd but not found."
    exit 1
fi

echo "Starting kubefwd for all services in relevant namespaces..."
echo "You will be prompted for your sudo password."
echo "Keep this terminal window open to maintain the forwards."

# Forward all services from the following namespaces
NAMESPACES="observability,supabase,minio,vault"

# Run kubefwd
sudo -E kubefwd svc -n ${NAMESPACES} --kubeconfig ~/.kube/config

# When this script exits, kubefwd will be stopped
echo "kubefwd has been stopped. Services are no longer accessible." 