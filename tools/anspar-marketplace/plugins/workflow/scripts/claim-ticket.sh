#!/bin/bash
# =====================================================
# claim-ticket.sh
# =====================================================
#
# Claims a ticket for this worktree by creating/updating
# WORKFLOW_STATE with the active ticket.
#
# Usage:
#   ./claim-ticket.sh <TICKET-ID> [AGENT-TYPE] [SPONSOR]
#
# Arguments:
#   TICKET-ID     Ticket ID (e.g., CUR-262, PROJ-123)
#   AGENT-TYPE    Agent type: claude|human (default: human)
#   SPONSOR       Sponsor context (optional, omit for core work)
#
# Examples:
#   ./claim-ticket.sh CUR-262                    # Core functionality work
#   ./claim-ticket.sh CUR-262 claude             # Core work, claimed by Claude
#   ./claim-ticket.sh CUR-262 human carina       # Carina sponsor-specific work
#   ./claim-ticket.sh CUR-262 claude callisto    # Callisto sponsor-specific work
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
SPONSOR="${3:-}"

if [ -z "$TICKET_ID" ]; then
    # Discover available sponsors for help text
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
    SPONSOR_DIR="$REPO_ROOT/sponsor"
    AVAILABLE_SPONSORS=""

    if [ -d "$SPONSOR_DIR" ]; then
        while IFS= read -r dir; do
            SPONSOR_NAME=$(basename "$dir")
            if [[ ! "$SPONSOR_NAME" =~ ^[_\.] ]]; then
                if [ -z "$AVAILABLE_SPONSORS" ]; then
                    AVAILABLE_SPONSORS="$SPONSOR_NAME"
                else
                    AVAILABLE_SPONSORS="$AVAILABLE_SPONSORS, $SPONSOR_NAME"
                fi
            fi
        done < <(find "$SPONSOR_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    fi

    echo "❌ ERROR: Ticket ID required"
    echo ""
    echo "Usage: $0 <TICKET-ID> [AGENT-TYPE] [SPONSOR]"
    echo ""
    echo "Arguments:"
    echo "  TICKET-ID   Ticket ID (e.g., CUR-262, PROJ-123)"
    echo "  AGENT-TYPE  Agent type: claude|human (default: human)"
    echo "  SPONSOR     Sponsor context (optional, omit for core work)"
    echo ""
    if [ -n "$AVAILABLE_SPONSORS" ]; then
        echo "Available sponsors: $AVAILABLE_SPONSORS"
        echo "If no sponsor specified, assumes core functionality work"
        echo ""
    fi
    echo "Examples:"
    echo "  $0 CUR-262                    # Core functionality work"
    echo "  $0 CUR-262 claude             # Core work, claimed by Claude"
    if [ -n "$AVAILABLE_SPONSORS" ]; then
        # Show first sponsor as example
        FIRST_SPONSOR=$(echo "$AVAILABLE_SPONSORS" | cut -d',' -f1 | xargs)
        echo "  $0 CUR-262 human $FIRST_SPONSOR       # $FIRST_SPONSOR sponsor-specific work"
    fi
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
# Sponsor Discovery and Validation
# =====================================================

validate_sponsor() {
    local sponsor="$1"

    # null or empty string is valid (core work)
    if [ -z "$sponsor" ] || [ "$sponsor" = "null" ]; then
        return 0
    fi

    # Find repository root (may be different from worktree root)
    local repo_root
    repo_root="$(git rev-parse --show-toplevel)"

    # Check if sponsor/ directory exists
    if [ ! -d "$repo_root/sponsor" ]; then
        echo "❌ ERROR: sponsor/ directory not found at repository root" >&2
        echo "   Expected: $repo_root/sponsor/" >&2
        return 1
    fi

    # Discover valid sponsors (directories not starting with _ or .)
    local valid_sponsors=()
    while IFS= read -r -d '' dir; do
        local dirname
        dirname="$(basename "$dir")"
        # Skip directories starting with _ or .
        if [[ ! "$dirname" =~ ^[_\.] ]]; then
            valid_sponsors+=("$dirname")
        fi
    done < <(find "$repo_root/sponsor" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    # Check if sponsor is in valid list
    local found=false
    for valid in "${valid_sponsors[@]}"; do
        if [ "$valid" = "$sponsor" ]; then
            found=true
            break
        fi
    done

    if [ "$found" = false ]; then
        echo "❌ ERROR: Invalid sponsor: $sponsor" >&2
        echo "" >&2
        if [ ${#valid_sponsors[@]} -eq 0 ]; then
            echo "   No sponsors found in sponsor/ directory" >&2
            echo "   Sponsors are subdirectories in sponsor/ (excluding those starting with _ or .)" >&2
        else
            echo "   Valid sponsors:" >&2
            for valid in "${valid_sponsors[@]}"; do
                echo "     • $valid" >&2
            done
        fi
        echo "" >&2
        echo "   Use without sponsor parameter for core functionality work" >&2
        return 1
    fi

    return 0
}

# Validate sponsor if provided
if ! validate_sponsor "$SPONSOR"; then
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
if [ -n "$SPONSOR" ]; then
    echo "   Sponsor: $SPONSOR"
else
    echo "   Sponsor: (core functionality)"
fi
echo ""

# =====================================================
# Fetch Requirements from Linear (Optional)
# =====================================================

REQUIREMENTS="[]"

# Check if linear-integration is available
LINEAR_INTEGRATION_PATH="$WORKTREE_PATH/tools/anspar-marketplace/plugins/linear-integration"

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
    if [ -n "$SPONSOR" ]; then
        jq --arg ticketId "$TICKET_ID" \
            --argjson requirements "$REQUIREMENTS" \
            --arg claimedAt "$TIMESTAMP" \
            --arg claimedBy "$AGENT_TYPE" \
            --arg sponsor "$SPONSOR" \
            --argjson claimEntry "$CLAIM_HISTORY_ENTRY" \
            '.sponsor = $sponsor | .activeTicket = {
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
        jq --arg ticketId "$TICKET_ID" \
            --argjson requirements "$REQUIREMENTS" \
            --arg claimedAt "$TIMESTAMP" \
            --arg claimedBy "$AGENT_TYPE" \
            --argjson claimEntry "$CLAIM_HISTORY_ENTRY" \
            '.sponsor = null | .activeTicket = {
                id: $ticketId,
                requirements: $requirements,
                claimedAt: $claimedAt,
                claimedBy: $claimedBy,
                trackerMetadata: {
                    trackerType: "linear"
                }
            } | .history += [$claimEntry]' \
            "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    fi
else
    # Create new state file
    if [ -n "$SPONSOR" ]; then
        jq -n \
            --arg version "1.0.0" \
            --arg worktreePath "$WORKTREE_PATH" \
            --arg branch "$BRANCH" \
            --arg sponsor "$SPONSOR" \
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
                sponsor: $sponsor,
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
    else
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
                sponsor: null,
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
