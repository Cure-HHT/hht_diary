#!/usr/bin/env bash
#
# Initialize Agent Ops integration with Claude Code
#
# Updates .claude/instructions.md with agent-ops workflow
# Idempotent - safe to re-run
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
INSTRUCTIONS_FILE="$CLAUDE_DIR/instructions.md"

echo -e "${BLUE}=== Agent Ops Setup ===${NC}"

# Create .claude directory if needed
mkdir -p "$CLAUDE_DIR"

# Check if already configured
if grep -q "## Agent Ops" "$INSTRUCTIONS_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ Already configured${NC}"
    exit 0
fi

# Add Agent Ops section
cat >> "$INSTRUCTIONS_FILE" << 'EOF'

## Agent Ops

**For Orchestrators** (recommended):
Read `agent-ops/ai/ORCHESTRATOR.md` - delegate to `ai-coordination` sub-agent for session management.

**For Direct Control**:
Read `agent-ops/ai/AGENT_GUIDE.md` - manage sessions yourself with scripts/slash commands.
EOF

echo -e "${GREEN}✓ Added to .claude/instructions.md${NC}"
echo
echo "Next: Read agent-ops/README.md"
