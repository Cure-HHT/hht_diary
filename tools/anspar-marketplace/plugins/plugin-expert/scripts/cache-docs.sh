#!/bin/bash
# =====================================================
# cache-docs.sh
# =====================================================
#
# Fetches and caches Claude Code documentation for
# offline reference and improved performance.
#
# Usage:
#   ./cache-docs.sh              # Refresh stale docs only
#   ./cache-docs.sh --force      # Force refresh all docs
#   ./cache-docs.sh --status     # Show cache status
#
# =====================================================

set -e

# Find plugin directory
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$PLUGIN_DIR/cache/docs"
METADATA_FILE="$CACHE_DIR/.cache-metadata.json"

# Cache age threshold (24 hours in seconds)
CACHE_MAX_AGE=$((24 * 60 * 60))

# Documentation URLs to cache
DOCS=(
    "agent-sdk-overview:https://docs.claude.com/en/api/agent-sdk/overview"
    "hooks:https://docs.claude.com/en/docs/claude-code/hooks"
    "plugins-reference:https://docs.claude.com/en/docs/claude-code/plugins"
    "cli-reference:https://docs.claude.com/en/docs/claude-code/cli"
)

# =====================================================
# Parse arguments
# =====================================================

FORCE=false
STATUS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --status)
            STATUS_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force] [--status]"
            exit 1
            ;;
    esac
done

# =====================================================
# Status mode
# =====================================================

if [ "$STATUS_ONLY" = true ]; then
    if [ ! -f "$METADATA_FILE" ]; then
        echo "📦 Cache status: Empty (no metadata file)"
        exit 0
    fi

    echo "📦 Cache status:"
    echo ""

    CURRENT_TIME=$(date +%s)
    for doc_entry in "${DOCS[@]}"; do
        DOC_NAME="${doc_entry%%:*}"
        DOC_FILE="$CACHE_DIR/${DOC_NAME}.md"

        if [ ! -f "$DOC_FILE" ]; then
            echo "  ❌ $DOC_NAME: Not cached"
        else
            LAST_FETCH=$(jq -r ".\"$DOC_NAME\".lastFetch // 0" "$METADATA_FILE" 2>/dev/null || echo "0")

            if [ "$LAST_FETCH" = "0" ] || [ "$LAST_FETCH" = "null" ]; then
                echo "  ⚠️  $DOC_NAME: Cached (unknown age)"
            else
                AGE=$((CURRENT_TIME - LAST_FETCH))
                AGE_HOURS=$((AGE / 3600))

                if [ $AGE -gt $CACHE_MAX_AGE ]; then
                    echo "  ⏰ $DOC_NAME: Stale (${AGE_HOURS}h old)"
                else
                    echo "  ✅ $DOC_NAME: Fresh (${AGE_HOURS}h old)"
                fi
            fi
        fi
    done

    exit 0
fi

# =====================================================
# Create cache directory if needed
# =====================================================

mkdir -p "$CACHE_DIR"

# Initialize metadata file if it doesn't exist
if [ ! -f "$METADATA_FILE" ]; then
    echo '{}' > "$METADATA_FILE"
fi

# =====================================================
# Fetch documentation
# =====================================================

echo "📚 Fetching Claude Code documentation..."
echo ""

FETCH_COUNT=0
SUCCESS_COUNT=0
CURRENT_TIME=$(date +%s)

for doc_entry in "${DOCS[@]}"; do
    DOC_NAME="${doc_entry%%:*}"
    DOC_URL="${doc_entry#*:}"
    DOC_FILE="$CACHE_DIR/${DOC_NAME}.md"

    # Check if we need to fetch
    SHOULD_FETCH=false

    if [ "$FORCE" = true ]; then
        SHOULD_FETCH=true
    elif [ ! -f "$DOC_FILE" ]; then
        SHOULD_FETCH=true
    else
        LAST_FETCH=$(jq -r ".\"$DOC_NAME\".lastFetch // 0" "$METADATA_FILE" 2>/dev/null || echo "0")

        if [ "$LAST_FETCH" = "0" ] || [ "$LAST_FETCH" = "null" ]; then
            SHOULD_FETCH=true
        else
            AGE=$((CURRENT_TIME - LAST_FETCH))
            if [ $AGE -gt $CACHE_MAX_AGE ]; then
                SHOULD_FETCH=true
            fi
        fi
    fi

    if [ "$SHOULD_FETCH" = false ]; then
        echo "  ⏭️  Skipping $DOC_NAME (cache fresh)"
        continue
    fi

    FETCH_COUNT=$((FETCH_COUNT + 1))
    echo "  ⬇️  Fetching $DOC_NAME..."

    # Fetch with curl
    if curl -sS -L -o "$DOC_FILE.tmp" "$DOC_URL" 2>/dev/null; then
        # Verify we got actual content (not error page)
        if [ -s "$DOC_FILE.tmp" ]; then
            mv "$DOC_FILE.tmp" "$DOC_FILE"

            # Update metadata
            METADATA=$(jq --arg name "$DOC_NAME" \
                          --arg timestamp "$CURRENT_TIME" \
                          --arg url "$DOC_URL" \
                          '.[$name] = {
                              "lastFetch": ($timestamp | tonumber),
                              "url": $url,
                              "status": "success"
                          }' "$METADATA_FILE")
            echo "$METADATA" > "$METADATA_FILE"

            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            echo "     ✅ Cached"
        else
            rm -f "$DOC_FILE.tmp"
            echo "     ⚠️  Empty response - skipped"

            # Update metadata with failure
            METADATA=$(jq --arg name "$DOC_NAME" \
                          --arg timestamp "$CURRENT_TIME" \
                          '.[$name].lastAttempt = ($timestamp | tonumber) |
                           .[$name].status = "failed"' "$METADATA_FILE")
            echo "$METADATA" > "$METADATA_FILE"
        fi
    else
        rm -f "$DOC_FILE.tmp"
        echo "     ❌ Fetch failed"

        # Update metadata with failure
        METADATA=$(jq --arg name "$DOC_NAME" \
                      --arg timestamp "$CURRENT_TIME" \
                      '.[$name].lastAttempt = ($timestamp | tonumber) |
                       .[$name].status = "failed"' "$METADATA_FILE")
        echo "$METADATA" > "$METADATA_FILE"
    fi
done

# =====================================================
# Summary
# =====================================================

echo ""
if [ $FETCH_COUNT -eq 0 ]; then
    echo "✅ All documentation is fresh"
else
    echo "📊 Fetched $SUCCESS_COUNT / $FETCH_COUNT documents"

    if [ $SUCCESS_COUNT -lt $FETCH_COUNT ]; then
        echo "⚠️  Some documents failed to fetch - using stale cache where available"
    fi
fi

exit 0
