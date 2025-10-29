#!/usr/bin/env bash
# resume.sh - Display current context and next steps for resuming work
# Usage: ./resume.sh

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SBDT_ROOT="$PROJECT_ROOT/agent-ops"

clear

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  SBDT Resume - Session-Based Development Tracking${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Display current git status
echo -e "${CYAN}${BOLD}Git Status:${NC}"
echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
cd "$PROJECT_ROOT"
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null | head -n 1 || echo "unknown")

echo -e "  ${BOLD}Branch:${NC} $BRANCH"
echo -e "  ${BOLD}Commit:${NC} $COMMIT"
echo -e "  ${BOLD}Message:${NC} $COMMIT_MSG"
echo ""

# Display current context
if [ -f "$SBDT_ROOT/active/CONTEXT.md" ]; then
    echo -e "${GREEN}${BOLD}Current Context (active/CONTEXT.md):${NC}"
    echo -e "${GREEN}─────────────────────────────────────────────────────────${NC}"

    # Extract and display key sections
    awk '
        /^## Current State/,/^---/ {
            if ($0 !~ /^## Current State/ && $0 !~ /^---/) {
                print "  " $0
            }
        }
    ' "$SBDT_ROOT/active/CONTEXT.md"
    echo ""

    # Extract current work
    awk '
        /^## Current Work/,/^---/ {
            if ($0 !~ /^## Current Work/ && $0 !~ /^---/) {
                print "  " $0
            }
        }
    ' "$SBDT_ROOT/active/CONTEXT.md"
    echo ""

    # Extract blockers
    awk '
        /^## Current Blockers/,/^---/ {
            if ($0 !~ /^## Current Blockers/ && $0 !~ /^---/) {
                print "  " $0
            }
        }
    ' "$SBDT_ROOT/active/CONTEXT.md"
    echo ""
else
    echo -e "${YELLOW}  Warning: active/CONTEXT.md not found${NC}"
    echo ""
fi

# Display next steps
if [ -f "$SBDT_ROOT/active/NEXT.md" ]; then
    echo -e "${YELLOW}${BOLD}Next Steps (active/NEXT.md):${NC}"
    echo -e "${YELLOW}─────────────────────────────────────────────────────────${NC}"

    # Extract next steps section
    awk '
        /^## ⭐ START HERE ⭐/,/^---/ {
            if ($0 !~ /^## ⭐ START HERE ⭐/ && $0 !~ /^---/ && $0 !~ /^\*\*Next session should\*\*:/) {
                print "  " $0
            }
        }
    ' "$SBDT_ROOT/active/NEXT.md"
    echo ""
else
    echo -e "${YELLOW}  Warning: active/NEXT.md not found${NC}"
    echo ""
fi

# Find latest session
echo -e "${CYAN}${BOLD}Recent Sessions:${NC}"
echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

LATEST_SESSION=$(find "$SBDT_ROOT/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r | head -n 1)
LATEST_ARCHIVE=$(find "$SBDT_ROOT/archive" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r | head -n 1)

if [ -n "$LATEST_SESSION" ]; then
    SESSION_NAME=$(basename "$LATEST_SESSION")
    echo -e "  ${BOLD}Latest Active:${NC} sessions/$SESSION_NAME/"

    if [ -f "$LATEST_SESSION/results.md" ]; then
        # Check if results are filled out
        if ! grep -q "^\[2-4 sentence summary" "$LATEST_SESSION/results.md" 2>/dev/null; then
            echo -e "    ${GREEN}Status: Complete (results.md filled)${NC}"
        else
            echo -e "    ${YELLOW}Status: In progress (results.md incomplete)${NC}"
        fi
    else
        echo -e "    ${YELLOW}Status: In progress${NC}"
    fi
fi

if [ -n "$LATEST_ARCHIVE" ]; then
    ARCHIVE_NAME=$(basename "$LATEST_ARCHIVE")
    echo -e "  ${BOLD}Latest Archive:${NC} archive/$ARCHIVE_NAME/"
fi

if [ -z "$LATEST_SESSION" ] && [ -z "$LATEST_ARCHIVE" ]; then
    echo -e "  ${YELLOW}No sessions found (first time setup)${NC}"
fi

echo ""

# Display quick commands
echo -e "${BLUE}${BOLD}Quick Commands:${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}View context:${NC} cat agent-ops/active/CONTEXT.md"
echo -e "  ${BOLD}View next steps:${NC} cat agent-ops/active/NEXT.md"
echo -e "  ${BOLD}View decisions:${NC} cat agent-ops/active/DECISIONS.md"
if [ -n "$LATEST_SESSION" ]; then
    echo -e "  ${BOLD}View latest session:${NC} cat agent-ops/sessions/$SESSION_NAME/results.md"
fi
echo ""

# Offer to start new session
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
read -p "Start new session? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter session name (or press Enter for 'work'): " SESSION_NAME
    SESSION_NAME=${SESSION_NAME:-work}

    "$SCRIPT_DIR/new-session.sh" "$SESSION_NAME"
else
    echo ""
    echo -e "${GREEN}Ready to resume!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review active/CONTEXT.md and active/NEXT.md"
    if [ -n "$LATEST_SESSION" ]; then
        if grep -q "^\[2-4 sentence summary" "$LATEST_SESSION/results.md" 2>/dev/null; then
            echo "2. Continue in existing session: agent-ops/sessions/$SESSION_NAME/"
        else
            echo "2. Start new session: ./agent-ops/scripts/new-session.sh"
        fi
    else
        echo "2. Start new session: ./agent-ops/scripts/new-session.sh"
    fi
    echo ""
fi
