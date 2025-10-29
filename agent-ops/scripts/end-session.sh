#!/usr/bin/env bash
# end-session.sh - End current session and archive to agent branch
# Usage: ./end-session.sh [session_directory]

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

cd "$PROJECT_ROOT"

echo -e "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Agent Ops - End Session${NC}"
echo -e "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# Find session directory
if [ -n "${1:-}" ]; then
    SESSION_DIR="$1"
else
    # Find most recent session
    SESSION_DIR=$(find "$AGENT_OPS_ROOT/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r | head -n 1)

    if [ -z "$SESSION_DIR" ]; then
        echo -e "${RED}Error: No session found in agent-ops/sessions/${NC}"
        echo "Usage: $0 [session_directory]"
        exit 1
    fi
fi

if [ ! -d "$SESSION_DIR" ]; then
    echo -e "${RED}Error: Session directory not found: $SESSION_DIR${NC}"
    exit 1
fi

SESSION_NAME=$(basename "$SESSION_DIR")
echo -e "${BLUE}Session:${NC} $SESSION_NAME"
echo ""

# Check if results.md already filled out
echo -e "${GREEN}[1/5]${NC} Checking results.md..."
if grep -q "^\[2-4 sentence summary" "$SESSION_DIR/results.md" 2>/dev/null; then
    echo -e "${YELLOW}Results.md needs to be completed${NC}"
    echo ""
    echo -e "${YELLOW}Please fill out the following in results.md:${NC}"
    echo "- Summary of session (2-4 sentences)"
    echo "- Completed/incomplete/blocked tasks"
    echo "- Files changed"
    echo "- Decisions made"
    echo "- What next session should do"
    echo ""
    echo "File: $SESSION_DIR/results.md"
    echo ""
    read -p "Press Enter when results.md is complete..."
    echo ""
else
    echo "   Results.md appears complete ✓"
fi

# Determine current and agent branches
echo -e "${GREEN}[2/5]${NC} Finding agent branch..."
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
AGENT_BRANCH=""

if [ -z "$CURRENT_BRANCH" ]; then
    echo -e "${RED}Error: Not on a git branch${NC}"
    exit 1
fi

# Check if we're already on an agent branch
if echo "$CURRENT_BRANCH" | grep -q "ai-agent-"; then
    AGENT_BRANCH="$CURRENT_BRANCH"
    echo "   Currently on agent branch: $AGENT_BRANCH"
else
    # Try to find corresponding agent branch
    echo "   Current branch: $CURRENT_BRANCH"

    # Extract potential session ID (last segment after last -)
    SESSION_ID=$(echo "$CURRENT_BRANCH" | grep -o '[^-]*$' || echo "")

    if [ -n "$SESSION_ID" ]; then
        # Look for agent branch with this session ID
        echo "   Looking for agent branch with session ID: $SESSION_ID"

        # Try local branches first
        POSSIBLE_AGENT=$(git branch | grep "ai-agent-.*$SESSION_ID" | head -1 | sed 's/^[* ]*//' || echo "")

        if [ -z "$POSSIBLE_AGENT" ]; then
            # Try remote branches
            POSSIBLE_AGENT=$(git branch -r | grep "ai-agent-.*$SESSION_ID" | head -1 | sed 's/^[[:space:]]*//' | sed 's/origin\///' || echo "")

            if [ -n "$POSSIBLE_AGENT" ]; then
                echo "   Found remote agent branch: $POSSIBLE_AGENT"
                echo "   Checking out locally..."
                git checkout -b "$POSSIBLE_AGENT" "origin/$POSSIBLE_AGENT" 2>/dev/null || git checkout "$POSSIBLE_AGENT"
                AGENT_BRANCH="$POSSIBLE_AGENT"
            fi
        else
            AGENT_BRANCH="$POSSIBLE_AGENT"
            echo "   Found local agent branch: $AGENT_BRANCH"
        fi
    fi
fi

# If still no agent branch, offer to create one
if [ -z "$AGENT_BRANCH" ]; then
    echo ""
    echo -e "${YELLOW}No agent branch found for this session.${NC}"
    echo ""
    read -p "Create agent branch now? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Extract prefix and session ID
        PREFIX=$(echo "$CURRENT_BRANCH" | sed 's/\/.*//')
        SESSION_ID=$(echo "$CURRENT_BRANCH" | grep -o '[^-]*$' || echo "")

        if [ -z "$SESSION_ID" ]; then
            SESSION_ID=$(date +"%Y%m%d")
        fi

        AGENT_BRANCH="${PREFIX}/ai-agent-${SESSION_ID}"

        echo ""
        echo -e "${CYAN}Creating agent branch: $AGENT_BRANCH${NC}"

        # Remember current branch to return to
        PRODUCT_BRANCH="$CURRENT_BRANCH"

        # Create and setup agent branch
        git checkout -b "$AGENT_BRANCH"

        # Extract agent ID from branch name
        AGENT_ID=$(echo "$AGENT_BRANCH" | sed 's/.*ai-agent-//')

        mkdir -p "agent-ops/agents/$AGENT_ID"

        # Create initial CONTEXT.md
        cat > "agent-ops/agents/$AGENT_ID/CONTEXT.md" <<EOF
# Agent: $AGENT_ID

**Status**: 🟢 Active
**Product Branch**: $PRODUCT_BRANCH
**Linear Ticket**: N/A
**Started**: $(date +"%Y-%m-%d %H:%M:%S")

## Current Work

Session: $SESSION_NAME

## Files Modified

[See session archive for details]
EOF

        git add agent-ops/
        git commit -m "[AGENT] $AGENT_ID: Initialize agent"
        git push -u origin "$AGENT_BRANCH"

        echo -e "${GREEN}✓ Agent branch created and pushed${NC}"
    else
        echo -e "${YELLOW}Cannot end session without agent branch. Exiting.${NC}"
        exit 0
    fi
fi

# Now we have an agent branch, switch to it
if [ "$(git branch --show-current)" != "$AGENT_BRANCH" ]; then
    PRODUCT_BRANCH="$CURRENT_BRANCH"
    echo ""
    echo -e "${CYAN}Switching to agent branch: $AGENT_BRANCH${NC}"
    git checkout "$AGENT_BRANCH"
else
    # Already on agent branch, find product branch from CONTEXT
    AGENT_ID=$(echo "$AGENT_BRANCH" | sed 's/.*ai-agent-//')
    PRODUCT_BRANCH=$(grep "^\*\*Product Branch\*\*:" "agent-ops/agents/$AGENT_ID/CONTEXT.md" 2>/dev/null | sed 's/\*\*Product Branch\*\*:[[:space:]]*//' || echo "")

    if [ -z "$PRODUCT_BRANCH" ]; then
        echo -e "${YELLOW}Warning: Could not determine product branch${NC}"
        PRODUCT_BRANCH="unknown"
    fi
fi

# Extract agent ID
AGENT_ID=$(echo "$AGENT_BRANCH" | sed 's/.*ai-agent-//')

echo "   Agent ID: $AGENT_ID"
echo "   Agent branch: $AGENT_BRANCH"
echo ""

# Archive session
echo -e "${GREEN}[3/5]${NC} Archiving session..."

# Generate archive name (include description from session name if available)
ARCHIVE_NAME="$SESSION_NAME"

# Create archive directory
ARCHIVE_DIR="agent-ops/archive/$ARCHIVE_NAME"
mkdir -p "agent-ops/archive"

# Move session to archive
cp -r "$SESSION_DIR" "$ARCHIVE_DIR"

echo "   Archived to: $ARCHIVE_DIR"

# Update agent CONTEXT.md
echo -e "${GREEN}[4/5]${NC} Updating agent CONTEXT.md..."

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Extract summary from results.md
SUMMARY=$(awk '/^## Summary/,/^---/ {if ($0 !~ /^## Summary/ && $0 !~ /^---/ && $0 !~ /^\*\*/ && $0 !~ /^Example:/) print}' "$ARCHIVE_DIR/results.md" | sed 's/^[[:space:]]*//' | grep -v '^$' | head -n 3 || echo "Session $SESSION_NAME completed")

# Update CONTEXT.md
cat > "agent-ops/agents/$AGENT_ID/CONTEXT.md" <<EOF
# Agent: $AGENT_ID

**Status**: 🟢 Active
**Product Branch**: $PRODUCT_BRANCH
**Last Updated**: $TIMESTAMP
**Last Session**: archive/$ARCHIVE_NAME/

## Last Session Summary

$SUMMARY

## Recent Work

- Session $SESSION_NAME completed at $TIMESTAMP
- Archive: agent-ops/archive/$ARCHIVE_NAME/

## Next Steps

[To be determined in next session]
EOF

echo "   Updated: agent-ops/agents/$AGENT_ID/CONTEXT.md"

# Commit to agent branch
echo -e "${GREEN}[5/5]${NC} Committing to agent branch..."

git add agent-ops/
git commit -m "[ARCHIVE] Session $SESSION_NAME complete"
git push origin "$AGENT_BRANCH"

echo -e "${GREEN}✓ Pushed to: $AGENT_BRANCH${NC}"
echo ""

# Clean up local session directory
echo -e "${CYAN}Cleaning up local session directory...${NC}"
rm -rf "$SESSION_DIR"
echo "   Removed: $SESSION_DIR"
echo ""

# Switch back to product branch
if [ "$PRODUCT_BRANCH" != "unknown" ] && [ -n "$PRODUCT_BRANCH" ]; then
    echo -e "${CYAN}Switching back to product branch: $PRODUCT_BRANCH${NC}"
    git checkout "$PRODUCT_BRANCH" 2>/dev/null || {
        echo -e "${YELLOW}Warning: Could not switch back to $PRODUCT_BRANCH${NC}"
        echo "You are on: $(git branch --show-current)"
    }
fi

echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Session Ended Successfully!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Session archived to:${NC} $AGENT_BRANCH"
echo -e "${BLUE}Archive location:${NC} agent-ops/archive/$ARCHIVE_NAME/"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Continue work on product branch: $PRODUCT_BRANCH"
echo "2. Start new session: ./agent-ops/scripts/new-session.sh"
echo "3. View all agents: ./agent-ops/scripts/show-agents.sh"
echo ""
