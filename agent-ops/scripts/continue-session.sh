#!/usr/bin/env bash
# continue-session.sh - Continue an interrupted session
# Appends to existing diary with resume marker
#
# Usage:
#   ./continue-session.sh [session_directory]
#   ./continue-session.sh                        # Auto-detect latest session

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  Continue Session${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Check for agent config
CONFIG_FILE="$PROJECT_ROOT/untracked-notes/agent-ops.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}Error: No agent config found${NC}"
  echo "Run ./agent-ops/scripts/init-agent.sh to initialize an agent."
  exit 1
fi

# Read agent config
AGENT_NAME=$(jq -r '.agent_name' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
PRODUCT_BRANCH=$(jq -r '.product_branch' "$CONFIG_FILE" 2>/dev/null || echo "unknown")

echo -e "${BOLD}Agent:${NC} $AGENT_NAME"
echo -e "${BOLD}Product Branch:${NC} $PRODUCT_BRANCH"
echo ""

# Determine session directory
SESSION_DIR=""

if [ $# -eq 1 ]; then
  # Session directory provided
  SESSION_DIR="$1"
  if [ ! -d "$SESSION_DIR" ]; then
    echo -e "${RED}Error: Session directory not found: $SESSION_DIR${NC}"
    exit 1
  fi
else
  # Auto-detect latest session
  SESSIONS=$(find "$PROJECT_ROOT/agent-ops/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r || echo "")

  if [ -z "$SESSIONS" ]; then
    echo -e "${RED}Error: No session directories found${NC}"
    echo "Expected location: agent-ops/sessions/"
    exit 1
  fi

  # Get latest session
  SESSION_DIR=$(echo "$SESSIONS" | head -1)

  SESSION_COUNT=$(echo "$SESSIONS" | wc -l)
  if [ "$SESSION_COUNT" -gt 1 ]; then
    echo -e "${YELLOW}Found $SESSION_COUNT sessions. Using latest:${NC}"
    echo "  $SESSION_DIR"
    echo ""
    echo "To continue a different session, run:"
    echo "  $0 <session_directory>"
    echo ""
  fi
fi

SESSION_NAME=$(basename "$SESSION_DIR")

echo -e "${BOLD}Session:${NC} $SESSION_NAME"
echo ""

# Validate session can be continued
if [ ! -f "$SESSION_DIR/diary.md" ]; then
  echo -e "${RED}Error: Session has no diary.md${NC}"
  echo "Cannot continue a session without a diary."
  exit 1
fi

if [ -f "$SESSION_DIR/results.md" ]; then
  # Check if results are filled
  if ! grep -q "^\[2-4 sentence summary" "$SESSION_DIR/results.md" 2>/dev/null; then
    echo -e "${RED}Error: Session already has completed results.md${NC}"
    echo "This session appears to be complete. Cannot continue."
    echo ""
    echo "Options:"
    echo "  - Start a new session: ./agent-ops/scripts/new-session.sh"
    echo "  - Archive this session: ./agent-ops/scripts/end-session.sh"
    exit 1
  fi
fi

# Verify current branch matches
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$PRODUCT_BRANCH" ]; then
  echo -e "${YELLOW}Warning: Current branch mismatch${NC}"
  echo "  Expected: $PRODUCT_BRANCH"
  echo "  Current:  $CURRENT_BRANCH"
  echo ""
  read -p "Switch to $PRODUCT_BRANCH? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git checkout "$PRODUCT_BRANCH" 2>/dev/null || {
      echo -e "${RED}Error: Could not switch to $PRODUCT_BRANCH${NC}"
      exit 1
    }
    echo -e "${GREEN}✓ Switched to $PRODUCT_BRANCH${NC}"
    echo ""
  else
    echo "Continuing on current branch: $CURRENT_BRANCH"
    echo ""
  fi
fi

# Show last few diary entries for context
echo -e "${CYAN}Last diary entries:${NC}"
echo -e "${CYAN}────────────────────────────────────────────${NC}"
tail -20 "$SESSION_DIR/diary.md" | sed 's/^/  /'
echo -e "${CYAN}────────────────────────────────────────────${NC}"
echo ""

# Confirm continuation
read -p "Continue this session? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""

# Append resume marker to diary
TIMESTAMP=$(date +"%H:%M")

cat >> "$SESSION_DIR/diary.md" <<EOF

## [$TIMESTAMP] Session Resumed

Session interrupted and resumed by: $AGENT_NAME

**Previous Status**: Work in progress
**Action**: Continuing from last recorded state

EOF

echo -e "${GREEN}✓ Session resumed${NC}"
echo ""
echo "Session diary updated: $SESSION_DIR/diary.md"
echo ""

# Update heartbeat (session is now active)
HEARTBEAT_FILE="$PROJECT_ROOT/untracked-notes/agent-ops-heartbeat"
date -Iseconds > "$HEARTBEAT_FILE"

echo -e "${CYAN}Next steps:${NC}"
echo "  1. Review diary to understand what was being worked on"
echo "  2. Continue implementation"
echo "  3. Log work as usual: ai-coordination log_work events"
echo "  4. Complete session when done: ./agent-ops/scripts/end-session.sh"
echo ""

# Optionally open diary in editor
read -p "Open diary in editor? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  ${EDITOR:-nano} "$SESSION_DIR/diary.md"
fi

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Session Ready to Continue${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
