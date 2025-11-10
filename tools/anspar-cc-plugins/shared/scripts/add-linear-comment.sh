#!/bin/bash
# =====================================================
# add-linear-comment.sh
# =====================================================
#
# Shared utility to add a comment to a Linear ticket.
# Used by multiple plugins in the anspar-cc-plugins marketplace.
#
# Usage:
#   ./add-linear-comment.sh TICKET_ID "Comment text"
#
# Arguments:
#   TICKET_ID    Linear ticket identifier (e.g., CUR-123)
#   COMMENT      Comment text (supports markdown)
#
# Environment:
#   LINEAR_API_TOKEN    Required. Linear API token.
#
# Exit codes:
#   0  Success
#   1  Missing arguments or LINEAR_API_TOKEN
#   2  Failed to add comment
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

if [ $# -lt 2 ]; then
    echo "Usage: $0 TICKET_ID \"Comment text\"" >&2
    exit 1
fi

TICKET_ID="$1"
COMMENT="$2"

# =====================================================
# Validate Environment
# =====================================================

if [ -z "$LINEAR_API_TOKEN" ]; then
    echo "⚠️  LINEAR_API_TOKEN not set - skipping Linear comment" >&2
    echo "   Set LINEAR_API_TOKEN to enable Linear integration" >&2
    exit 0
fi

# =====================================================
# Find Linear API Plugin
# =====================================================

# Assume we're in shared/scripts, so linear-api is at ../../plugins/linear-api
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINEAR_API_LIB="$SCRIPT_DIR/../../plugins/linear-api/lib"

if [ ! -d "$LINEAR_API_LIB" ]; then
    echo "❌ ERROR: Linear API plugin not found at $LINEAR_API_LIB" >&2
    exit 2
fi

# =====================================================
# Add Comment via Node
# =====================================================

node -e "
const ticketUpdater = require('$LINEAR_API_LIB/ticket-updater.js');

(async () => {
    try {
        const updater = new ticketUpdater.TicketUpdater();
        await updater.addComment('$TICKET_ID', \`$COMMENT\`, { silent: false });
        process.exit(0);
    } catch (error) {
        console.error('❌ Failed to add comment:', error.message);
        process.exit(2);
    }
})();
" 2>&1

exit $?
