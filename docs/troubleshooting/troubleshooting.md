# Troubleshooting Guide

This guide addresses common issues you might encounter with your Kubernetes GitOps cluster.

## Flux Issues

### Flux Components Not Reconciling

**Symptoms**: Components are not deploying or updating despite changes in Git.

**Troubleshooting Steps**:

1. Check Flux system status:
   ```bash
   flux check
   ```

2. View Flux system logs:
   ```bash
   kubectl -n flux-system logs deployment/source-controller
   kubectl -n flux-system logs deployment/kustomize-controller
   kubectl -n flux-system logs deployment/helm-controller
   ```

3. Check for reconciliation errors:
   ```bash
   flux get all --all-namespaces
   ```

4. Verify GitRepository status:
   ```bash
   flux get sources git --all-namespaces
   ```

5. Force manual reconciliation:
   ```bash
   flux reconcile kustomization flux-system --with-source
   ```

### Authentication Issues with Git Repository

**Symptoms**: Flux cannot access or pull from the Git repository.

**Troubleshooting Steps**:

1. Check deploy key access in GitHub repository settings
2. Verify GitRepository source status:
   ```bash
   kubectl -n flux-system describe gitrepository flux-system
   ```
3. Reset the deploy key:
   ```bash
   flux create secret git flux-system \
   --url=https://github.com/<username>/<repo> \
   --ssh-key-algorithm=ed25519 \
   --username=git \
   --password=<personal-access-token>
   ```

## Helm Release Issues

### Helm Releases Not Installing or Upgrading

**Symptoms**: Helm charts are not being installed or upgraded.

**Troubleshooting Steps**:

1. Check Helm release status:
   ```bash
   flux get helmreleases --all-namespaces
   ```

2. View Helm controller logs:
   ```bash
   kubectl -n flux-system logs deployment/helm-controller
   ```

3. Check for Chart availability:
   ```bash
   flux get sources helm --all-namespaces
   ```

4. Manually reconcile a HelmRelease:
   ```bash
   flux reconcile helmrelease <release-name> -n <namespace>
   ```

### Helm Repository Issues

**Symptoms**: Unable to fetch charts from Helm repositories.

**Troubleshooting Steps**:

1. Verify Helm repository status:
   ```bash
   flux get sources helm --all-namespaces
   ```

2. Check for network connectivity issues in the cluster
3. Verify the Helm repository URL is correct
4. Check if the Helm repository requires authentication

## Pod Startup Issues

### Pods Stuck in Pending State

**Symptoms**: Pods are stuck in a Pending state and not being scheduled.

**Troubleshooting Steps**:

1. Check pod status and events:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

2. Check for resource constraints:
   ```bash
   kubectl get nodes -o wide
   kubectl describe node <node-name>
   ```

3. Verify PersistentVolumeClaims are bound:
   ```bash
   kubectl get pvc -n <namespace>
   ```

4. Increase Minikube resources if needed:
   ```bash
   minikube stop
   minikube config set memory 10240
   minikube config set cpus 6
   minikube start
   ```

### Pods Crashing or Failing

**Symptoms**: Pods are in CrashLoopBackOff or Error state.

**Troubleshooting Steps**:

1. Check pod logs:
   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```

2. Describe the pod for events:
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

3. Check for configuration issues:
   ```bash
   kubectl get configmaps -n <namespace>
   kubectl get secrets -n <namespace>
   ```

## Networking Issues

### Services Not Accessible

**Symptoms**: Unable to access services via LoadBalancer or Ingress.

**Troubleshooting Steps**:

1. Check service status:
   ```bash
   kubectl get svc -n <namespace>
   ```

2. Verify MetalLB configuration:
   ```bash
   kubectl get ipaddresspools -n metallb-system
   kubectl get l2advertisements -n metallb-system
   ```

3. Check Ingress status:
   ```bash
   kubectl get ingress -A
   kubectl describe ingress <name> -n <namespace>
   ```

4. Verify Ingress controller logs:
   ```bash
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   ```

5. Check NetworkPolicies:
   ```bash
   kubectl get networkpolicies -A
   ```

### DNS Resolution Issues

**Symptoms**: Services cannot resolve other services by DNS name.

**Troubleshooting Steps**:

1. Check CoreDNS pods:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   kubectl logs -n kube-system -l k8s-app=kube-dns
   ```

2. Test DNS resolution from a test pod:
   ```bash
   kubectl run -it --rm debug --image=busybox -- nslookup kubernetes.default
   ```

## Observability Stack Issues

### Prometheus Not Scraping Metrics

**Symptoms**: Missing metrics in Grafana or Prometheus.

**Troubleshooting Steps**:

1. Check Prometheus targets:
   ```bash
   kubectl port-forward -n observability svc/prometheus-stack-prometheus 9090:9090
   ```
   Then browse to `http://localhost:9090/targets`

2. Verify ServiceMonitor configuration:
   ```bash
   kubectl get servicemonitors -A
   kubectl describe servicemonitor <name> -n <namespace>
   ```

3. Check Prometheus logs:
   ```bash
   kubectl logs -n observability prometheus-prometheus-stack-prometheus-0
   ```

### Grafana Cannot Connect to Prometheus

**Symptoms**: Grafana dashboards show "No data" errors.

**Troubleshooting Steps**:

1. Check Grafana datasource configuration:
   ```bash
   kubectl get configmap -n observability prometheus-stack-grafana
   ```

2. Verify connectivity between Grafana and Prometheus pods
3. Check Grafana logs:
   ```bash
   kubectl logs -n observability deployment/prometheus-stack-grafana
   ```

## Certificate Issues

### cert-manager Not Issuing Certificates

**Symptoms**: TLS certificates are not being issued or renewed.

**Troubleshooting Steps**:

1. Check Certificate status:
   ```bash
   kubectl get certificates -A
   kubectl describe certificate <name> -n <namespace>
   ```

2. Verify ClusterIssuer status:
   ```bash
   kubectl get clusterissuers
   kubectl describe clusterissuer <name>
   ```

3. Check cert-manager logs:
   ```bash
   kubectl logs -n cert-manager deployment/cert-manager
   ```

## Sealed Secrets Issues

### Unable to Decrypt Sealed Secrets

**Symptoms**: Sealed Secrets controller cannot decrypt sealed secrets.

**Troubleshooting Steps**:

1. Verify Sealed Secrets controller is running:
   ```bash
   kubectl get pods -n sealed-secrets
   ```

2. Check Sealed Secrets controller logs:
   ```bash
   kubectl logs -n sealed-secrets deployment/sealed-secrets
   ```

3. Ensure the secret was sealed using the correct controller
4. Re-seal the secret if needed

## Resource Constraints

### Cluster Performance Issues

**Symptoms**: Slow response times, pod scheduling delays.

**Troubleshooting Steps**:

1. Check node resource utilization:
   ```bash
   kubectl top nodes
   kubectl top pods -A
   ```

2. Review resource requests and limits:
   ```bash
   kubectl get pods -o=custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,CPU_REQUEST:.spec.containers[*].resources.requests.cpu,MEMORY_REQUEST:.spec.containers[*].resources.requests.memory,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEMORY_LIMIT:.spec.containers[*].resources.limits.memory -A
   ```

3. Increase Minikube resources:
   ```bash
   minikube stop
   minikube config set memory 12288
   minikube config set cpus 8
   minikube start
   ```

## Minikube-Specific Issues

### Minikube Addons Not Working

**Symptoms**: Ingress, metrics-server, or registry addons not functioning.

**Troubleshooting Steps**:

1. Verify addon status:
   ```bash
   minikube addons list
   ```

2. Disable and re-enable the addon:
   ```bash
   minikube addons disable <addon-name>
   minikube addons enable <addon-name>
   ```

3. Check addon logs:
   ```bash
   minikube logs | grep <addon-name>
   ```

### Docker Driver Issues

**Symptoms**: Problems with Docker driver connectivity or performance.

**Troubleshooting Steps**:

1. Check Docker daemon status:
   ```bash
   docker info
   ```

2. Verify Docker resources allocation
3. Try an alternative driver:
   ```bash
   minikube stop
   minikube delete
   minikube start --driver=hyperkit # or virtualbox, depending on OS
   ``` 