# Local Environment Troubleshooting Guide

This document provides solutions for common issues encountered when setting up and running the local Minikube environment.

## Minikube Issues

### Insufficient Resources

**Symptom:** Minikube fails to start or components crash frequently.

**Solution:**
```bash
# Stop minikube
minikube stop

# Start with increased resources
minikube start --memory 10240 --cpus 6 --disk-size 40g
```

### Connection Refused

**Symptom:** `kubectl` commands fail with "connection refused" errors.

**Solution:**
```bash
# Verify minikube status
minikube status

# If minikube is not running, start it
minikube start

# If still having issues, try recreating the minikube context
minikube delete
./scripts/cluster/setup-minikube.sh
```

### Local Domain Resolution

**Symptom:** Cannot access services via `.local` domains.

**Solution:**
```bash
# Check if ingress addon is enabled
minikube addons list

# Enable ingress if not enabled
minikube addons enable ingress

# Verify hosts file entries
sudo cat /etc/hosts | grep local

# Add missing entries
echo "$(minikube ip) grafana.local prometheus.local vault.local supabase.local" | sudo tee -a /etc/hosts
```

## Infrastructure Component Issues

### Cert-Manager

**Symptom:** Certificate issuance fails, TLS errors.

**Solution:**
```bash
# Check cert-manager pod status
kubectl get pods -n cert-manager

# View logs of the cert-manager pod
kubectl logs -n cert-manager -l app=cert-manager

# Verify ClusterIssuers
kubectl get clusterissuers

# Create self-signed issuer if missing
kubectl apply -f clusters/local/infrastructure/cert-manager/patches/self-signed-issuer.yaml
```

### Sealed Secrets

**Symptom:** Unable to decrypt secrets, pods failing due to missing secrets.

**Solution:**
```bash
# Check if sealed secrets controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Recreate controller and secrets (Warning: this will require resealing all secrets)
kubectl delete -f clusters/local/infrastructure/sealed-secrets/
kubectl apply -k clusters/local/infrastructure/sealed-secrets/
```

### Vault

**Symptom:** Vault is sealed or inaccessible.

**Solution:**
```bash
# Check vault status
kubectl exec -it vault-0 -n vault -- vault status

# Unseal vault if sealed
./scripts/components/vault-unseal.sh

# If needed, reinitialize vault
./scripts/components/vault-init.sh
```

## Networking Issues

### Ingress Not Working

**Symptom:** Unable to access services through ingress.

**Solution:**
```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress --all-namespaces

# Verify ingress controller service
kubectl get svc -n ingress-nginx

# Restart ingress controller if needed
kubectl rollout restart deployment -n ingress-nginx ingress-nginx-controller
```

### MetalLB Issues

**Symptom:** LoadBalancer services stuck in pending state.

**Solution:**
```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Verify address pool configuration
kubectl get cm -n metallb-system config -o yaml

# Check logs
kubectl logs -n metallb-system -l app=metallb

# Recreate MetalLB if needed
kubectl apply -k clusters/local/infrastructure/metallb
```

## Observability Issues

### Prometheus Not Collecting Metrics

**Symptom:** No metrics in Prometheus or data missing in Grafana.

**Solution:**
```bash
# Check Prometheus pods
kubectl get pods -n observability

# Check ServiceMonitor resources
kubectl get servicemonitors --all-namespaces

# Check PodMonitor resources
kubectl get podmonitors --all-namespaces

# Verify storage (PVCs)
kubectl get pvc -n observability

# Restart Prometheus if needed
kubectl rollout restart statefulset -n observability prometheus-prometheus
```

### Grafana Issues

**Symptom:** Cannot access Grafana or dashboards missing.

**Solution:**
```bash
# Check Grafana pod
kubectl get pods -n observability -l app.kubernetes.io/name=grafana

# Verify Grafana service
kubectl get svc -n observability -l app.kubernetes.io/name=grafana

# Check Grafana logs
kubectl logs -n observability -l app.kubernetes.io/name=grafana

# Reset Grafana admin password
kubectl delete secret -n observability grafana-admin-credentials
kubectl apply -f clusters/local/observability/grafana/patches/admin-credentials.yaml
```

### Loki Log Issues

**Symptom:** Logs not appearing in Grafana/Loki.

**Solution:**
```bash
# Check Loki pods
kubectl get pods -n observability -l app=loki

# Check Promtail pods (log collectors)
kubectl get pods -n observability -l app=promtail

# View Promtail logs
kubectl logs -n observability -l app=promtail

# Restart log collection
kubectl rollout restart daemonset -n observability promtail
```

## Application Issues

### Supabase Connectivity

**Symptom:** Cannot connect to Supabase services.

**Solution:**
```bash
# Check Supabase pods
kubectl get pods -n supabase

# Check individual services
kubectl get svc -n supabase

# Verify database init job completed
kubectl get jobs -n supabase

# Check database logs
kubectl logs -n supabase -l app=postgres

# Reset Supabase instance
kubectl delete -f clusters/local/applications/supabase/
kubectl apply -k clusters/local/applications/supabase/
```

## Flux Issues

### GitOps Sync Failures

**Symptom:** Flux not syncing changes from Git.

**Solution:**
```bash
# Check Flux components
kubectl get pods -n flux-system

# Check GitRepository resource
kubectl get gitrepositories -n flux-system

# Check Kustomization resources
kubectl get kustomizations -n flux-system

# View reconciliation logs
kubectl logs -n flux-system -l app=source-controller
kubectl logs -n flux-system -l app=kustomize-controller

# Trigger manual reconciliation
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

## Complete Environment Reset

If all else fails, you can reset everything and start fresh:

```bash
# Delete the entire Minikube cluster
minikube delete

# Remove any leftover files
rm -rf ~/.minikube

# Start fresh setup
./scripts/cluster/setup-minikube.sh
./scripts/cluster/setup-all.sh
```

## Performance Optimization

If the environment is running slowly:

```bash
# Reduce resource usage
kubectl scale deployment -n observability prometheus-operator --replicas=0 # temporarily disable operator
kubectl patch prometheus -n observability prometheus-prometheus --type merge -p '{"spec":{"resources":{"requests":{"memory":"512Mi","cpu":"100m"}}}}'
kubectl patch deployment -n observability grafana --type merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"grafana","resources":{"requests":{"memory":"128Mi","cpu":"50m"}}}]}}}}'

# Reduce logging verbosity
kubectl patch cm -n observability loki --type merge -p '{"data":{"loki.yaml":"log_level: warn"}}'
```

## Getting Help

If you've tried the solutions above and still have issues:

1. Gather diagnostic information with `./scripts/cluster/collect-diagnostics.sh`
2. Check the issue tracker on the project repository
3. Contact the development team with the diagnostic information 