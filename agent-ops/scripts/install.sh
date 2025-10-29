#!/usr/bin/env bash
#
# Agent Ops Installation Script
# Run once per project to set up the agent-ops system
#

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
AGENT_OPS_ROOT="$PROJECT_ROOT/agent-ops"

echo ""
echo -e "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Agent Ops Installation${NC}"
echo -e "${BOLD}${BLUE}  Version 4.0 (Simplified - No plan.md)${NC}"
echo -e "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
echo -e "${CYAN}[1/6] Checking prerequisites...${NC}"

# Check for jq (required for agent config)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}✗ jq is not installed${NC}"
    echo ""
    echo "jq is required for agent configuration management."
    echo "Install with:"
    echo "  - Ubuntu/Debian: sudo apt-get install jq"
    echo "  - macOS: brew install jq"
    echo "  - Fedora: sudo dnf install jq"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ jq is installed${NC}"
fi

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ git is not installed${NC}"
    exit 1
else
    echo -e "${GREEN}✓ git is installed${NC}"
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}✗ Not in a git repository${NC}"
    exit 1
else
    echo -e "${GREEN}✓ In a git repository${NC}"
fi

echo ""

# Set up .gitignore
echo -e "${CYAN}[2/6] Configuring .gitignore...${NC}"

GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"

if [ ! -f "$GITIGNORE_FILE" ]; then
    echo -e "${YELLOW}Creating new .gitignore file${NC}"
    touch "$GITIGNORE_FILE"
fi

# Check if agent-ops entries exist
if grep -q "agent-ops/sessions/" "$GITIGNORE_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ .gitignore already configured${NC}"
else
    echo -e "${YELLOW}Adding agent-ops entries to .gitignore${NC}"

    # Add entries
    if ! grep -q "^# Agent Ops" "$GITIGNORE_FILE" 2>/dev/null; then
        cat >> "$GITIGNORE_FILE" <<'EOF'

# Agent Ops - Local session files (archived to agent branches)
agent-ops/sessions/
EOF
        echo -e "${GREEN}✓ Added agent-ops entries to .gitignore${NC}"
    fi
fi

# Ensure untracked-notes is ignored
if ! grep -q "untracked-notes" "$GITIGNORE_FILE" 2>/dev/null; then
    cat >> "$GITIGNORE_FILE" <<'EOF'

# Untracked notes and scratch files
/untracked-notes/
EOF
    echo -e "${GREEN}✓ Added untracked-notes to .gitignore${NC}"
fi

echo ""

# Create necessary directories
echo -e "${CYAN}[3/6] Creating directories...${NC}"

mkdir -p "$PROJECT_ROOT/untracked-notes"
mkdir -p "$AGENT_OPS_ROOT/sessions"

echo -e "${GREEN}✓ Created untracked-notes/${NC}"
echo -e "${GREEN}✓ Created agent-ops/sessions/${NC}"

echo ""

# Set up CLAUDE.md integration
echo -e "${CYAN}[4/6] Configuring CLAUDE.md integration...${NC}"

CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"

if [ ! -f "$CLAUDE_MD" ]; then
    echo -e "${YELLOW}CLAUDE.md not found${NC}"
    echo -e "${YELLOW}This file should contain project-specific instructions for Claude Code.${NC}"
    echo ""
    read -p "Create basic CLAUDE.md now? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cat > "$CLAUDE_MD" <<'EOF'
# Project Instructions for Claude Code

Add your project-specific instructions here.

EOF
        echo -e "${GREEN}✓ Created CLAUDE.md template${NC}"
    fi
fi

# Check if agent-ops is mentioned in CLAUDE.md
if [ -f "$CLAUDE_MD" ] && ! grep -q "agent-ops" "$CLAUDE_MD" 2>/dev/null; then
    echo -e "${YELLOW}Adding agent-ops reference to CLAUDE.md${NC}"

    cat >> "$CLAUDE_MD" <<'EOF'

## Agent Ops System

This project uses the agent-ops system for multi-agent coordination.

**For AI Agents**:
- Read `agent-ops/ai/ORCHESTRATOR.md` for orchestrator workflow
- Use `ai-coordination` sub-agent for session management
- Run `./agent-ops/scripts/init-agent.sh` once per session

**Documentation**:
- `agent-ops/README.md` - System overview
- `agent-ops/HUMAN.md` - Human-readable guide
- `agent-ops/ai/AI_COORDINATION.md` - Sub-agent instructions

EOF
    echo -e "${GREEN}✓ Added agent-ops reference to CLAUDE.md${NC}"
else
    echo -e "${GREEN}✓ CLAUDE.md already configured${NC}"
fi

echo ""

# Set up .claude/instructions.md (if .claude directory exists)
echo -e "${CYAN}[5/6] Configuring .claude/instructions.md...${NC}"

CLAUDE_DIR="$PROJECT_ROOT/.claude"
INSTRUCTIONS_FILE="$CLAUDE_DIR/instructions.md"

if [ -d "$CLAUDE_DIR" ]; then
    mkdir -p "$CLAUDE_DIR"

    if [ ! -f "$INSTRUCTIONS_FILE" ]; then
        touch "$INSTRUCTIONS_FILE"
    fi

    # Check if already configured
    if grep -q "## Agent Ops" "$INSTRUCTIONS_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ .claude/instructions.md already configured${NC}"
    else
        echo -e "${YELLOW}Adding Agent Ops section to .claude/instructions.md${NC}"

        cat >> "$INSTRUCTIONS_FILE" <<'EOF'

## Agent Ops

**For Orchestrators** (recommended):
Read `agent-ops/ai/ORCHESTRATOR.md` - delegate to `ai-coordination` sub-agent for session management.

**For Direct Control**:
Use `agent-ops/scripts/` for manual session management.

EOF
        echo -e "${GREEN}✓ Added to .claude/instructions.md${NC}"
    fi
else
    echo -e "${YELLOW}.claude/ directory not found (skipping)${NC}"
fi

echo ""

# Verify installation
echo -e "${CYAN}[6/6] Verifying installation...${NC}"

CHECKS_PASSED=0
CHECKS_TOTAL=5

# Check 1: Templates exist
if [ -f "$AGENT_OPS_ROOT/ai/templates/diary.md" ] && [ -f "$AGENT_OPS_ROOT/ai/templates/results.md" ]; then
    echo -e "${GREEN}✓ Templates found${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo -e "${RED}✗ Templates missing${NC}"
fi

# Check 2: Scripts are executable
if [ -x "$AGENT_OPS_ROOT/scripts/init-agent.sh" ] && [ -x "$AGENT_OPS_ROOT/scripts/new-session.sh" ]; then
    echo -e "${GREEN}✓ Scripts are executable${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo -e "${YELLOW}Making scripts executable...${NC}"
    chmod +x "$AGENT_OPS_ROOT/scripts/"*.sh
    echo -e "${GREEN}✓ Scripts made executable${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
fi

# Check 3: AI instructions exist
if [ -f "$AGENT_OPS_ROOT/ai/ORCHESTRATOR.md" ] && [ -f "$AGENT_OPS_ROOT/ai/AI_COORDINATION.md" ]; then
    echo -e "${GREEN}✓ AI instructions found${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo -e "${RED}✗ AI instructions missing${NC}"
fi

# Check 4: gitignore configured
if grep -q "agent-ops/sessions/" "$GITIGNORE_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ .gitignore configured${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo -e "${RED}✗ .gitignore not configured${NC}"
fi

# Check 5: jq available
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq available${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo -e "${RED}✗ jq not available${NC}"
fi

echo ""

if [ $CHECKS_PASSED -eq $CHECKS_TOTAL ]; then
    echo -e "${BOLD}${GREEN}════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}  Installation Complete!${NC}"
    echo -e "${BOLD}${GREEN}════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review agent-ops/README.md for system overview"
    echo "2. Run ./agent-ops/scripts/init-agent.sh when starting a new session"
    echo "3. Read agent-ops/ai/ORCHESTRATOR.md for AI agent workflow"
    echo ""
else
    echo -e "${YELLOW}Installation completed with warnings.${NC}"
    echo -e "${YELLOW}$CHECKS_PASSED/$CHECKS_TOTAL checks passed${NC}"
    echo ""
fi
