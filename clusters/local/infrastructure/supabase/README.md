# Supabase for GitOps Kubernetes

This directory contains the necessary files to deploy Supabase to a Kubernetes cluster using GitOps with Flux.

## Components

Supabase consists of several services that work together:

- **PostgreSQL Database**: The core database that stores all data
- **Auth Service**: Authentication and authorization service
- **Storage Service**: File storage service integrated with S3-compatible storage (MinIO)
- **Realtime Service**: Realtime subscriptions service
- **API Service**: REST and GraphQL APIs
- **Studio**: Web-based admin dashboard
- **Vector**: Logging and metrics collection
- **Analytics**: Analytics service

## Configuration

The deployment uses the following components:

1. **GitRepository** - References the Supabase community Kubernetes Helm charts repository
2. **HelmRelease** - Defines how to deploy Supabase using the Helm chart
3. **ConfigMap** - Contains the values for configuring the Supabase deployment
4. **SealedSecret** - Contains encrypted sensitive data like JWT tokens

## Security

Sensitive information like JWT keys are stored as SealedSecrets, which are encrypted and safe to store in Git. The credentials are only decrypted when deployed to the cluster with the correct key.

## Integration with MinIO

This deployment is configured to use the existing MinIO deployment for storage. The Storage service is configured to connect to the MinIO service in the cluster.

## Accessing the Services

Supabase is exposed via an Ingress at `http://supabase.local`. You may need to add this to your hosts file to access it locally.

The admin dashboard can be accessed at `http://supabase.local` with the credentials specified in the configuration:
- Username: admin
- Password: change_me_immediately (you should change this in production)

## Production Considerations

For production use, consider:

1. Changing all default passwords and credentials
2. Using proper TLS certificates with cert-manager
3. Using a production-ready PostgreSQL deployment with replication
4. Implementing proper backup strategies
5. Scaling resources based on actual usage
6. Creating additional SealedSecrets for SMTP, database, and other credentials 