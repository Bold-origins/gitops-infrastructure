# Cluster Health Diagnostic Report - Tue Mar  4 21:11:03 CET 2025
**LIGHTWEIGHT MODE** - Some resource-intensive checks skipped

## Kubernetes Version
```
```

## Node Status
```
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
minikube   Ready    control-plane   23h   v1.32.0   192.168.49.2   <none>        Ubuntu 22.04.5 LTS   6.10.14-linuxkit   docker://27.4.1
```

## Control Plane Components
```
coredns-668d6bf9bc-mt76s           1/1   Running   3 (5h15m ago)   23h
etcd-minikube                      1/1   Running   3 (5h15m ago)   23h
kube-apiserver-minikube            1/1   Running   3 (5h15m ago)   23h
kube-controller-manager-minikube   1/1   Running   3 (5h15m ago)   23h
kube-proxy-skh9k                   1/1   Running   3 (5h15m ago)   23h
... (truncated,       10 total pods in kube-system)
```

## Resource Usage
Resource usage metrics skipped in lightweight mode

## Storage Classes
```
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  23h
```

## Persistent Volumes
```
Total Persistent Volumes: 4
Total Persistent Volume Claims: 2
```

## Namespaces
```
NAME                   STATUS   AGE
cert-manager           Active   23h
default                Active   23h
example                Active   23h
flux-system            Active   11h
gatekeeper-system      Active   23h
ingress-nginx          Active   23h
kube-node-lease        Active   23h
kube-public            Active   23h
kube-system            Active   23h
kubernetes-dashboard   Active   23h
minio                  Active   9h
sealed-secrets         Active   23h
supabase               Active   9h
vault                  Active   23h
```

