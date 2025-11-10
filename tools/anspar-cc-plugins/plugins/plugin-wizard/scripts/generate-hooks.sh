#!/bin/bash
# Generate hook scripts based on agent's hook knowledge

set -e

# Parse arguments
PLUGIN_PATH=""
HOOKS_JSON=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --plugin-path=*)
      PLUGIN_PATH="${1#*=}"
      shift
      ;;
    --hooks-json=*)
      HOOKS_JSON="${1#*=}"
      shift
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Validate arguments
if [ -z "$PLUGIN_PATH" ]; then
  echo "ERROR: --plugin-path required" >&2
  exit 1
fi

if [ -z "$HOOKS_JSON" ]; then
  echo "ERROR: --hooks-json required" >&2
  exit 1
fi

if [ ! -d "$PLUGIN_PATH" ]; then
  echo "ERROR: Plugin directory not found: $PLUGIN_PATH" >&2
  exit 1
fi

# Parse JSON
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required for parsing hooks JSON" >&2
  exit 1
fi

HOOKS_COUNT=$(echo "$HOOKS_JSON" | jq 'length')

if [ "$HOOKS_COUNT" -eq 0 ]; then
  echo "No hooks to generate"
  exit 0
fi

echo "Generating $HOOKS_COUNT hook(s)..."

# Read plugin.json
PLUGIN_JSON_PATH="$PLUGIN_PATH/.claude-plugin/plugin.json"
PLUGIN_JSON=$(cat "$PLUGIN_JSON_PATH")

# Initialize hooks object if empty
PLUGIN_JSON=$(echo "$PLUGIN_JSON" | jq '.hooks = {}')

# Generate each hook
for i in $(seq 0 $((HOOKS_COUNT - 1))); do
  HOOK=$(echo "$HOOKS_JSON" | jq -r ".[$i]")
  HOOK_TYPE=$(echo "$HOOK" | jq -r '.type')
  HOOK_DESC=$(echo "$HOOK" | jq -r '.description')

  echo "  Creating hook: $HOOK_TYPE"

  # Convert hook type to filename (SessionStart -> session-start)
  HOOK_FILE_NAME=$(echo "$HOOK_TYPE" | sed 's/\([A-Z]\)/-\L\1/g' | sed 's/^-//')
  HOOK_FILE="$PLUGIN_PATH/hooks/$HOOK_FILE_NAME"

  # Create hook script based on type
  case $HOOK_TYPE in
    SessionStart)
      cat > "$HOOK_FILE" <<'EOF'
#!/bin/bash
# SessionStart hook: HOOK_DESC_PLACEHOLDER

# Check required environment variables
# if [ -z "$REQUIRED_VAR" ]; then
#   echo "⚠️  Plugin requires REQUIRED_VAR environment variable" >&2
#   exit 0  # Non-blocking warning
# fi

echo "📦 Plugin loaded: PLUGIN_NAME_PLACEHOLDER"
exit 0
EOF
      ;;

    UserPromptSubmit)
      cat > "$HOOK_FILE" <<'EOF'
#!/bin/bash
# UserPromptSubmit hook: HOOK_DESC_PLACEHOLDER

# Read user prompt from stdin
USER_PROMPT=$(cat)

# TODO: Detect relevant patterns and provide proactive guidance
# Example:
# if echo "$USER_PROMPT" | grep -qi "pattern"; then
#   echo "💡 TIP: Consider using /command instead" >&2
# fi

exit 0  # Always non-blocking
EOF
      ;;

    PreToolUse)
      cat > "$HOOK_FILE" <<'EOF'
#!/bin/bash
# PreToolUse hook: HOOK_DESC_PLACEHOLDER

TOOL_NAME="$CLAUDE_TOOL_NAME"

# TODO: Validate preconditions before tool use
# Example: Block Write/Edit if preconditions not met
# if [[ "$TOOL_NAME" =~ ^(Write|Edit)$ ]]; then
#   if [ ! -f .required-file ]; then
#     echo "❌ ERROR: Required precondition not met" >&2
#     exit 1  # Block operation
#   fi
# fi

exit 0  # Allow operation
EOF
      ;;

    PostToolUse)
      cat > "$HOOK_FILE" <<'EOF'
#!/bin/bash
# PostToolUse hook: HOOK_DESC_PLACEHOLDER

TOOL_NAME="$CLAUDE_TOOL_NAME"

# TODO: Provide guidance after tool use
# Example: Suggest next steps after git commit
# if [[ "$TOOL_NAME" == "Bash" ]] && echo "$CLAUDE_TOOL_INPUT" | grep -q "git commit"; then
#   echo "💡 Next: Consider running tests or creating a PR" >&2
# fi

exit 0  # Always non-blocking
EOF
      ;;

    *)
      echo "  WARNING: Unknown hook type: $HOOK_TYPE (creating generic hook)"
      cat > "$HOOK_FILE" <<'EOF'
#!/bin/bash
# HOOK_TYPE_PLACEHOLDER hook: HOOK_DESC_PLACEHOLDER

# TODO: Implement hook logic

exit 0
EOF
      ;;
  esac

  # Replace placeholders
  sed -i "s/HOOK_DESC_PLACEHOLDER/$HOOK_DESC/g" "$HOOK_FILE"
  sed -i "s/HOOK_TYPE_PLACEHOLDER/$HOOK_TYPE/g" "$HOOK_FILE"

  # Get plugin name from plugin.json
  PLUGIN_NAME=$(echo "$PLUGIN_JSON" | jq -r '.name')
  sed -i "s/PLUGIN_NAME_PLACEHOLDER/$PLUGIN_NAME/g" "$HOOK_FILE"

  chmod +x "$HOOK_FILE"

  # Update plugin.json hooks section
  # Note: This is a simplified version. Real implementation should handle hook matchers properly.
  BLOCKING="false"
  if [ "$HOOK_TYPE" = "PreToolUse" ]; then
    BLOCKING="true"
  fi

  PLUGIN_JSON=$(echo "$PLUGIN_JSON" | jq ".hooks[\"$HOOK_TYPE\"] += [{
    \"hooks\": [{
      \"type\": \"command\",
      \"command\": \"\${CLAUDE_PLUGIN_ROOT}/hooks/$HOOK_FILE_NAME\",
      \"blocking\": $BLOCKING,
      \"timeout\": 5000
    }]
  }]")
done

# Write updated plugin.json
echo "$PLUGIN_JSON" | jq '.' > "$PLUGIN_JSON_PATH"

echo ""
echo "Generated $HOOKS_COUNT hook(s) successfully"
echo "Updated plugin.json with hook definitions"
