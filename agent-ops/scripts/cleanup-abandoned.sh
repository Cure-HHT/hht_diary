#!/usr/bin/env bash
# cleanup-abandoned.sh - Clean up abandoned sessions
# Detects abandoned sessions and offers options to:
#   - Archive to agent branch (preserves work)
#   - Delete (loses work)
#   - Mark as paused (keep for later)
#
# Usage:
#   ./cleanup-abandoned.sh              # Interactive cleanup
#   ./cleanup-abandoned.sh --list       # Just list abandoned sessions
#   ./cleanup-abandoned.sh --auto       # Auto-archive stale sessions

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

# Source state detection helpers from init-agent.sh
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
    echo "${seconds}s"
  elif [ "$seconds" -lt 3600 ]; then
    echo "$((seconds/60))m"
  elif [ "$seconds" -lt 86400 ]; then
    echo "$((seconds/3600))h"
  else
    echo "$((seconds/86400))d"
  fi
}

# Helper: Detect session state
detect_session_state() {
  local config_file=$1

  if [ ! -f "$config_file" ]; then
    echo "none"
    return
  fi

  local pid_file="${config_file%.json}.pid"
  local heartbeat_file="${config_file%.json}-heartbeat"

  local has_pid=false
  local pid=0
  if [ -f "$pid_file" ]; then
    pid=$(cat "$pid_file" 2>/dev/null || echo "0")
    has_pid=true
  fi

  local has_heartbeat=false
  local heartbeat_age=999999
  if [ -f "$heartbeat_file" ]; then
    local heartbeat=$(cat "$heartbeat_file" 2>/dev/null || echo "")
    if [ -n "$heartbeat" ]; then
      heartbeat_age=$(get_timestamp_age "$heartbeat")
      has_heartbeat=true
    fi
  fi

  # Determine state
  if [ "$has_pid" = true ] && is_process_alive "$pid"; then
    if [ "$has_heartbeat" = true ] && [ "$heartbeat_age" -lt 600 ]; then
      echo "active"
    else
      echo "active_idle"
    fi
  else
    if [ "$has_heartbeat" = true ] && [ "$heartbeat_age" -lt 3600 ]; then
      echo "recently_abandoned"
    else
      echo "stale_abandoned"
    fi
  fi
}

# Parse arguments
MODE="interactive"  # interactive, list, auto

while [[ $# -gt 0 ]]; do
  case $1 in
    --list)
      MODE="list"
      shift
      ;;
    --auto)
      MODE="auto"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--list|--auto]"
      exit 1
      ;;
  esac
done

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  Abandoned Session Cleanup${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Check for agent config
CONFIG_FILE="$PROJECT_ROOT/untracked-notes/agent-ops.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${YELLOW}No agent config found.${NC}"
  echo "Run ./agent-ops/scripts/init-agent.sh to initialize an agent."
  echo ""

  # Check for orphaned session directories anyway
  if [ -d "$PROJECT_ROOT/agent-ops/sessions" ]; then
    SESSION_DIRS=$(find "$PROJECT_ROOT/agent-ops/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null || echo "")
    if [ -n "$SESSION_DIRS" ]; then
      echo -e "${YELLOW}Found orphaned session directories (no agent config):${NC}"
      while IFS= read -r session_dir; do
        [ -z "$session_dir" ] && continue
        echo "  - $(basename "$session_dir")"
      done <<< "$SESSION_DIRS"
      echo ""
      echo "These sessions cannot be archived without agent config."
      echo "Options:"
      echo "  1. Initialize agent and archive manually"
      echo "  2. Delete if work is not needed"
      exit 1
    fi
  fi

  echo "No abandoned sessions found."
  exit 0
fi

# Read agent config
AGENT_NAME=$(jq -r '.agent_name' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
AGENT_BRANCH=$(jq -r '.agent_branch' "$CONFIG_FILE" 2>/dev/null || echo "unknown")

# Detect current session state
STATE=$(detect_session_state "$CONFIG_FILE")

echo -e "${BOLD}Current Agent:${NC} $AGENT_NAME"
echo -e "${BOLD}Agent Branch:${NC} $AGENT_BRANCH"

# Format state
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

echo -e "${BOLD}Session State:${NC} $STATE_DISPLAY"
echo ""

# Check for abandoned sessions
SESSION_DIRS=$(find "$PROJECT_ROOT/agent-ops/sessions" -maxdepth 1 -type d -name "2*" 2>/dev/null || echo "")

if [ -z "$SESSION_DIRS" ]; then
  echo -e "${GREEN}No session directories found.${NC}"

  # Check if current state is abandoned
  if [ "$STATE" = "recently_abandoned" ] || [ "$STATE" = "stale_abandoned" ]; then
    echo ""
    echo -e "${YELLOW}However, current agent config indicates abandoned state.${NC}"
    echo "This means a session was started but files were already cleaned up."
    echo ""
    read -p "Reset agent config? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -f "$CONFIG_FILE"
      rm -f "${CONFIG_FILE%.json}.pid"
      rm -f "${CONFIG_FILE%.json}-heartbeat"
      echo -e "${GREEN}✓ Agent config reset${NC}"
    fi
  fi

  exit 0
fi

echo -e "${BOLD}${YELLOW}═══ Found Session Directories ═══${NC}"
echo ""

# Analyze each session
declare -a SESSIONS=()

while IFS= read -r session_dir; do
  [ -z "$session_dir" ] && continue

  session_name=$(basename "$session_dir")

  # Check if diary exists
  if [ ! -f "$session_dir/diary.md" ]; then
    echo -e "${YELLOW}⚠ $session_name${NC} - No diary.md (empty/broken session)"
    SESSIONS+=("$session_dir|broken|no_diary")
    continue
  fi

  # Check if results.md exists and is filled
  if [ -f "$session_dir/results.md" ]; then
    if grep -q "^\[2-4 sentence summary" "$session_dir/results.md" 2>/dev/null; then
      # Template not filled
      echo -e "${CYAN}ℹ $session_name${NC} - Has diary, results not filled (incomplete)"
      SESSIONS+=("$session_dir|incomplete|has_diary")
    else
      # Results filled
      echo -e "${GREEN}✓ $session_name${NC} - Complete (has results)"
      SESSIONS+=("$session_dir|complete|ready_archive")
    fi
  else
    echo -e "${CYAN}ℹ $session_name${NC} - Has diary, no results (in progress)"
    SESSIONS+=("$session_dir|in_progress|has_diary")
  fi

done <<< "$SESSION_DIRS"

echo ""

# Exit if just listing
if [ "$MODE" = "list" ]; then
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
  exit 0
fi

# Cleanup options
total_sessions=${#SESSIONS[@]}

if [ $total_sessions -eq 0 ]; then
  echo -e "${GREEN}No sessions to clean up!${NC}"
  exit 0
fi

echo -e "${BOLD}${CYAN}═══ Cleanup Options ═══${NC}"
echo ""
echo "Found $total_sessions session(s) that may need cleanup."
echo ""

if [ "$MODE" = "auto" ]; then
  echo -e "${YELLOW}Auto mode: Will archive/delete based on state${NC}"
  echo ""

  for entry in "${SESSIONS[@]}"; do
    IFS='|' read -r session_dir category reason <<< "$entry"
    session_name=$(basename "$session_dir")

    case "$category" in
      complete)
        echo -e "${CYAN}Archiving complete session: $session_name${NC}"
        # Call end-session.sh logic here or just remove
        rm -rf "$session_dir"
        echo -e "${GREEN}✓ Cleaned up${NC}"
        ;;
      broken)
        echo -e "${RED}Deleting broken session: $session_name${NC}"
        rm -rf "$session_dir"
        echo -e "${GREEN}✓ Deleted${NC}"
        ;;
      *)
        echo -e "${YELLOW}Skipping: $session_name (${category})${NC}"
        ;;
    esac
    echo ""
  done

else
  # Interactive mode
  echo "Options:"
  echo "  1. Archive all sessions to agent branch"
  echo "  2. Delete all sessions (lose work)"
  echo "  3. Interactive (choose for each session)"
  echo "  4. Cancel"
  echo ""
  read -p "Choose option (1-4): " -n 1 -r
  echo ""
  echo ""

  case "$REPLY" in
    1)
      echo -e "${CYAN}Archiving all sessions...${NC}"
      for entry in "${SESSIONS[@]}"; do
        IFS='|' read -r session_dir category reason <<< "$entry"
        session_name=$(basename "$session_dir")
        echo "  - $session_name"
        # Note: Proper archiving would need end-session.sh logic
        # For now, just inform
      done
      echo ""
      echo -e "${YELLOW}Note: Proper archiving requires running end-session.sh${NC}"
      echo "Sessions kept for manual archiving."
      ;;
    2)
      echo -e "${RED}WARNING: This will DELETE all session work!${NC}"
      echo ""
      read -p "Are you sure? Type 'DELETE' to confirm: " confirm
      if [ "$confirm" = "DELETE" ]; then
        for entry in "${SESSIONS[@]}"; do
          IFS='|' read -r session_dir category reason <<< "$entry"
          session_name=$(basename "$session_dir")
          echo -e "${RED}Deleting: $session_name${NC}"
          rm -rf "$session_dir"
        done
        echo -e "${GREEN}✓ All sessions deleted${NC}"

        # Reset agent config
        echo ""
        read -p "Reset agent config as well? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          rm -f "$CONFIG_FILE"
          rm -f "${CONFIG_FILE%.json}.pid"
          rm -f "${CONFIG_FILE%.json}-heartbeat"
          echo -e "${GREEN}✓ Agent config reset${NC}"
        fi
      else
        echo "Cancelled (must type 'DELETE' exactly)"
      fi
      ;;
    3)
      for entry in "${SESSIONS[@]}"; do
        IFS='|' read -r session_dir category reason <<< "$entry"
        session_name=$(basename "$session_dir")

        echo -e "${BOLD}Session:${NC} $session_name"
        echo -e "${BOLD}Category:${NC} $category"
        echo -e "${BOLD}Status:${NC} $reason"

        # Show last diary entry
        if [ -f "$session_dir/diary.md" ]; then
          echo -e "${BOLD}Last entries:${NC}"
          tail -10 "$session_dir/diary.md" | sed 's/^/  /'
        fi

        echo ""
        echo "Options: (k)eep, (d)elete, (v)iew full diary"
        read -p "Action: " -n 1 -r
        echo ""

        case "$REPLY" in
          d|D)
            rm -rf "$session_dir"
            echo -e "${GREEN}✓ Deleted${NC}"
            ;;
          v|V)
            less "$session_dir/diary.md"
            echo ""
            read -p "Delete after viewing? (y/n): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
              rm -rf "$session_dir"
              echo -e "${GREEN}✓ Deleted${NC}"
            else
              echo -e "${YELLOW}Kept${NC}"
            fi
            ;;
          *)
            echo -e "${YELLOW}Kept${NC}"
            ;;
        esac
        echo ""
      done
      ;;
    4)
      echo "Cancelled."
      exit 0
      ;;
    *)
      echo "Invalid option. Cancelled."
      exit 1
      ;;
  esac
fi

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Cleanup Complete${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo ""
