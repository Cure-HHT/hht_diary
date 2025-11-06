#!/bin/bash
# =====================================================
# get-active-ticket.sh
# =====================================================
#
# Retrieves the active ticket for this worktree from
# WORKFLOW_STATE.
#
# Usage:
#   ./get-active-ticket.sh [--format=<FORMAT>]
#
# Arguments:
#   --format=json     Output as JSON (default)
#   --format=id       Output only ticket ID
#   --format=reqs     Output only requirements array
#   --format=human    Output human-readable summary
#
# Examples:
#   ./get-active-ticket.sh
#   ./get-active-ticket.sh --format=id
#   ./get-active-ticket.sh --format=reqs
#
# Exit codes:
#   0  Success (ticket found)
#   1  No active ticket
#   2  State file not found
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

FORMAT="json"

for arg in "$@"; do
    case $arg in
        --format=*)
            FORMAT="${arg#*=}"
            ;;
    esac
done

# Validate format
if [[ "$FORMAT" != "json" && "$FORMAT" != "id" && "$FORMAT" != "reqs" && "$FORMAT" != "human" ]]; then
    echo "❌ ERROR: Invalid format: $FORMAT" >&2
    echo "   Expected: json, id, reqs, or human" >&2
    exit 1
fi

# =====================================================
# Worktree Info
# =====================================================

WORKTREE_PATH="$(git rev-parse --show-toplevel)"
# Use git-dir to support both regular repos and worktrees
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

if [ ! -f "$STATE_FILE" ]; then
    if [ "$FORMAT" = "human" ]; then
        echo "⚠️  No workflow state file found"
        echo "   Run claim-ticket.sh to claim a ticket"
    fi
    exit 2
fi

# =====================================================
# Read State File
# =====================================================

ACTIVE_TICKET=$(jq -r '.activeTicket' "$STATE_FILE" 2>/dev/null || echo "null")

if [ "$ACTIVE_TICKET" = "null" ]; then
    if [ "$FORMAT" = "human" ]; then
        echo "⚠️  No active ticket in this worktree"
        echo "   Run claim-ticket.sh to claim a ticket"
    fi
    exit 1
fi

# =====================================================
# Output Based on Format
# =====================================================

case $FORMAT in
    json)
        echo "$ACTIVE_TICKET" | jq '.'
        ;;

    id)
        echo "$ACTIVE_TICKET" | jq -r '.id'
        ;;

    reqs)
        echo "$ACTIVE_TICKET" | jq -r '.requirements[]'
        ;;

    human)
        TICKET_ID=$(echo "$ACTIVE_TICKET" | jq -r '.id')
        REQUIREMENTS=$(echo "$ACTIVE_TICKET" | jq -r '.requirements[]' | tr '\n' ' ')
        CLAIMED_AT=$(echo "$ACTIVE_TICKET" | jq -r '.claimedAt')
        CLAIMED_BY=$(echo "$ACTIVE_TICKET" | jq -r '.claimedBy')
        SPONSOR=$(jq -r '.sponsor // "null"' "$STATE_FILE")

        echo "📋 Active Ticket: $TICKET_ID"
        echo "   Requirements: ${REQUIREMENTS:-none}"
        echo "   Claimed: $CLAIMED_AT"
        echo "   Agent: $CLAIMED_BY"
        if [ "$SPONSOR" != "null" ] && [ -n "$SPONSOR" ]; then
            echo "   Sponsor: $SPONSOR"
        else
            echo "   Sponsor: (core)"
        fi
        ;;
esac

exit 0
