#!/bin/bash
# =====================================================
# check-doc-cache.sh
# =====================================================
#
# Checks documentation cache freshness and reports
# status to SessionStart hook.
#
# Called by: SessionStart hook
# Returns: JSON with cache status and refresh needs
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
    "hooks:https://code.claude.com/docs/en/hooks"
    "plugins-reference:https://code.claude.com/docs/en/plugins-reference"
    "cli-reference:https://code.claude.com/docs/en/cli-reference"
)

# =====================================================
# Check if cache needs refresh
# =====================================================

NEEDS_REFRESH=false
STALE_DOCS=()
CURRENT_TIME=$(date +%s)

# Check if metadata file exists
if [ ! -f "$METADATA_FILE" ]; then
    NEEDS_REFRESH=true
    STALE_DOCS=("all")
else
    # Check each document
    for doc_entry in "${DOCS[@]}"; do
        DOC_NAME="${doc_entry%%:*}"
        DOC_FILE="$CACHE_DIR/${DOC_NAME}.md"

        # Check if file exists
        if [ ! -f "$DOC_FILE" ]; then
            NEEDS_REFRESH=true
            STALE_DOCS+=("$DOC_NAME")
            continue
        fi

        # Check timestamp from metadata
        LAST_FETCH=$(jq -r ".\"$DOC_NAME\".lastFetch // 0" "$METADATA_FILE" 2>/dev/null || echo "0")

        if [ "$LAST_FETCH" = "null" ] || [ "$LAST_FETCH" = "0" ]; then
            NEEDS_REFRESH=true
            STALE_DOCS+=("$DOC_NAME")
        else
            AGE=$((CURRENT_TIME - LAST_FETCH))
            if [ $AGE -gt $CACHE_MAX_AGE ]; then
                NEEDS_REFRESH=true
                STALE_DOCS+=("$DOC_NAME")
            fi
        fi
    done
fi

# =====================================================
# Generate output
# =====================================================

if [ "$NEEDS_REFRESH" = true ]; then
    # Build URL list for refresh
    URLS_TO_FETCH=()
    for doc_entry in "${DOCS[@]}"; do
        DOC_NAME="${doc_entry%%:*}"
        DOC_URL="${doc_entry#*:}"

        # Check if this doc is stale
        if [[ "${STALE_DOCS[@]}" =~ "all" ]] || [[ "${STALE_DOCS[@]}" =~ "$DOC_NAME" ]]; then
            URLS_TO_FETCH+=("{\"name\": \"$DOC_NAME\", \"url\": \"$DOC_URL\"}")
        fi
    done

    # Join URLs with commas
    URLS_JSON=$(IFS=,; echo "${URLS_TO_FETCH[*]}")

    # Output JSON for hook
    cat <<EOF
{
  "cacheStatus": "stale",
  "needsRefresh": true,
  "staleDocuments": [$(IFS=,; echo "\"${STALE_DOCS[*]// /\", \"}\")"],
  "documentsToFetch": [$URLS_JSON],
  "cacheDir": "$CACHE_DIR",
  "metadataFile": "$METADATA_FILE"
}
EOF
else
    # Cache is fresh
    cat <<EOF
{
  "cacheStatus": "fresh",
  "needsRefresh": false,
  "cacheDir": "$CACHE_DIR"
}
EOF
fi

exit 0
