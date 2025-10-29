#!/usr/bin/env bash
# show-agents.sh - Discover and display all active agents
# Usage: ./show-agents.sh

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Agent Discovery - Multi-Agent Coordination${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Fetch all remote branches
echo -e "${CYAN}Fetching remote branches...${NC}"
git fetch --all --quiet 2>/dev/null || true

# Find all agent branches
AGENT_BRANCHES=$(git branch -r | grep "ai-agent-" | sed 's/^[[:space:]]*//' || true)

if [ -z "$AGENT_BRANCHES" ]; then
    echo -e "${YELLOW}No agent branches found.${NC}"
    echo ""
    echo "To create an agent branch:"
    echo "  git checkout -b {prefix}/ai-agent-{your-id}"
    echo "  mkdir -p agent-ops/agents/{your-id}"
    echo "  # Fill out CONTEXT.md and STATUS.md"
    echo "  git push -u origin {prefix}/ai-agent-{your-id}"
    echo ""
    exit 0
fi

echo -e "${GREEN}Found agent branches:${NC}"
echo ""

# Get current branch to highlight yourself
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

# Process each agent branch
while IFS= read -r branch; do
    # Skip if empty
    [ -z "$branch" ] && continue

    # Extract agent ID from branch name
    # Pattern: */ai-agent-{id} or ai-agent-{id}
    agent_id=$(echo "$branch" | sed 's/.*ai-agent-/ai-agent-/' | sed 's/^ai-agent-//')

    # Determine if this is "you"
    IS_YOU=""
    if echo "$CURRENT_BRANCH" | grep -q "ai-agent-$agent_id"; then
        IS_YOU=" ${CYAN}(YOU)${NC}"
    fi

    echo -e "${BOLD}${BLUE}Agent:${NC} ${agent_id}${IS_YOU}"
    echo -e "${BOLD}${BLUE}Branch:${NC} ${branch}"

    # Try to read CONTEXT.md
    CONTEXT_FILE="agent-ops/agents/$agent_id/CONTEXT.md"
    CONTEXT_CONTENT=$(git show "$branch:$CONTEXT_FILE" 2>/dev/null || echo "")

    if [ -n "$CONTEXT_CONTENT" ]; then
        # Extract key info from CONTEXT.md
        STATUS=$(echo "$CONTEXT_CONTENT" | grep "^\*\*Status\*\*:" | head -1 | sed 's/\*\*Status\*\*:[[:space:]]*//' || echo "Unknown")
        LAST_UPDATED=$(echo "$CONTEXT_CONTENT" | grep "^\*\*Last Updated\*\*:" | head -1 | sed 's/\*\*Last Updated\*\*:[[:space:]]*//' || echo "Unknown")
        PRODUCT_BRANCH=$(echo "$CONTEXT_CONTENT" | grep "^\*\*Product Branch\*\*:" | head -1 | sed 's/\*\*Product Branch\*\*:[[:space:]]*//' || echo "Unknown")
        LINEAR_TICKET=$(echo "$CONTEXT_CONTENT" | grep "^\*\*Linear Ticket\*\*:" | head -1 | sed 's/\*\*Linear Ticket\*\*:[[:space:]]*//' || echo "N/A")

        # Extract current work (first few lines under ## Current Work)
        CURRENT_WORK=$(echo "$CONTEXT_CONTENT" | awk '/^## Current Work/,/^##/ {if ($0 !~ /^## Current Work/ && $0 !~ /^##$/ && $0 !~ /^##[^#]/) print}' | head -3 | sed 's/^/  /')

        echo -e "  ${BOLD}Status:${NC} $STATUS"
        echo -e "  ${BOLD}Last Updated:${NC} $LAST_UPDATED"
        if [ "$PRODUCT_BRANCH" != "Unknown" ]; then
            echo -e "  ${BOLD}Product Branch:${NC} $PRODUCT_BRANCH"
        fi
        if [ "$LINEAR_TICKET" != "N/A" ]; then
            echo -e "  ${BOLD}Linear Ticket:${NC} $LINEAR_TICKET"
        fi

        if [ -n "$CURRENT_WORK" ]; then
            echo -e "  ${BOLD}Current Work:${NC}"
            echo "$CURRENT_WORK"
        fi
    else
        echo -e "  ${YELLOW}No CONTEXT.md found${NC}"
    fi

    # Try to read STATUS.md
    STATUS_FILE="agent-ops/agents/$agent_id/STATUS.md"
    STATUS_CONTENT=$(git show "$branch:$STATUS_FILE" 2>/dev/null || echo "")

    if [ -n "$STATUS_CONTENT" ]; then
        LAST_HEARTBEAT=$(echo "$STATUS_CONTENT" | grep "^\*\*Last Heartbeat\*\*:" | head -1 | sed 's/\*\*Last Heartbeat\*\*:[[:space:]]*//' || echo "")
        if [ -n "$LAST_HEARTBEAT" ]; then
            echo -e "  ${BOLD}Last Heartbeat:${NC} $LAST_HEARTBEAT"
        fi
    fi

    echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"
    echo ""

done <<< "$AGENT_BRANCHES"

# Summary
AGENT_COUNT=$(echo "$AGENT_BRANCHES" | wc -l)
echo -e "${GREEN}Total agents: $AGENT_COUNT${NC}"
echo ""

# Show cache info if exists
CACHE_DIR="$PROJECT_ROOT/agent-ops/.cache/agents"
if [ -d "$CACHE_DIR" ]; then
    CACHE_AGE=$(find "$CACHE_DIR" -type f -name "*.context.md" -printf '%T+\n' 2>/dev/null | sort -r | head -1 || echo "")
    if [ -n "$CACHE_AGE" ]; then
        echo -e "${CYAN}Local cache last updated: $CACHE_AGE${NC}"
        echo -e "${CYAN}Run ./agent-ops/scripts/sync-agents.sh to update cache${NC}"
    fi
fi

echo ""
