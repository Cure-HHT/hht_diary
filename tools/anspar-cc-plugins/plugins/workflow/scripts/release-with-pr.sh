#!/bin/bash
# =====================================================
# release-with-pr.sh
# =====================================================
#
# Releases active ticket with PR reference.
# Called by post-tool-use hook after PR merge.
#
# Usage:
#   ./release-with-pr.sh TICKET_ID PR_NUMBER PR_URL [BRANCH_TO_DELETE]
#
# Arguments:
#   TICKET_ID         Linear ticket identifier (e.g., CUR-123)
#   PR_NUMBER         GitHub PR number
#   PR_URL            GitHub PR URL
#   BRANCH_TO_DELETE  Optional: local branch to delete (if safe)
#
# =====================================================

set -e

TICKET_ID="$1"
PR_NUMBER="$2"
PR_URL="$3"
BRANCH_TO_DELETE="$4"

if [ -z "$TICKET_ID" ]; then
    echo "❌ ERROR: TICKET_ID required" >&2
    exit 1
fi

# Build reason message
if [ -n "$PR_NUMBER" ] && [ -n "$PR_URL" ]; then
    REASON="Work complete - PR #${PR_NUMBER} merged"
    LINEAR_COMMENT="Work complete - [PR #${PR_NUMBER}](${PR_URL})"
elif [ -n "$PR_NUMBER" ]; then
    REASON="Work complete - PR #${PR_NUMBER} merged"
    LINEAR_COMMENT="Work complete - PR #${PR_NUMBER}"
else
    REASON="Work complete - PR merged"
    LINEAR_COMMENT="Work complete"
fi

# Find plugin directory
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_SCRIPT="$PLUGIN_DIR/scripts/release-ticket.sh"

# Find shared scripts
MARKETPLACE_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
ADD_COMMENT_SCRIPT="$MARKETPLACE_ROOT/shared/scripts/add-linear-comment.sh"

echo "📋 Releasing ticket: $TICKET_ID"
echo "   Reason: $REASON"
echo ""

# Release ticket
if [ -f "$RELEASE_SCRIPT" ]; then
    "$RELEASE_SCRIPT" "$REASON"
else
    echo "❌ ERROR: release-ticket.sh not found at $RELEASE_SCRIPT" >&2
    exit 2
fi

# Add Linear comment if script exists
if [ -f "$ADD_COMMENT_SCRIPT" ]; then
    echo ""
    echo "💬 Adding comment to Linear..."
    "$ADD_COMMENT_SCRIPT" "$TICKET_ID" "$LINEAR_COMMENT" || {
        echo "⚠️  Failed to add Linear comment (non-fatal)" >&2
    }
else
    echo "⚠️  Linear comment script not found - skipping" >&2
fi

echo ""
echo "✅ Ticket released with PR reference!"

# Delete branch if requested and safe
if [ -n "$BRANCH_TO_DELETE" ]; then
    echo ""
    echo "🗑️  Deleting local branch: $BRANCH_TO_DELETE"

    # Switch to main first
    git checkout main >/dev/null 2>&1 || {
        echo "⚠️  Failed to switch to main - branch not deleted" >&2
        exit 0
    }

    # Delete the branch
    if git branch -d "$BRANCH_TO_DELETE" 2>&1; then
        echo "✅ Branch deleted successfully"
    else
        echo "⚠️  Failed to delete branch (it may have unmerged changes)" >&2
    fi
fi

exit 0
