#!/bin/bash
# =====================================================
# release-ticket.sh
# =====================================================
#
# Releases the active ticket for this worktree by updating
# WORKFLOW_STATE to set activeTicket = null.
#
# Usage:
#   ./release-ticket.sh [REASON] [--pr-number NUM] [--pr-url URL]
#
# Arguments:
#   REASON         Optional reason for release (default: "Work complete")
#   --pr-number    GitHub PR number (adds Linear comment with PR link)
#   --pr-url       GitHub PR URL (used with --pr-number)
#
# Examples:
#   ./release-ticket.sh
#   ./release-ticket.sh "Switching to different ticket"
#   ./release-ticket.sh "Work complete" --pr-number 42 --pr-url https://github.com/org/repo/pull/42
#
# Integration:
#   - Updates WORKFLOW_STATE (source of truth)
#   - Optionally adds Linear comment with release reason and PR link
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
PR_NUMBER=""
PR_URL=""

# Parse optional flags
shift || true
while [ $# -gt 0 ]; do
    case "$1" in
        --pr-number)
            PR_NUMBER="$2"
            shift 2
            ;;
        --pr-url)
            PR_URL="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

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

# Find plugin and marketplace directories
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKETPLACE_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
ADD_COMMENT_SCRIPT="$MARKETPLACE_ROOT/shared/scripts/add-linear-comment.sh"

# Build Linear comment if PR info provided
if [ -n "$PR_NUMBER" ] || [ -n "$PR_URL" ]; then
    if [ -n "$PR_NUMBER" ] && [ -n "$PR_URL" ]; then
        LINEAR_COMMENT="$REASON - [PR #${PR_NUMBER}](${PR_URL})"
    elif [ -n "$PR_NUMBER" ]; then
        LINEAR_COMMENT="$REASON - PR #${PR_NUMBER}"
    else
        LINEAR_COMMENT="$REASON"
    fi

    if [ -f "$ADD_COMMENT_SCRIPT" ]; then
        echo ""
        echo "💬 Adding comment to Linear ticket $ACTIVE_TICKET..."
        "$ADD_COMMENT_SCRIPT" "$ACTIVE_TICKET" "$LINEAR_COMMENT" || {
            echo "⚠️  Failed to add Linear comment (non-fatal)" >&2
        }
    else
        echo ""
        echo "💡 TIP: Install shared/scripts/add-linear-comment.sh for Linear integration"
    fi
else
    echo ""
    echo "💡 TIP: Consider adding a comment to Linear ticket $ACTIVE_TICKET"
    echo "   Use --pr-number and --pr-url flags to automatically add PR reference"
fi

echo ""
exit 0
