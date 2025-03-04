# Example App Helm Chart

This Helm chart deploys an example application that demonstrates the integration of Vault and Sealed Secrets for managing sensitive information in a Kubernetes environment.

## Features

- Demonstrates Vault integration for dynamic secrets
- Shows how to use Sealed Secrets for static encrypted secrets
- Includes configurable probes for health checking
- Provides ingress configuration options
- Configurable resource limits and requests

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0+
- Vault installed and configured in the cluster
- Sealed Secrets controller installed in the cluster

## Installing the Chart

To install the chart with the release name `my-example-app`:

```bash
helm install my-example-app ./example-app
```

## Configuration

The following table lists the configurable parameters of the example-app chart and their default values.

| Parameter                         | Description                                                  | Default                               |
|-----------------------------------|--------------------------------------------------------------|---------------------------------------|
| `replicaCount`                    | Number of replicas                                           | `1`                                   |
| `image.repository`                | Image repository                                             | `busybox`                             |
| `image.tag`                       | Image tag                                                    | `latest`                              |
| `image.pullPolicy`                | Image pull policy                                            | `IfNotPresent`                        |
| `serviceAccount.create`           | Create service account                                       | `true`                                |
| `service.type`                    | Kubernetes Service type                                      | `ClusterIP`                           |
| `service.port`                    | Service port                                                 | `80`                                  |
| `service.targetPort`              | Service target port                                          | `8080`                                |
| `ingress.enabled`                 | Enable ingress                                               | `false`                               |
| `resources.limits.cpu`            | CPU resource limits                                          | `100m`                                |
| `resources.limits.memory`         | Memory resource limits                                       | `128Mi`                               |
| `resources.requests.cpu`          | CPU resource requests                                        | `50m`                                 |
| `resources.requests.memory`       | Memory resource requests                                     | `64Mi`                                |
| `vault.enabled`                   | Enable Vault integration                                     | `true`                                |
| `vault.role`                      | Vault role to use                                            | `example-app`                         |
| `vault.secretPath`                | Path to the secret in Vault                                  | `secret/data/example-app/database`    |
| `vault.secretFileName`            | Filename for the injected secret                             | `database-config.txt`                 |
| `sealedSecrets.enabled`           | Enable Sealed Secrets                                        | `true`                                |
| `sealedSecrets.data`              | Encrypted data for Sealed Secrets                            | `{}`                                  |
| `app.command`                     | Container command                                            | `["/bin/sh", "-c"]`                   |
| `app.args`                        | Container args                                               | See `values.yaml`                     |
| `probes.readiness.enabled`        | Enable readiness probe                                       | `true`                                |
| `probes.liveness.enabled`         | Enable liveness probe                                        | `true`                                |

## Secrets Management

### Vault Integration

This chart demonstrates how to use Vault for dynamic secrets management. The Vault Agent Injector is used to inject secrets from Vault into the pod as files.

To use Vault:

1. Ensure Vault is installed and configured in your cluster
2. Configure the `vault` section in `values.yaml`
3. The application will access secrets from the file at `/vault/secrets/database-config.txt`

### Sealed Secrets

This chart also demonstrates how to use Sealed Secrets for static encrypted secrets. Sealed Secrets allow you to store encrypted secrets in Git.

To use Sealed Secrets:

1. Ensure the Sealed Secrets controller is installed in your cluster
2. Create a sealed secret using the `kubeseal` CLI
3. Add the encrypted data to the `sealedSecrets.data` section in `values.yaml`
4. The application will access these secrets as environment variables

## Example Usage

```yaml
# Example values.yaml override
replicaCount: 2

vault:
  role: "custom-role"
  secretPath: "secret/data/my-app/credentials"

sealedSecrets:
  data:
    api-key: "AgBy8hCF8...encrypted-data..."
    api-secret: "AgBy8hCF8...encrypted-data..."

ingress:
  enabled: true
  hosts:
    - host: example.local
      paths:
        - path: /
          pathType: Prefix
``` 