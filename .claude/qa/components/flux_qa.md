# Flux GitOps Q&A

This document contains common questions and answers about Flux GitOps in this repository.

## Setup Questions

### Q: How do I set up Flux in a new cluster?

**A:** Use the setup-flux.sh script:

```bash
./scripts/cluster/setup-flux.sh
```

This script will:
1. Install Flux CLI if not present
2. Bootstrap Flux on the cluster
3. Create the necessary GitRepository and Kustomization resources

**Context:** The script handles the complexity of bootstrapping Flux, which includes installing the Flux controllers, setting up the Git repository source, and creating the initial Kustomization resources.

**Reasoning:** Using the script ensures consistent setup across different environments and handles potential issues like RBAC configuration and Git credentials.

### Q: How do I check if Flux is working properly?

**A:** Use the following commands:

```bash
# Check Flux controllers
kubectl get pods -n flux-system

# Check Flux sources
flux get sources all

# Check Flux kustomizations
flux get kustomizations

# Check Flux HelmReleases
flux get helmreleases -A
```

**Context:** These commands check different aspects of Flux's operation, from the controllers themselves to the resources they manage.

**Reasoning:** A properly functioning Flux installation should have all controllers running, sources reconciled, and kustomizations/helmreleases in a "Ready" state.

## Troubleshooting Questions

### Q: Why is my HelmRelease stuck in "progressing" state?

**A:** Common causes include:

1. Helm chart source is not available
2. Values configuration is invalid
3. Dependencies are not ready

**Debugging steps:**
```bash
# Get detailed status
flux get helmrelease -n <namespace> <name> -A

# Check HelmChart resource
kubectl get helmcharts -n <namespace>

# Check HelmRepository
flux get source helm -A

# Check the Helm chart values
kubectl get secret -n <namespace> sh.helm.release.<release-name>.v1 -o yaml
```

**Context:** HelmReleases depend on HelmCharts, which in turn depend on HelmRepositories. Any issue in this chain can cause the HelmRelease to get stuck.

**Reasoning:** Following the dependency chain helps identify the root cause of the issue.

### Q: How do I debug a Kustomization that's not applying?

**A:** Check the following:

1. Kustomization status and events
```bash
flux get kustomization <name> -A
kubectl describe kustomization <name> -n flux-system
```

2. Check if the Git source is reconciled
```bash
flux get sources git
```

3. Verify kustomization.yaml file
```bash
kubectl kustomize <path-to-kustomization>
```

**Context:** Kustomizations can fail due to issues with the Git source, syntax errors in the kustomization.yaml file, or resource validation errors.

**Reasoning:** These steps help identify where in the process the kustomization is failing.

## Configuration Questions

### Q: How do I add a new application to the cluster?

**A:** Follow these steps:

1. Create a new directory in `clusters/base/applications/`
2. Add the necessary resources (namespace, HelmRelease, etc.)
3. Create environment-specific overlays in `clusters/[env]/applications/`
4. Update the kustomization.yaml files to include the new application

**Context:** This repository follows a GitOps pattern where base configurations are defined in `clusters/base/` and environment-specific overlays are defined in `clusters/[env]/`.

**Reasoning:** This approach ensures consistency across environments while allowing for environment-specific customizations.

### Q: How do I update a Helm chart version?

**A:** Update the version in the HelmRelease resource:

```yaml
spec:
  chart:
    spec:
      chart: <chart-name>
      version: "<new-version>"
      sourceRef:
        kind: HelmRepository
        name: <repo-name>
        namespace: flux-system
```

**Context:** Flux automatically detects changes to the HelmRelease resource and applies the update.

**Reasoning:** This declarative approach ensures that the desired state is always reflected in the Git repository.