#!/bin/bash
# =====================================================
# release-ticket.sh
# =====================================================
#
# Releases the active ticket for this worktree by updating
# WORKFLOW_STATE to set activeTicket = null.
#
# Usage:
#   ./release-ticket.sh [REASON]
#
# Arguments:
#   REASON    Optional reason for release (default: "Work complete")
#
# Examples:
#   ./release-ticket.sh
#   ./release-ticket.sh "Switching to different ticket"
#   ./release-ticket.sh "Work blocked - need review"
#
# Integration:
#   - Updates WORKFLOW_STATE (source of truth)
#   - Optionally adds Linear comment with release reason
#
# Exit codes:
#   0  Success
#   1  No active ticket
#   2  Failed to update state file
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

REASON="${1:-Work complete}"

# =====================================================
# Worktree Info
# =====================================================

WORKTREE_PATH="$(git rev-parse --show-toplevel)"
# Use git-dir to support both regular repos and worktrees
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

if [ ! -f "$STATE_FILE" ]; then
    echo "⚠️  No workflow state file found"
    echo "   This worktree has no active ticket"
    exit 0
fi

# =====================================================
# Check Active Ticket
# =====================================================

ACTIVE_TICKET=$(jq -r '.activeTicket.id // "none"' "$STATE_FILE" 2>/dev/null || echo "none")

if [ "$ACTIVE_TICKET" = "none" ] || [ "$ACTIVE_TICKET" = "null" ]; then
    echo "⚠️  No active ticket in this worktree"
    exit 0
fi

echo "📋 Releasing ticket: $ACTIVE_TICKET"
echo "   Reason: $REASON"
echo ""

# =====================================================
# Update State File
# =====================================================

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Create release history entry
RELEASE_HISTORY_ENTRY=$(jq -n \
    --arg action "release" \
    --arg timestamp "$TIMESTAMP" \
    --arg ticketId "$ACTIVE_TICKET" \
    --arg reason "$REASON" \
    '{
        action: $action,
        timestamp: $timestamp,
        ticketId: $ticketId,
        details: {
            reason: $reason
        }
    }')

# Update state file: clear activeTicket, add release to history
jq --argjson entry "$RELEASE_HISTORY_ENTRY" \
    '.activeTicket = null | .history += [$entry]' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to update state file"
    exit 2
fi

echo "✅ Ticket released successfully!"
echo ""
echo "State file: $STATE_FILE"
echo ""

# Show current state
echo "Current state:"
jq '.' "$STATE_FILE"

# =====================================================
# Optional: Add Linear Comment
# =====================================================

# This would require linear-integration
# For now, just note that this integration point exists

echo ""
echo "💡 TIP: Consider adding a comment to Linear ticket $ACTIVE_TICKET"
echo "   Reason: $REASON"
echo ""

exit 0
