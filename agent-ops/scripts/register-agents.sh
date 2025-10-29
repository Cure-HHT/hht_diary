#!/bin/bash
# Register agent-ops agents in .claude/agents.json
# This ensures the startup and coordination agents are available

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
AGENTS_FILE="$REPO_ROOT/.claude/agents.json"

# Ensure .claude directory exists
mkdir -p "$REPO_ROOT/.claude"

# Create agents.json if it doesn't exist
if [ ! -f "$AGENTS_FILE" ]; then
  echo "Creating new .claude/agents.json..."
  echo '{"agents": []}' > "$AGENTS_FILE"
fi

# Read current agents
CURRENT_AGENTS=$(cat "$AGENTS_FILE")

# Check if agent-ops-startup is already registered
if echo "$CURRENT_AGENTS" | jq -e '.agents[] | select(.name == "agent-ops-startup")' > /dev/null 2>&1; then
  echo "✓ agent-ops-startup already registered"
  STARTUP_EXISTS=true
else
  echo "Adding agent-ops-startup..."
  STARTUP_EXISTS=false
fi

# Check if ai-coordination is already registered
if echo "$CURRENT_AGENTS" | jq -e '.agents[] | select(.name == "ai-coordination")' > /dev/null 2>&1; then
  echo "✓ ai-coordination already registered"
  COORDINATION_EXISTS=true
else
  echo "Adding ai-coordination..."
  COORDINATION_EXISTS=false
fi

# If both exist, we're done
if [ "$STARTUP_EXISTS" = true ] && [ "$COORDINATION_EXISTS" = true ]; then
  echo ""
  echo "All agent-ops agents already registered in .claude/agents.json"
  exit 0
fi

# Add missing agents
UPDATED_AGENTS="$CURRENT_AGENTS"

if [ "$STARTUP_EXISTS" = false ]; then
  UPDATED_AGENTS=$(echo "$UPDATED_AGENTS" | jq '.agents += [{
    "name": "agent-ops-startup",
    "description": "MANDATORY: Launch at session start to verify agent-ops configuration and announce agent identity. Reports worktree location, initialization status, and agent name. Use FIRST before any other work.",
    "instructions_file": "agent-ops/ai/AGENT_OPS_STARTUP.md",
    "tools": ["Bash", "Read"],
    "model": "haiku"
  }]')
fi

if [ "$COORDINATION_EXISTS" = false ]; then
  UPDATED_AGENTS=$(echo "$UPDATED_AGENTS" | jq '.agents += [{
    "name": "ai-coordination",
    "description": "Manages all agent branch operations via worktree. Agent branches named after mechanical objects (wrench, hammer, etc.). Use at session start (check outstanding work), when starting features, reporting work, or completing features.",
    "instructions_file": "agent-ops/ai/AI_COORDINATION.md",
    "tools": ["*"]
  }]')
fi

# Write updated agents.json
echo "$UPDATED_AGENTS" | jq '.' > "$AGENTS_FILE"

echo ""
echo "✓ Agent registration complete"
echo "  File: $AGENTS_FILE"
echo ""
echo "Agent-ops agents registered:"
if [ "$STARTUP_EXISTS" = false ]; then
  echo "  ✓ agent-ops-startup (session startup checks)"
fi
if [ "$COORDINATION_EXISTS" = false ]; then
  echo "  ✓ ai-coordination (session tracking & coordination)"
fi
echo ""
echo "These agents are now available via the Task tool."
echo ""
echo "To use at session start:"
echo "  - Run '/startup' slash command"
echo "  - Or manually: Task tool with subagent_type='agent-ops-startup'"
