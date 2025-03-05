# Cluster Health Diagnostic Report - Tue Mar  4 20:29:21 CET 2025
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
coredns-668d6bf9bc-mt76s           1/1   Running   3 (4h33m ago)   23h
etcd-minikube                      1/1   Running   3 (4h33m ago)   23h
kube-apiserver-minikube            1/1   Running   3 (4h33m ago)   23h
kube-controller-manager-minikube   1/1   Running   3 (4h33m ago)   23h
kube-proxy-skh9k                   1/1   Running   3 (4h33m ago)   23h
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
cert-manager           Active   22h
default                Active   23h
example                Active   22h
flux-system            Active   11h
gatekeeper-system      Active   22h
ingress-nginx          Active   23h
kube-node-lease        Active   23h
kube-public            Active   23h
kube-system            Active   23h
kubernetes-dashboard   Active   23h
minio                  Active   8h
sealed-secrets         Active   22h
supabase               Active   8h
vault                  Active   22h
```

