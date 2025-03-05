#!/bin/bash

# Script to fix the minikube tunnel setup
# This script will:
# 1. Update /etc/hosts entries
# 2. Stop existing minikube tunnel if running
# 3. Start a new minikube tunnel

# Must be run with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (sudo)."
    exit 1
fi

echo "Fixing minikube tunnel setup..."

# Get minikube IP
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: ${MINIKUBE_IP}"

# Update /etc/hosts
echo "Updating /etc/hosts entries..."
# Remove any existing entries for our domains
sed -i.bak '/grafana.local/d' /etc/hosts
sed -i.bak '/minio.local/d' /etc/hosts
sed -i.bak '/vault.local/d' /etc/hosts
sed -i.bak '/supabase.local/d' /etc/hosts
sed -i.bak '/example.local/d' /etc/hosts

# Add new entries
echo "127.0.0.1 grafana.local minio.local vault.local supabase.local example.local" >> /etc/hosts
echo "Updated /etc/hosts with local domain entries"

# Stop existing minikube tunnel if running
echo "Stopping any existing minikube tunnel..."
pkill -f "minikube tunnel" || true
sleep 2

echo "Setup completed. Now run 'minikube tunnel' in a separate terminal and keep it running."
echo "You should be able to access your UIs at:"
echo "- Grafana: http://grafana.local"
echo "- Supabase: http://supabase.local"
echo "- MinIO: http://minio.local"
echo "- Vault: http://vault.local" 