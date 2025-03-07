# Minikube Operations Cheatsheet

This document provides quick-reference for common Minikube operations in this repository.

## Basic Minikube Commands

```bash
# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8g --disk-size=50g

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete

# Get Minikube status
minikube status

# Access Minikube dashboard
minikube dashboard
```

## Working with Minikube Addons

```bash
# List available addons
minikube addons list

# Enable an addon
minikube addons enable <addon-name>

# Disable an addon
minikube addons disable <addon-name>

# Common addons
minikube addons enable metrics-server
minikube addons enable ingress
minikube addons enable registry
```

## Accessing Services

```bash
# Get service URL
minikube service <service-name> -n <namespace> --url

# Access service in browser
minikube service <service-name> -n <namespace>

# Port forwarding (alternative to service access)
kubectl port-forward -n <namespace> service/<service-name> <local-port>:<service-port>
```

## Working with Docker Registry

```bash
# Get Minikube's Docker environment
eval $(minikube docker-env)

# Build image directly in Minikube's Docker
docker build -t <image-name>:<tag> .

# Use image in Kubernetes with imagePullPolicy: Never
kubectl run <pod-name> --image=<image-name>:<tag> --image-pull-policy=Never
```

## Resource Management

```bash
# Check resource usage
minikube ssh -- top

# Check disk usage
minikube ssh -- df -h

# SSH into Minikube
minikube ssh
```

## Minikube Profiles

```bash
# Create a new profile
minikube start -p <profile-name> --driver=docker --cpus=4 --memory=8g

# Switch between profiles
minikube profile <profile-name>

# List profiles
minikube profile list
```

## Troubleshooting

```bash
# Check Minikube logs
minikube logs

# Check for issues
minikube ssh -- journalctl -xeu kubelet

# Restart Minikube with debug output
minikube start --alsologtostderr -v=7

# Reset Minikube
minikube delete
minikube start
```