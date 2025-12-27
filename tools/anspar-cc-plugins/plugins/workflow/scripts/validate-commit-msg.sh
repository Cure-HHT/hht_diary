#!/bin/bash
# =====================================================
# validate-commit-msg.sh
# =====================================================
#
# Validates that a commit message contains:
#   1. At least one REQ-xxx reference (requirement traceability)
#   2. A Linear ticket reference [CUR-XXX] (work item traceability)
#   3. The ticket reference matches the claimed active ticket
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
#   0  Valid (both REQ and CUR references found, ticket matches)
#   1  Invalid (missing REQ/CUR reference or ticket mismatch)
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00018: Git Hook Implementation
#   REQ-d00068: Enhanced Workflow New Work Detection
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
COMMIT_TICKET=""
if echo "$COMMIT_MSG" | grep -qE '\[?CUR-[0-9]+\]?'; then
    HAS_CUR=true
    # Extract the ticket ID from the commit message (first match)
    COMMIT_TICKET=$(echo "$COMMIT_MSG" | grep -oE 'CUR-[0-9]+' | head -1)
fi

# =====================================================
# Validate Ticket Matches Claimed Active Ticket
# =====================================================

TICKET_MISMATCH=false
ACTIVE_TICKET=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
WORKFLOW_STATE="$REPO_ROOT/.git/WORKFLOW_STATE"

# Check if we have a workflow state with an active ticket
if [ -n "$REPO_ROOT" ] && [ -f "$WORKFLOW_STATE" ]; then
    # Extract active ticket ID from WORKFLOW_STATE JSON
    if command -v jq &> /dev/null; then
        ACTIVE_TICKET=$(jq -r '.activeTicket.id // empty' "$WORKFLOW_STATE" 2>/dev/null || echo "")
    else
        # Fallback: simple grep for ticket ID pattern
        ACTIVE_TICKET=$(grep -oE '"id":\s*"CUR-[0-9]+"' "$WORKFLOW_STATE" | head -1 | grep -oE 'CUR-[0-9]+' || echo "")
    fi

    # If we have both an active ticket and a commit ticket, verify they match
    if [ -n "$ACTIVE_TICKET" ] && [ -n "$COMMIT_TICKET" ]; then
        if [ "$ACTIVE_TICKET" != "$COMMIT_TICKET" ]; then
            TICKET_MISMATCH=true
        fi
    fi
fi

# =====================================================
# Validate REQ Reference
# =====================================================

# Pattern: REQ-{optional-sponsor-prefix}{type}{number}
# Sponsor prefix: 2-4 uppercase letters (optional, e.g., CAL-, CORE-)
# Type: p (PRD), o (Ops), d (Dev)
# Number: 5 digits (00001-99999)
# Examples:
#   Core: REQ-p00042, REQ-o00015, REQ-d00027
#   Sponsor: REQ-CAL-d00001, REQ-TIT-p00003

HAS_REQ=false
if echo "$COMMIT_MSG" | grep -qE 'REQ-([A-Z]{2,4}-)?[pdo][0-9]{5}'; then
    HAS_REQ=true
fi

# =====================================================
# Check All Requirements
# =====================================================

ERRORS=()

if [ "$HAS_CUR" = "false" ]; then
    ERRORS+=("Missing Linear ticket reference (CUR-XXX)")
fi

if [ "$HAS_REQ" = "false" ]; then
    ERRORS+=("Missing requirement reference (REQ-XXX)")
fi

if [ "$TICKET_MISMATCH" = "true" ]; then
    ERRORS+=("Ticket mismatch: commit references '$COMMIT_TICKET' but active ticket is '$ACTIVE_TICKET'")
fi

if [ ${#ERRORS[@]} -eq 0 ]; then
    # Valid - all checks passed
    exit 0
else
    # Invalid - one or more checks failed
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
    echo "  Implements: REQ-{type}{number} or REQ-{sponsor}-{type}{number}" >&2
    echo "" >&2
    echo "Where:" >&2
    echo "  CUR-XXX: Linear ticket number (must match claimed ticket: $ACTIVE_TICKET)" >&2
    echo "  REQ type: p (PRD), o (Ops), d (Dev)" >&2
    echo "  REQ number: 5 digits (e.g., 00042)" >&2
    echo "  Sponsor prefix: 2-4 letters (e.g., CAL-, TIT-) - optional for sponsor repos" >&2
    echo "" >&2

    if [ "$TICKET_MISMATCH" = "true" ]; then
        echo "To fix ticket mismatch:" >&2
        echo "  Option 1: Update commit to reference active ticket [$ACTIVE_TICKET]" >&2
        echo "  Option 2: Switch to correct ticket: /workflow:switch $COMMIT_TICKET" >&2
        echo "" >&2
    fi

    echo "Example:" >&2
    echo "  [${ACTIVE_TICKET:-CUR-XXX}] Add Linear ticket enforcement to hooks" >&2
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
