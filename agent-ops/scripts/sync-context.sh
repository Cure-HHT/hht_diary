#!/usr/bin/env bash
# sync-context.sh - Sync CONTEXT.md from latest session results
# Usage: ./sync-context.sh [session_directory]

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SBDT_ROOT="$PROJECT_ROOT/agent-ops"

echo -e "${BLUE}Syncing context from session...${NC}"
echo ""

# Find session directory
if [ -n "${1:-}" ]; then
    SESSION_DIR="$1"
else
    # Find most recent session
    SESSION_DIR=$(find "$SBDT_ROOT/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r | head -n 1)

    if [ -z "$SESSION_DIR" ]; then
        # Try archive
        SESSION_DIR=$(find "$SBDT_ROOT/archive" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r | head -n 1)
    fi

    if [ -z "$SESSION_DIR" ]; then
        echo -e "${RED}Error: No session found${NC}"
        exit 1
    fi
fi

if [ ! -d "$SESSION_DIR" ]; then
    echo -e "${RED}Error: Session directory not found: $SESSION_DIR${NC}"
    exit 1
fi

SESSION_NAME=$(basename "$SESSION_DIR")
echo -e "${BLUE}Session:${NC} $SESSION_NAME"

# Check if results.md exists
if [ ! -f "$SESSION_DIR/results.md" ]; then
    echo -e "${RED}Error: results.md not found in session${NC}"
    exit 1
fi

# Check if results.md is filled out
if grep -q "^\[2-4 sentence summary" "$SESSION_DIR/results.md" 2>/dev/null; then
    echo -e "${YELLOW}Warning: results.md appears incomplete${NC}"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""
echo -e "${GREEN}Extracting information from results.md...${NC}"

# Extract summary from results.md
SUMMARY=$(awk '/^## Summary/,/^---/ {if ($0 !~ /^## Summary/ && $0 !~ /^---/ && $0 !~ /^\*\*/ && $0 !~ /^Example:/) print}' "$SESSION_DIR/results.md" | sed 's/^[[:space:]]*//' | grep -v '^$' | head -n 5)

if [ -z "$SUMMARY" ]; then
    echo -e "${YELLOW}Warning: Could not extract summary from results.md${NC}"
    SUMMARY="[Session $SESSION_NAME completed. See results.md for details.]"
fi

# Extract recent changes (files changed)
FILES_CREATED=$(awk '/^### Created/,/^###/ {if ($0 !~ /^###/ && $0 !~ /^---/ && $0 ~ /^-/) print "  " $0}' "$SESSION_DIR/results.md")
FILES_MODIFIED=$(awk '/^### Modified/,/^###/ {if ($0 !~ /^###/ && $0 !~ /^---/ && $0 ~ /^-/) print "  " $0}' "$SESSION_DIR/results.md")

RECENT_CHANGES=""
if [ -n "$FILES_CREATED" ]; then
    RECENT_CHANGES="${RECENT_CHANGES}Created: ${FILES_CREATED}\n"
fi
if [ -n "$FILES_MODIFIED" ]; then
    RECENT_CHANGES="${RECENT_CHANGES}Modified: ${FILES_MODIFIED}"
fi

if [ -z "$RECENT_CHANGES" ]; then
    RECENT_CHANGES="  Session $SESSION_NAME work completed"
fi

# Get git info
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
BRANCH=$(cd "$PROJECT_ROOT" && git branch --show-current 2>/dev/null || echo "unknown")
COMMIT=$(cd "$PROJECT_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Backup existing CONTEXT.md
if [ -f "$SBDT_ROOT/active/CONTEXT.md" ]; then
    cp "$SBDT_ROOT/active/CONTEXT.md" "$SBDT_ROOT/active/CONTEXT.md.backup"
    echo -e "${GREEN}✓ Backed up existing CONTEXT.md${NC}"
fi

# Update CONTEXT.md
cat > "$SBDT_ROOT/active/CONTEXT.md" <<EOF
# Current Context

**Last Updated**: $TIMESTAMP
**Updated By**: Session $SESSION_NAME (auto-synced)
**Branch**: $BRANCH
**Commit**: $COMMIT

---

## Current State

$SUMMARY

---

## Current Work

**Phase/Milestone**: [Update as needed]
**Status**: [Update as needed]
**Focus**: [Update as needed]

---

## Key Facts

- [Important fact 1]
- [Important fact 2]
- [Update with relevant facts from session]

---

## Current Blockers

[Check results.md for blockers and update here]

---

## Recent Changes

- [$TIMESTAMP]: Session $SESSION_NAME completed
$RECENT_CHANGES

---

## Environment Notes

- Python 3.11 required
- Git hooks enabled: \`git config core.hooksPath .githooks\`
- GitHub Actions enabled on repository

---

## Related Sessions

- Latest: $(echo "$SESSION_DIR" | sed "s|$SBDT_ROOT/||")/
- Previous: [Update as needed]

---

**This file is shared across all instances. Keep it current and concise.**
EOF

echo -e "${GREEN}✓ CONTEXT.md updated${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Review and manually update the following sections in active/CONTEXT.md:"
echo "  - Current Work (phase/milestone/status/focus)"
echo "  - Key Facts"
echo "  - Current Blockers"
echo ""
echo -e "${BLUE}Backup saved to:${NC} agent-ops/active/CONTEXT.md.backup"
echo ""
