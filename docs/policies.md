# Policy Enforcement with OPA Gatekeeper

This document explains how policies are implemented and enforced in our Kubernetes cluster using Open Policy Agent (OPA) Gatekeeper.

## Overview

OPA Gatekeeper is a policy controller for Kubernetes that enforces customizable policies. It validates, mutates, or rejects resources that don't conform to the organization's policies before they are persisted to the Kubernetes API server.

## Policy Structure

In our implementation, policies are organized in two main components:

1. **Constraint Templates** - Define the policy logic and schema
2. **Constraints** - Instances of templates that enforce specific rules

### Directory Structure

```
clusters/local/policies/
├── templates/           # Contains ConstraintTemplates
│   ├── probe-template.yaml
│   └── ...
└── constraints/         # Contains Constraints
    ├── require-probes.yaml
    └── ...
```

## Implemented Policies

### Resource Requirements

**Policy**: All pods must have CPU and memory requests and limits defined.
**Purpose**: Ensure proper resource allocation and prevent resource starvation.

### Probe Requirements

**Policy**: All pods must have readiness and liveness probes configured.
**Purpose**: Ensure proper health checking and self-healing of applications.

### Required Labels

**Policy**: All resources must have specific labels (app, environment, component).
**Purpose**: Ensure proper organization and categorization of resources.

### Restricted Repositories

**Policy**: Container images must come from approved registries.
**Purpose**: Security measure to ensure only trusted images are deployed.

## Adding New Policies

To add a new policy:

1. Create a new ConstraintTemplate in `clusters/local/policies/templates/`
2. Create a Constraint instance in `clusters/local/policies/constraints/`
3. Apply the changes with `kubectl apply -k clusters/local/policies`

### Example Template

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg, "details": {"missing_labels": missing}}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }
```

### Example Constraint

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-label
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces: ["default", "example"]
  parameters:
    labels: ["app", "environment", "component"]
```

## Best Practices

1. **Start with audit mode**: Use `enforcementAction: dryrun` to test policies without blocking resources
2. **Target specific resources**: Use the `match` section to limit the scope of policies
3. **Provide clear error messages**: Make violation messages descriptive to help users understand what went wrong
4. **Use namespaces for exceptions**: Exclude system namespaces from policy enforcement
5. **Validate policies before applying**: Test policies with various resources to avoid unexpected behavior

## Troubleshooting

To debug policy violations:

1. Check the Gatekeeper audit logs:
   ```bash
   kubectl logs -n gatekeeper-system deployment/gatekeeper-audit
   ```

2. Check the constraint status:
   ```bash
   kubectl get constraints
   kubectl describe constraint <constraint-name>
   ```

3. Test a resource against a policy:
   ```bash
   kubectl get <resource> -o yaml | kubectl apply -f - --dry-run=server
   ```

## References

- [OPA Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- [Kubernetes Policy Working Group](https://github.com/kubernetes/community/tree/master/wg-policy)
- [Gatekeeper Library](https://github.com/open-policy-agent/gatekeeper-library) 