#!/bin/bash
# =====================================================
# fetch-ticket-reqs.sh
# =====================================================
#
# Fetches requirement references from a Linear ticket
# and caches them in WORKFLOW_STATE.
#
# Architecture:
#   1. Uses linear-api plugin to fetch ticket data
#   2. Uses parse-req-refs.sh to extract REQ references
#   3. Caches results in WORKFLOW_STATE
#
# Usage:
#   ./fetch-ticket-reqs.sh [TICKET-ID]
#
# Arguments:
#   TICKET-ID    Optional ticket ID (defaults to active ticket)
#
# Examples:
#   ./fetch-ticket-reqs.sh
#   ./fetch-ticket-reqs.sh CUR-240
#
# Exit codes:
#   0  Success
#   1  No ticket specified/found
#   2  Failed to fetch from Linear
#   3  Failed to update state file
#
# =====================================================

set -e

# =====================================================
# Configuration
# =====================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

# =====================================================
# Get Ticket ID
# =====================================================

TICKET_ID="$1"

if [ -z "$TICKET_ID" ]; then
    # Try to get active ticket
    if [ -f "$STATE_FILE" ]; then
        TICKET_ID=$(jq -r '.activeTicket.id' "$STATE_FILE" 2>/dev/null || echo "null")
        if [ "$TICKET_ID" = "null" ]; then
            echo "❌ ERROR: No active ticket found"
            echo "   Run: claim-ticket.sh <TICKET-ID>"
            exit 1
        fi
    else
        echo "❌ ERROR: No workflow state file and no ticket ID provided"
        exit 1
    fi
fi

echo "🔍 Fetching requirements for $TICKET_ID..."

# =====================================================
# Step 1: Fetch Ticket from Linear
# =====================================================

# Check if linear-api plugin is available
LINEAR_PLUGIN="$SCRIPT_DIR/../../linear-api"
if [ ! -d "$LINEAR_PLUGIN" ]; then
    echo "⚠️  WARNING: linear-api plugin not found"
    echo "   Requirements will not be fetched from Linear"
    exit 0
fi

# Use Linear API to fetch ticket
LINEAR_FETCH="$LINEAR_PLUGIN/scripts/fetch-tickets.js"
if [ ! -x "$LINEAR_FETCH" ]; then
    echo "⚠️  WARNING: Linear fetch script not executable"
    exit 0
fi

# Fetch ticket data
echo "  📥 Fetching from Linear..."
TICKET_DATA=$("$LINEAR_FETCH" "$TICKET_ID" 2>/dev/null || echo "null")

if [ "$TICKET_DATA" = "null" ] || [ -z "$TICKET_DATA" ]; then
    echo "⚠️  WARNING: Could not fetch ticket from Linear"
    echo "   Continuing without requirements"
    exit 0
fi

# =====================================================
# Step 2: Parse REQ References
# =====================================================

# Extract description from ticket
DESCRIPTION=$(echo "$TICKET_DATA" | jq -r '.description // ""' 2>/dev/null)

if [ -z "$DESCRIPTION" ] || [ "$DESCRIPTION" = "null" ]; then
    echo "ℹ️  No description found in ticket"
    echo "   No requirements to cache"
    REQUIREMENTS="[]"
else
    # Use the reusable parser to extract REQ references
    echo "  🔍 Parsing REQ references..."
    REQUIREMENTS=$(echo "$DESCRIPTION" | "$SCRIPT_DIR/parse-req-refs.sh" --format=json)

    if [ "$REQUIREMENTS" = "[]" ] || [ -z "$REQUIREMENTS" ]; then
        echo "ℹ️  No requirement references found in ticket description"
        echo "   Expected format: REQ-p00042, REQ-d00027, REQ-o00015"
        REQUIREMENTS="[]"
    else
        REQ_COUNT=$(echo "$REQUIREMENTS" | jq 'length')
        echo "✅ Found $REQ_COUNT requirement(s):"
        echo "$REQUIREMENTS" | jq -r '.[]' | sed 's/^/   - /'
    fi
fi

# =====================================================
# Update WORKFLOW_STATE
# =====================================================

if [ ! -f "$STATE_FILE" ]; then
    echo "❌ ERROR: Workflow state file not found"
    exit 3
fi

# Update requirements in activeTicket
TMP_FILE=$(mktemp)
jq ".activeTicket.requirements = $REQUIREMENTS" "$STATE_FILE" > "$TMP_FILE"

if [ $? -eq 0 ]; then
    mv "$TMP_FILE" "$STATE_FILE"
    echo "✅ Requirements cached in workflow state"
else
    rm -f "$TMP_FILE"
    echo "❌ ERROR: Failed to update workflow state"
    exit 3
fi

exit 0
