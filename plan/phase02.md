# Phase 2: Repository Restructuring for Multi-Environment Workflow

## Objective

Restructure the repository to use a base/overlay pattern with Kustomize to simplify environment promotion and reduce duplication, creating a clean path for promoting changes from local to staging to production.

## Instructions for Coding Agent

### 1. Analyze Current Repository Structure

Start by analyzing the existing repository structure to identify common components and environment-specific configurations.

````bash
#!/bin/bash
# scripts/analyze_repo_structure.sh

set -e
REPORT_FILE="repo_structure_analysis_$(date +%Y%m%d_%H%M%S).md"

echo "# Repository Structure Analysis - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Current Directory Structure" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
find . -type d -not -path "*/\.*" -not -path "*/node_modules*" | sort >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Kubernetes Resource Types by Environment" >> $REPORT_FILE

# Function to analyze resources in a directory
analyze_resources() {
  local dir="$1"
  local env_name="$2"

  echo "### $env_name Environment" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Find all yaml files
  resource_count=0

  # Process each yaml file
  for file in $(find "$dir" -name "*.yaml" -o -name "*.yml" 2>/dev/null); do
    # Count resources by kind
    kinds=$(grep -i "kind:" "$file" | awk '{print $2}' | sort)
    if [ -n "$kinds" ]; then
      resource_count=$((resource_count + $(echo "$kinds" | wc -l)))
      echo "$kinds" >> /tmp/kinds_$env_name.txt
    fi
  done

  if [ -f "/tmp/kinds_$env_name.txt" ]; then
    echo "Found $resource_count Kubernetes resources:" >> $REPORT_FILE
    sort /tmp/kinds_$env_name.txt | uniq -c | sort -nr >> $REPORT_FILE
    rm /tmp/kinds_$env_name.txt
  else
    echo "No Kubernetes resources found" >> $REPORT_FILE
  fi

  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
}

# Analyze each environment
if [ -d "clusters/local" ]; then
  analyze_resources "clusters/local" "Local"
fi

if [ -d "clusters/vps/staging" ]; then
  analyze_resources "clusters/vps/staging" "Staging"
fi

if [ -d "clusters/vps/production" ]; then
  analyze_resources "clusters/vps/production" "Production"
fi

echo "## Common Components Analysis" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Identify potential base components
echo "### Potential Base Components" >> $REPORT_FILE
echo "Components that appear in all environments and could be moved to a common base:" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# This is a simplified approach - a more comprehensive analysis would compare actual configs
if [ -d "clusters/local/infrastructure" ] && [ -d "clusters/vps/staging/infrastructure" ] && [ -d "clusters/vps/production/infrastructure" ]; then
  echo "#### Infrastructure Components" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Get components from each environment
  ls -1 clusters/local/infrastructure/ > /tmp/local_infra.txt
  ls -1 clusters/vps/staging/infrastructure/ > /tmp/staging_infra.txt
  ls -1 clusters/vps/production/infrastructure/ > /tmp/prod_infra.txt

  # Find common components
  comm -12 <(sort /tmp/local_infra.txt) <(sort /tmp/staging_infra.txt) | comm -12 - <(sort /tmp/prod_infra.txt) >> $REPORT_FILE

  rm /tmp/local_infra.txt /tmp/staging_infra.txt /tmp/prod_infra.txt

  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
fi

echo "Repository structure analysis completed: $REPORT_FILE"
````

### 2. Create New Directory Structure

Create the base/overlays directory structure that will form the foundation of the new GitOps workflow:

````bash
#!/bin/bash
# scripts/create_restructured_repo.sh

set -e
REPORT_FILE="repo_restructuring_$(date +%Y%m%d_%H%M%S).md"

echo "# Repository Restructuring Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Creating New Directory Structure" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

# Create base directory structure
mkdir -p base/{apps,infrastructure,observability}
echo "Created base directory structure" >> $REPORT_FILE

# Create environment directories
mkdir -p environments/{local,staging,production}
echo "Created environment directories" >> $REPORT_FILE

# Create subdirectories in each environment
for env in local staging production; do
  mkdir -p environments/$env/{apps,infrastructure,observability}
  echo "Created subdirectories for $env environment" >> $REPORT_FILE
done

echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## New Directory Structure" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
find base environments -type d | sort >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Repository structure created successfully." >> $REPORT_FILE
````

### 3. Create Base Configurations

Based on the analysis, move common components to the base directory:

````bash
#!/bin/bash
# scripts/create_base_components.sh

set -e
REPORT_FILE="base_components_creation_$(date +%Y%m%d_%H%M%S).md"

echo "# Base Components Creation Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

# Define function to create a simple kustomization file
create_kustomization() {
  local dir="$1"
  local resources="$2"

  mkdir -p "$dir"

  echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$dir/kustomization.yaml"
  echo "kind: Kustomization" >> "$dir/kustomization.yaml"
  echo "resources:" >> "$dir/kustomization.yaml"

  # Add each resource to the kustomization file
  if [ -n "$resources" ]; then
    for resource in $resources; do
      echo "- $resource" >> "$dir/kustomization.yaml"
    done
  fi
}

# Create base infrastructure components
echo "## Creating Base Infrastructure Components" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Common infrastructure components to move to base
COMPONENTS=("cert-manager" "ingress" "sealed-secrets" "gatekeeper" "policy-engine")

for component in "${COMPONENTS[@]}"; do
  echo "### Setting up $component" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Create directory for component
  mkdir -p "base/infrastructure/$component"
  echo "Created directory: base/infrastructure/$component" >> $REPORT_FILE

  # Create basic structure with placeholder for actual config
  create_kustomization "base/infrastructure/$component" ""
  echo "Created kustomization file for $component" >> $REPORT_FILE

  # Create a README explaining this component
  cat > "base/infrastructure/$component/README.md" << EOF
# $component

This is a base configuration for $component that will be used across all environments.

## Usage

Reference this base in your environment-specific overlay:

\`\`\`yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../base/infrastructure/$component
patchesStrategicMerge:
- $component-patch.yaml
\`\`\`
EOF

  echo "Created README for $component" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
done

# Create base observability components
echo "## Creating Base Observability Components" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Common observability components to move to base
OBS_COMPONENTS=("prometheus" "grafana" "loki" "opentelemetry")

for component in "${OBS_COMPONENTS[@]}"; do
  echo "### Setting up $component" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Create directory for component
  mkdir -p "base/observability/$component"
  echo "Created directory: base/observability/$component" >> $REPORT_FILE

  # Create basic structure with placeholder for actual config
  create_kustomization "base/observability/$component" ""
  echo "Created kustomization file for $component" >> $REPORT_FILE

  # Create a README explaining this component
  cat > "base/observability/$component/README.md" << EOF
# $component

This is a base configuration for $component that will be used across all environments.

## Usage

Reference this base in your environment-specific overlay:

\`\`\`yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../base/observability/$component
patchesStrategicMerge:
- $component-patch.yaml
\`\`\`
EOF

  echo "Created README for $component" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
done

# Create a sample app in the base directory
echo "## Creating Sample Application Base" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

# Create sample app directory
mkdir -p "base/apps/example-app"
echo "Created directory: base/apps/example-app" >> $REPORT_FILE

# Create deployment.yaml
cat > "base/apps/example-app/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
  labels:
    app: example-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      containers:
      - name: example-app
        image: nginx:1.21.6
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF
echo "Created deployment.yaml for example-app" >> $REPORT_FILE

# Create service.yaml
cat > "base/apps/example-app/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: example-app
  labels:
    app: example-app
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: example-app
EOF
echo "Created service.yaml for example-app" >> $REPORT_FILE

# Create kustomization.yaml
cat > "base/apps/example-app/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF
echo "Created kustomization.yaml for example-app" >> $REPORT_FILE

echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Base components created successfully." >> $REPORT_FILE
````

### 4. Create Environment Overlays

Create environment-specific overlays that reference and customize the base configurations:

````bash
#!/bin/bash
# scripts/create_environment_overlays.sh

set -e
REPORT_FILE="environment_overlays_creation_$(date +%Y%m%d_%H%M%S).md"

echo "# Environment Overlays Creation Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

# Create a patch for each environment for the example app
echo "## Creating Environment-Specific Overlays for Apps" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Function to create environment overlay for an app
create_app_overlay() {
  local env="$1"
  local app_name="$2"
  local replicas="$3"
  local memory_request="$4"
  local cpu_request="$5"
  local memory_limit="$6"
  local cpu_limit="$7"

  echo "### Creating $env overlay for $app_name" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Create directory
  mkdir -p "environments/$env/apps/$app_name"
  echo "Created directory: environments/$env/apps/$app_name" >> $REPORT_FILE

  # Create kustomization.yaml
  cat > "environments/$env/apps/$app_name/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../../base/apps/$app_name
patchesStrategicMerge:
- deployment-patch.yaml
EOF
  echo "Created kustomization.yaml" >> $REPORT_FILE

  # Create deployment patch
  cat > "environments/$env/apps/$app_name/deployment-patch.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app_name
spec:
  replicas: $replicas
  template:
    spec:
      containers:
      - name: $app_name
        resources:
          requests:
            memory: "$memory_request"
            cpu: "$cpu_request"
          limits:
            memory: "$memory_limit"
            cpu: "$cpu_limit"
        env:
        - name: ENVIRONMENT
          value: $env
EOF
  echo "Created deployment-patch.yaml" >> $REPORT_FILE

  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
}

# Create example-app overlays for each environment
create_app_overlay "local" "example-app" "1" "64Mi" "100m" "128Mi" "200m"
create_app_overlay "staging" "example-app" "2" "128Mi" "200m" "256Mi" "400m"
create_app_overlay "production" "example-app" "3" "256Mi" "300m" "512Mi" "600m"

# Create environment-specific infrastructure overlays
echo "## Creating Environment-Specific Overlays for Infrastructure" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Function to create environment overlay for infrastructure components
create_infra_overlay() {
  local env="$1"
  local component="$2"

  echo "### Creating $env overlay for $component" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Create directory
  mkdir -p "environments/$env/infrastructure/$component"
  echo "Created directory: environments/$env/infrastructure/$component" >> $REPORT_FILE

  # Create kustomization.yaml
  cat > "environments/$env/infrastructure/$component/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../../base/infrastructure/$component
patchesStrategicMerge:
- $component-patch.yaml
EOF
  echo "Created kustomization.yaml" >> $REPORT_FILE

  # Create patch file with environment-specific customizations
  cat > "environments/$env/infrastructure/$component/$component-patch.yaml" << EOF
# Environment-specific configuration for $component in $env environment
# This is a placeholder file - replace with actual configurations
EOF
  echo "Created $component-patch.yaml" >> $REPORT_FILE

  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
}

# Create infrastructure overlays for key components in each environment
COMPONENTS=("cert-manager" "ingress" "sealed-secrets")
ENVIRONMENTS=("local" "staging" "production")

for env in "${ENVIRONMENTS[@]}"; do
  for component in "${COMPONENTS[@]}"; do
    create_infra_overlay "$env" "$component"
  done
done

# Create environment-specific observability overlays
echo "## Creating Environment-Specific Overlays for Observability" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Function to create environment overlay for observability components
create_obs_overlay() {
  local env="$1"
  local component="$2"

  echo "### Creating $env overlay for $component" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Create directory
  mkdir -p "environments/$env/observability/$component"
  echo "Created directory: environments/$env/observability/$component" >> $REPORT_FILE

  # Create kustomization.yaml
  cat > "environments/$env/observability/$component/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../../base/observability/$component
patchesStrategicMerge:
- $component-patch.yaml
EOF
  echo "Created kustomization.yaml" >> $REPORT_FILE

  # Create patch file with environment-specific customizations
  cat > "environments/$env/observability/$component/$component-patch.yaml" << EOF
# Environment-specific configuration for $component in $env environment
# This is a placeholder file - replace with actual configurations
EOF
  echo "Created $component-patch.yaml" >> $REPORT_FILE

  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
}

# Create observability overlays for each environment
OBS_COMPONENTS=("prometheus" "grafana")
for env in "${ENVIRONMENTS[@]}"; do
  for component in "${OBS_COMPONENTS[@]}"; do
    create_obs_overlay "$env" "$component"
  done
done

echo "Environment overlays created successfully." >> $REPORT_FILE
````

### 5. Create Environment Root Kustomizations

Create root kustomization files for each environment that include all components:

````bash
#!/bin/bash
# scripts/create_env_kustomizations.sh

set -e
REPORT_FILE="env_kustomizations_creation_$(date +%Y%m%d_%H%M%S).md"

echo "# Environment Root Kustomizations Creation Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

# Function to create root kustomization for an environment
create_root_kustomization() {
  local env="$1"

  echo "## Creating Root Kustomization for $env Environment" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Create the kustomization.yaml file
  cat > "environments/$env/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Common resources for $env environment
resources:
EOF
  echo "Created environments/$env/kustomization.yaml" >> $REPORT_FILE

  # Add infrastructure components
  if ls -A "environments/$env/infrastructure/" >/dev/null 2>&1; then
    echo "# Infrastructure components" >> "environments/$env/kustomization.yaml"
    for component in environments/$env/infrastructure/*/; do
      component_name=$(basename $component)
      echo "- infrastructure/$component_name" >> "environments/$env/kustomization.yaml"
      echo "Added infrastructure/$component_name to kustomization" >> $REPORT_FILE
    done
  fi

  # Add observability components
  if ls -A "environments/$env/observability/" >/dev/null 2>&1; then
    echo "" >> "environments/$env/kustomization.yaml"
    echo "# Observability components" >> "environments/$env/kustomization.yaml"
    for component in environments/$env/observability/*/; do
      component_name=$(basename $component)
      echo "- observability/$component_name" >> "environments/$env/kustomization.yaml"
      echo "Added observability/$component_name to kustomization" >> $REPORT_FILE
    done
  fi

  # Add applications
  if ls -A "environments/$env/apps/" >/dev/null 2>&1; then
    echo "" >> "environments/$env/kustomization.yaml"
    echo "# Applications" >> "environments/$env/kustomization.yaml"
    for app in environments/$env/apps/*/; do
      app_name=$(basename $app)
      echo "- apps/$app_name" >> "environments/$env/kustomization.yaml"
      echo "Added apps/$app_name to kustomization" >> $REPORT_FILE
    done
  fi

  # Add environment-specific configurations
  echo "" >> "environments/$env/kustomization.yaml"
  echo "# Environment-specific configurations" >> "environments/$env/kustomization.yaml"
  echo "namespace: default  # This can be customized per environment" >> "environments/$env/kustomization.yaml"

  # Add namePrefix based on environment
  case "$env" in
    "local")
      echo "namePrefix: local-" >> "environments/$env/kustomization.yaml"
      ;;
    "staging")
      echo "namePrefix: staging-" >> "environments/$env/kustomization.yaml"
      ;;
    "production")
      echo "namePrefix: prod-" >> "environments/$env/kustomization.yaml"
      ;;
  esac

  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
}

# Create root kustomization for each environment
for env in local staging production; do
  create_root_kustomization "$env"
done

echo "Environment root kustomizations created successfully." >> $REPORT_FILE
````

### 6. Create Application Management Scripts

Create scripts to automate creating and promoting applications between environments:

````bash
#!/bin/bash
# scripts/create_app_management_scripts.sh

set -e
REPORT_FILE="app_management_scripts_creation_$(date +%Y%m%d_%H%M%S).md"

echo "# Application Management Scripts Creation Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Creating Application Creation Script" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

# Create directory for scripts if it doesn't exist
mkdir -p scripts
echo "Created scripts directory" >> $REPORT_FILE

# Create script to generate new application structures
cat > "scripts/create_app.sh" << 'EOF'
#!/bin/bash
# scripts/create_app.sh
# Usage: ./scripts/create_app.sh <app-name> <image>

set -e

APP_NAME=$1
IMAGE=${2:-nginx:latest}

if [ -z "$APP_NAME" ]; then
  echo "Usage: $0 <app-name> [image]"
  echo "Example: $0 my-app nginx:1.21.6"
  exit 1
fi

# Create base app structure
echo "Creating base app structure for $APP_NAME..."
mkdir -p "base/apps/$APP_NAME"

# Create deployment.yaml
cat > "base/apps/$APP_NAME/deployment.yaml" << END
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  labels:
    app: $APP_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: $APP_NAME
        image: $IMAGE
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
END

# Create service.yaml
cat > "base/apps/$APP_NAME/service.yaml" << END
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME
  labels:
    app: $APP_NAME
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: $APP_NAME
END

# Create kustomization.yaml
cat > "base/apps/$APP_NAME/kustomization.yaml" << END
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
END

# Create environment overlays
for ENV in local staging production; do
  echo "Creating $ENV overlay for $APP_NAME..."

  # Create directory
  mkdir -p "environments/$ENV/apps/$APP_NAME"

  # Create kustomization.yaml
  cat > "environments/$ENV/apps/$APP_NAME/kustomization.yaml" << END
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../../base/apps/$APP_NAME
patchesStrategicMerge:
- deployment-patch.yaml
END

  # Set environment-specific values
  case "$ENV" in
    "local")
      REPLICAS=1
      MEM_REQUEST="64Mi"
      CPU_REQUEST="100m"
      MEM_LIMIT="128Mi"
      CPU_LIMIT="200m"
      ;;
    "staging")
      REPLICAS=2
      MEM_REQUEST="128Mi"
      CPU_REQUEST="200m"
      MEM_LIMIT="256Mi"
      CPU_LIMIT="400m"
      ;;
    "production")
      REPLICAS=3
      MEM_REQUEST="256Mi"
      CPU_REQUEST="300m"
      MEM_LIMIT="512Mi"
      CPU_LIMIT="600m"
      ;;
  esac

  # Create deployment patch
  cat > "environments/$ENV/apps/$APP_NAME/deployment-patch.yaml" << END
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
spec:
  replicas: $REPLICAS
  template:
    spec:
      containers:
      - name: $APP_NAME
        resources:
          requests:
            memory: "$MEM_REQUEST"
            cpu: "$CPU_REQUEST"
          limits:
            memory: "$MEM_LIMIT"
            cpu: "$CPU_LIMIT"
        env:
        - name: ENVIRONMENT
          value: $ENV
END
done

echo "Application $APP_NAME created successfully."
echo "Base: base/apps/$APP_NAME"
echo "Environments:"
echo "  - environments/local/apps/$APP_NAME"
echo "  - environments/staging/apps/$APP_NAME"
echo "  - environments/production/apps/$APP_NAME"
EOF

chmod +x "scripts/create_app.sh"
echo "Created scripts/create_app.sh" >> $REPORT_FILE

echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Creating Application Promotion Script" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

# Create script to promote applications between environments
cat > "scripts/promote_app.sh" << 'EOF'
#!/bin/bash
# scripts/promote_app.sh
# Usage: ./scripts/promote_app.sh <app-name> <from-env> <to-env>

set -e

APP_NAME=$1
FROM_ENV=$2
TO_ENV=$3

if [ -z "$APP_NAME" ] || [ -z "$FROM_ENV" ] || [ -z "$TO_ENV" ]; then
  echo "Usage: $0 <app-name> <from-env> <to-env>"
  echo "Example: $0 my-app local staging"
  exit 1
fi

# Validate environments
if [[ ! "$FROM_ENV" =~ ^(local|staging)$ ]] || [[ ! "$TO_ENV" =~ ^(staging|production)$ ]]; then
  echo "Error: Environments must be one of: local, staging, production"
  echo "  and promotion must go from lower to higher environment"
  exit 1
fi

if [ "$FROM_ENV" = "$TO_ENV" ]; then
  echo "Error: Source and destination environments cannot be the same"
  exit 1
fi

# Check if source app exists
if [ ! -d "environments/$FROM_ENV/apps/$APP_NAME" ]; then
  echo "Error: App $APP_NAME not found in $FROM_ENV environment"
  exit 1
fi

# Create a branch for the promotion
BRANCH="promote-$APP_NAME-$FROM_ENV-to-$TO_ENV-$(date +%s)"
git checkout -b "$BRANCH"

# Ensure destination directory exists
mkdir -p "environments/$TO_ENV/apps/$APP_NAME"

# Copy configurations, preserving git history
echo "Promoting $APP_NAME from $FROM_ENV to $TO_ENV..."

# Get image tag from source environment
SOURCE_IMAGE=""
if [ -f "environments/$FROM_ENV/apps/$APP_NAME/deployment-patch.yaml" ]; then
  SOURCE_IMAGE=$(grep -o "image:.*" "environments/$FROM_ENV/apps/$APP_NAME/deployment-patch.yaml" || echo "")
fi

# Copy all files from source to destination
cp -r "environments/$FROM_ENV/apps/$APP_NAME"/* "environments/$TO_ENV/apps/$APP_NAME"/

# If image was found, update the destination deployment
if [ -n "$SOURCE_IMAGE" ]; then
  echo "Updating image to: $SOURCE_IMAGE"
  sed -i "s|image:.*|$SOURCE_IMAGE|" "environments/$TO_ENV/apps/$APP_NAME/deployment-patch.yaml" 2>/dev/null || true
fi

# Customize for destination environment
case "$TO_ENV" in
  "staging")
    echo "Customizing for staging environment..."
    # Update replicas if needed
    sed -i 's/replicas: 1/replicas: 2/' "environments/$TO_ENV/apps/$APP_NAME/deployment-patch.yaml" 2>/dev/null || true
    ;;
  "production")
    echo "Customizing for production environment..."
    # Update replicas if needed
    sed -i 's/replicas: [12]/replicas: 3/' "environments/$TO_ENV/apps/$APP_NAME/deployment-patch.yaml" 2>/dev/null || true
    ;;
esac

# Commit the changes
git add "environments/$TO_ENV/apps/$APP_NAME"
git commit -m "Promote $APP_NAME from $FROM_ENV to $TO_ENV"

# Push the branch
git push origin "$BRANCH"

echo "Promotion branch created: $BRANCH"
echo "Create a Pull Request with this link:"
echo "  https://github.com/YOUR_USERNAME/YOUR_REPO/compare/main...$BRANCH"
echo ""
echo "After review and merge, Flux will automatically deploy to $TO_ENV"
EOF

chmod +x "scripts/promote_app.sh"
echo "Created scripts/promote_app.sh" >> $REPORT_FILE

echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Application management scripts created successfully." >> $REPORT_FILE
````

### 7. Set Up Flux Configuration for the New Structure

Create Flux configuration to deploy from the new repository structure:

````bash
#!/bin/bash
# scripts/setup_flux_for_new_structure.sh

set -e
REPORT_FILE="flux_setup_$(date +%Y%m%d_%H%M%S).md"

echo "# Flux Configuration for New Structure - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Creating Flux Kustomization for Environments" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Function to create Flux Kustomization for an environment
create_flux_kustomization() {
  local env="$1"

  echo "### Creating Flux Kustomization for $env Environment" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  mkdir -p "clusters/$env/flux-system"

  # Create Flux Kustomization for the environment
  cat > "clusters/$env/flux-system/$env-kustomization.yaml" << EOF
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: $env-apps
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./environments/$env
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  validation: client
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: example-app
      namespace: default
EOF

  echo "Created clusters/$env/flux-system/$env-kustomization.yaml" >> $REPORT_FILE

  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE
}

# Create Flux kustomizations for each environment
for env in local staging production; do
  create_flux_kustomization "$env"
done

echo "Flux configuration for new structure created successfully." >> $REPORT_FILE
````

### 8. Create a Test Script

Create a script to test building the new Kustomize configurations:

````bash
#!/bin/bash
# scripts/test_kustomize_build.sh

set -e
REPORT_FILE="kustomize_build_test_$(date +%Y%m%d_%H%M%S).md"

echo "# Kustomize Build Test Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

# Function to test building a kustomization
test_kustomize_build() {
  local env="$1"

  echo "## Testing Kustomize Build for $env Environment" >> $REPORT_FILE
  echo "" >> $REPORT_FILE

  echo "### Building Root Kustomization" >> $REPORT_FILE
  echo '```' >> $REPORT_FILE

  # Try building the kustomization
  if kustomize build "environments/$env" > /dev/null 2>&1; then
    echo "✅ Kustomize build successful for environments/$env" >> $REPORT_FILE
  else
    echo "❌ Kustomize build failed for environments/$env" >> $REPORT_FILE
    echo "Error:" >> $REPORT_FILE
    kustomize build "environments/$env" 2>&1 | head -20 >> $REPORT_FILE
  fi

  echo '```' >> $REPORT_FILE
  echo "" >> $REPORT_FILE

  echo "### Testing Individual Component Builds" >> $REPORT_FILE
  echo "" >> $REPORT_FILE

  # Test each app
  for app_dir in environments/$env/apps/*/; do
    if [ -d "$app_dir" ]; then
      app=$(basename $app_dir)
      echo "#### App: $app" >> $REPORT_FILE
      echo '```' >> $REPORT_FILE

      if kustomize build "$app_dir" > /dev/null 2>&1; then
        echo "✅ Kustomize build successful for $app_dir" >> $REPORT_FILE
      else
        echo "❌ Kustomize build failed for $app_dir" >> $REPORT_FILE
        echo "Error:" >> $REPORT_FILE
        kustomize build "$app_dir" 2>&1 | head -10 >> $REPORT_FILE
      fi

      echo '```' >> $REPORT_FILE
      echo "" >> $REPORT_FILE
    fi
  done

  # Test each infrastructure component
  for infra_dir in environments/$env/infrastructure/*/; do
    if [ -d "$infra_dir" ]; then
      component=$(basename $infra_dir)
      echo "#### Infrastructure: $component" >> $REPORT_FILE
      echo '```' >> $REPORT_FILE

      if kustomize build "$infra_dir" > /dev/null 2>&1; then
        echo "✅ Kustomize build successful for $infra_dir" >> $REPORT_FILE
      else
        echo "❌ Kustomize build failed for $infra_dir" >> $REPORT_FILE
        echo "Error:" >> $REPORT_FILE
        kustomize build "$infra_dir" 2>&1 | head -10 >> $REPORT_FILE
      fi

      echo '```' >> $REPORT_FILE
      echo "" >> $REPORT_FILE
    fi
  done
}

# Test building kustomizations for each environment
for env in local staging production; do
  test_kustomize_build "$env"
done

echo "Kustomize build tests completed." >> $REPORT_FILE
````

### 9. Implementation Workflow

Follow these steps to implement the repository restructuring:

1. First, analyze the current repository structure:

   ```bash
   ./scripts/analyze_repo_structure.sh
   ```

2. Create the new directory structure:

   ```bash
   ./scripts/create_restructured_repo.sh
   ```

3. Set up base components:

   ```bash
   ./scripts/create_base_components.sh
   ```

4. Create environment overlays:

   ```bash
   ./scripts/create_environment_overlays.sh
   ```

5. Create root kustomizations for each environment:

   ```bash
   ./scripts/create_env_kustomizations.sh
   ```

6. Create application management scripts:

   ```bash
   ./scripts/create_app_management_scripts.sh
   ```

7. Set up Flux for the new structure:

   ```bash
   ./scripts/setup_flux_for_new_structure.sh
   ```

8. Test building the new Kustomize configurations:
   ```bash
   ./scripts/test_kustomize_build.sh
   ```

### 10. Progress Reporting

After completing the repository restructuring phase, create a detailed progress report:

```bash
#!/bin/bash
# create_phase2_report.sh

REPORT_FILE="phase2_completion_report_$(date +%Y%m%d).md"

cat > $REPORT_FILE << EOF
# Phase 2: Repository Restructuring Completion Report

## Overview
This report summarizes the repository restructuring work completed to implement a base/overlay pattern with Kustomize to simplify environment promotion.

## Key Accomplishments

### New Repository Structure
- Created base directory with common components
- Created environment-specific overlay directories (local, staging, production)
- Implemented Kustomize-based workflow for customizing components per environment

### Base Components
- Created common infrastructure component bases
- Created common observability component bases
- Created example application base

### Environment Overlays
- Created environment-specific overlays for infrastructure components
- Created environment-specific overlays for observability components
- Created environment-specific overlays for applications

### Automation Scripts
- Created script for generating new application structures
- Created script for promoting applications between environments
- Created scripts for testing Kustomize builds

### Flux Configuration
- Created Flux kustomizations for deploying from the new structure
- Configured health checks for monitoring deployments

## Migration Strategy

### Implemented Migration Approach
[Describe the approach used for migrating from the old structure to the new one]

### Transition Plan
1. [Step 1 of the transition plan]
2. [Step 2 of the transition plan]
3. [Step 3 of the transition plan]
...

## Testing Results
- Kustomize build tests: [Success/Failure]
- Application promotion tests: [Success/Failure]
- Flux reconciliation tests: [Success/Failure]

## Challenges Encountered
- [Challenge 1 and how it was resolved]
- [Challenge 2 and how it was resolved]
- [Challenge 3 and how it was resolved]

## Recommendations
- [Recommendation 1]
- [Recommendation 2]
- [Recommendation 3]

## Next Steps
1. Proceed to Phase 3: CI/CD Integration & Validation Pipeline
2. Begin testing the promotion workflow with real applications
3. Document the new workflow for team members

## Artifacts
- [Link to analysis report]
- [Link to kustomize build test report]
- [Other relevant documents]
EOF

echo "Phase 2 completion report created: $REPORT_FILE"
```

## Expected Outcome

After completing this phase, you should have:

1. A repository structure organized around the base/overlay pattern
2. Environment-specific overlays that extend the base configurations
3. Scripts for creating and promoting applications between environments
4. Flux configurations for automated deployment
5. A clear path for promoting changes from local to staging to production

## Verification Checklist

Before proceeding to Phase 3, verify the following:

- [ ] All base components have been created with proper configurations
- [ ] Environment overlays correctly reference and extend base components
- [ ] Kustomize builds successfully for all environments
- [ ] Application management scripts work as expected
- [ ] Flux configurations are correctly set up for the new structure
- [ ] Example application can be deployed across environments
- [ ] Promotion workflow has been tested and documented
- [ ] Completion report has been generated and reviewed

## Notes for Coding Agent

1. When analyzing the current repository structure, pay special attention to identifying components that can be shared across environments
2. Create placeholder files initially and gradually fill them with actual configurations as you migrate from the old structure
3. Test each component individually before integrating them into the full environment
4. Use git branches to isolate changes during restructuring
5. Document each step of the migration process, especially any manual adjustments needed
6. Submit a comprehensive progress report after completing this phase with:
   - Before/after comparison of the repository structure
   - Details of any challenges encountered during migration
   - Recommendations for optimizing the new structure
   - Examples of how to use the new workflow for common tasks
   - Timeline for completing Phase 2
   - Screenshots of successful Kustomize builds and deployments
