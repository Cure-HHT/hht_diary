#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00005: Sponsor Configuration Detection Implementation
#
# Collect sponsor content from sponsor repositories into sponsor-content/
# for Docker build consumption.
#
# Usage:
#   tools/build/collect-sponsor-content.sh           # Clone from GitHub (CI/CD)
#   tools/build/collect-sponsor-content.sh --local    # Copy from sibling dirs (dev)
#
# Requires:
#   - jq (JSON parsing)
#   - git or gh CLI (for cloning)
#   - GH_TOKEN env var (for private repos in CI/CD mode)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/sponsor-repos.json"
OUTPUT_DIR="$REPO_ROOT/sponsor-content"
LOCAL_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --local)
            LOCAL_MODE=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--local]"
            exit 1
            ;;
    esac
done

# Validate dependencies
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required but not installed."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Clean and create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Collecting sponsor content"
echo "Mode: $([ "$LOCAL_MODE" = true ] && echo "local" || echo "github")"
echo "Config: $CONFIG_FILE"
echo "Output: $OUTPUT_DIR"
echo "========================================"

# Read sponsor repos from config
SPONSOR_COUNT=$(jq length "$CONFIG_FILE")
echo "Found $SPONSOR_COUNT sponsor(s) in config"

ERRORS=0

for i in $(seq 0 $((SPONSOR_COUNT - 1))); do
    SPONSOR_ID=$(jq -r ".[$i].sponsorId" "$CONFIG_FILE")
    REPO=$(jq -r ".[$i].repo" "$CONFIG_FILE")

    echo ""
    echo "--- Sponsor: $SPONSOR_ID (repo: $REPO) ---"

    SPONSOR_OUTPUT="$OUTPUT_DIR/$SPONSOR_ID"

    if [ "$LOCAL_MODE" = true ]; then
        # Local mode: copy from sibling directory
        LOCAL_DIR="$REPO_ROOT/../hht_diary_${SPONSOR_ID}/content"

        if [ ! -d "$LOCAL_DIR" ]; then
            echo "ERROR: Local content directory not found: $LOCAL_DIR"
            ERRORS=$((ERRORS + 1))
            continue
        fi

        echo "Copying from $LOCAL_DIR"
        cp -r "$LOCAL_DIR" "$SPONSOR_OUTPUT"
    else
        # CI/CD mode: sparse clone from GitHub
        CLONE_DIR=$(mktemp -d)
        trap "rm -rf $CLONE_DIR" EXIT

        echo "Cloning content/ from $REPO"
        git clone --depth 1 --filter=blob:none --sparse \
            "https://x-access-token:${GH_TOKEN:-}@github.com/$REPO.git" \
            "$CLONE_DIR" 2>&1 || {
            echo "ERROR: Failed to clone $REPO. Check GH_TOKEN and repo access."
            ERRORS=$((ERRORS + 1))
            continue
        }

        (cd "$CLONE_DIR" && git sparse-checkout set content)

        if [ ! -d "$CLONE_DIR/content" ]; then
            echo "ERROR: No content/ directory in $REPO"
            ERRORS=$((ERRORS + 1))
            rm -rf "$CLONE_DIR"
            continue
        fi

        cp -r "$CLONE_DIR/content" "$SPONSOR_OUTPUT"
        rm -rf "$CLONE_DIR"
    fi

    # Validate sponsor-config.json exists and has sponsorId
    if [ ! -f "$SPONSOR_OUTPUT/sponsor-config.json" ]; then
        echo "ERROR: Missing sponsor-config.json for $SPONSOR_ID"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    CONFIG_SPONSOR_ID=$(jq -r '.sponsorId // empty' "$SPONSOR_OUTPUT/sponsor-config.json")
    if [ "$CONFIG_SPONSOR_ID" != "$SPONSOR_ID" ]; then
        echo "ERROR: sponsorId mismatch in sponsor-config.json"
        echo "  Expected: $SPONSOR_ID"
        echo "  Got: $CONFIG_SPONSOR_ID"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    echo "OK: Collected content for $SPONSOR_ID"
    ls -la "$SPONSOR_OUTPUT/"
done

echo ""
echo "========================================"
if [ $ERRORS -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) encountered"
    exit 1
fi
echo "SUCCESS: All $SPONSOR_COUNT sponsor(s) collected"
echo "========================================"
