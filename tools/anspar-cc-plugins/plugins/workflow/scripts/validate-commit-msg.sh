#!/bin/bash
# =====================================================
# validate-commit-msg.sh
# =====================================================
#
# Validates commit message references (all checks controlled by env vars):
#   1. (Optional) Linear ticket reference [CUR-XXX] (work item traceability)
#      Controlled by ENFORCE_CUR_IN_COMMITS env var (default: false)
#   2. (Optional) Ticket mismatch check (only when CUR enforcement is on)
#   3. (Optional) At least one REQ-xxx reference (requirement traceability)
#      Controlled by ENFORCE_REQ_IN_COMMITS env var (default: false)
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
#   0  Valid (all enforced checks pass)
#   1  Invalid (missing enforced reference or ticket mismatch when enforced)
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
# TODO: Re-enable CUR enforcement by setting ENFORCE_CUR_IN_COMMITS=true
# CUR-XXX is now enforced at the PR level only (validate-pr-metadata CI job).
# When re-enabling, also update:
#   - .github/workflows/pr-validation.yml (ENFORCE_CUR_IN_COMMITS env var)
#   - tests/test-hooks.sh (test expectations)
ENFORCE_CUR_IN_COMMITS="${ENFORCE_CUR_IN_COMMITS:-false}"

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
    # Only check mismatch when CUR enforcement is on
    if [ "$ENFORCE_CUR_IN_COMMITS" = "true" ] && [ -n "$ACTIVE_TICKET" ] && [ -n "$COMMIT_TICKET" ]; then
        if [ "$ACTIVE_TICKET" != "$COMMIT_TICKET" ]; then
            TICKET_MISMATCH=true
        fi
    fi
fi

# =====================================================
# Validate REQ Reference
# =====================================================
# TODO: Re-enable REQ enforcement by setting ENFORCE_REQ_IN_COMMITS=true
# This was disabled to reduce friction during development.
# When re-enabling, also update:
#   - .github/workflows/pr-validation.yml (ENFORCE_REQ_IN_COMMITS env var)
#   - tests/test-hooks.sh (test expectations)
ENFORCE_REQ_IN_COMMITS="${ENFORCE_REQ_IN_COMMITS:-false}"

# Pattern: REQ-{type}{number} or EQ-CAL-{type}{number}
# Type: p (PRD), o (Ops), d (Dev)
# Number: 5 digits (00001-99999)
# Examples: REQ-p00042, REQ-o00015, REQ-d00027, EQ-CAL-d00005

HAS_REQ=false
if echo "$COMMIT_MSG" | grep -qE '(REQ|EQ-CAL)-[pdo][0-9]{5}'; then
    HAS_REQ=true
fi

# =====================================================
# Check All Requirements
# =====================================================

ERRORS=()

if [ "$ENFORCE_CUR_IN_COMMITS" = "true" ] && [ "$HAS_CUR" = "false" ]; then
    ERRORS+=("Missing Linear ticket reference (CUR-XXX)")
fi

if [ "$ENFORCE_REQ_IN_COMMITS" = "true" ] && [ "$HAS_REQ" = "false" ]; then
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
    if [ "$ENFORCE_CUR_IN_COMMITS" = "true" ]; then
        echo "  [CUR-XXX] Subject line describing the change" >&2
    else
        echo "  Subject line describing the change" >&2
    fi
    echo "  " >&2
    echo "  Optional body with more details." >&2
    if [ "$ENFORCE_REQ_IN_COMMITS" = "true" ]; then
        echo "  " >&2
        echo "  Implements: REQ-{type}{number} or EQ-CAL-{type}{number}" >&2
    fi
    echo "" >&2
    if [ "$ENFORCE_CUR_IN_COMMITS" = "true" ] || [ "$ENFORCE_REQ_IN_COMMITS" = "true" ]; then
        echo "Where:" >&2
        if [ "$ENFORCE_CUR_IN_COMMITS" = "true" ]; then
            echo "  CUR-XXX: Linear ticket number (must match claimed ticket: $ACTIVE_TICKET)" >&2
        fi
        if [ "$ENFORCE_REQ_IN_COMMITS" = "true" ]; then
            echo "  REQ/EQ-CAL type: p (PRD), o (Ops), d (Dev)" >&2
            echo "  REQ/EQ-CAL number: 5 digits (e.g., 00042)" >&2
        fi
        echo "" >&2
    fi

    if [ "$TICKET_MISMATCH" = "true" ]; then
        echo "To fix ticket mismatch:" >&2
        echo "  Option 1: Update commit to reference active ticket [$ACTIVE_TICKET]" >&2
        echo "  Option 2: Switch to correct ticket: /workflow:switch $COMMIT_TICKET" >&2
        echo "" >&2
    fi

    echo "Example:" >&2
    if [ "$ENFORCE_CUR_IN_COMMITS" = "true" ]; then
        echo "  [${ACTIVE_TICKET:-CUR-XXX}] Add Linear ticket enforcement to hooks" >&2
    else
        echo "  Add Linear ticket enforcement to hooks" >&2
    fi
    if [ "$ENFORCE_REQ_IN_COMMITS" = "true" ]; then
        echo "  " >&2
        echo "  Implements: REQ-d00018" >&2
    fi
    echo "" >&2
    echo "Your commit message:" >&2
    echo "---" >&2
    cat "$MSG_FILE" >&2
    echo "---" >&2
    echo "" >&2
    exit 1
fi
