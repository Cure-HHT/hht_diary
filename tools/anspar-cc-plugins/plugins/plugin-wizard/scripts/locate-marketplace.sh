#!/bin/bash
# Locate marketplace directory by searching for tools/*/marketplace.json

set -e

# Start from current directory and search upward for project root
current_dir="$(pwd)"
project_root=""

# Search upward for a directory containing tools/
while [ "$current_dir" != "/" ]; do
  if [ -d "$current_dir/tools" ]; then
    project_root="$current_dir"
    break
  fi
  current_dir="$(dirname "$current_dir")"
done

if [ -z "$project_root" ]; then
  echo "ERROR: Could not find project root (no tools/ directory found)" >&2
  exit 1
fi

# Search for marketplace.json files
marketplaces=$(find "$project_root/tools" -name "marketplace.json" -type f 2>/dev/null | grep -E "\.claude-plugin/marketplace\.json$" || true)

if [ -z "$marketplaces" ]; then
  echo "ERROR: No marketplace.json found in $project_root/tools" >&2
  exit 1
fi

# Count marketplaces
marketplace_count=$(echo "$marketplaces" | wc -l)

if [ "$marketplace_count" -gt 1 ]; then
  echo "ERROR: Multiple marketplaces found:" >&2
  echo "$marketplaces" >&2
  echo "" >&2
  echo "Please specify marketplace path with --marketplace-path=/path/to/marketplace" >&2
  exit 1
fi

# Extract marketplace directory (remove /.claude-plugin/marketplace.json)
marketplace_path=$(dirname "$(dirname "$marketplaces")")

echo "$marketplace_path"
