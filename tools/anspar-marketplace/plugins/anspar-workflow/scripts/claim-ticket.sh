#!/bin/bash
# =====================================================
# claim-ticket.sh
# =====================================================
#
# Claims a ticket for this worktree by creating/updating
# WORKFLOW_STATE with the active ticket.
#
# Usage:
#   ./claim-ticket.sh <TICKET-ID> [AGENT-TYPE]
#
# Arguments:
#   TICKET-ID     Ticket ID (e.g., CUR-262, PROJ-123)
#   AGENT-TYPE    Agent type: claude|human (default: human)
#
# Examples:
#   ./claim-ticket.sh CUR-262
#   ./claim-ticket.sh CUR-262 claude
#
# Integration:
#   - Updates WORKFLOW_STATE (source of truth)
#   - Optionally fetches requirements from Linear
#   - Optionally updates Linear ticket status to "In Progress"
#
# Exit codes:
#   0  Success
#   1  Invalid arguments
#   2  Failed to fetch requirements
#   3  Failed to update state file
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

TICKET_ID="$1"
AGENT_TYPE="${2:-human}"

if [ -z "$TICKET_ID" ]; then
    echo "❌ ERROR: Ticket ID required"
    echo ""
    echo "Usage: $0 <TICKET-ID> [AGENT-TYPE]"
    echo ""
    echo "Examples:"
    echo "  $0 CUR-262"
    echo "  $0 CUR-262 claude"
    exit 1
fi

# Validate ticket ID format (flexible pattern)
if ! [[ "$TICKET_ID" =~ ^[A-Z]+-[0-9]+$ ]]; then
    echo "❌ ERROR: Invalid ticket ID format: $TICKET_ID"
    echo "   Expected: PROJECT-NUMBER (e.g., CUR-262, PROJ-123)"
    exit 1
fi

# Validate agent type
if [[ "$AGENT_TYPE" != "claude" && "$AGENT_TYPE" != "human" ]]; then
    echo "❌ ERROR: Invalid agent type: $AGENT_TYPE"
    echo "   Expected: claude or human"
    exit 1
fi

# =====================================================
# Worktree Info
# =====================================================

WORKTREE_PATH="$(git rev-parse --show-toplevel)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
# Use git-dir to support both regular repos and worktrees
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

echo "📋 Claiming ticket: $TICKET_ID"
echo "   Worktree: $WORKTREE_PATH"
echo "   Branch: $BRANCH"
echo "   Agent: $AGENT_TYPE"
echo ""

# =====================================================
# Fetch Requirements from Linear (Optional)
# =====================================================

REQUIREMENTS="[]"

# Check if anspar-linear-integration is available
LINEAR_INTEGRATION_PATH="$WORKTREE_PATH/tools/anspar-marketplace/plugins/anspar-linear-integration"

if [ -d "$LINEAR_INTEGRATION_PATH" ] && [ -n "$LINEAR_API_TOKEN" ]; then
    echo "🔍 Fetching requirements from Linear..."

    # Attempt to fetch ticket details and extract REQ references
    # This is optional - if it fails, we'll just use empty array
    if command -v node &> /dev/null; then
        # Use Linear API to fetch ticket description
        # Extract REQ-xxx references from description
        # This requires a helper script in anspar-linear-integration

        # For now, we'll just note that this integration point exists
        echo "   ⚠️  Linear integration available but requires fetch-ticket-details.js"
        echo "   Continuing with empty requirements array"
    else
        echo "   ⚠️  Node.js not found - skipping Linear integration"
    fi
else
    echo "   ⚠️  Linear integration not available or LINEAR_API_TOKEN not set"
    echo "   Continuing with empty requirements array"
fi

echo ""

# =====================================================
# Create/Update State File
# =====================================================

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Check if state file exists and has active ticket
if [ -f "$STATE_FILE" ]; then
    echo "⚠️  Worktree already has workflow state"

    # Parse existing state
    EXISTING_TICKET=$(jq -r '.activeTicket.id // "none"' "$STATE_FILE" 2>/dev/null || echo "none")

    if [ "$EXISTING_TICKET" != "none" ] && [ "$EXISTING_TICKET" != "null" ]; then
        echo "   Current ticket: $EXISTING_TICKET"
        echo ""
        read -p "   Release current ticket and claim $TICKET_ID? [y/N] " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Cancelled"
            exit 0
        fi

        # Release current ticket first
        echo "   Releasing $EXISTING_TICKET..."
        # Add release action to history
        RELEASE_HISTORY_ENTRY=$(jq -n \
            --arg action "release" \
            --arg timestamp "$TIMESTAMP" \
            --arg ticketId "$EXISTING_TICKET" \
            '{
                action: $action,
                timestamp: $timestamp,
                ticketId: $ticketId,
                details: {
                    reason: "Claiming new ticket"
                }
            }')

        # Update state file: add release to history
        jq --argjson entry "$RELEASE_HISTORY_ENTRY" \
            '.history += [$entry]' \
            "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    fi
fi

# Create claim history entry
CLAIM_HISTORY_ENTRY=$(jq -n \
    --arg action "claim" \
    --arg timestamp "$TIMESTAMP" \
    --arg ticketId "$TICKET_ID" \
    --argjson requirements "$REQUIREMENTS" \
    '{
        action: $action,
        timestamp: $timestamp,
        ticketId: $ticketId,
        details: {
            requirements: $requirements
        }
    }')

# Create or update state file
if [ -f "$STATE_FILE" ]; then
    # Update existing state file
    jq --arg ticketId "$TICKET_ID" \
        --argjson requirements "$REQUIREMENTS" \
        --arg claimedAt "$TIMESTAMP" \
        --arg claimedBy "$AGENT_TYPE" \
        --argjson claimEntry "$CLAIM_HISTORY_ENTRY" \
        '.activeTicket = {
            id: $ticketId,
            requirements: $requirements,
            claimedAt: $claimedAt,
            claimedBy: $claimedBy,
            trackerMetadata: {
                trackerType: "linear"
            }
        } | .history += [$claimEntry]' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
else
    # Create new state file
    jq -n \
        --arg version "1.0.0" \
        --arg worktreePath "$WORKTREE_PATH" \
        --arg branch "$BRANCH" \
        --arg ticketId "$TICKET_ID" \
        --argjson requirements "$REQUIREMENTS" \
        --arg claimedAt "$TIMESTAMP" \
        --arg claimedBy "$AGENT_TYPE" \
        --argjson claimEntry "$CLAIM_HISTORY_ENTRY" \
        '{
            version: $version,
            worktree: {
                path: $worktreePath,
                branch: $branch
            },
            activeTicket: {
                id: $ticketId,
                requirements: $requirements,
                claimedAt: $claimedAt,
                claimedBy: $claimedBy,
                trackerMetadata: {
                    trackerType: "linear"
                }
            },
            history: [$claimEntry]
        }' > "$STATE_FILE"
fi

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Failed to update state file"
    exit 3
fi

echo "✅ Ticket claimed successfully!"
echo ""
echo "State file: $STATE_FILE"
echo ""

# Show current state
echo "Current state:"
jq '.' "$STATE_FILE"

# =====================================================
# Optional: Update Linear Ticket Status
# =====================================================

# This would require anspar-linear-integration
# For now, just note that this integration point exists

echo ""
echo "💡 TIP: You can now commit with 'Implements: REQ-xxx' in the commit message"
echo ""

exit 0
