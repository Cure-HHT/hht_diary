#!/bin/bash
# =====================================================
# resume-ticket.sh
# =====================================================
#
# Resumes work on a previously released ticket by
# showing recent released tickets and allowing selection.
#
# Usage:
#   ./resume-ticket.sh [TICKET-ID]
#
# Arguments:
#   TICKET-ID    Optional ticket ID to resume directly
#
# Examples:
#   ./resume-ticket.sh              # Interactive selection
#   ./resume-ticket.sh CUR-262      # Resume specific ticket
#
# Workflow:
#   1. Shows recently released tickets from history
#   2. Allows interactive selection or direct specification
#   3. Claims the selected ticket
#
# Exit codes:
#   0  Success
#   1  No released tickets found
#   2  Invalid selection
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

TICKET_ID="$1"

# =====================================================
# Find Scripts
# =====================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAIM_SCRIPT="$SCRIPT_DIR/claim-ticket.sh"

# =====================================================
# Read State File
# =====================================================

WORKTREE_PATH="$(git rev-parse --show-toplevel)"
# Use git-dir to support both regular repos and worktrees
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

if [ ! -f "$STATE_FILE" ]; then
    echo "⚠️  No workflow state file found"
    echo "   No previous tickets to resume"
    exit 1
fi

# =====================================================
# Find Recently Released Tickets
# =====================================================

# Get last 20 release actions
RELEASED_TICKETS=$(jq -r '
    [.history[] | select(.action == "release")] |
    .[-20:] |
    reverse |
    .[] |
    "\(.ticketId)|\(.timestamp)|\(.details.reason // "No reason")"
' "$STATE_FILE" 2>/dev/null || true)

if [ -z "$RELEASED_TICKETS" ]; then
    echo "⚠️  No released tickets found in history"
    echo "   Nothing to resume"
    exit 1
fi

# =====================================================
# Interactive or Direct Selection
# =====================================================

if [ -n "$TICKET_ID" ]; then
    # Direct selection - verify ticket was released before
    if ! echo "$RELEASED_TICKETS" | grep -q "^$TICKET_ID|"; then
        echo "⚠️  WARNING: Ticket $TICKET_ID not found in recent release history"
        echo "   This might be a new ticket or one from a different worktree"
        echo ""
        read -p "Continue claiming this ticket anyway? [y/N] " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Cancelled"
            exit 0
        fi
    fi

    SELECTED_TICKET="$TICKET_ID"
else
    # Interactive selection
    echo "📋 Recently Released Tickets"
    echo ""
    echo "Select a ticket to resume:"
    echo ""

    # Build array of unique tickets (most recent first)
    declare -a TICKET_LIST
    while IFS='|' read -r ticket timestamp reason; do
        # Check if already in list (keep first occurrence = most recent)
        if [[ ! " ${TICKET_LIST[@]} " =~ " ${ticket} " ]]; then
            TICKET_LIST+=("$ticket")
            echo "  $((${#TICKET_LIST[@]}))  $ticket"
            echo "      Released: $(date -d "$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$timestamp")"
            echo "      Reason: $reason"
            echo ""
        fi
    done <<< "$RELEASED_TICKETS"

    if [ ${#TICKET_LIST[@]} -eq 0 ]; then
        echo "⚠️  No released tickets found"
        exit 1
    fi

    echo ""
    read -p "Enter number (1-${#TICKET_LIST[@]}) or 'q' to quit: " selection

    if [ "$selection" = "q" ]; then
        echo "❌ Cancelled"
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#TICKET_LIST[@]} ]; then
        echo "❌ ERROR: Invalid selection: $selection"
        exit 2
    fi

    SELECTED_TICKET="${TICKET_LIST[$((selection-1))]}"
fi

# =====================================================
# Claim Selected Ticket
# =====================================================

echo ""
echo "📋 Resuming ticket: $SELECTED_TICKET"
echo ""

"$CLAIM_SCRIPT" "$SELECTED_TICKET"

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to resume ticket"
    exit 2
fi

echo ""
echo "✅ Successfully resumed ticket $SELECTED_TICKET"
echo ""

exit 0
