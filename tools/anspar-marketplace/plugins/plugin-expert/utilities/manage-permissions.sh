#!/bin/bash
# =====================================================
# manage-permissions.sh
# =====================================================
#
# Manages Claude Code permissions for a specific plugin
# Tracks which plugin added which permission to enable
# safe addition and removal.
#
# Usage:
#   ./manage-permissions.sh add <plugin-name> <permissions-file>
#   ./manage-permissions.sh remove <plugin-name>
#
# =====================================================

set -euo pipefail

# Locations
SETTINGS_FILE="./.claude/settings.local.json"
REGISTRY_FILE="./.claude/permissions-registry.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Usage
usage() {
    cat <<EOF
Usage: $0 <command> <plugin-name> [permissions-file]

Commands:
  add <plugin-name> <permissions-file>    Add permissions for plugin
  remove <plugin-name>                     Remove permissions for plugin
  list                                     List all registered permissions

Examples:
  $0 add plugin-expert ./.claude-plugin/permissions.json
  $0 remove plugin-expert
  $0 list

EOF
    exit 1
}

# Check jq availability
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}ERROR: jq is required but not installed${NC}"
        echo "Install jq:"
        echo "  - Ubuntu/Debian: sudo apt-get install jq"
        echo "  - macOS: brew install jq"
        exit 1
    fi
}

# Initialize settings file if needed
init_settings() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo "Creating $SETTINGS_FILE..."
        mkdir -p "$(dirname "$SETTINGS_FILE")"
        cat > "$SETTINGS_FILE" <<'EOF'
{
  "permissions": {
    "allow": [],
    "deny": [],
    "ask": []
  }
}
EOF
    fi

    # Ensure permissions structure exists
    if ! jq -e '.permissions.allow' "$SETTINGS_FILE" >/dev/null 2>&1; then
        jq '. + {"permissions": {"allow": [], "deny": [], "ask": []}}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
}

# Initialize registry file if needed
init_registry() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo "Creating permissions registry..."
        mkdir -p "$(dirname "$REGISTRY_FILE")"
        echo '{"plugins": {}}' > "$REGISTRY_FILE"
    fi
}

# Add permissions for a plugin
add_permissions() {
    local plugin_name="$1"
    local permissions_file="$2"

    if [[ ! -f "$permissions_file" ]]; then
        echo -e "${RED}ERROR: Permissions file not found: $permissions_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}Adding permissions for: $plugin_name${NC}"
    echo

    # Read permissions from plugin's permissions.json
    local permissions
    permissions=$(jq -r '.permissions.allow[].pattern' "$permissions_file")

    if [[ -z "$permissions" ]]; then
        echo -e "${YELLOW}No permissions defined in $permissions_file${NC}"
        return 0
    fi

    local added_count=0
    local skipped_count=0

    while IFS= read -r permission; do
        # Check if permission already exists in settings
        if jq -e --arg perm "$permission" '.permissions.allow | index($perm)' "$SETTINGS_FILE" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $permission (already present)"
            skipped_count=$((skipped_count + 1))
        else
            # Add permission to settings
            jq --arg perm "$permission" '.permissions.allow += [$perm]' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo -e "  ${GREEN}+${NC} $permission (added)"
            added_count=$((added_count + 1))
        fi
    done <<< "$permissions"

    # Register plugin permissions in registry
    while IFS= read -r permission; do
        jq --arg plugin "$plugin_name" \
           --arg perm "$permission" \
           '.plugins[$plugin] = (.plugins[$plugin] // []) | .plugins[$plugin] += [$perm] | .plugins[$plugin] |= unique' \
           "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"
        mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
    done <<< "$permissions"

    echo
    if [[ $added_count -gt 0 ]]; then
        echo -e "${GREEN}✓ Added $added_count new permission(s) for $plugin_name${NC}"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "${BLUE}ℹ $skipped_count permission(s) already present${NC}"
    fi
    echo
}

# Remove permissions for a plugin
remove_permissions() {
    local plugin_name="$1"

    echo -e "${BLUE}Removing permissions for: $plugin_name${NC}"
    echo

    # Check if plugin is registered
    if ! jq -e --arg plugin "$plugin_name" '.plugins[$plugin]' "$REGISTRY_FILE" >/dev/null 2>&1; then
        echo -e "${YELLOW}Plugin $plugin_name not found in registry${NC}"
        return 0
    fi

    # Get plugin's permissions
    local permissions
    permissions=$(jq -r --arg plugin "$plugin_name" '.plugins[$plugin][]' "$REGISTRY_FILE")

    local removed_count=0
    local kept_count=0

    while IFS= read -r permission; do
        # Check if any other plugin also uses this permission
        local other_users
        other_users=$(jq -r --arg plugin "$plugin_name" --arg perm "$permission" \
            '.plugins | to_entries[] | select(.key != $plugin and (.value | index($perm))) | .key' \
            "$REGISTRY_FILE")

        if [[ -n "$other_users" ]]; then
            echo -e "  ${BLUE}→${NC} $permission (kept - used by: $other_users)"
            kept_count=$((kept_count + 1))
        else
            # Remove from settings (safe if not present)
            jq --arg perm "$permission" '.permissions.allow -= [$perm]' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
            mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
            echo -e "  ${GREEN}−${NC} $permission (removed)"
            removed_count=$((removed_count + 1))
        fi
    done <<< "$permissions"

    # Remove plugin from registry
    jq --arg plugin "$plugin_name" 'del(.plugins[$plugin])' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp"
    mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

    echo
    if [[ $removed_count -gt 0 ]]; then
        echo -e "${GREEN}✓ Removed $removed_count permission(s)${NC}"
    fi
    if [[ $kept_count -gt 0 ]]; then
        echo -e "${BLUE}ℹ Kept $kept_count shared permission(s)${NC}"
    fi
    echo
}

# List all registered permissions
list_permissions() {
    echo -e "${BLUE}Registered plugin permissions:${NC}"
    echo

    if ! jq -e '.plugins | length > 0' "$REGISTRY_FILE" >/dev/null 2>&1; then
        echo "No plugins registered"
        return 0
    fi

    jq -r '.plugins | to_entries[] | "\(.key):\n" + (.value[] | "  - \(.)") + "\n"' "$REGISTRY_FILE"
}

# Main
main() {
    check_jq
    init_settings
    init_registry

    local command="${1:-}"

    case "$command" in
        add)
            if [[ $# -ne 3 ]]; then
                usage
            fi
            add_permissions "$2" "$3"
            ;;
        remove)
            if [[ $# -ne 2 ]]; then
                usage
            fi
            remove_permissions "$2"
            ;;
        list)
            list_permissions
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
