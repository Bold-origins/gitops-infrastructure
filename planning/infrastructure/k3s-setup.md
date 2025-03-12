# k3s Installation and Configuration Plan

## Server Specifications
- VPS IP: 91.108.112.146
- Admin User: boldman (with sudo privileges)
- OS: Ubuntu 24.04.2 LTS

## k3s Installation Steps

### 1. Install k3s
```bash
# Connect to server
ssh boldman@91.108.112.146

# Install k3s as a server node
curl -sfL https://get.k3s.io | sudo sh -
```

### 2. Verify Installation
```bash
# Check k3s service status
sudo systemctl status k3s

# View running nodes
sudo kubectl get nodes
```

### 3. Secure Access to k3s
```bash
# Get kubeconfig from the server
sudo cat /etc/rancher/k3s/k3s.yaml
```
- Copy the kubeconfig to local machine at `~/.kube/config`
- Replace "127.0.0.1" with the VPS IP address

### 4. Configure Local kubectl
```bash
# Create directory if it doesn't exist
mkdir -p ~/.kube

# Set up kubeconfig file
vim ~/.kube/config
```
- Paste the modified kubeconfig file
- Test with `kubectl get nodes`

## Resource Configuration

### 1. CPU and Memory Limits
- Evaluate VPS resources and set appropriate limits for k3s components
- Configure resource requests and limits for system workloads

### 2. Storage Configuration
- Set up persistent volume storage for stateful applications
- Consider local-path-provisioner for development purposes

## Networking Configuration

### 1. Network Policies
- Implement basic network policies to secure pod-to-pod communication
- Configure default deny policies for production namespaces

### 2. Ingress Setup
- Install and configure Traefik (comes with k3s by default)
- Set up TLS for secure connections

## Ongoing Maintenance

### 1. Upgrade Strategy
- Plan for regular k3s upgrades
- Test upgrades in development before applying to staging

### 2. Backup Strategy
- Regularly backup etcd data
- Document restore procedures 