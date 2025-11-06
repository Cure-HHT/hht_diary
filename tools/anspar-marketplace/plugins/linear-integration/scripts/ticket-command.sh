#!/bin/bash
# =====================================================
# ticket-command.sh
# =====================================================
#
# Implements /ticket and /issue slash commands
# Provides workflow-integrated ticket management
#
# Usage:
#   /ticket              # Show current ticket
#   /ticket new          # Create new ticket
#   /ticket CUR-XXX      # Switch to ticket
#
# =====================================================

set -euo pipefail

# Find plugin roots
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$(cd "$PLUGIN_DIR/../../../.." && pwd)"
fi
WORKFLOW_PLUGIN="$REPO_ROOT/tools/anspar-marketplace/plugins/workflow"

# =====================================================
# Parse Arguments
# =====================================================

ARG="${1:-}"

# =====================================================
# Case 1: No arguments - show current ticket
# =====================================================

if [ -z "$ARG" ]; then
    if [ -f "$WORKFLOW_PLUGIN/scripts/check-active-ticket.sh" ]; then
        "$WORKFLOW_PLUGIN/scripts/check-active-ticket.sh"
    else
        echo "⚠️  Workflow plugin not found"
        echo "Cannot determine active ticket without workflow plugin installed"
        exit 1
    fi
    exit 0
fi

# =====================================================
# Case 2: "new" - create new ticket
# =====================================================

if [ "$ARG" = "new" ]; then
    cat <<'EOF'
📋 CREATE NEW TICKET

To create a new ticket with intelligent assistance, use the ticket-creation-agent.

The agent will:
  • Analyze your git context (branch, commits, changed files)
  • Infer smart defaults for priority and labels
  • Suggest descriptions based on recent work
  • Validate ticket quality before creation
  • Link requirements automatically
  • Offer to claim the ticket after creation

HOW TO USE:
Just say: "Create a ticket for [your work description]"

Example:
  "Create a ticket for fixing the authentication redirect loop"

The ticket-creation-agent will take over and guide you through the process.
EOF
    exit 0
fi

# =====================================================
# Case 3: Ticket ID - switch to ticket
# =====================================================

TICKET_ID="$ARG"

# Validate ticket ID format (e.g., CUR-123)
if ! echo "$TICKET_ID" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "❌ Invalid ticket ID format: $TICKET_ID"
    echo "Expected format: PROJECT-NUMBER (e.g., CUR-123)"
    exit 1
fi

echo "🔄 Switching to ticket: $TICKET_ID"
echo

# Check if workflow plugin is available
if [ ! -f "$WORKFLOW_PLUGIN/scripts/switch-ticket.sh" ]; then
    echo "⚠️  Workflow plugin not found"
    echo "Cannot switch tickets without workflow plugin installed"
    exit 1
fi

# Switch ticket using workflow plugin
if "$WORKFLOW_PLUGIN/scripts/switch-ticket.sh" "$TICKET_ID" "Switched via /ticket command"; then
    echo
    echo "✅ Successfully switched to $TICKET_ID"
    echo

    # Update Linear status to "In Progress"
    echo "📊 Updating Linear status to 'In Progress'..."

    if [ -n "${LINEAR_API_TOKEN:-}" ]; then
        if node "$PLUGIN_DIR/scripts/update-ticket-status.js" \
            --token="$LINEAR_API_TOKEN" \
            --ticket-id="$TICKET_ID" \
            --status="in-progress" 2>/dev/null; then
            echo "✅ Linear status updated"
        else
            echo "⚠️  Could not update Linear status (non-fatal)"
            echo "   You may need to update it manually in Linear"
        fi
    else
        echo "⚠️  LINEAR_API_TOKEN not set - skipping Linear status update"
        echo "   Set LINEAR_API_TOKEN to enable automatic status updates"
    fi

    echo
    echo "🎯 Now working on: $TICKET_ID"
else
    echo "❌ Failed to switch to $TICKET_ID"
    exit 1
fi
