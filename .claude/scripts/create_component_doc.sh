#!/bin/bash
# Script to automatically generate component documentation for the .claude directory

# Usage: ./create_component_doc.sh component-name component-type
# Example: ./create_component_doc.sh cert-manager infrastructure

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 component-name component-type"
    echo "Example: $0 cert-manager infrastructure"
    exit 1
fi

COMPONENT_NAME=$1
COMPONENT_TYPE=$2
BASE_DIR=$(git rev-parse --show-toplevel)
CLAUDE_DIR="$BASE_DIR/.claude"

# Create component directory if it doesn't exist
mkdir -p "$CLAUDE_DIR/metadata/components/$COMPONENT_TYPE"

# Generate component metadata
cat > "$CLAUDE_DIR/metadata/components/$COMPONENT_TYPE/$COMPONENT_NAME.md" << EOF
# $COMPONENT_NAME

## Overview

\`$COMPONENT_NAME\` is a $COMPONENT_TYPE component that provides...

## Directory Structure

\`\`\`
clusters/base/$COMPONENT_TYPE/$COMPONENT_NAME/
├── README.md
├── kustomization.yaml
├── namespace.yaml
├── $COMPONENT_NAME.yaml
└── ...
\`\`\`

## Dependencies

This component depends on:
- TBD

## Required By

This component is required by:
- TBD

## Configuration

### Base Configuration

The base configuration is located in \`clusters/base/$COMPONENT_TYPE/$COMPONENT_NAME/\`.

### Environment-Specific Configuration

Environment-specific configurations are located in:
- \`clusters/local/$COMPONENT_TYPE/$COMPONENT_NAME/\`
- \`clusters/staging/$COMPONENT_TYPE/$COMPONENT_NAME/\` (if applicable)
- \`clusters/production/$COMPONENT_TYPE/$COMPONENT_NAME/\` (if applicable)

## Common Operations

\`\`\`bash
# Check component status
kubectl get pods -n $COMPONENT_NAME

# View logs
kubectl logs -n $COMPONENT_NAME deployment/$COMPONENT_NAME

# View configuration
kubectl get -n $COMPONENT_NAME configmap/$COMPONENT_NAME-config -o yaml
\`\`\`

## Troubleshooting

Common issues:
1. TBD

## Memory Anchors

<!-- CLAUDE-ANCHOR:$COMPONENT_NAME:$(uuidgen | tr -d '-' | cut -c1-8) -->
\`$COMPONENT_NAME\` is a $COMPONENT_TYPE component that...
<!-- END-CLAUDE-ANCHOR:$COMPONENT_NAME -->
EOF

echo "Created component documentation for $COMPONENT_NAME at $CLAUDE_DIR/metadata/components/$COMPONENT_TYPE/$COMPONENT_NAME.md"

# Create QA file if it doesn't exist
mkdir -p "$CLAUDE_DIR/qa/components"
if [ ! -f "$CLAUDE_DIR/qa/components/${COMPONENT_NAME}_qa.md" ]; then
    cat > "$CLAUDE_DIR/qa/components/${COMPONENT_NAME}_qa.md" << EOF
# $COMPONENT_NAME Q&A

This document contains common questions and answers about $COMPONENT_NAME.

## Setup Questions

### Q: How do I set up $COMPONENT_NAME?

**A:** 

**Context:** 

**Reasoning:** 

### Q: How do I check if $COMPONENT_NAME is working properly?

**A:** 

**Context:** 

**Reasoning:** 

## Configuration Questions

### Q: How do I configure $COMPONENT_NAME?

**A:** 

**Context:** 

**Reasoning:** 

## Troubleshooting Questions

### Q: Why is $COMPONENT_NAME not working?

**A:** 

**Context:** 

**Reasoning:** 
EOF

    echo "Created Q&A file for $COMPONENT_NAME at $CLAUDE_DIR/qa/components/${COMPONENT_NAME}_qa.md"
fi

echo "Done!"