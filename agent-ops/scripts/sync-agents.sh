#!/usr/bin/env bash
# sync-agents.sh - Sync and cache other agents' state locally
# Usage: ./sync-agents.sh

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CACHE_DIR="$PROJECT_ROOT/agent-ops/.cache/agents"

cd "$PROJECT_ROOT"

echo -e "${BLUE}Syncing agent states...${NC}"
echo ""

# Fetch all remote branches
echo -e "${GREEN}[1/3]${NC} Fetching remote branches..."
git fetch --all --quiet 2>/dev/null || true

# Create cache directory
mkdir -p "$CACHE_DIR"

# Find all agent branches
AGENT_BRANCHES=$(git branch -r | grep "ai-agent-" | sed 's/^[[:space:]]*//' || true)

if [ -z "$AGENT_BRANCHES" ]; then
    echo -e "${YELLOW}No agent branches found. Nothing to cache.${NC}"
    exit 0
fi

# Count agents
AGENT_COUNT=$(echo "$AGENT_BRANCHES" | wc -l)
echo -e "${GREEN}[2/3]${NC} Found $AGENT_COUNT agent branch(es)"

# Process each agent branch
echo -e "${GREEN}[3/3]${NC} Caching agent states..."

COUNT=0
while IFS= read -r branch; do
    # Skip if empty
    [ -z "$branch" ] && continue

    # Extract agent ID
    agent_id=$(echo "$branch" | sed 's/.*ai-agent-/ai-agent-/' | sed 's/^ai-agent-//')

    # Cache CONTEXT.md
    CONTEXT_FILE="agent-ops/agents/$agent_id/CONTEXT.md"
    git show "$branch:$CONTEXT_FILE" > "$CACHE_DIR/$agent_id.context.md" 2>/dev/null || {
        echo -e "  ${YELLOW}Warning: No CONTEXT.md for $agent_id${NC}"
        echo "# No context available" > "$CACHE_DIR/$agent_id.context.md"
    }

    # Cache STATUS.md
    STATUS_FILE="agent-ops/agents/$agent_id/STATUS.md"
    git show "$branch:$STATUS_FILE" > "$CACHE_DIR/$agent_id.status.md" 2>/dev/null || {
        echo "# No status available" > "$CACHE_DIR/$agent_id.status.md"
    }

    # Cache CURRENT_SESSION.md if exists
    SESSION_FILE="agent-ops/agents/$agent_id/CURRENT_SESSION.md"
    git show "$branch:$SESSION_FILE" > "$CACHE_DIR/$agent_id.session.md" 2>/dev/null || {
        echo "# No current session" > "$CACHE_DIR/$agent_id.session.md"
    }

    COUNT=$((COUNT + 1))
    echo "  ✓ Cached: $agent_id"

done <<< "$AGENT_BRANCHES"

echo ""
echo -e "${GREEN}✓ Cached $COUNT agent state(s) to: agent-ops/.cache/agents/${NC}"
echo ""
echo "Use './agent-ops/scripts/show-agents.sh' to view agent states"
echo ""
