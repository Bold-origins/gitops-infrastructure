# MetalLB Base Configuration

This directory contains the base configuration for MetalLB that can be used across multiple environments (local, staging, production). The configuration is designed to be used with Kustomize overlays.

## What is MetalLB?

MetalLB is a load-balancer implementation for bare metal/on-premises Kubernetes clusters, providing network load-balancers implementation through standard protocols (ARP, NDP, BGP).

## Environment-Specific Customizations

When creating environment overlays, consider customizing the following components:

### 1. IP Address Ranges

The most critical environment-specific setting is the IP address range in `ipaddresspool.yaml`:

```yaml
# Local environment
spec:
  addresses:
  - 192.168.1.240-192.168.1.250  # Adjust for your local network

# Staging environment
spec:
  addresses:
  - 10.10.10.100-10.10.10.200  # Adjust for your staging network

# Production environment
spec:
  addresses:
  - 10.0.0.100-10.0.0.200  # Adjust for your production network
```

### 2. Advertisement Mode

For different network configurations, you might need L2 (ARP/NDP) or BGP modes:

```yaml
# L2 (default) for simple networks
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advertisement
spec:
  ipAddressPools:
  - first-pool

# BGP mode for more advanced network configurations
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: bgp-advertisement
spec:
  ipAddressPools:
  - first-pool
```

### 3. Resource Allocation

For larger environments, you may want to adjust resource requirements:

```yaml
# Production-level resources
speaker:
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi

controller:
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
```

### 4. BGP Peers (if using BGP mode)

For environments using BGP, you'll need to define peers in each environment:

```yaml
# Production BGP peers
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: router
  namespace: metallb-system
spec:
  peerASN: 64500
  myASN: 64501
  peerAddress: 192.0.2.1
```

### 5. Flux/GitOps Integration

The base configuration includes Flux HelmRelease custom resources. If your environment:
- Uses Flux: Ensure the correct namespace references and repositories
- Doesn't use Flux: Create an alternative installation method in your overlay

## Example Overlay Structure

```
clusters/
├── base/
│   └── infrastructure/
│       └── metallb/
│           ├── ...
├── local/
│   └── infrastructure/
│       └── metallb/
│           ├── kustomization.yaml
│           └── ipaddresspool-patch.yaml
├── staging/
│   └── ...
└── production/
    └── ...
```

Example overlay `kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../../base/infrastructure/metallb

patchesStrategicMerge:
  - ipaddresspool-patch.yaml
```

## Example Environments

This directory includes an `examples/` folder with sample overlay configurations for:
- **Local**: Simple L2 configuration with local network IP range
- **Staging**: Standard configuration with staging-specific IP ranges
- **Production**: Advanced configuration with high availability settings

These examples demonstrate proper customization for different environments and can be used
as templates when creating your actual environment overlays. 