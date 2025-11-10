#!/bin/bash
# =====================================================
# generate-commit-msg.sh
# =====================================================
#
# Generates a commit message template with ticket ID
# and requirement references from WORKFLOW_STATE.
#
# Usage:
#   ./generate-commit-msg.sh [--summary "commit summary"]
#   ./generate-commit-msg.sh --editor
#   ./generate-commit-msg.sh --help
#
# Options:
#   --summary "text"   Pre-fill summary line
#   --editor          Open template in $EDITOR
#   --fetch           Fetch requirements from Linear first
#   --help            Show this help message
#
# Examples:
#   # Generate template (printed to stdout)
#   ./generate-commit-msg.sh
#
#   # Generate with pre-filled summary
#   ./generate-commit-msg.sh --summary "Add test suites for plugins"
#
#   # Fetch requirements and generate
#   ./generate-commit-msg.sh --fetch
#
#   # Open in editor
#   ./generate-commit-msg.sh --editor
#
# Exit codes:
#   0  Success
#   1  No active ticket
#   2  Failed to fetch requirements
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

SUMMARY=""
USE_EDITOR=false
FETCH_REQS=false
SHOW_HELP=false

while [ $# -gt 0 ]; do
    case $1 in
        --summary)
            SUMMARY="$2"
            shift 2
            ;;
        --editor)
            USE_EDITOR=true
            shift
            ;;
        --fetch)
            FETCH_REQS=true
            shift
            ;;
        --help)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "❌ ERROR: Unknown option: $1"
            echo "   Run with --help for usage"
            exit 1
            ;;
    esac
done

# =====================================================
# Help
# =====================================================

if [ "$SHOW_HELP" = true ]; then
    cat << 'EOF'
generate-commit-msg.sh - Generate commit message template

Usage:
  ./generate-commit-msg.sh [OPTIONS]

Options:
  --summary "text"   Pre-fill summary line
  --editor          Open template in $EDITOR
  --fetch           Fetch requirements from Linear first
  --help            Show this help message

Examples:
  # Generate template (printed to stdout)
  ./generate-commit-msg.sh

  # Generate with pre-filled summary
  ./generate-commit-msg.sh --summary "Add test suites for plugins"

  # Fetch requirements and generate
  ./generate-commit-msg.sh --fetch

  # Open in editor
  ./generate-commit-msg.sh --editor

Template Format:
  [TICKET-ID] Brief summary

  Detailed description of changes.

  Implements: REQ-p00042, REQ-d00027

  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  Co-Authored-By: Claude <noreply@anthropic.com>

Git Alias:
  # Add to your git config for easy access
  git config alias.cm '!f() { bash tools/anspar-marketplace/plugins/workflow/scripts/generate-commit-msg.sh "$@"; }; f'

  # Then use:
  git cm
  git cm --summary "My commit"
  git cm --fetch --editor

EOF
    exit 0
fi

# =====================================================
# Configuration
# =====================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

# =====================================================
# Fetch Requirements (if requested)
# =====================================================

if [ "$FETCH_REQS" = true ]; then
    echo "🔄 Fetching requirements from Linear..." >&2
    "$SCRIPT_DIR/fetch-ticket-reqs.sh" || {
        echo "⚠️  WARNING: Failed to fetch requirements" >&2
    }
    echo "" >&2
fi

# =====================================================
# Get Active Ticket
# =====================================================

if [ ! -f "$STATE_FILE" ]; then
    echo "❌ ERROR: No workflow state file found" >&2
    echo "   Run: claim-ticket.sh <TICKET-ID>" >&2
    exit 1
fi

TICKET_DATA=$(jq -r '.activeTicket' "$STATE_FILE" 2>/dev/null)

if [ -z "$TICKET_DATA" ] || [ "$TICKET_DATA" = "null" ]; then
    echo "❌ ERROR: No active ticket found" >&2
    echo "   Run: claim-ticket.sh <TICKET-ID>" >&2
    exit 1
fi

TICKET_ID=$(echo "$TICKET_DATA" | jq -r '.id')
REQUIREMENTS=$(echo "$TICKET_DATA" | jq -r '.requirements[]' 2>/dev/null | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

# =====================================================
# Generate Commit Message Template
# =====================================================

generate_template() {
    # Summary line
    if [ -n "$SUMMARY" ]; then
        echo "[$TICKET_ID] $SUMMARY"
    else
        echo "[$TICKET_ID] Brief summary of changes"
    fi

    echo ""
    echo "Detailed description of changes:"
    echo "- "
    echo ""

    # Requirements section
    if [ -n "$REQUIREMENTS" ]; then
        echo "Implements: $REQUIREMENTS"
    else
        echo "Implements: REQ-xxxxx"
    fi

    echo ""
    echo "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
    echo ""
    echo "Co-Authored-By: Claude <noreply@anthropic.com>"
}

# =====================================================
# Output or Edit
# =====================================================

if [ "$USE_EDITOR" = true ]; then
    TEMP_FILE=$(mktemp /tmp/commit-msg.XXXXXX)
    generate_template > "$TEMP_FILE"

    # Use git's core.editor or fallback to EDITOR or vi
    EDITOR_CMD=$(git config core.editor || echo "${EDITOR:-vi}")
    $EDITOR_CMD "$TEMP_FILE"

    echo "" >&2
    echo "📋 Commit message:" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    cat "$TEMP_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "To commit with this message:" >&2
    echo "  git commit -F $TEMP_FILE" >&2
    echo "" >&2
    echo "Or copy the content above" >&2
else
    generate_template
fi

exit 0
