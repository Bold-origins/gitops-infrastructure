#!/bin/bash
# diagnostics/check_documentation.sh

set -e

# Determine the environment (default to local if not specified)
ENVIRONMENT=${1:-local}
REPORTS_DIR="diagnostics/reports/$ENVIRONMENT"

# Create reports directory if it doesn't exist
mkdir -p $REPORTS_DIR

REPORT_FILE="$REPORTS_DIR/diagnostics_report_documentation_$(date +%Y%m%d_%H%M%S).md"
REPO_ROOT="."  # Adjust if needed

echo "# Documentation Diagnostic Report - $(date)" > $REPORT_FILE
echo "" >> $REPORT_FILE

if [ ! -d "$REPO_ROOT/docs" ]; then
  echo "Documentation directory not found at $REPO_ROOT/docs" >> $REPORT_FILE
  exit 1
fi

echo "## Documentation Files Inventory" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
find $REPO_ROOT/docs -type f -name "*.md" | sort >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Documentation Categories" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
find $REPO_ROOT/docs -type d | sort >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "## Documentation Coverage Analysis" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check for setup documentation
echo "### Setup Documentation" >> $REPORT_FILE
if [ -f "$REPO_ROOT/docs/setup-guide.md" ] || [ -f "$REPO_ROOT/docs/setup.md" ]; then
  echo "✅ Setup guide found" >> $REPORT_FILE
else
  echo "❌ No setup guide found" >> $REPORT_FILE
fi

# Check for architecture documentation
if [ -f "$REPO_ROOT/docs/architecture.md" ]; then
  echo "✅ Architecture documentation found" >> $REPORT_FILE
else
  echo "❌ No architecture documentation found" >> $REPORT_FILE
fi

# Check for troubleshooting documentation
if [ -f "$REPO_ROOT/docs/troubleshooting.md" ]; then
  echo "✅ Troubleshooting guide found" >> $REPORT_FILE
else
  echo "❌ No troubleshooting guide found" >> $REPORT_FILE
fi

# Check for secrets management documentation
if [ -f "$REPO_ROOT/docs/secrets-management.md" ]; then
  echo "✅ Secrets management documentation found" >> $REPORT_FILE
else
  echo "❌ No secrets management documentation found" >> $REPORT_FILE
fi

echo "Diagnostic report created: $REPORT_FILE" 