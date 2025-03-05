# Security & Policy Diagnostic Report - Tue Mar  4 20:29:22 CET 2025

## OPA Gatekeeper Status
```
NAME                                             READY   STATUS    RESTARTS        AGE
gatekeeper-audit-7f54f98bbc-ztwf6                1/1     Running   7 (4h33m ago)   9h
gatekeeper-controller-manager-5c87d9b9b4-7r9pz   1/1     Running   7 (4h33m ago)   9h
```
### Constraint Templates
```
```
### Constraints
```
No Constraints found
```

## Network Policies
```
NAMESPACE     NAME                     POD-SELECTOR                      AGE
example       example-network-policy   app=example-app,part-of=example   22h
flux-system   allow-egress             <none>                            11h
flux-system   allow-scraping           <none>                            11h
flux-system   allow-webhooks           app=notification-controller       11h
```

## RBAC Configuration Summary
### Roles
```
NAMESPACE              NAME                                             CREATED AT
gatekeeper-system      gatekeeper-manager-role                          2025-03-04T09:49:36Z
ingress-nginx          ingress-nginx                                    2025-03-03T20:21:41Z
ingress-nginx          ingress-nginx-admission                          2025-03-03T20:21:41Z
kube-public            kubeadm:bootstrap-signer-clusterinfo             2025-03-03T20:21:31Z
kube-public            system:controller:bootstrap-signer               2025-03-03T20:21:30Z
kube-system            extension-apiserver-authentication-reader        2025-03-03T20:21:30Z
kube-system            kube-proxy                                       2025-03-03T20:21:32Z
kube-system            kubeadm:kubelet-config                           2025-03-03T20:21:31Z
kube-system            kubeadm:nodes-kubeadm-config                     2025-03-03T20:21:31Z
kube-system            system::leader-locking-kube-controller-manager   2025-03-03T20:21:30Z
kube-system            system::leader-locking-kube-scheduler            2025-03-03T20:21:30Z
kube-system            system:controller:bootstrap-signer               2025-03-03T20:21:30Z
kube-system            system:controller:cloud-provider                 2025-03-03T20:21:30Z
kube-system            system:controller:token-cleaner                  2025-03-03T20:21:30Z
kube-system            system:persistent-volume-provisioner             2025-03-03T20:21:33Z
kubernetes-dashboard   kubernetes-dashboard                             2025-03-03T20:21:53Z
```
### ClusterRoles
```
NAME                                                                   CREATED AT
admin                                                                  2025-03-03T20:21:30Z
cert-manager                                                           2025-03-03T20:32:33Z
cluster-admin                                                          2025-03-03T20:21:30Z
crd-controller-flux-system                                             2025-03-04T08:17:24Z
edit                                                                   2025-03-03T20:21:30Z
flux-edit-flux-system                                                  2025-03-04T08:17:24Z
flux-view-flux-system                                                  2025-03-04T08:17:24Z
gatekeeper-admin                                                       2025-03-03T20:32:33Z
gatekeeper-manager-role                                                2025-03-04T09:58:49Z
ingress-nginx                                                          2025-03-03T20:21:41Z
ingress-nginx-admission                                                2025-03-03T20:21:41Z
kubeadm:get-nodes                                                      2025-03-03T20:21:31Z
kubernetes-dashboard                                                   2025-03-03T20:21:53Z
sealed-secrets-controller                                              2025-03-03T20:32:33Z
view                                                                   2025-03-03T20:21:30Z
```
