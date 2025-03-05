# UI Access Methods for Local Kubernetes Cluster

This document explains different methods to access the UIs in your local Kubernetes cluster.

## Available UIs

- **Grafana**: Monitoring and dashboards
- **Supabase**: Database and backend services
- **MinIO**: Object storage
- **Vault**: Secret management

## Option 1: Port Forwarding Script

The `port-forward.sh` script provides a simple way to start and stop port forwards for all UIs.

### Usage

```bash
# Start all port forwards
./port-forward.sh start

# Stop all port forwards
./port-forward.sh stop
```

### Accessing UIs

- Grafana: http://localhost:3000 (admin/admin)
- Supabase API: http://localhost:3001 (Note: This is the Kong API gateway, not the Studio UI)
- MinIO Console: http://localhost:3002 (minioadmin/minioadmin)
- Vault: http://localhost:3003

## Option 2: Minikube Tunnel

The `fix-tunnel.sh` script configures your system to use domain names with minikube tunnel.

### Usage

```bash
# First, fix the tunnel configuration
sudo ./fix-tunnel.sh

# Then start the minikube tunnel in a separate terminal
minikube tunnel
```

### Accessing UIs

- Grafana: http://grafana.local
- Supabase: http://supabase.local
- MinIO: http://minio.local
- Vault: http://vault.local

## Option 3: kubefwd

The `kubefwd-setup.sh` script uses kubefwd to forward all services from selected namespaces.

### Usage

```bash
# Install and start kubefwd
./kubefwd-setup.sh
```

### Accessing UIs

With kubefwd, you can access services directly using their service names:

- Grafana: http://grafana.observability:80
- Supabase Kong API: http://supabase-supabase-kong.supabase:8000
- Supabase Studio (if available): http://supabase-supabase-studio.supabase:3000
- MinIO Console: http://minio-console.minio:9001
- Vault: http://vault.vault:8200

## Troubleshooting

### Port Already In Use

If you see an error like "address already in use", you may have another port-forward running. 
Stop all forwards with `./port-forward.sh stop` before starting new ones.

### Minikube Tunnel Issues

If minikube tunnel is not working correctly, try these steps:

1. Stop existing tunnel: `pkill -f "minikube tunnel"`
2. Delete and recreate the tunnel: `minikube tunnel --cleanup ; minikube tunnel`
3. Check that your /etc/hosts file has the correct entries

### Supabase Studio Issues

The Supabase Studio UI might not be reliably accessible through port forwarding. If you need direct access to the Studio UI, try one of these approaches:

1. Use the minikube tunnel method with domain names
2. Use kubefwd to access it directly
3. Try a longer port-forward command: `kubectl port-forward -n supabase deployment/supabase-supabase-studio 3001:3000` 