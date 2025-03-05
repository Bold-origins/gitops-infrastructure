#!/bin/bash

# Script to port-forward all UIs in the cluster
# Usage: ./port-forward.sh start|stop

# Function to start port forwards
start_forwards() {
  echo "Starting port forwards for all UIs..."
  
  # Grafana
  kubectl port-forward -n observability svc/grafana 3000:80 > /tmp/pf-grafana.log 2>&1 &
  echo "Grafana UI started on http://localhost:3000 (PID: $!)"
  echo $! > /tmp/pf-grafana.pid
  
  # Supabase - using Kong API instead of studio which might be unreliable
  kubectl port-forward -n supabase svc/supabase-supabase-kong 3001:8000 > /tmp/pf-supabase.log 2>&1 &
  echo "Supabase API started on http://localhost:3001 (PID: $!)"
  echo $! > /tmp/pf-supabase.pid
  
  # MinIO Console
  kubectl port-forward -n minio svc/minio-console 3002:9001 > /tmp/pf-minio.log 2>&1 &
  echo "MinIO Console UI started on http://localhost:3002 (PID: $!)"
  echo $! > /tmp/pf-minio.pid
  
  # Vault
  kubectl port-forward -n vault svc/vault 3003:8200 > /tmp/pf-vault.log 2>&1 &
  echo "Vault UI started on http://localhost:3003 (PID: $!)"
  echo $! > /tmp/pf-vault.pid
  
  echo "All UIs are now accessible via localhost ports"
  echo "To stop all port forwards, run: ./port-forward.sh stop"
}

# Function to stop port forwards
stop_forwards() {
  echo "Stopping all port forwards..."
  
  for service in grafana supabase minio vault; do
    if [ -f "/tmp/pf-${service}.pid" ]; then
      pid=$(cat /tmp/pf-${service}.pid)
      echo "Stopping ${service} port forward (PID: ${pid})"
      kill ${pid} 2>/dev/null || true
      rm -f /tmp/pf-${service}.pid
      rm -f /tmp/pf-${service}.log
    fi
  done
  
  echo "All port forwards stopped"
}

# Check command line arguments
case "$1" in
  start)
    start_forwards
    ;;
  stop)
    stop_forwards
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac

exit 0 