#!/bin/bash
# =====================================================
# validate-commit-msg.sh
# =====================================================
#
# Validates that a commit message contains:
#   1. At least one REQ-xxx reference (requirement traceability)
#   2. A Linear ticket reference [CUR-XXX] (work item traceability)
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
#   0  Valid (both REQ and CUR references found)
#   1  Invalid (missing REQ or CUR reference)
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00018: Git Hook Implementation
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
# Validate Linear Ticket Reference (CUR-XXX)
# =====================================================

# Pattern: CUR-{number} or [CUR-{number}]
# Number: 1+ digits
# Examples: CUR-399, [CUR-123], CUR-1

HAS_CUR=false
if echo "$COMMIT_MSG" | grep -qE '\[?CUR-[0-9]+\]?'; then
    HAS_CUR=true
fi

# =====================================================
# Validate REQ Reference
# =====================================================

# Pattern: REQ-{type}{number}
# Type: p (PRD), o (Ops), d (Dev)
# Number: 5 digits (00001-99999)
# Examples: REQ-p00042, REQ-o00015, REQ-d00027

HAS_REQ=false
if echo "$COMMIT_MSG" | grep -qE 'REQ-[pdo][0-9]{5}'; then
    HAS_REQ=true
fi

# =====================================================
# Check Both Requirements
# =====================================================

ERRORS=()

if [ "$HAS_CUR" = "false" ]; then
    ERRORS+=("Missing Linear ticket reference (CUR-XXX)")
fi

if [ "$HAS_REQ" = "false" ]; then
    ERRORS+=("Missing requirement reference (REQ-XXX)")
fi

if [ ${#ERRORS[@]} -eq 0 ]; then
    # Valid - both references found
    exit 0
else
    # Invalid - missing one or both references
    echo "❌ ERROR: Commit message validation failed" >&2
    echo "" >&2

    for error in "${ERRORS[@]}"; do
        echo "  • $error" >&2
    done

    echo "" >&2
    echo "Expected format:" >&2
    echo "  [CUR-XXX] Subject line describing the change" >&2
    echo "  " >&2
    echo "  Optional body with more details." >&2
    echo "  " >&2
    echo "  Implements: REQ-{type}{number}" >&2
    echo "" >&2
    echo "Where:" >&2
    echo "  CUR-XXX: Linear ticket number (e.g., CUR-399)" >&2
    echo "  REQ type: p (PRD), o (Ops), d (Dev)" >&2
    echo "  REQ number: 5 digits (e.g., 00042)" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  [CUR-399] Add Linear ticket enforcement to hooks" >&2
    echo "  " >&2
    echo "  Implements: REQ-d00018" >&2
    echo "" >&2
    echo "Your commit message:" >&2
    echo "---" >&2
    cat "$MSG_FILE" >&2
    echo "---" >&2
    echo "" >&2
    exit 1
fi
