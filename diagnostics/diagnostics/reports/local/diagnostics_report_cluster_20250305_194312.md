# Cluster Health Diagnostic Report - Wed Mar  5 19:43:12 CET 2025

## Kubernetes Version
```
```

## Node Status
```
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
minikube   Ready    control-plane   46h   v1.32.0   192.168.49.2   <none>        Ubuntu 22.04.5 LTS   6.10.14-linuxkit   docker://27.4.1
```

## Control Plane Components
```
NAME                               READY   STATUS    RESTARTS      AGE
coredns-668d6bf9bc-mt76s           1/1     Running   3 (27h ago)   46h
etcd-minikube                      1/1     Running   3 (27h ago)   46h
kube-apiserver-minikube            1/1     Running   3 (27h ago)   46h
kube-controller-manager-minikube   1/1     Running   3 (27h ago)   46h
kube-proxy-skh9k                   1/1     Running   3 (27h ago)   46h
kube-scheduler-minikube            1/1     Running   3 (27h ago)   46h
metrics-server-7fbb699795-nwz85    1/1     Running   8 (27h ago)   46h
registry-6c86875c6f-znjcd          1/1     Running   3 (27h ago)   46h
registry-proxy-2j8zj               1/1     Running   3 (27h ago)   46h
storage-provisioner                1/1     Running   9 (24h ago)   46h
```

## Resource Usage
```
NODE RESOURCE USAGE:

POD RESOURCE USAGE (TOP 10):
```

## Storage Classes
```
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  46h
```

## Persistent Volumes
```
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                                    STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-042bfc8a-4887-46af-ad06-a4417eba94f0   5Gi        RWO            Delete           Bound      observability/grafana                    standard       <unset>                          4h32m
persistentvolume/pvc-36039549-8bcb-4c1e-aaaa-8be285f3c14d   10Gi       RWO            Delete           Released   supabase/supabase-supabase-storage-pvc   standard       <unset>                          27h
persistentvolume/pvc-3bf0e265-e844-4276-9c74-64112f1f6d90   20Gi       RWO            Delete           Released   supabase/supabase-supabase-db-pvc        standard       <unset>                          30h
persistentvolume/pvc-434eb3e4-60c7-4cc8-a0f4-332e88e608ee   20Gi       RWO            Delete           Released   supabase/supabase-supabase-db-pvc        standard       <unset>                          27h
persistentvolume/pvc-5564a2ac-f777-40c4-ae3e-eb96b9118603   10Gi       RWO            Delete           Bound      minio/minio                              standard       <unset>                          64m
persistentvolume/pvc-5f2ed697-0615-42f7-9589-96685dcc40b5   10Gi       RWO            Delete           Released   supabase/supabase-supabase-storage-pvc   standard       <unset>                          30h
persistentvolume/pvc-6df64144-4080-4ae0-9ac9-0e9e4211af62   10Gi       RWO            Delete           Bound      supabase/supabase-supabase-storage-pvc   standard       <unset>                          34m
persistentvolume/pvc-ccc93a39-8489-4bc3-9eda-0426a61e7935   20Gi       RWO            Delete           Bound      supabase/supabase-supabase-db-pvc        standard       <unset>                          34m

NAMESPACE       NAME                                                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
minio           persistentvolumeclaim/minio                           Bound    pvc-5564a2ac-f777-40c4-ae3e-eb96b9118603   10Gi       RWO            standard       <unset>                 64m
observability   persistentvolumeclaim/grafana                         Bound    pvc-042bfc8a-4887-46af-ad06-a4417eba94f0   5Gi        RWO            standard       <unset>                 4h32m
supabase        persistentvolumeclaim/supabase-supabase-db-pvc        Bound    pvc-ccc93a39-8489-4bc3-9eda-0426a61e7935   20Gi       RWO            standard       <unset>                 34m
supabase        persistentvolumeclaim/supabase-supabase-storage-pvc   Bound    pvc-6df64144-4080-4ae0-9ac9-0e9e4211af62   10Gi       RWO            standard       <unset>                 34m
```

## Namespaces
```
NAME                   STATUS   AGE
cert-manager           Active   21m
default                Active   46h
example                Active   46h
flux-system            Active   34h
gatekeeper-system      Active   29m
ingress-nginx          Active   79m
kube-node-lease        Active   46h
kube-public            Active   46h
kube-system            Active   46h
kubernetes-dashboard   Active   46h
metallb-system         Active   179m
minio                  Active   79m
monitoring             Active   102m
observability          Active   4h32m
sealed-secrets         Active   79m
security               Active   29m
supabase               Active   65m
vault                  Active   36m
```

