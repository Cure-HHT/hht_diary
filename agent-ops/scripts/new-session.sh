#!/usr/bin/env bash
# new-session.sh - Create new agent-ops session
# Usage: ./new-session.sh [optional session name]

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT_OPS_ROOT="$PROJECT_ROOT/agent-ops"

# Generate timestamp for session directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Get optional session name from argument
SESSION_NAME="${1:-work}"
SESSION_NAME=$(echo "$SESSION_NAME" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')

echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Agent Ops - New Session${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# Optional: Show other agents
echo -e "${CYAN}Checking for other active agents...${NC}"
if command -v "$SCRIPT_DIR/show-agents.sh" &> /dev/null; then
    AGENT_COUNT=$(git branch -r 2>/dev/null | grep -c "ai-agent-" || echo "0")

    if [ "$AGENT_COUNT" -gt "0" ]; then
        echo -e "${YELLOW}Found $AGENT_COUNT other agent(s). Run './agent-ops/scripts/show-agents.sh' to see details.${NC}"
        echo ""
        read -p "Show other agents now? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            "$SCRIPT_DIR/show-agents.sh"
            echo ""
            read -p "Press Enter to continue creating session..."
            echo ""
        fi
    else
        echo -e "${GREEN}No other agents found. You're the first!${NC}"
    fi
else
    echo -e "${YELLOW}show-agents.sh not found, skipping agent discovery${NC}"
fi

echo ""

# Create session directory
SESSION_DIR="$AGENT_OPS_ROOT/sessions/${TIMESTAMP}"
mkdir -p "$SESSION_DIR"

echo -e "${BLUE}Creating new session...${NC}"
echo ""

# Copy templates
echo -e "${GREEN}[1/4]${NC} Copying templates..."
cp "$AGENT_OPS_ROOT/meta/templates/plan.md" "$SESSION_DIR/plan.md"
cp "$AGENT_OPS_ROOT/meta/templates/diary.md" "$SESSION_DIR/diary.md"
cp "$AGENT_OPS_ROOT/meta/templates/results.md" "$SESSION_DIR/results.md"
touch "$SESSION_DIR/notes.md"

# Fill in timestamp in templates
sed -i "s/\[YYYY-MM-DD HH:MM:SS\]/$(date +"%Y-%m-%d %H:%M:%S")/g" "$SESSION_DIR/plan.md"
sed -i "s/\[YYYYMMDD_HHMMSS\]/${TIMESTAMP}/g" "$SESSION_DIR/plan.md"

sed -i "s/\[YYYY-MM-DD HH:MM:SS\]/$(date +"%Y-%m-%d %H:%M:%S")/g" "$SESSION_DIR/diary.md"
sed -i "s/\[YYYYMMDD_HHMMSS\]/${TIMESTAMP}/g" "$SESSION_DIR/diary.md"

sed -i "s/\[YYYYMMDD_HHMMSS\]/${TIMESTAMP}/g" "$SESSION_DIR/results.md"

# Update session name placeholders
sed -i "s/\[Session name\]/${SESSION_NAME}/g" "$SESSION_DIR/plan.md"
sed -i "s/\[Session name\]/${SESSION_NAME}/g" "$SESSION_DIR/diary.md"
sed -i "s/\[Session name\]/${SESSION_NAME}/g" "$SESSION_DIR/results.md"

# Check for previous session
echo -e "${GREEN}[2/4]${NC} Checking for previous sessions..."
LATEST_SESSION=$(find "$AGENT_OPS_ROOT/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r | head -n 2 | tail -n 1 || echo "")

# Check agent branch for archives
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
AGENT_BRANCH=""

# Try to find corresponding agent branch
if echo "$CURRENT_BRANCH" | grep -q "ai-agent-"; then
    AGENT_BRANCH="$CURRENT_BRANCH"
elif [ -n "$CURRENT_BRANCH" ]; then
    # Extract session ID and look for agent branch
    SESSION_ID=$(echo "$CURRENT_BRANCH" | grep -o '[^-]*$' || echo "")
    if [ -n "$SESSION_ID" ]; then
        # Look for ai-agent branch with this session ID
        POSSIBLE_AGENT=$(git branch -r | grep "ai-agent-.*$SESSION_ID" | head -1 | sed 's/^[[:space:]]*//' || echo "")
        if [ -n "$POSSIBLE_AGENT" ]; then
            AGENT_BRANCH="$POSSIBLE_AGENT"
            echo "   Found potential agent branch: $AGENT_BRANCH"
        fi
    fi
fi

LATEST_ARCHIVE=""
if [ -n "$AGENT_BRANCH" ]; then
    # Try to find archives on agent branch
    ARCHIVE_LIST=$(git show "$AGENT_BRANCH:agent-ops/archive/" 2>/dev/null | grep "^[0-9]" || echo "")
    if [ -n "$ARCHIVE_LIST" ]; then
        LATEST_ARCHIVE=$(echo "$ARCHIVE_LIST" | sort -r | head -1)
        echo "   Latest archive on $AGENT_BRANCH: $LATEST_ARCHIVE"
    fi
fi

if [ -n "$LATEST_SESSION" ]; then
    echo "   Previous local session: $(basename "$LATEST_SESSION")"
    sed -i "s|\[Link to previous session if applicable, or \"New session\"\]|Previous session: sessions/$(basename "$LATEST_SESSION")/|g" "$SESSION_DIR/plan.md"
elif [ -n "$LATEST_ARCHIVE" ]; then
    echo "   Previous session (archived): $LATEST_ARCHIVE"
    sed -i "s|\[Link to previous session if applicable, or \"New session\"\]|Previous session: archive/$LATEST_ARCHIVE/ (on agent branch)|g" "$SESSION_DIR/plan.md"
else
    echo "   No previous session found (first session)"
    sed -i "s|\[Link to previous session if applicable, or \"New session\"\]|First session|g" "$SESSION_DIR/plan.md"
fi

# Add initial diary entry
echo -e "${GREEN}[3/4]${NC} Creating initial diary entry..."
cat >> "$SESSION_DIR/diary.md" <<EOF

## [$(date +"%H:%M")] Session Start

**Current Branch**: $CURRENT_BRANCH
**Session Goal**: $SESSION_NAME

EOF

if [ -n "$AGENT_BRANCH" ]; then
    cat >> "$SESSION_DIR/diary.md" <<EOF
**Agent Branch**: $AGENT_BRANCH

EOF
fi

cat >> "$SESSION_DIR/diary.md" <<EOF
**Plan**: [Fill out plan.md and summarize here]

---

EOF

# Get git info
echo -e "${GREEN}[4/4]${NC} Recording git state..."
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "   Branch: $GIT_BRANCH"
echo "   Commit: $GIT_COMMIT"

# Update plan.md with git info
sed -i "s/\[git branch\]/$GIT_BRANCH/g" "$SESSION_DIR/plan.md"

# Success message
echo ""
echo -e "${GREEN}✓ Session created successfully!${NC}"
echo ""
echo -e "${BLUE}Session directory:${NC} $SESSION_DIR"
echo -e "${BLUE}Relative path:${NC} agent-ops/sessions/${TIMESTAMP}/"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Fill out $SESSION_DIR/plan.md"
echo "2. Start working and update $SESSION_DIR/diary.md as you go"
echo "3. When done, run ./agent-ops/scripts/end-session.sh"
echo ""
echo -e "${CYAN}Note:${NC} This session is local (gitignored)."
echo "To share with other agents, archive to your agent branch when complete."
echo ""
