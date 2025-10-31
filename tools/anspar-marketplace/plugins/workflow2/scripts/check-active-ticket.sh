#!/bin/bash
# =====================================================
# check-active-ticket.sh
# =====================================================
#
# Quick check for active ticket in this worktree.
# Used by Claude Code to proactively enforce workflow.
#
# Usage:
#   ./check-active-ticket.sh [--silent]
#
# Exit codes:
#   0  Active ticket exists
#   1  No active ticket
#   2  No workflow state file
#
# Arguments:
#   --silent    Suppress output (only return exit code)
#
# =====================================================

set -e

SILENT=false

for arg in "$@"; do
    case $arg in
        --silent)
            SILENT=true
            ;;
    esac
done

# =====================================================
# Check for Workflow State
# =====================================================

WORKTREE_PATH="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$WORKTREE_PATH" ]; then
    if [ "$SILENT" = false ]; then
        echo "⚠️  Not in a git repository"
    fi
    exit 2
fi

# Use git-dir to support both regular repos and worktrees
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

if [ ! -f "$STATE_FILE" ]; then
    if [ "$SILENT" = false ]; then
        echo "No active ticket"
    fi
    exit 1
fi

# =====================================================
# Check for Active Ticket
# =====================================================

ACTIVE_TICKET=$(jq -r '.activeTicket.id // "none"' "$STATE_FILE" 2>/dev/null || echo "none")

if [ "$ACTIVE_TICKET" = "none" ] || [ "$ACTIVE_TICKET" = "null" ]; then
    if [ "$SILENT" = false ]; then
        echo "No active ticket"
    fi
    exit 1
fi

# =====================================================
# Active Ticket Found
# =====================================================

if [ "$SILENT" = false ]; then
    echo "$ACTIVE_TICKET"
fi

exit 0
