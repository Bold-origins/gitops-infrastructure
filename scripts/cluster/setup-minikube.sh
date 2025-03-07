#!/bin/bash

# setup-minikube.sh: Sets up a Minikube cluster for local development
# This script initializes a Minikube cluster with the necessary configuration

set -e

# Source environment variables if .env file exists
if [ -f ".env" ]; then
  source .env
fi

# Default values if not set in environment
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-8192}
MINIKUBE_CPUS=${MINIKUBE_CPUS:-4}
MINIKUBE_DISK_SIZE=${MINIKUBE_DISK_SIZE:-20g}
MINIKUBE_DRIVER=${MINIKUBE_DRIVER:-"docker"}

# Display banner
echo "========================================"
echo "   Setting up Minikube Environment"
echo "========================================"
echo "Memory: ${MINIKUBE_MEMORY}MB"
echo "CPUs: ${MINIKUBE_CPUS}"
echo "Disk: ${MINIKUBE_DISK_SIZE}"
echo "Driver: ${MINIKUBE_DRIVER}"
echo "========================================"

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "Minikube is not installed. Please install Minikube first."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Delete existing Minikube cluster if it exists
echo "Checking for existing Minikube clusters..."
if minikube status &> /dev/null; then
    echo "Existing Minikube cluster found. Stopping and deleting..."
    minikube stop
    minikube delete
    echo "Existing cluster deleted."
fi

# Start Minikube with specified resources
echo "Starting Minikube with ${MINIKUBE_MEMORY}MB memory, ${MINIKUBE_CPUS} CPUs, ${MINIKUBE_DISK_SIZE} disk..."
minikube start --memory="${MINIKUBE_MEMORY}" --cpus="${MINIKUBE_CPUS}" --disk-size="${MINIKUBE_DISK_SIZE}" --driver="${MINIKUBE_DRIVER}"

# Enable required addons
echo "Enabling required addons..."
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable storage-provisioner

# Wait for addons to be ready
echo "Waiting for addons to be ready..."
sleep 10

# Verify all pods are running
echo "Verifying cluster status..."
kubectl wait --for=condition=ready pod --all -A --timeout=180s || true

# Create a default storage class if needed
echo "Setting up storage classes..."
if ! kubectl get storageclass standard &> /dev/null; then
    cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
fi

# Get Minikube IP for hosts file
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: ${MINIKUBE_IP}"
echo "You may need to add the following to your /etc/hosts file:"
echo "${MINIKUBE_IP} grafana.local prometheus.local vault.local supabase.local"

# Display success message
echo "========================================"
echo "   Minikube setup complete!"
echo "========================================"
echo "To view the Kubernetes Dashboard, run:"
echo "minikube dashboard"
echo ""
echo "To access services, add the following to /etc/hosts:"
echo "${MINIKUBE_IP} grafana.local prometheus.local vault.local supabase.local"
echo ""
echo "Next steps:"
echo "1. Run './scripts/cluster/setup-core-infrastructure.sh' to set up core infrastructure"
echo "2. Run './scripts/cluster/setup-networking.sh' to set up networking"
echo "3. Run './scripts/cluster/setup-observability.sh' to set up observability"
echo "4. Run './scripts/cluster/setup-applications.sh' to set up applications"
echo "========================================" 