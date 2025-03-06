#!/bin/bash
# Script to reset Vault deployment to a clean state

set -e

echo "WARNING: This will completely reset Vault, removing all secrets and configurations."
echo "All existing keys and tokens will be invalidated."
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Operation cancelled."
    exit 1
fi

echo "Resetting Vault..."

# Delete the existing Vault pod to force recreation
echo "Deleting Vault pod..."
kubectl delete pod -n vault -l app=vault --force --grace-period=0

# Wait for new pod to start
echo "Waiting for new Vault pod to start..."
sleep 5
kubectl wait --for=condition=Ready pod -n vault -l app=vault --timeout=60s

# Get the name of the new pod
POD_NAME=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
echo "New Vault pod name: $POD_NAME"

# Initialize Vault
echo "Initializing Vault..."
INIT_OUTPUT=$(kubectl exec -it -n vault $POD_NAME -- \
  /bin/sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator init -key-shares=1 -key-threshold=1 -format=json")

# Extract unseal key and root token
UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')

# Save to .env file
sed -i '' "s|VAULT_UNSEAL_KEY=\".*\"|VAULT_UNSEAL_KEY=\"$UNSEAL_KEY\"|g" .env
sed -i '' "s|VAULT_ROOT_TOKEN=\".*\"|VAULT_ROOT_TOKEN=\"$ROOT_TOKEN\"|g" .env

# Create the secrets directory if it doesn't exist
mkdir -p secrets

# Also save to a dedicated secrets file
echo "Vault Credentials" > secrets/vault_credentials.txt
echo "=================" >> secrets/vault_credentials.txt
echo "Unseal Key: $UNSEAL_KEY" >> secrets/vault_credentials.txt
echo "Root Token: $ROOT_TOKEN" >> secrets/vault_credentials.txt
echo "" >> secrets/vault_credentials.txt
echo "Keep this information secure and backed up!" >> secrets/vault_credentials.txt

# Unseal Vault
echo "Unsealing Vault..."
kubectl exec -it -n vault $POD_NAME -- \
  /bin/sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator unseal $UNSEAL_KEY"

# Create a SealedSecret for the Vault credentials
echo "Creating a SealedSecret for Vault credentials..."
cat <<EOF > secrets/vault-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: vault-credentials
  namespace: vault
type: Opaque
stringData:
  unsealKey: $UNSEAL_KEY
  rootToken: $ROOT_TOKEN
EOF

# Seal the Secret
mkdir -p clusters/local/infrastructure/vault/sealed-secrets
kubeseal --controller-namespace=sealed-secrets --controller-name=sealed-secrets < secrets/vault-credentials.yaml > clusters/local/infrastructure/vault/sealed-secrets/vault-credentials-sealed.yaml

echo ""
echo "Vault has been reset and unsealed."
echo "Credentials have been saved to secrets/vault_credentials.txt and updated in .env file."
echo "A SealedSecret has been created at clusters/local/infrastructure/vault/sealed-secrets/vault-credentials-sealed.yaml"
echo ""
echo "IMPORTANT: Keep these credentials secure! Do not commit the secrets directory or .env file to version control." 