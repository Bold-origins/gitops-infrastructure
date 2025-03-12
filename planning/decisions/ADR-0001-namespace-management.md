# ADR-0001: Centralized Namespace Management Approach

## Status
Proposed

## Context
Our current GitOps repository structure has namespace definitions distributed across individual component directories. This approach has the advantage of component ownership but leads to:

1. Difficulty in applying consistent labels and annotations across namespaces
2. Challenges with environment-specific configurations
3. No centralized view of all namespaces in the system
4. Complexity when adding new environments

We need to determine a pattern that:
- Maintains component ownership principles
- Provides a centralized reference point
- Enables environment-specific customizations
- Follows GitOps and kustomize best practices

## Decision
We will implement a hybrid approach that maintains component ownership while providing centralization:

1. Components will continue to own their namespace definitions in their respective directories
2. We will create a central reference point in `clusters/base/infrastructure/namespaces` that:
   - Contains a comprehensive manifest of all namespaces
   - Applies common labels and annotations
3. Environment-specific overlays will reference this central directory
4. We will document the pattern in `docs/patterns/namespace-management.md`

The centralized namespace directory will be maintained using a specific pattern to avoid duplication and synchronization issues between component-owned files and the central directory.

## Alternatives Considered

### Alternative 1: Fully Centralized Namespace Management
Move all namespace definitions to a central directory, removing them from component directories.

**Pros:**
- Simple centralized management
- Easy to understand structure
- Direct environment customization

**Cons:**
- Violates component ownership principle
- Separates namespaces from their components
- Makes component deployment more complex
- Breaks existing patterns

### Alternative 2: Component-Only Management with Label Transformers
Keep namespaces only in component directories and use kustomize transformers to add environment-specific labels.

**Pros:**
- Strong component ownership
- No duplication
- Follows existing patterns

**Cons:**
- Complex label transformation setup
- Difficult to get a centralized view
- Challenging environment-specific customizations
- More complex for new environment onboarding

### Alternative 3: Scripted Synchronization
Use scripts to synchronize component-owned namespace definitions with a central directory.

**Pros:**
- Maintains component ownership
- Provides centralization
- Allows for easier environment customization

**Cons:**
- Introduces complexity with synchronization
- Potential for synchronization failures
- Non-declarative approach

## Consequences

### Positive
- Clearer namespace management pattern
- Easier environment-specific customizations
- Centralized view of all namespaces
- Maintained component ownership
- Simplified onboarding of new environments

### Negative
- More complex kustomize structure
- Potential for confusion between component-owned and centralized references
- Need for clear documentation of the pattern

## Implementation
1. Create the centralized namespace directory structure
2. Develop and document the pattern for maintaining namespace definitions
3. Update environment-specific kustomizations to use the centralized approach
4. Add documentation to guide future component additions

The implementation will be done in phases, starting with the staging environment and then extending to other environments. 