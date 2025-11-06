#!/bin/bash
# =====================================================
# switch-ticket.sh
# =====================================================
#
# Switches from current active ticket to a new ticket,
# automatically releasing the current ticket with a
# reason and claiming the new one.
#
# Usage:
#   ./switch-ticket.sh <NEW-TICKET-ID> <REASON>
#
# Arguments:
#   NEW-TICKET-ID    Ticket ID to switch to (e.g., CUR-263)
#   REASON           Reason for pausing current ticket
#
# Examples:
#   ./switch-ticket.sh CUR-263 "Blocked - waiting for review"
#   ./switch-ticket.sh CUR-264 "Focus pivot to higher priority"
#   ./switch-ticket.sh CUR-262 "Resuming previous work"
#
# Workflow:
#   1. Releases current ticket (if any) with specified reason
#   2. Claims new ticket
#   3. History preserves the full story for later resume
#
# Exit codes:
#   0  Success
#   1  Invalid arguments
#   2  Failed to release/claim
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

NEW_TICKET_ID="$1"
REASON="$2"

if [ -z "$NEW_TICKET_ID" ]; then
    echo "❌ ERROR: New ticket ID required"
    echo ""
    echo "Usage: $0 <NEW-TICKET-ID> <REASON>"
    echo ""
    echo "Examples:"
    echo "  $0 CUR-263 \"Blocked - waiting for review\""
    echo "  $0 CUR-264 \"Focus pivot to higher priority\""
    echo "  $0 CUR-262 \"Resuming previous work\""
    exit 1
fi

if [ -z "$REASON" ]; then
    echo "❌ ERROR: Reason required"
    echo "   Please provide a reason for switching tickets"
    echo ""
    echo "Common reasons:"
    echo "  - Blocked - waiting for review"
    echo "  - Blocked - waiting for dependency"
    echo "  - Focus pivot to higher priority"
    echo "  - Interrupted - short attention span"
    echo "  - Resuming previous work"
    exit 1
fi

# =====================================================
# Find Scripts
# =====================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_SCRIPT="$SCRIPT_DIR/release-ticket.sh"
CLAIM_SCRIPT="$SCRIPT_DIR/claim-ticket.sh"
GET_TICKET_SCRIPT="$SCRIPT_DIR/get-active-ticket.sh"

# =====================================================
# Check Current Ticket
# =====================================================

echo "🔄 Switching tickets..."
echo ""

if "$GET_TICKET_SCRIPT" --format=id &>/dev/null; then
    CURRENT_TICKET=$("$GET_TICKET_SCRIPT" --format=id)
    echo "Current ticket: $CURRENT_TICKET"
    echo "New ticket: $NEW_TICKET_ID"
    echo "Reason: $REASON"
    echo ""

    if [ "$CURRENT_TICKET" = "$NEW_TICKET_ID" ]; then
        echo "⚠️  Already working on ticket $NEW_TICKET_ID"
        exit 0
    fi

    # Release current ticket
    echo "📋 Releasing current ticket..."
    "$RELEASE_SCRIPT" "Switching to $NEW_TICKET_ID: $REASON"

    if [ $? -ne 0 ]; then
        echo "❌ ERROR: Failed to release current ticket"
        exit 2
    fi

    echo ""
else
    echo "ℹ️  No current ticket - claiming new ticket directly"
    echo "New ticket: $NEW_TICKET_ID"
    echo ""
fi

# =====================================================
# Claim New Ticket
# =====================================================

echo "📋 Claiming new ticket..."
"$CLAIM_SCRIPT" "$NEW_TICKET_ID"

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to claim new ticket"
    exit 2
fi

echo ""
echo "✅ Successfully switched to ticket $NEW_TICKET_ID"
echo ""

# =====================================================
# Show History (Last 5 Actions)
# =====================================================

echo "Recent activity:"
WORKTREE_PATH="$(git rev-parse --show-toplevel)"
# Use git-dir to support both regular repos and worktrees
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

if [ -f "$STATE_FILE" ]; then
    jq -r '.history[-5:] | .[] | "  [\(.timestamp | split("T")[0])] \(.action | ascii_upcase): \(.ticketId) - \(.details.reason // "N/A")"' "$STATE_FILE"
fi

echo ""

exit 0
