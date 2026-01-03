#!/bin/bash
# Sponsor Resolution Script
#
# Resolves active sponsors from multiple sources (in priority order):
# 1. SPONSOR_MANIFEST environment variable (from Doppler - production/CI)
# 2. .github/config/sponsors.yml (local development fallback)
# 3. sponsor/ directory scan (discovery mode)
#
# Outputs JSON array of sponsor objects for consumption by other tools.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00070: Sponsor integration automation
#   REQ-d00069: Doppler manifest system
#
# USAGE:
#   ./tools/build/resolve-sponsors.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output as JSON (default)
#   --names             Output sponsor names only (newline-separated)
#   --enabled-only      Only include enabled sponsors
#   --local-only        Only include local sponsors (repo: local)
#   --remote-only       Only include remote sponsors
#   --sponsor NAME      Filter to specific sponsor
#   --source            Show which source was used
#   --quiet             Suppress informational messages
#
# ENVIRONMENT VARIABLES:
#   SPONSOR_MANIFEST    YAML manifest from Doppler (highest priority)
#
# OUTPUT FORMAT (JSON):
#   [
#     {
#       "name": "callisto",
#       "code": "CAL",
#       "enabled": true,
#       "repo": "local",
#       "tag": "main",
#       "path": "sponsor/callisto",
#       "type": "production",
#       "spec_path": "spec",
#       "source": "manifest"
#     }
#   ]

set -euo pipefail

# Colors for output (disabled in quiet mode)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default options
OUTPUT_FORMAT="json"
ENABLED_ONLY=false
LOCAL_ONLY=false
REMOTE_ONLY=false
FILTER_SPONSOR=""
SHOW_SOURCE=false
QUIET=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --names)
      OUTPUT_FORMAT="names"
      shift
      ;;
    --enabled-only)
      ENABLED_ONLY=true
      shift
      ;;
    --local-only)
      LOCAL_ONLY=true
      shift
      ;;
    --remote-only)
      REMOTE_ONLY=true
      shift
      ;;
    --sponsor)
      FILTER_SPONSOR="$2"
      shift 2
      ;;
    --source)
      SHOW_SOURCE=true
      shift
      ;;
    --quiet|-q)
      QUIET=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Resolve active sponsors from manifest, config, or directory scan."
      echo ""
      echo "Options:"
      echo "  --json          Output as JSON (default)"
      echo "  --names         Output sponsor names only"
      echo "  --enabled-only  Only include enabled sponsors"
      echo "  --local-only    Only include local sponsors"
      echo "  --remote-only   Only include remote sponsors"
      echo "  --sponsor NAME  Filter to specific sponsor"
      echo "  --source        Show which source was used"
      echo "  --quiet, -q     Suppress informational messages"
      echo "  --help, -h      Show this help"
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown argument $1${NC}" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Helper: Print info message (respects quiet mode)
info() {
  if [[ "$QUIET" != "true" ]]; then
    echo -e "${BLUE}$1${NC}" >&2
  fi
}

# Helper: Print warning message
warn() {
  if [[ "$QUIET" != "true" ]]; then
    echo -e "${YELLOW}$1${NC}" >&2
  fi
}

# Check for required tools
HAS_YQ=false

check_dependencies() {
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed${NC}" >&2
    echo "Install: brew install jq (macOS) or apt install jq (Linux)" >&2
    exit 1
  fi

  if command -v yq &> /dev/null; then
    HAS_YQ=true
  else
    # Check if we can use Python for YAML parsing
    if ! python3 -c "import yaml" 2>/dev/null; then
      warn "Neither yq nor Python PyYAML available - YAML parsing limited"
    fi
  fi
}

# Helper: Parse YAML to JSON using yq or Python fallback
yaml_to_json() {
  local yaml_content="$1"
  local query="${2:-.}"

  if [[ "$HAS_YQ" == "true" ]]; then
    echo "$yaml_content" | yq -o=json "$query"
  else
    # Python fallback
    python3 -c "
import sys, yaml, json
try:
    data = yaml.safe_load(sys.stdin.read())
    # Handle simple queries like '.sponsors' or '.sponsors.local'
    query = '''$query'''
    if query != '.':
        for key in query.strip('.').split('.'):
            if key:
                data = data.get(key, []) if isinstance(data, dict) else []
    print(json.dumps(data if data else []))
except Exception as e:
    print('[]')
" <<< "$yaml_content"
  fi
}

# Helper: Read YAML field from file
yaml_read_field() {
  local file="$1"
  local field="$2"

  if [[ "$HAS_YQ" == "true" ]]; then
    yq "$field" "$file" 2>/dev/null || echo ""
  else
    python3 -c "
import yaml
try:
    with open('$file') as f:
        data = yaml.safe_load(f)
    field = '''$field'''.strip('.')
    for key in field.split('.'):
        if key:
            data = data.get(key, '') if isinstance(data, dict) else ''
    print(data if data else '')
except:
    print('')
"
  fi
}

# Resolve sponsors from SPONSOR_MANIFEST environment variable
resolve_from_manifest() {
  if [[ -z "${SPONSOR_MANIFEST:-}" ]]; then
    return 1
  fi

  info "Resolving sponsors from SPONSOR_MANIFEST..."

  # Parse YAML manifest and convert to JSON
  local sponsors
  sponsors=$(yaml_to_json "$SPONSOR_MANIFEST" ".sponsors")

  # Add source and compute local path for local sponsors
  echo "$sponsors" | jq --arg repo_root "$REPO_ROOT" '
    [.[] | . + {
      "source": "manifest",
      "path": (if .repo == "local" then ($repo_root + "/sponsor/" + .name) else null end),
      "spec_path": (.spec_path // "spec"),
      "type": (.type // "production")
    }]
  '
}

# Resolve sponsors from local sponsors.yml config file
resolve_from_config() {
  local config_file="$REPO_ROOT/.github/config/sponsors.yml"

  if [[ ! -f "$config_file" ]]; then
    return 1
  fi

  info "Resolving sponsors from sponsors.yml..."

  # Read full config and parse with Python/yq
  local config_content
  config_content=$(cat "$config_file")

  # Parse local sponsors from config
  local local_sponsors
  local_sponsors=$(yaml_to_json "$config_content" ".sponsors.local")

  # Parse remote sponsors from config (if any defined)
  local remote_sponsors
  remote_sponsors=$(yaml_to_json "$config_content" ".sponsors.remote")

  # Merge and add source
  jq -n --argjson local "$local_sponsors" --argjson remote "$remote_sponsors" --arg repo_root "$REPO_ROOT" '
    ([$local[] | . + {
      "source": "config",
      "repo": "local",
      "tag": "main",
      "path": ($repo_root + "/" + .path),
      "spec_path": (.spec_path // "spec"),
      "type": (.type // "example")
    }]) +
    ([$remote[] | . + {
      "source": "config",
      "path": null,
      "spec_path": (.spec_path // "spec"),
      "type": (.type // "production")
    }])
  '
}

# Resolve sponsors by scanning the sponsor/ directory
resolve_from_directory() {
  local sponsor_dir="$REPO_ROOT/sponsor"

  if [[ ! -d "$sponsor_dir" ]]; then
    return 1
  fi

  info "Resolving sponsors from directory scan..."

  local sponsors="[]"

  for dir in "$sponsor_dir"/*/; do
    if [[ ! -d "$dir" ]]; then
      continue
    fi

    local name
    name=$(basename "$dir")

    # Skip if no sponsor-config.yml
    local config_file="$dir/sponsor-config.yml"
    if [[ ! -f "$config_file" ]]; then
      warn "  Skipping $name (no sponsor-config.yml)"
      continue
    fi

    # Extract sponsor code and namespace
    local code namespace
    code=$(yaml_read_field "$config_file" ".sponsor.code")
    namespace=$(yaml_read_field "$config_file" ".requirements.namespace")

    # Use code if available, otherwise try namespace, otherwise uppercase name
    if [[ -z "$code" ]]; then
      code="${namespace:-$(echo "$name" | tr '[:lower:]' '[:upper:]' | cut -c1-3)}"
    fi

    # Determine type based on name
    local type="production"
    if [[ "$name" == "template" ]] || [[ "$name" == "example"* ]]; then
      type="example"
    fi

    # Add sponsor to list
    sponsors=$(echo "$sponsors" | jq --arg name "$name" \
      --arg code "$code" \
      --arg path "$dir" \
      --arg type "$type" \
      '. + [{
        "name": $name,
        "code": $code,
        "enabled": true,
        "repo": "local",
        "tag": "main",
        "path": ($path | rtrimstr("/")),
        "type": $type,
        "spec_path": "spec",
        "source": "directory"
      }]')
  done

  echo "$sponsors"
}

# Apply filters to sponsor list
apply_filters() {
  local sponsors="$1"

  # Filter by enabled status
  if [[ "$ENABLED_ONLY" == "true" ]]; then
    sponsors=$(echo "$sponsors" | jq '[.[] | select(.enabled == true)]')
  fi

  # Filter by local/remote
  if [[ "$LOCAL_ONLY" == "true" ]]; then
    sponsors=$(echo "$sponsors" | jq '[.[] | select(.repo == "local")]')
  elif [[ "$REMOTE_ONLY" == "true" ]]; then
    sponsors=$(echo "$sponsors" | jq '[.[] | select(.repo != "local")]')
  fi

  # Filter by specific sponsor name
  if [[ -n "$FILTER_SPONSOR" ]]; then
    sponsors=$(echo "$sponsors" | jq --arg name "$FILTER_SPONSOR" '[.[] | select(.name == $name)]')
  fi

  # Remove source field if not requested
  if [[ "$SHOW_SOURCE" != "true" ]]; then
    sponsors=$(echo "$sponsors" | jq '[.[] | del(.source)]')
  fi

  echo "$sponsors"
}

# Format output based on requested format
format_output() {
  local sponsors="$1"

  case "$OUTPUT_FORMAT" in
    json)
      echo "$sponsors" | jq '.'
      ;;
    names)
      echo "$sponsors" | jq -r '.[].name'
      ;;
    *)
      echo "$sponsors" | jq '.'
      ;;
  esac
}

# Main execution
main() {
  check_dependencies

  local sponsors=""
  local source_used=""

  # Try sources in priority order
  if sponsors=$(resolve_from_manifest 2>/dev/null); then
    source_used="manifest"
  elif sponsors=$(resolve_from_config 2>/dev/null); then
    source_used="config"
  elif sponsors=$(resolve_from_directory 2>/dev/null); then
    source_used="directory"
  else
    warn "No sponsors found from any source"
    echo "[]"
    exit 0
  fi

  # Validate we got valid JSON
  if ! echo "$sponsors" | jq . > /dev/null 2>&1; then
    echo -e "${RED}Error: Failed to parse sponsor data${NC}" >&2
    exit 1
  fi

  # Apply filters
  sponsors=$(apply_filters "$sponsors")

  # Output result
  format_output "$sponsors"

  # Show source if requested (to stderr so it doesn't affect JSON output)
  if [[ "$SHOW_SOURCE" == "true" ]] && [[ "$QUIET" != "true" ]]; then
    info "Source: $source_used"
  fi
}

main
