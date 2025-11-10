#!/bin/bash
# =====================================================
# suggest-req.sh
# =====================================================
#
# Suggests REQ IDs to use in commit message based on:
# 1. Active ticket in WORKFLOW_STATE
# 2. Recent commits in this branch
# 3. Changed files (looks for REQ references in code)
#
# Usage:
#   ./suggest-req.sh
#
# Output:
#   List of suggested REQ IDs (one per line)
#
# Examples:
#   ./suggest-req.sh
#   # Output:
#   # REQ-d00027
#   # REQ-p00042
#
# Exit codes:
#   0  Success (suggestions found or not found)
#
# =====================================================

set -e

# =====================================================
# Worktree Info
# =====================================================

WORKTREE_PATH="$(git rev-parse --show-toplevel)"
# Use git-dir to support both regular repos and worktrees
GIT_DIR="$(git rev-parse --git-dir)"
STATE_FILE="$GIT_DIR/WORKFLOW_STATE"

# =====================================================
# Suggestion Sources
# =====================================================

SUGGESTIONS=()

# Source 1: Active ticket in WORKFLOW_STATE
if [ -f "$STATE_FILE" ]; then
    ACTIVE_TICKET_REQS=$(jq -r '.activeTicket.requirements[]? // empty' "$STATE_FILE" 2>/dev/null || true)

    if [ -n "$ACTIVE_TICKET_REQS" ]; then
        while IFS= read -r req; do
            SUGGESTIONS+=("$req")
        done <<< "$ACTIVE_TICKET_REQS"
    fi
fi

# Source 2: Recent commits in this branch
RECENT_COMMIT_REQS=$(git log --oneline -10 2>/dev/null | grep -oE 'REQ-[pdo][0-9]{5}' | sort -u || true)

if [ -n "$RECENT_COMMIT_REQS" ]; then
    while IFS= read -r req; do
        SUGGESTIONS+=("$req")
    done <<< "$RECENT_COMMIT_REQS"
fi

# Source 3: Changed files (staged and unstaged)
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || true)

if [ -n "$CHANGED_FILES" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Look for REQ references in first 50 lines (header comments)
            FILE_REQS=$(head -n 50 "$file" 2>/dev/null | grep -oE 'REQ-[pdo][0-9]{5}' | sort -u || true)

            if [ -n "$FILE_REQS" ]; then
                while IFS= read -r req; do
                    SUGGESTIONS+=("$req")
                done <<< "$FILE_REQS"
            fi
        fi
    done <<< "$CHANGED_FILES"
fi

# =====================================================
# Deduplicate and Output
# =====================================================

if [ ${#SUGGESTIONS[@]} -eq 0 ]; then
    echo "⚠️  No REQ suggestions found" >&2
    echo "" >&2
    echo "Suggestion sources:" >&2
    echo "  1. Active ticket in WORKFLOW_STATE" >&2
    echo "  2. Recent commits in this branch" >&2
    echo "  3. Changed files (REQ references in file headers)" >&2
    echo "" >&2
    echo "💡 TIP: Claim a ticket with claim-ticket.sh to get suggestions" >&2
    exit 0
fi

# Deduplicate and sort
printf '%s\n' "${SUGGESTIONS[@]}" | sort -u

exit 0
