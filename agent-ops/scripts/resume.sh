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
AGENT_OPS_ROOT="$PROJECT_ROOT/agent-ops"

clear

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Agent Ops Resume - Multi-Agent Coordination${NC}"
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

# Check for agent configuration
CONFIG_FILE="$PROJECT_ROOT/untracked-notes/agent-ops.json"
AGENT_NAME=""
AGENT_BRANCH=""
WORKTREE_PATH=""

if [ -f "$CONFIG_FILE" ]; then
    AGENT_NAME=$(jq -r '.agent_name' "$CONFIG_FILE" 2>/dev/null || echo "")
    AGENT_BRANCH=$(jq -r '.agent_branch' "$CONFIG_FILE" 2>/dev/null || echo "")
    WORKTREE_PATH=$(jq -r '.worktree_path' "$CONFIG_FILE" 2>/dev/null || echo "")

    echo -e "${GREEN}${BOLD}Agent Configuration:${NC}"
    echo -e "${GREEN}─────────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}Agent Name:${NC} $AGENT_NAME"
    echo -e "  ${BOLD}Agent Branch:${NC} $AGENT_BRANCH"
    echo -e "  ${BOLD}Worktree Path:${NC} $WORKTREE_PATH"
    echo ""

    # Check if agent branch exists and has context
    if [ -n "$AGENT_NAME" ]; then
        CONTEXT_FILE="$AGENT_OPS_ROOT/agents/$AGENT_NAME/CONTEXT.md"

        # Try to find context on agent branch
        if git show "$AGENT_BRANCH:agent-ops/agents/$AGENT_NAME/CONTEXT.md" &> /dev/null; then
            echo -e "${YELLOW}${BOLD}Agent Context (from agent branch):${NC}"
            echo -e "${YELLOW}─────────────────────────────────────────────────────────${NC}"

            # Extract work in progress
            git show "$AGENT_BRANCH:agent-ops/agents/$AGENT_NAME/CONTEXT.md" | awk '
                /^## Work In Progress/,/^## / {
                    if ($0 !~ /^## Work In Progress/ && $0 !~ /^##[^#]/) {
                        print "  " $0
                    }
                }
            ' | head -20
            echo ""

            # Extract completed work
            echo -e "${GREEN}${BOLD}Recently Completed:${NC}"
            git show "$AGENT_BRANCH:agent-ops/agents/$AGENT_NAME/CONTEXT.md" | awk '
                /^## Completed/,/^$/ {
                    if ($0 !~ /^## Completed/) {
                        print "  " $0
                    }
                }
            ' | head -10
            echo ""
        elif [ -f "$CONTEXT_FILE" ]; then
            # Context exists locally
            echo -e "${YELLOW}${BOLD}Agent Context (local):${NC}"
            echo -e "${YELLOW}─────────────────────────────────────────────────────────${NC}"

            awk '
                /^## Work In Progress/,/^## / {
                    if ($0 !~ /^## Work In Progress/ && $0 !~ /^##[^#]/) {
                        print "  " $0
                    }
                }
            ' "$CONTEXT_FILE" | head -20
            echo ""
        fi
    fi
else
    echo -e "${YELLOW}No agent configuration found.${NC}"
    echo -e "${YELLOW}Run: ./agent-ops/scripts/init-agent.sh${NC}"
    echo ""
fi

# Find latest session
echo -e "${CYAN}${BOLD}Recent Sessions:${NC}"
echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

LATEST_SESSION=$(find "$AGENT_OPS_ROOT/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r | head -n 1)

if [ -n "$LATEST_SESSION" ]; then
    SESSION_NAME=$(basename "$LATEST_SESSION")
    echo -e "  ${BOLD}Latest Active:${NC} sessions/$SESSION_NAME/"

    if [ -f "$LATEST_SESSION/diary.md" ]; then
        # Extract goal from diary
        GOAL=$(grep -A 2 "^### Goal" "$LATEST_SESSION/diary.md" 2>/dev/null | tail -1 || echo "")
        if [ -n "$GOAL" ]; then
            echo -e "    ${BOLD}Goal:${NC} $GOAL"
        fi

        # Check if results are filled out
        if [ -f "$LATEST_SESSION/results.md" ] && ! grep -q "^\[2-4 sentence summary" "$LATEST_SESSION/results.md" 2>/dev/null; then
            echo -e "    ${GREEN}Status: Complete (results.md filled)${NC}"
        else
            echo -e "    ${YELLOW}Status: In progress${NC}"
        fi
    else
        echo -e "    ${YELLOW}Status: In progress${NC}"
    fi
else
    echo -e "  ${YELLOW}No active sessions found${NC}"
fi

# Check for archives on agent branch
if [ -n "$AGENT_BRANCH" ] && [ -n "$AGENT_NAME" ]; then
    LATEST_ARCHIVE=$(git show "$AGENT_BRANCH:agent-ops/archive/" 2>/dev/null | grep "^[0-9]" | sort -r | head -1 || echo "")

    if [ -n "$LATEST_ARCHIVE" ]; then
        echo -e "  ${BOLD}Latest Archive:${NC} $LATEST_ARCHIVE (on $AGENT_BRANCH)"
    fi
fi

if [ -z "$LATEST_SESSION" ] && [ -z "$LATEST_ARCHIVE" ]; then
    echo -e "  ${YELLOW}No sessions found - ready for first session${NC}"
fi

echo ""

# Display quick commands
echo -e "${BLUE}${BOLD}Quick Commands:${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"
if [ -n "$AGENT_NAME" ] && [ -n "$AGENT_BRANCH" ]; then
    echo -e "  ${BOLD}View agent context:${NC} git show $AGENT_BRANCH:agent-ops/agents/$AGENT_NAME/CONTEXT.md"
fi
if [ -n "$LATEST_SESSION" ]; then
    echo -e "  ${BOLD}View latest session:${NC} cat $LATEST_SESSION/diary.md"
fi
echo -e "  ${BOLD}Start new session:${NC} ./agent-ops/scripts/new-session.sh"
echo -e "  ${BOLD}End current session:${NC} ./agent-ops/scripts/end-session.sh"
echo -e "  ${BOLD}Show all agents:${NC} ./agent-ops/scripts/show-agents.sh"
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
    if [ -n "$LATEST_SESSION" ]; then
        if [ -f "$LATEST_SESSION/results.md" ] && ! grep -q "^\[2-4 sentence summary" "$LATEST_SESSION/results.md" 2>/dev/null; then
            echo -e "${YELLOW}Latest session is complete. Start a new one when ready.${NC}"
        else
            echo -e "${YELLOW}Continue working in: $LATEST_SESSION${NC}"
        fi
    else
        echo -e "${YELLOW}Start a new session when ready: ./agent-ops/scripts/new-session.sh${NC}"
    fi
    echo ""
fi
