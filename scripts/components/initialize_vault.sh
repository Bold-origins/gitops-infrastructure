#!/bin/bash
# Script to initialize and unseal Vault

set -e

# First, ensure the directory exists
mkdir -p scripts
mkdir -p secrets

echo "Initializing Vault..."
INIT_OUTPUT=$(kubectl exec -it -n vault $(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}') -- \
  /bin/sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator init -key-shares=1 -key-threshold=1 -format=json")

# Check if Vault is already initialized
if [[ $INIT_OUTPUT == *"Vault is already initialized"* ]]; then
  echo "Vault is already initialized. Unable to retrieve unseal keys and root token."
  echo "You may need to reset Vault to get new credentials."
  exit 1
fi

# Extract unseal key and root token
UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')

# Save to .env file
sed -i '' "s|VAULT_UNSEAL_KEY=\"Replace with actual key\"|VAULT_UNSEAL_KEY=\"$UNSEAL_KEY\"|g" .env
sed -i '' "s|VAULT_ROOT_TOKEN=\"Replace with actual token\"|VAULT_ROOT_TOKEN=\"$ROOT_TOKEN\"|g" .env

# Also save to a dedicated secrets file
echo "Vault Credentials" > secrets/vault_credentials.txt
echo "=================" >> secrets/vault_credentials.txt
echo "Unseal Key: $UNSEAL_KEY" >> secrets/vault_credentials.txt
echo "Root Token: $ROOT_TOKEN" >> secrets/vault_credentials.txt
echo "" >> secrets/vault_credentials.txt
echo "Keep this information secure and backed up!" >> secrets/vault_credentials.txt

echo "Unsealing Vault..."
kubectl exec -it -n vault $(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}') -- \
  /bin/sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && vault operator unseal $UNSEAL_KEY"

echo "Vault is now initialized and unsealed."
echo "Credentials have been saved to secrets/vault_credentials.txt and updated in .env file."
echo "IMPORTANT: Keep these credentials secure!" 