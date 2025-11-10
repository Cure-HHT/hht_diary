#!/bin/bash
# Generate skill wrappers and implementation scripts from analysis

set -e

# Parse arguments
PLUGIN_PATH=""
SKILLS_JSON=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --plugin-path=*)
      PLUGIN_PATH="${1#*=}"
      shift
      ;;
    --skills-json=*)
      SKILLS_JSON="${1#*=}"
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

if [ -z "$SKILLS_JSON" ]; then
  echo "ERROR: --skills-json required" >&2
  exit 1
fi

if [ ! -d "$PLUGIN_PATH" ]; then
  echo "ERROR: Plugin directory not found: $PLUGIN_PATH" >&2
  exit 1
fi

# Parse JSON (using jq if available, otherwise basic parsing)
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required for parsing skills JSON" >&2
  exit 1
fi

SKILLS_COUNT=$(echo "$SKILLS_JSON" | jq 'length')

if [ "$SKILLS_COUNT" -eq 0 ]; then
  echo "No skills to generate"
  exit 0
fi

echo "Generating $SKILLS_COUNT skill(s)..."

# Read plugin.json
PLUGIN_JSON_PATH="$PLUGIN_PATH/.claude-plugin/plugin.json"
PLUGIN_JSON=$(cat "$PLUGIN_JSON_PATH")

# Generate each skill
for i in $(seq 0 $((SKILLS_COUNT - 1))); do
  SKILL=$(echo "$SKILLS_JSON" | jq -r ".[$i]")
  SKILL_NAME=$(echo "$SKILL" | jq -r '.name')
  SKILL_DESC=$(echo "$SKILL" | jq -r '.description')

  echo "  Creating skill: $SKILL_NAME"

  # Create skill wrapper
  SKILL_FILE="$PLUGIN_PATH/skills/$SKILL_NAME.skill"
  cat > "$SKILL_FILE" <<EOF
#!/bin/bash
# $SKILL_DESC

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
bash "\$SCRIPT_DIR/scripts/$SKILL_NAME.sh" "\$@"
EOF

  chmod +x "$SKILL_FILE"

  # Create implementation script
  SCRIPT_FILE="$PLUGIN_PATH/scripts/$SKILL_NAME.sh"
  cat > "$SCRIPT_FILE" <<'SCRIPT_EOF'
#!/bin/bash
# Implementation for SKILL_NAME_PLACEHOLDER skill
# SKILL_DESC_PLACEHOLDER

set -e

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      echo "Usage: SCRIPT_NAME_PLACEHOLDER.sh [OPTIONS]"
      echo ""
      echo "SKILL_DESC_PLACEHOLDER"
      echo ""
      echo "Options:"
      echo "  --help    Show this help message"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
  shift
done

# TODO: Implement skill logic here
echo "TODO: Implement $SKILL_NAME skill"
exit 1
SCRIPT_EOF

  # Replace placeholders
  sed -i "s/SKILL_NAME_PLACEHOLDER/$SKILL_NAME/g" "$SCRIPT_FILE"
  sed -i "s/SKILL_DESC_PLACEHOLDER/$SKILL_DESC/g" "$SCRIPT_FILE"
  sed -i "s/SCRIPT_NAME_PLACEHOLDER/$SKILL_NAME/g" "$SCRIPT_FILE"

  chmod +x "$SCRIPT_FILE"

  # Update plugin.json to include skill
  PLUGIN_JSON=$(echo "$PLUGIN_JSON" | jq ".skills += [{\"name\": \"$SKILL_NAME\", \"path\": \"skills/$SKILL_NAME.skill\"}]")
done

# Write updated plugin.json
echo "$PLUGIN_JSON" | jq '.' > "$PLUGIN_JSON_PATH"

echo ""
echo "Generated $SKILLS_COUNT skill(s) successfully"
echo "Updated plugin.json with skill definitions"
