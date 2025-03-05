#!/bin/bash

# Script to port-forward all UIs in the cluster
# Usage: ./port-forward.sh start|stop|status
# Enhanced with timeout improvements and better status checking

# Function to check if a service is up
check_service() {
  local url=$1
  local max_attempts=${2:-10}
  local attempt=1
  local wait_time=1
  
  echo "Checking service at $url..."
  
  while [ $attempt -le $max_attempts ]; do
    if curl -s -o /dev/null -I -w "%{http_code}" "$url" | grep -q -E "200|301|302|307"; then
      echo "✅ Service at $url is up and running!"
      return 0
    fi
    
    echo "Attempt $attempt/$max_attempts: Service not ready yet, waiting ${wait_time}s..."
    sleep $wait_time
    attempt=$((attempt + 1))
    wait_time=$((wait_time + 1))  # Gradually increase wait time
  done
  
  echo "❌ Failed to connect to service at $url after $max_attempts attempts"
  return 1
}

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
  
  echo "All port forwards have been started. Checking service availability..."
  sleep 2 # Give a moment for port-forwards to establish
  
  # Check if services are accessible
  check_service "http://localhost:3000" 5
  check_service "http://localhost:3001" 5
  check_service "http://localhost:3002" 5
  check_service "http://localhost:3003" 5
  
  echo ""
  echo "All UIs should now be accessible via localhost ports"
  echo "To view status of port forwards, run: ./port-forward.sh status"
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

# Function to check status of port forwards
check_status() {
  echo "Checking status of port forwards..."
  
  all_running=true
  
  for service in grafana supabase minio vault; do
    if [ -f "/tmp/pf-${service}.pid" ]; then
      pid=$(cat /tmp/pf-${service}.pid)
      if ps -p ${pid} > /dev/null; then
        port_num=$([[ "$service" == "grafana" ]] && echo "3000" || [[ "$service" == "supabase" ]] && echo "3001" || [[ "$service" == "minio" ]] && echo "3002" || echo "3003")
        
        echo "✅ ${service} port forward is running (PID: ${pid})"
        echo "   URL: http://localhost:${port_num}"
        
        # Check if service is accessible
        if curl -s -o /dev/null -I -w "%{http_code}" "http://localhost:${port_num}" | grep -q -E "200|301|302|307"; then
          echo "   Status: Service is accessible"
        else
          echo "   Status: ⚠️ Service is not responding (port-forward running but service unreachable)"
          all_running=false
        fi
      else
        echo "❌ ${service} port forward is NOT running (PID: ${pid} not found)"
        all_running=false
      fi
    else
      echo "❌ ${service} port forward is NOT configured (no PID file found)"
      all_running=false
    fi
    echo ""
  done
  
  if [ "$all_running" = true ]; then
    echo "All port forwards are running and services are accessible."
  else
    echo "Some port forwards are not running or services are not accessible."
    echo "To restart all port forwards, run: ./port-forward.sh stop && ./port-forward.sh start"
  fi
}

# Check command line arguments
case "$1" in
  start)
    stop_forwards # First stop any existing forwards
    start_forwards
    ;;
  stop)
    stop_forwards
    ;;
  status)
    check_status
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac

exit 0 