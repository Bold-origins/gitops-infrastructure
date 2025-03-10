#!/bin/bash
# path-helper.sh: Helper functions for path resolution in GitOps scripts
# This script helps resolve paths correctly across the GitOps scripts

# Get the absolute path to the repository root directory
get_repo_root() {
  local current_dir="$1"
  
  # Navigate up until we find the repository root (where .git exists)
  while [[ "$current_dir" != "/" && ! -d "$current_dir/.git" ]]; do
    current_dir="$(dirname "$current_dir")"
  done
  
  # If we found the root (.git exists), return it, otherwise return the starting directory
  if [[ -d "$current_dir/.git" ]]; then
    echo "$current_dir"
  else
    # Fall back to the starting directory
    echo "$1"
  fi
}

# Helper function to validate a directory path exists
validate_dir() {
  local dir_path="$1"
  local description="$2"
  
  if [[ ! -d "$dir_path" ]]; then
    echo "ERROR: $description directory not found: $dir_path" >&2
    return 1
  fi
  
  return 0
}

# Helper function to validate a file path exists
validate_file() {
  local file_path="$1"
  local description="$2"
  
  if [[ ! -f "$file_path" ]]; then
    echo "ERROR: $description file not found: $file_path" >&2
    return 1
  fi
  
  return 0
} 