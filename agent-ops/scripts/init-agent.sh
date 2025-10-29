#!/bin/bash
# Initialize agent configuration for this session
# Run once per session - generates agent name and worktree path

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Helper: Detect session state
detect_session_state() {
  local config_file=$1

  if [ ! -f "$config_file" ]; then
    echo "none"
    return
  fi

  # Read PID if available
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
      echo "active"  # Process alive, recent activity (<10min)
    else
      echo "active_idle"  # Process alive but no recent activity
    fi
  else
    if [ "$has_heartbeat" = true ] && [ "$heartbeat_age" -lt 3600 ]; then
      echo "recently_abandoned"  # Process dead, recent activity (<1hr)
    else
      echo "stale_abandoned"  # Process dead, old activity (>1hr) or no heartbeat
    fi
  fi
}

# Get product branch
PRODUCT_BRANCH=$(git branch --show-current)

# Extract session ID from product branch (pattern: digits followed by letters)
SESSION_ID=$(echo "$PRODUCT_BRANCH" | grep -oP '\d+[A-Za-z]+$' || echo "")

if [ -z "$SESSION_ID" ]; then
  # No session ID in branch name - generate one from branch name hash
  echo "No session ID found in branch: $PRODUCT_BRANCH"
  echo "Generating session ID from branch name..."
  BRANCH_HASH=$(echo -n "$PRODUCT_BRANCH" | md5sum | grep -oP '^[0-9a-f]+')
  SESSION_ID="${BRANCH_HASH:0:6}"  # Use first 6 hex chars as session ID
  echo "Generated session ID: $SESSION_ID"
fi

# Generate deterministic agent name
NAMES=(anvil axle bearing bellows bolt cam clamp clutch crank drill flywheel forge fulcrum gear hammer hinge hoist jack lathe lever motor piston pulley pump ratchet rivet rotor saw spindle spring sprocket turbine valve vise wedge wheel winch wrench)
HASH=$(echo -n "$SESSION_ID" | md5sum | grep -oP '^[0-9a-f]+')
INDEX=$((0x${HASH:0:8} % ${#NAMES[@]}))
AGENT_NAME=${NAMES[$INDEX]}

# Define paths
REPO_ROOT=$(git rev-parse --show-toplevel)
CONFIG_FILE="$REPO_ROOT/untracked-notes/agent-ops.json"
WORKTREE_PATH="$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-$AGENT_NAME"
AGENT_BRANCH="claude/$AGENT_NAME"

# Ensure config directory exists
mkdir -p "$REPO_ROOT/untracked-notes"

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
  EXISTING_NAME=$(jq -r '.agent_name' "$CONFIG_FILE" 2>/dev/null || echo "")

  # Detect current session state
  STATE=$(detect_session_state "$CONFIG_FILE")

  if [ "$EXISTING_NAME" == "$AGENT_NAME" ]; then
    # Same agent - check state
    case "$STATE" in
      active)
        echo -e "${GREEN}✓ Agent already initialized: $AGENT_NAME${NC}"
        echo -e "${GREEN}  Status: ACTIVE (process running, recent activity)${NC}"
        echo "  Config: $CONFIG_FILE"
        exit 0
        ;;
      active_idle)
        echo -e "${YELLOW}⚠ Agent already initialized: $AGENT_NAME${NC}"
        echo -e "${YELLOW}  Status: ACTIVE but IDLE (no recent work logged)${NC}"
        echo "  Config: $CONFIG_FILE"
        echo ""
        echo "  This may indicate:"
        echo "    - Agent paused/waiting for input"
        echo "    - Agent process still running but not actively working"
        echo ""
        exit 0
        ;;
      recently_abandoned|stale_abandoned)
        echo -e "${RED}⚠ Agent session appears abandoned: $AGENT_NAME${NC}"
        echo -e "${RED}  Status: ${STATE}${NC}"
        echo "  Config: $CONFIG_FILE"
        echo ""
        echo "  Options:"
        echo "    1. Continue anyway (creates new session, clears old state)"
        echo "    2. Clean up abandoned session first: ./agent-ops/scripts/cleanup-abandoned.sh"
        echo "    3. Check for incomplete work: cat agent-ops/sessions/*/diary.md"
        echo ""
        read -p "Continue with new session? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "Aborted. Please clean up abandoned session first."
          exit 1
        fi
        echo "Continuing... (will overwrite abandoned session state)"
        ;;
    esac
  else
    echo -e "${YELLOW}Warning: Existing agent config found with different name: $EXISTING_NAME${NC}"
    echo -e "${YELLOW}  Old agent: $EXISTING_NAME${NC}"
    echo -e "${YELLOW}  New agent: $AGENT_NAME${NC}"
    echo -e "${YELLOW}  State: $STATE${NC}"
    echo ""
    echo "This usually means you switched branches."
    echo "Overwriting with new agent configuration..."
  fi
fi

# Get parent process ID (Claude Code process)
AGENT_PID=$PPID

# Write config file
cat > "$CONFIG_FILE" <<EOF
{
  "agent_name": "$AGENT_NAME",
  "agent_branch": "$AGENT_BRANCH",
  "worktree_path": "$WORKTREE_PATH",
  "product_branch": "$PRODUCT_BRANCH",
  "session_id": "$SESSION_ID",
  "initialized_at": "$(date -Iseconds)",
  "status": "active",
  "pid": $AGENT_PID,
  "last_heartbeat": "$(date -Iseconds)"
}
EOF

# Write PID file
PID_FILE="${CONFIG_FILE%.json}.pid"
echo "$AGENT_PID" > "$PID_FILE"

# Write initial heartbeat
HEARTBEAT_FILE="${CONFIG_FILE%.json}-heartbeat"
date -Iseconds > "$HEARTBEAT_FILE"

echo -e "${GREEN}✓ Agent initialized: $AGENT_NAME${NC}"
echo "  Config: $CONFIG_FILE"
echo "  Branch: $AGENT_BRANCH"
echo "  Worktree: $WORKTREE_PATH"
echo "  PID: $AGENT_PID"
echo ""
echo -e "${CYAN}Session tracking active. Files created:${NC}"
echo "  - $CONFIG_FILE (agent config)"
echo "  - $PID_FILE (process tracking)"
echo "  - $HEARTBEAT_FILE (activity tracking)"
