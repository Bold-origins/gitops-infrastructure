#!/bin/bash
set -e

# Check if environment is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <environment> [anon_key] [service_key] [jwt_secret]"
  echo "  environment: local, staging, or production"
  echo "  anon_key: (optional) JWT token for anonymous access"
  echo "  service_key: (optional) JWT token for service role access"
  echo "  jwt_secret: (optional) Secret key for JWT signing"
  exit 1
fi

ENV=$1
ANON_KEY=${2:-"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.ZopqoUjlYrXLn3FpKiRJIKzusXkqHQBPo2TCFWSMQnI"}
SERVICE_KEY=${3:-"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.M2d2z4SFn5C1AqsKYAhJWuGFJI5viMQRJqcbJTgGR_8"}
JWT_SECRET=${4:-"super_secret_jwt_token_with_at_least_32_characters"}

# Validate environment
if [[ ! "$ENV" =~ ^(local|staging|production)$ ]]; then
  echo "Error: Environment must be one of: local, staging, production"
  exit 1
fi

# Ensure environment directory exists
ENV_DIR="clusters/$ENV/applications/supabase/sealed-secrets"
mkdir -p "$ENV_DIR"

echo "Generating JWT secret template for $ENV environment..."

# Create a template with proper key structure
# Note the key is named 'secret' not 'jwtSecret' for compatibility with all components
cat <<EOF > /tmp/jwt-secret-template.yaml
apiVersion: v1
kind: Secret
metadata:
  name: supabase-jwt
  namespace: supabase
  labels:
    app.kubernetes.io/part-of: supabase
type: Opaque
stringData:
  anonKey: "${ANON_KEY}"
  serviceKey: "${SERVICE_KEY}"
  secret: "${JWT_SECRET}"
EOF

echo "Sealing the secret for $ENV environment..."
kubeseal --format yaml --controller-namespace=sealed-secrets < /tmp/jwt-secret-template.yaml > "$ENV_DIR/jwt-secret.yaml"

echo "Secret created and sealed at: $ENV_DIR/jwt-secret.yaml"
echo "Done!" 