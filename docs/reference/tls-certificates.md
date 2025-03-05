# TLS Certificates Management

This document explains how TLS certificates are managed in our Kubernetes GitOps infrastructure using cert-manager.

## Overview

Our cluster uses cert-manager to automate the management and issuance of TLS certificates. The following issuers are configured:

1. **Self-Signed Issuer**: For local development and testing
2. **Let's Encrypt Staging**: For testing certificate issuance without hitting rate limits
3. **Let's Encrypt Production**: For production-ready certificates

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Ingress   │────▶│ Certificate │────▶│ ClusterIssuer│
│  Resources  │     │  Resources  │     │   Resources  │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │ Let's Encrypt│
                                        │  or SelfSigned│
                                        └─────────────┘
```

## Certificate Issuers

### Self-Signed Issuer

Used for:
- Local development
- Testing environments
- Situations where external validation is not possible

Configuration:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
```

### Let's Encrypt Staging

Used for:
- Testing certificate issuance process
- Development environments requiring real certificates
- Avoiding rate limits during testing

Configuration:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: rodrigo.mourey@boldorigins.io
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Let's Encrypt Production

Used for:
- Production environments
- Public-facing services requiring trusted certificates

Configuration:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: rodrigo.mourey@boldorigins.io
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

## Using Certificates with Services

To use certificates with your services, add annotations to your Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    # Use self-signed for local development
    cert-manager.io/cluster-issuer: "selfsigned-cluster-issuer"
    
    # Use staging for testing real certificate issuance
    # cert-manager.io/cluster-issuer: "letsencrypt-staging"
    
    # Use production for real, trusted certificates
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - example.local
    secretName: example-tls
  rules:
  - host: example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

## Local Testing with Minikube

For local testing with Minikube, you can use cert-manager with either self-signed certificates or DNS validation with Let's Encrypt.

### Using Self-Signed Certificates with Minikube

1. Start Minikube with the ingress addon:
   ```bash
   minikube start --memory 4096 --cpus 2 --addons ingress
   ```

2. Deploy cert-manager and the self-signed issuer:
   ```bash
   kubectl apply -k clusters/local/infrastructure/cert-manager
   ```

3. Update your local hosts file to map your service domain to the Minikube IP:
   ```bash
   echo "$(minikube ip) example.local" | sudo tee -a /etc/hosts
   ```

4. Deploy your service with an Ingress using the self-signed issuer

5. Access your service at https://example.local (ignore browser warnings)

### DNS Validation for Let's Encrypt in Local Development

For testing Let's Encrypt with DNS validation locally:

1. Set up a domain with a DNS provider that has an API (like Cloudflare, Route53)

2. Create a Secret with your DNS provider API credentials:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: cloudflare-api-token
     namespace: cert-manager
   type: Opaque
   stringData:
     api-token: your-api-token-here
   ```

3. Update the ClusterIssuer to use DNS validation:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-staging
   spec:
     acme:
       server: https://acme-staging-v02.api.letsencrypt.org/directory
       email: rodrigo.mourey@boldorigins.io
       privateKeySecretRef:
         name: letsencrypt-staging-account-key
       solvers:
       - dns01:
           cloudflare:
             apiTokenSecretRef:
               name: cloudflare-api-token
               key: api-token
   ```

## Troubleshooting

### Certificate Not Issued

Check the status of your Certificate resource:
```bash
kubectl get certificate -A
```

Check events:
```bash
kubectl describe certificate <name> -n <namespace>
```

Check cert-manager logs:
```bash
kubectl logs -n cert-manager -l app=cert-manager
```

### Ingress Not Picking Up Certificates

Ensure your Ingress has the correct annotations and TLS configuration:
```bash
kubectl describe ingress <name> -n <namespace>
```

Check that the Secret containing the TLS certificate exists:
```bash
kubectl get secret <tls-secret-name> -n <namespace>
```

## Best Practices

1. Always use the staging issuer before using the production issuer to avoid rate limits
2. Use descriptive names for Certificate resources
3. Set appropriate renewal and duration settings for certificates
4. Monitor certificate expiration dates
5. Configure alerts for certificate renewal failures 