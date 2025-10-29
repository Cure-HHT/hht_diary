#!/bin/bash
# Initialize agent configuration for this session
# Run once per session - generates agent name and worktree path

set -e

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
  if [ "$EXISTING_NAME" == "$AGENT_NAME" ]; then
    echo "Agent already initialized: $AGENT_NAME"
    echo "Config: $CONFIG_FILE"
    exit 0
  else
    echo "Warning: Existing agent config found with different name: $EXISTING_NAME"
    echo "Overwriting with new agent: $AGENT_NAME"
  fi
fi

# Write config file
cat > "$CONFIG_FILE" <<EOF
{
  "agent_name": "$AGENT_NAME",
  "agent_branch": "$AGENT_BRANCH",
  "worktree_path": "$WORKTREE_PATH",
  "product_branch": "$PRODUCT_BRANCH",
  "session_id": "$SESSION_ID",
  "initialized_at": "$(date -Iseconds)"
}
EOF

echo "✓ Agent initialized: $AGENT_NAME"
echo "  Config: $CONFIG_FILE"
echo "  Branch: $AGENT_BRANCH"
echo "  Worktree: $WORKTREE_PATH"
