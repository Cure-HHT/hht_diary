#!/bin/bash
# =====================================================
# validate-commit-msg.sh
# =====================================================
#
# Validates that a commit message contains at least one
# REQ-xxx reference.
#
# Usage:
#   ./validate-commit-msg.sh <COMMIT-MSG-FILE>
#
# Arguments:
#   COMMIT-MSG-FILE    Path to commit message file
#
# Called by:
#   - commit-msg git hook
#
# Exit codes:
#   0  Valid (REQ reference found)
#   1  Invalid (no REQ reference)
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

MSG_FILE="$1"

if [ -z "$MSG_FILE" ] || [ ! -f "$MSG_FILE" ]; then
    echo "❌ ERROR: Commit message file not found: $MSG_FILE" >&2
    exit 1
fi

# =====================================================
# Read Commit Message
# =====================================================

COMMIT_MSG=$(cat "$MSG_FILE")

# =====================================================
# Validate REQ Reference
# =====================================================

# Pattern: REQ-{type}{number}
# Type: p (PRD), o (Ops), d (Dev)
# Number: 5 digits (00001-99999)
# Examples: REQ-p00042, REQ-o00015, REQ-d00027

if echo "$COMMIT_MSG" | grep -qE 'REQ-[pdo][0-9]{5}'; then
    # Valid - at least one REQ reference found
    exit 0
else
    # Invalid - no REQ reference
    echo "❌ ERROR: Commit message must contain at least one requirement reference" >&2
    echo "" >&2
    echo "Expected format: REQ-{type}{number}" >&2
    echo "  Type: p (PRD), o (Ops), d (Dev)" >&2
    echo "  Number: 5 digits (e.g., 00042)" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  Implements: REQ-p00042" >&2
    echo "  Implements: REQ-d00027, REQ-o00015" >&2
    echo "" >&2
    echo "Your commit message:" >&2
    echo "---" >&2
    cat "$MSG_FILE" >&2
    echo "---" >&2
    echo "" >&2
    echo "💡 TIP: Add 'Implements: REQ-xxx' to your commit message" >&2
    echo "" >&2
    exit 1
fi
