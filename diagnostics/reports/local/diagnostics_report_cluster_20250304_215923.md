# Cluster Health Diagnostic Report - Tue Mar  4 21:59:23 CET 2025

## Kubernetes Version
```
```

## Node Status
```
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
minikube   Ready    control-plane   24h   v1.32.0   192.168.49.2   <none>        Ubuntu 22.04.5 LTS   6.10.14-linuxkit   docker://27.4.1
```

## Control Plane Components
```
NAME                               READY   STATUS    RESTARTS       AGE
coredns-668d6bf9bc-mt76s           1/1     Running   3 (6h3m ago)   24h
etcd-minikube                      1/1     Running   3 (6h3m ago)   24h
kube-apiserver-minikube            1/1     Running   3 (6h3m ago)   24h
kube-controller-manager-minikube   1/1     Running   3 (6h3m ago)   24h
kube-proxy-skh9k                   1/1     Running   3 (6h3m ago)   24h
kube-scheduler-minikube            1/1     Running   3 (6h3m ago)   24h
metrics-server-7fbb699795-nwz85    1/1     Running   8 (6h3m ago)   24h
registry-6c86875c6f-znjcd          1/1     Running   3 (6h3m ago)   24h
registry-proxy-2j8zj               1/1     Running   3 (6h3m ago)   24h
storage-provisioner                1/1     Running   9 (177m ago)   24h
```

## Resource Usage
```
NODE RESOURCE USAGE:

POD RESOURCE USAGE (TOP 10):
```

## Storage Classes
```
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  24h
```

## Persistent Volumes
```
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                                    STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-2ed381f1-6924-434a-903d-7e26721a97e4   10Gi       RWO            Delete           Bound      minio/minio                              standard       <unset>                          39m
persistentvolume/pvc-36039549-8bcb-4c1e-aaaa-8be285f3c14d   10Gi       RWO            Delete           Released   supabase/supabase-supabase-storage-pvc   standard       <unset>                          6h5m
persistentvolume/pvc-3bf0e265-e844-4276-9c74-64112f1f6d90   20Gi       RWO            Delete           Released   supabase/supabase-supabase-db-pvc        standard       <unset>                          9h
persistentvolume/pvc-434eb3e4-60c7-4cc8-a0f4-332e88e608ee   20Gi       RWO            Delete           Released   supabase/supabase-supabase-db-pvc        standard       <unset>                          6h5m
persistentvolume/pvc-5f2ed697-0615-42f7-9589-96685dcc40b5   10Gi       RWO            Delete           Released   supabase/supabase-supabase-storage-pvc   standard       <unset>                          9h

NAMESPACE   NAME                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
minio       persistentvolumeclaim/minio   Bound    pvc-2ed381f1-6924-434a-903d-7e26721a97e4   10Gi       RWO            standard       <unset>                 39m
```

## Namespaces
```
NAME                   STATUS   AGE
cert-manager           Active   24h
default                Active   24h
example                Active   24h
flux-system            Active   12h
gatekeeper-system      Active   24h
kube-node-lease        Active   24h
kube-public            Active   24h
kube-system            Active   24h
kubernetes-dashboard   Active   24h
minio                  Active   9h
sealed-secrets         Active   24h
supabase               Active   10h
vault                  Active   24h
```

