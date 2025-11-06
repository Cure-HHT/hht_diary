#!/bin/bash
# =====================================================
# list-history.sh
# =====================================================
#
# Lists the full workflow history for this worktree,
# showing all ticket claims, releases, and commits.
#
# Usage:
#   ./list-history.sh [--limit=N] [--action=ACTION]
#
# Arguments:
#   --limit=N         Show only last N actions (default: all)
#   --action=ACTION   Filter by action type: claim|release|commit
#   --format=FORMAT   Output format: human|json (default: human)
#
# Examples:
#   ./list-history.sh
#   ./list-history.sh --limit=10
#   ./list-history.sh --action=claim
#   ./list-history.sh --format=json
#
# Exit codes:
#   0  Success
#   1  No history found
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

LIMIT=""
ACTION_FILTER=""
FORMAT="human"

for arg in "$@"; do
    case $arg in
        --limit=*)
            LIMIT="${arg#*=}"
            ;;
        --action=*)
            ACTION_FILTER="${arg#*=}"
            ;;
        --format=*)
            FORMAT="${arg#*=}"
            ;;
    esac
done

# Validate format
if [[ "$FORMAT" != "human" && "$FORMAT" != "json" ]]; then
    echo "❌ ERROR: Invalid format: $FORMAT"
    echo "   Expected: human or json"
    exit 1
fi

# =====================================================
# Read State File
# =====================================================

WORKTREE_PATH="$(git rev-parse --show-toplevel)"
# Use git-dir to support both regular repos and worktrees
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

if [ ! -f "$STATE_FILE" ]; then
    echo "⚠️  No workflow state file found"
    echo "   This worktree has no history yet"
    exit 1
fi

HISTORY=$(jq -r '.history' "$STATE_FILE" 2>/dev/null || echo "[]")

if [ "$HISTORY" = "[]" ]; then
    echo "⚠️  No workflow history found"
    exit 1
fi

# =====================================================
# Filter by Action
# =====================================================

if [ -n "$ACTION_FILTER" ]; then
    HISTORY=$(echo "$HISTORY" | jq --arg action "$ACTION_FILTER" '[.[] | select(.action == $action)]')
fi

# =====================================================
# Limit Results
# =====================================================

if [ -n "$LIMIT" ]; then
    HISTORY=$(echo "$HISTORY" | jq ".[-${LIMIT}:]")
fi

# =====================================================
# Output
# =====================================================

if [ "$FORMAT" = "json" ]; then
    echo "$HISTORY" | jq '.'
else
    # Human-readable format
    echo "📜 Workflow History"
    echo ""

    echo "$HISTORY" | jq -r '.[] |
        "\u001b[36m[\(.timestamp | split("T")[0]) \(.timestamp | split("T")[1] | split("Z")[0])]\u001b[0m " +
        if .action == "claim" then "\u001b[32m✓ CLAIM\u001b[0m"
        elif .action == "release" then "\u001b[33m○ RELEASE\u001b[0m"
        elif .action == "commit" then "\u001b[35m◆ COMMIT\u001b[0m"
        else .action
        end +
        ": \(.ticketId)" +
        if .details.reason then " - \(.details.reason)"
        elif .details.commitHash then " - \(.details.commitHash[:7])"
        else ""
        end
    '

    echo ""
    echo "Legend:"
    echo "  ✓ CLAIM   - Ticket claimed for this worktree"
    echo "  ○ RELEASE - Ticket released (paused/completed)"
    echo "  ◆ COMMIT  - Commit created"
    echo ""
fi

exit 0
