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

# Helper: Check if process is alive
is_process_alive() {
  local pid=$1
  ps -p "$pid" > /dev/null 2>&1
}

# Helper: Calculate age of timestamp in seconds
get_timestamp_age() {
  local timestamp=$1
  local now=$(date +%s)
  local then=$(date -d "$timestamp" +%s 2>/dev/null || echo "0")
  echo $((now - then))
}

# Helper: Format duration
format_duration() {
  local seconds=$1
  if [ "$seconds" -lt 60 ]; then
    echo "${seconds}s ago"
  elif [ "$seconds" -lt 3600 ]; then
    echo "$((seconds/60))m ago"
  elif [ "$seconds" -lt 86400 ]; then
    echo "$((seconds/3600))h ago"
  else
    echo "$((seconds/86400))d ago"
  fi
}

# Helper: Detect session state with details
detect_session_state_detailed() {
  local config_file=$1
  local pid_file="${config_file%.json}.pid"
  local heartbeat_file="${config_file%.json}-heartbeat"

  local state="unknown"
  local details=""

  if [ ! -f "$config_file" ]; then
    echo "none|No config file"
    return
  fi

  # Check PID
  local process_status="unknown"
  if [ -f "$pid_file" ]; then
    local pid=$(cat "$pid_file" 2>/dev/null || echo "0")
    if is_process_alive "$pid"; then
      process_status="alive (PID $pid)"
    else
      process_status="dead (PID $pid not found)"
    fi
  else
    process_status="no PID file"
  fi

  # Check heartbeat
  local heartbeat_status="unknown"
  local heartbeat_age=999999
  if [ -f "$heartbeat_file" ]; then
    local heartbeat=$(cat "$heartbeat_file" 2>/dev/null || echo "")
    if [ -n "$heartbeat" ]; then
      heartbeat_age=$(get_timestamp_age "$heartbeat")
      heartbeat_status="$(format_duration $heartbeat_age)"
    else
      heartbeat_status="empty file"
    fi
  else
    heartbeat_status="no heartbeat file"
  fi

  # Determine state
  if [ -f "$pid_file" ]; then
    local pid=$(cat "$pid_file")
    if is_process_alive "$pid"; then
      if [ "$heartbeat_age" -lt 600 ]; then
        state="active"
        details="Process: $process_status, Activity: $heartbeat_status"
      else
        state="active_idle"
        details="Process: $process_status, Activity: $heartbeat_status"
      fi
    else
      if [ "$heartbeat_age" -lt 3600 ]; then
        state="recently_abandoned"
        details="Process: $process_status, Activity: $heartbeat_status"
      else
        state="stale_abandoned"
        details="Process: $process_status, Activity: $heartbeat_status"
      fi
    fi
  else
    state="unknown"
    details="$process_status, $heartbeat_status"
  fi

  echo "$state|$details"
}

echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}  Agent Status - Multi-Agent Coordination${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check local agent (current session)
CONFIG_FILE="$PROJECT_ROOT/untracked-notes/agent-ops.json"

if [ -f "$CONFIG_FILE" ]; then
  echo -e "${BOLD}${CYAN}═══ Local Agent (Current Session) ═══${NC}"
  echo ""

  AGENT_NAME=$(jq -r '.agent_name' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
  AGENT_BRANCH=$(jq -r '.agent_branch' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
  PRODUCT_BRANCH=$(jq -r '.product_branch' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
  WORKTREE_PATH=$(jq -r '.worktree_path' "$CONFIG_FILE" 2>/dev/null || echo "unknown")

  # Get state details
  STATE_INFO=$(detect_session_state_detailed "$CONFIG_FILE")
  STATE=$(echo "$STATE_INFO" | cut -d'|' -f1)
  DETAILS=$(echo "$STATE_INFO" | cut -d'|' -f2)

  # Format state with color
  case "$STATE" in
    active)
      STATE_DISPLAY="${GREEN}🟢 ACTIVE${NC}"
      ;;
    active_idle)
      STATE_DISPLAY="${YELLOW}🟡 ACTIVE (idle)${NC}"
      ;;
    recently_abandoned)
      STATE_DISPLAY="${YELLOW}🟠 RECENTLY ABANDONED${NC}"
      ;;
    stale_abandoned)
      STATE_DISPLAY="${RED}🔴 STALE/ABANDONED${NC}"
      ;;
    *)
      STATE_DISPLAY="${RED}❓ UNKNOWN${NC}"
      ;;
  esac

  echo -e "${BOLD}Agent:${NC} $AGENT_NAME ${CYAN}(YOU)${NC}"
  echo -e "${BOLD}Status:${NC} $STATE_DISPLAY"
  echo -e "${BOLD}Details:${NC} $DETAILS"
  echo -e "${BOLD}Branch:${NC} $AGENT_BRANCH"
  echo -e "${BOLD}Product Branch:${NC} $PRODUCT_BRANCH"
  echo -e "${BOLD}Worktree:${NC} $WORKTREE_PATH"

  # Check for active sessions
  if [ -d "$PROJECT_ROOT/agent-ops/sessions" ]; then
    SESSION_DIRS=$(find "$PROJECT_ROOT/agent-ops/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null || echo "")
    if [ -n "$SESSION_DIRS" ]; then
      SESSION_COUNT=$(echo "$SESSION_DIRS" | wc -l)
      echo -e "${BOLD}Active Sessions:${NC} $SESSION_COUNT"
      while IFS= read -r session_dir; do
        [ -z "$session_dir" ] && continue
        session_name=$(basename "$session_dir")
        echo -e "  - $session_name"
      done <<< "$SESSION_DIRS"
    else
      echo -e "${BOLD}Active Sessions:${NC} None"
    fi
  fi

  echo ""
else
  echo -e "${YELLOW}No local agent initialized.${NC}"
  echo -e "${YELLOW}Run ./agent-ops/scripts/init-agent.sh to initialize.${NC}"
  echo ""
fi

# Check for other agents on remote
echo -e "${BOLD}${CYAN}═══ Remote Agents (Agent Branches) ═══${NC}"
echo ""

# Fetch remote branches
echo -e "${CYAN}Fetching remote branches...${NC}"
git fetch --all --quiet 2>/dev/null || true

# Find all claude/* agent branches
AGENT_BRANCHES=$(git branch -r | grep "origin/claude/" | sed 's/^[[:space:]]*//' | sed 's|origin/||' || echo "")

if [ -z "$AGENT_BRANCHES" ]; then
  echo -e "${YELLOW}No remote agent branches found.${NC}"
  echo ""
  echo "Agent branches use the pattern: claude/{agent_name}"
  echo "Examples: claude/wrench, claude/hammer, claude/gear"
  echo ""
else
  echo -e "${GREEN}Found agent branches:${NC}"
  echo ""

  while IFS= read -r branch; do
    [ -z "$branch" ] && continue

    # Extract agent name from claude/{name}
    agent_name=$(echo "$branch" | sed 's|claude/||')

    # Check if this is the current local agent
    IS_LOCAL=""
    if [ -f "$CONFIG_FILE" ]; then
      LOCAL_AGENT=$(jq -r '.agent_name' "$CONFIG_FILE" 2>/dev/null || echo "")
      if [ "$LOCAL_AGENT" == "$agent_name" ]; then
        IS_LOCAL=" ${CYAN}(local)${NC}"
      fi
    fi

    echo -e "${BOLD}${BLUE}Agent:${NC} $agent_name$IS_LOCAL"
    echo -e "${BOLD}${BLUE}Branch:${NC} origin/$branch"

    # Try to read CONTEXT.md from agent branch
    CONTEXT_FILE="agent-ops/agents/$agent_name/CONTEXT.md"
    CONTEXT_CONTENT=$(git show "origin/$branch:$CONTEXT_FILE" 2>/dev/null || echo "")

    if [ -n "$CONTEXT_CONTENT" ]; then
      # Extract info from CONTEXT.md
      STATUS=$(echo "$CONTEXT_CONTENT" | grep "^\*\*Status\*\*:" | head -1 | sed 's/\*\*Status\*\*:[[:space:]]*//' || echo "Unknown")
      LAST_UPDATED=$(echo "$CONTEXT_CONTENT" | grep "^\*\*Last Updated\*\*:" | head -1 | sed 's/\*\*Last Updated\*\*:[[:space:]]*//' || echo "Unknown")
      PRODUCT_BRANCH_REMOTE=$(echo "$CONTEXT_CONTENT" | grep "^\*\*Product Branch\*\*:" | head -1 | sed 's/\*\*Product Branch\*\*:[[:space:]]*//' || echo "Unknown")

      # Extract WIP items
      WIP_ITEMS=$(echo "$CONTEXT_CONTENT" | awk '/^## Work In Progress/,/^## Completed/ {if ($0 ~ /^- /) print}' || echo "")

      echo -e "  ${BOLD}Status:${NC} $STATUS"
      echo -e "  ${BOLD}Last Updated:${NC} $LAST_UPDATED"
      if [ "$PRODUCT_BRANCH_REMOTE" != "Unknown" ]; then
        echo -e "  ${BOLD}Product Branch:${NC} $PRODUCT_BRANCH_REMOTE"
      fi

      if [ -n "$WIP_ITEMS" ]; then
        echo -e "  ${BOLD}Work In Progress:${NC}"
        echo "$WIP_ITEMS" | sed 's/^/    /'
      else
        echo -e "  ${BOLD}Work In Progress:${NC} None"
      fi
    else
      echo -e "  ${YELLOW}No CONTEXT.md found${NC}"
    fi

    echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"
    echo ""

  done <<< "$AGENT_BRANCHES"
fi

# Check for orphaned worktrees
echo -e "${BOLD}${CYAN}═══ Worktree Status ═══${NC}"
echo ""

WORKTREES=$(git worktree list --porcelain | grep "^worktree " | sed 's/^worktree //' | tail -n +2 || echo "")

if [ -n "$WORKTREES" ]; then
  echo -e "${YELLOW}Found additional worktrees:${NC}"
  echo ""

  while IFS= read -r worktree_path; do
    [ -z "$worktree_path" ] && continue
    [ "$worktree_path" == "$PROJECT_ROOT" ] && continue  # Skip main worktree

    worktree_name=$(basename "$worktree_path")

    # Get branch for this worktree
    branch=$(git -C "$worktree_path" branch --show-current 2>/dev/null || echo "unknown")

    # Check if branch is merged
    merged_status=""
    if git branch --merged main | grep -q "$branch" 2>/dev/null; then
      merged_status="${GREEN}(merged)${NC}"
    elif git show-ref --verify --quiet "refs/heads/$branch" || git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      merged_status="${YELLOW}(not merged)${NC}"
    else
      merged_status="${RED}(branch deleted!)${NC}"
    fi

    echo -e "  ${BOLD}Worktree:${NC} $worktree_path"
    echo -e "  ${BOLD}Branch:${NC} $branch $merged_status"

    # Check if this matches a known agent
    if [[ "$branch" == claude/* ]]; then
      agent_match=$(echo "$branch" | sed 's|claude/||')
      echo -e "  ${BOLD}Type:${NC} Agent worktree (${agent_match})"
    else
      echo -e "  ${BOLD}Type:${NC} Other worktree"
    fi

    echo ""
  done <<< "$WORKTREES"

  echo -e "${CYAN}Tip: Run ./agent-ops/scripts/detect-orphaned-worktrees.sh to clean up${NC}"
  echo ""
else
  echo -e "${GREEN}No additional worktrees found.${NC}"
  echo ""
fi

# Summary
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
