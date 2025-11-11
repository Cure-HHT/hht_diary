#!/bin/bash
# Sponsor Integration Script
#
# Integrates sponsor modules into the core application during build.
# Supports both mono-repo (local) and multi-repo modes.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00070: Sponsor integration automation
#   REQ-d00069: Doppler manifest system
#
# USAGE:
#   ./tools/build/integrate-sponsors.sh [--manifest MANIFEST_FILE]
#
# ENVIRONMENT VARIABLES:
#   SPONSOR_MANIFEST - YAML manifest from Doppler (required if --manifest not provided)
#   SPONSOR_REPO_TOKEN - GitHub PAT for cloning private repos (required for multi-repo mode)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPONSOR_DIR="$REPO_ROOT/sponsor"
BUILD_MANIFEST="$REPO_ROOT/build/sponsor-build-manifest.json"

# Parse arguments
MANIFEST_FILE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --manifest)
      MANIFEST_FILE="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Error: Unknown argument $1${NC}" >&2
      echo "Usage: $0 [--manifest MANIFEST_FILE]" >&2
      exit 1
      ;;
  esac
done

# Load manifest
if [[ -n "$MANIFEST_FILE" ]]; then
  if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo -e "${RED}Error: Manifest file not found: $MANIFEST_FILE${NC}" >&2
    exit 1
  fi
  MANIFEST=$(cat "$MANIFEST_FILE")
elif [[ -n "${SPONSOR_MANIFEST:-}" ]]; then
  MANIFEST="$SPONSOR_MANIFEST"
else
  echo -e "${RED}Error: No manifest provided${NC}" >&2
  echo "Provide manifest via --manifest or SPONSOR_MANIFEST environment variable" >&2
  exit 1
fi

echo -e "${BLUE}=== Sponsor Integration Starting ===${NC}"
echo "Manifest source: ${MANIFEST_FILE:-SPONSOR_MANIFEST env var}"
echo ""

# Validate yq is installed
if ! command -v yq &> /dev/null; then
  echo -e "${RED}Error: yq is required but not installed${NC}" >&2
  echo "Install: brew install yq (macOS) or snap install yq (Linux)" >&2
  exit 1
fi

# Parse manifest
echo -e "${BLUE}Parsing sponsor manifest...${NC}"
SPONSOR_COUNT=$(echo "$MANIFEST" | yq '.sponsors | length')
echo "Found $SPONSOR_COUNT sponsor(s) in manifest"
echo ""

# Initialize build manifest
mkdir -p "$(dirname "$BUILD_MANIFEST")"
echo "{\"sponsors\": [], \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"git_sha\": \"$(git rev-parse HEAD)\"}" > "$BUILD_MANIFEST"

# Track integration results
INTEGRATED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

# Process each sponsor
for i in $(seq 0 $((SPONSOR_COUNT - 1))); do
  # Extract sponsor fields
  SPONSOR_NAME=$(echo "$MANIFEST" | yq ".sponsors[$i].name")
  SPONSOR_CODE=$(echo "$MANIFEST" | yq ".sponsors[$i].code")
  SPONSOR_ENABLED=$(echo "$MANIFEST" | yq ".sponsors[$i].enabled")
  SPONSOR_REPO=$(echo "$MANIFEST" | yq ".sponsors[$i].repo")
  SPONSOR_TAG=$(echo "$MANIFEST" | yq ".sponsors[$i].tag")
  MOBILE_MODULE=$(echo "$MANIFEST" | yq ".sponsors[$i].mobile_module")
  PORTAL=$(echo "$MANIFEST" | yq ".sponsors[$i].portal")
  REGION=$(echo "$MANIFEST" | yq ".sponsors[$i].region")

  echo -e "${BLUE}Processing sponsor: $SPONSOR_NAME ($SPONSOR_CODE)${NC}"
  echo "  Enabled: $SPONSOR_ENABLED"
  echo "  Repo: $SPONSOR_REPO"
  echo "  Tag: $SPONSOR_TAG"
  echo "  Mobile Module: $MOBILE_MODULE"
  echo "  Portal: $PORTAL"
  echo "  Region: $REGION"

  # Skip if not enabled
  if [[ "$SPONSOR_ENABLED" != "true" ]]; then
    echo -e "${YELLOW}  ⏭️  Skipping (not enabled)${NC}"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    echo ""
    continue
  fi

  # Integrate based on repo type
  if [[ "$SPONSOR_REPO" == "local" ]]; then
    echo -e "${GREEN}  📁 Mono-repo mode (local)${NC}"

    # Verify sponsor directory exists
    if [[ ! -d "$SPONSOR_DIR/$SPONSOR_NAME" ]]; then
      echo -e "${RED}  ❌ Error: Sponsor directory not found: $SPONSOR_DIR/$SPONSOR_NAME${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi

    # Verify sponsor-config.yml exists
    if [[ ! -f "$SPONSOR_DIR/$SPONSOR_NAME/sponsor-config.yml" ]]; then
      echo -e "${RED}  ❌ Error: sponsor-config.yml not found${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi

    # Read config and verify namespace
    CONFIG_NAMESPACE=$(yq '.requirements.namespace' "$SPONSOR_DIR/$SPONSOR_NAME/sponsor-config.yml")
    if [[ "$CONFIG_NAMESPACE" != "$SPONSOR_CODE" ]]; then
      echo -e "${RED}  ❌ Error: Namespace mismatch (expected: $SPONSOR_CODE, got: $CONFIG_NAMESPACE)${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi

    # Record in build manifest
    SPONSOR_GIT_SHA=$(git rev-parse HEAD)

  else
    echo -e "${GREEN}  🌐 Multi-repo mode${NC}"

    # Verify GitHub token is available
    if [[ -z "${SPONSOR_REPO_TOKEN:-}" ]]; then
      echo -e "${RED}  ❌ Error: SPONSOR_REPO_TOKEN not set (required for multi-repo mode)${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi

    # Clone sponsor repo
    SPONSOR_PATH="$SPONSOR_DIR/$SPONSOR_NAME"

    # Remove existing directory if present
    if [[ -d "$SPONSOR_PATH" ]]; then
      echo "  🗑️  Removing existing directory"
      rm -rf "$SPONSOR_PATH"
    fi

    echo "  📥 Cloning $SPONSOR_REPO @ $SPONSOR_TAG"

    if ! git clone \
      --depth 1 \
      --branch "$SPONSOR_TAG" \
      "https://${SPONSOR_REPO_TOKEN}@github.com/${SPONSOR_REPO}.git" \
      "$SPONSOR_PATH"; then
      echo -e "${RED}  ❌ Error: Failed to clone sponsor repo${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi

    # Get commit SHA
    SPONSOR_GIT_SHA=$(git -C "$SPONSOR_PATH" rev-parse HEAD)
    echo "  📌 Commit SHA: $SPONSOR_GIT_SHA"

    # Verify sponsor-config.yml exists
    if [[ ! -f "$SPONSOR_PATH/sponsor-config.yml" ]]; then
      echo -e "${RED}  ❌ Error: sponsor-config.yml not found in cloned repo${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi

    # Verify namespace
    CONFIG_NAMESPACE=$(yq '.requirements.namespace' "$SPONSOR_PATH/sponsor-config.yml")
    if [[ "$CONFIG_NAMESPACE" != "$SPONSOR_CODE" ]]; then
      echo -e "${RED}  ❌ Error: Namespace mismatch (expected: $SPONSOR_CODE, got: $CONFIG_NAMESPACE)${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi

    # Remove .git directory to avoid nested repos
    rm -rf "$SPONSOR_PATH/.git"
  fi

  # Verify mobile module structure if enabled
  if [[ "$MOBILE_MODULE" == "true" ]]; then
    if [[ ! -d "$SPONSOR_DIR/$SPONSOR_NAME/mobile-module" ]]; then
      echo -e "${RED}  ❌ Error: mobile-module directory not found${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi
    echo "  ✅ Mobile module verified"
  fi

  # Verify portal structure if enabled
  if [[ "$PORTAL" == "true" ]]; then
    if [[ ! -d "$SPONSOR_DIR/$SPONSOR_NAME/portal" ]]; then
      echo -e "${RED}  ❌ Error: portal directory not found${NC}" >&2
      ERROR_COUNT=$((ERROR_COUNT + 1))
      echo ""
      continue
    fi
    echo "  ✅ Portal verified"
  fi

  # Record in build manifest
  jq --arg name "$SPONSOR_NAME" \
     --arg code "$SPONSOR_CODE" \
     --arg repo "$SPONSOR_REPO" \
     --arg tag "$SPONSOR_TAG" \
     --arg sha "$SPONSOR_GIT_SHA" \
     --argjson mobile "$MOBILE_MODULE" \
     --argjson portal "$PORTAL" \
     --arg region "$REGION" \
     '.sponsors += [{
       "name": $name,
       "code": $code,
       "repo": $repo,
       "tag": $tag,
       "git_sha": $sha,
       "mobile_module": $mobile,
       "portal": $portal,
       "region": $region
     }]' "$BUILD_MANIFEST" > "$BUILD_MANIFEST.tmp"
  mv "$BUILD_MANIFEST.tmp" "$BUILD_MANIFEST"

  echo -e "${GREEN}  ✅ Integration successful${NC}"
  INTEGRATED_COUNT=$((INTEGRATED_COUNT + 1))
  echo ""
done

# Summary
echo -e "${BLUE}=== Integration Summary ===${NC}"
echo "✅ Integrated: $INTEGRATED_COUNT"
echo "⏭️  Skipped: $SKIPPED_COUNT"
echo "❌ Errors: $ERROR_COUNT"
echo ""
echo "Build manifest written to: $BUILD_MANIFEST"
cat "$BUILD_MANIFEST" | jq '.'

# Exit with error if any failures
if [[ $ERROR_COUNT -gt 0 ]]; then
  echo -e "${RED}Integration completed with errors${NC}" >&2
  exit 1
fi

echo -e "${GREEN}✅ Integration completed successfully${NC}"
exit 0
