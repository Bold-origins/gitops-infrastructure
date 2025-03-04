# MinIO Configuration

MinIO is an S3-compatible object storage service used by Supabase for file storage.

## Credentials

For security reasons, the MinIO credentials should be managed as follows:

1. **Local Development:**
   - Create a `secret.yaml` file in this directory with your MinIO credentials (this file is gitignored)
   - Example format:
     ```yaml
     apiVersion: v1
     kind: Secret
     metadata:
       name: minio-credentials
       namespace: minio
     type: Opaque
     stringData:
       rootUser: minioadmin
       rootPassword: YOUR_SECURE_PASSWORD
     ```

2. **Production/Staging Environments:**
   - Use sealed-secrets for secure credential management
   - Create the sealed secret using:
     ```bash
     # Create the secret
     kubectl create secret generic minio-credentials \
       --namespace=minio \
       --from-literal=rootUser=YOUR_USERNAME \
       --from-literal=rootPassword=YOUR_SECURE_PASSWORD \
       --dry-run=client -o yaml > temp-secret.yaml
     
     # Seal the secret
     kubeseal --controller-name=sealed-secrets \
       --controller-namespace=sealed-secrets \
       --format yaml < temp-secret.yaml > sealed-secret.yaml
     
     # Clean up the temporary file
     rm temp-secret.yaml
     ```

## Do Not Commit Plaintext Secrets

**IMPORTANT:** Never commit plaintext secrets to the repository. The `secret.yaml` file is already added to `.gitignore` to prevent accidental commits. 