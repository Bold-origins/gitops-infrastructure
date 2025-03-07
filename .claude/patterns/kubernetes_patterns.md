# Kubernetes Patterns

This document outlines common Kubernetes patterns used in this repository.

## GitOps Patterns

### Flux Kustomization Pattern

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: component-name
  namespace: flux-system
spec:
  interval: 5m
  path: ./clusters/base/infrastructure/component-name
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: component-name
      namespace: component-namespace
  timeout: 3m
```

### Flux HelmRelease Pattern

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: component-name
  namespace: component-namespace
spec:
  interval: 5m
  chart:
    spec:
      chart: chart-name
      version: "chart-version"
      sourceRef:
        kind: HelmRepository
        name: repo-name
        namespace: flux-system
  values:
    # Default values
  valuesFrom:
    - kind: ConfigMap
      name: component-values
      valuesKey: values.yaml
```

## Sealed Secrets Pattern

### Template Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: template-secret
  namespace: component-namespace
  annotations:
    sealedsecrets.bitnami.com/template: "true"
type: Opaque
data:
  # Base64 encoded placeholders
  username: dXNlcm5hbWU=  # "username"
  password: cGFzc3dvcmQ=  # "password"
```

### Sealed Secret

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: actual-secret
  namespace: component-namespace
spec:
  encryptedData:
    username: AgBy8hCZ...
    password: AgBy8hCZ...
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/managed: "true"
    type: Opaque
```

## Ingress Pattern

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: component-ingress
  namespace: component-namespace
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  rules:
  - host: component.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: component-service
            port:
              number: 80
  tls:
  - hosts:
    - component.example.com
    secretName: component-tls
```

## Kustomize Patches Pattern

### Strategic Merge Patch

```yaml
# Original resource
apiVersion: apps/v1
kind: Deployment
metadata:
  name: component-deployment
  namespace: component-namespace
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: component
        image: component:latest
```

```yaml
# Patch
apiVersion: apps/v1
kind: Deployment
metadata:
  name: component-deployment
  namespace: component-namespace
spec:
  replicas: 3  # Overrides the original value
  template:
    spec:
      containers:
      - name: component
        resources:  # Adds resources configuration
          limits:
            cpu: 1
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi
```

### JSON Patch

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base
patchesJson6902:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: component-deployment
      namespace: component-namespace
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
      - op: add
        path: /spec/template/spec/containers/0/resources
        value:
          limits:
            cpu: 1
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi
```

## Configuration Pattern

### ConfigMap for Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: component-config
  namespace: component-namespace
data:
  config.yaml: |
    key1: value1
    key2: value2
    nested:
      key3: value3
```

### Secret for Sensitive Configuration

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: component-secret
  namespace: component-namespace
type: Opaque
data:
  username: dXNlcm5hbWU=  # Base64 encoded "username"
  password: cGFzc3dvcmQ=  # Base64 encoded "password"
```

## Service Pattern

### ClusterIP Service (default)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: component-service
  namespace: component-namespace
spec:
  type: ClusterIP
  selector:
    app: component
  ports:
  - port: 80
    targetPort: 8080
```

### LoadBalancer Service (with MetalLB)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: component-lb
  namespace: component-namespace
spec:
  type: LoadBalancer
  selector:
    app: component
  ports:
  - port: 80
    targetPort: 8080
```

## Volumes Pattern

### PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: component-data
  namespace: component-namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
```

### Deployment with Volume

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: component-deployment
  namespace: component-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: component
  template:
    metadata:
      labels:
        app: component
    spec:
      containers:
      - name: component
        image: component:latest
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: component-data
```

## Health Check Pattern

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: component-deployment
  namespace: component-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: component
  template:
    metadata:
      labels:
        app: component
    spec:
      containers:
      - name: component
        image: component:latest
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

## Resource Limits Pattern

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: component-deployment
  namespace: component-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: component
  template:
    metadata:
      labels:
        app: component
    spec:
      containers:
      - name: component
        image: component:latest
        resources:
          limits:
            cpu: 1
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi
```