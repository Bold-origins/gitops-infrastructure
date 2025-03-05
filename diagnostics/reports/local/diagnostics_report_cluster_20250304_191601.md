# Cluster Health Diagnostic Report - Tue Mar  4 19:16:01 CET 2025
**LIGHTWEIGHT MODE** - Some resource-intensive checks skipped

## Kubernetes Version
```
```

## Node Status
```
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
minikube   Ready    control-plane   21h   v1.32.0   192.168.49.2   <none>        Ubuntu 22.04.5 LTS   6.10.14-linuxkit   docker://27.4.1
```

## Control Plane Components
```
coredns-668d6bf9bc-mt76s           1/1   Running   3 (3h20m ago)   21h
etcd-minikube                      1/1   Running   3 (3h20m ago)   21h
kube-apiserver-minikube            1/1   Running   3 (3h20m ago)   21h
kube-controller-manager-minikube   1/1   Running   3 (3h20m ago)   21h
kube-proxy-skh9k                   1/1   Running   3 (3h20m ago)   21h
... (truncated,       10 total pods in kube-system)
```

## Resource Usage
Resource usage metrics skipped in lightweight mode

## Storage Classes
```
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  21h
```

## Persistent Volumes
```
Total Persistent Volumes: 4
Total Persistent Volume Claims: 2
```

## Namespaces
```
NAME                   STATUS   AGE
cert-manager           Active   21h
default                Active   21h
example                Active   21h
flux-system            Active   9h
gatekeeper-system      Active   21h
ingress-nginx          Active   21h
kube-node-lease        Active   21h
kube-public            Active   21h
kube-system            Active   21h
kubernetes-dashboard   Active   21h
minio                  Active   7h10m
sealed-secrets         Active   21h
supabase               Active   7h43m
vault                  Active   21h
```

