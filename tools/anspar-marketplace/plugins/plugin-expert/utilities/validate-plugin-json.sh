#!/bin/bash
# JSON Validation Utility for Claude Code Plugins
#
# Validates plugin.json and hooks.json files against Claude Code schemas
# Provides clear error messages with fix suggestions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error tracking
ERRORS=0

# Usage information
usage() {
    cat <<EOF
Usage: $0 <json-file>

Validates Claude Code plugin JSON files against schemas.

Supported files:
  - plugin.json    (plugin metadata)
  - hooks.json     (hook configuration)

Examples:
  $0 .claude-plugin/plugin.json
  $0 hooks/hooks.json

Exit codes:
  0 - Validation passed
  1 - Validation failed (syntax or schema errors)
  2 - Usage error
EOF
    exit 2
}

# Print error message
error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
    ((ERRORS++))
}

# Print warning message
warn() {
    echo -e "${YELLOW}WARNING:${NC} $1" >&2
}

# Print success message
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Print info message
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Validate JSON syntax
validate_json_syntax() {
    local file="$1"

    if ! jq empty "$file" 2>/dev/null; then
        error "Invalid JSON syntax in $file"
        echo "Run: jq . $file to see detailed syntax errors"
        return 1
    fi

    success "JSON syntax is valid"
    return 0
}

# Validate plugin.json schema
validate_plugin_json() {
    local file="$1"
    local has_errors=0

    info "Validating plugin.json schema..."

    # Check required fields
    local required_fields=("name" "version" "description" "author")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$file" >/dev/null 2>&1; then
            error "Missing required field: $field"
            has_errors=1
        else
            success "Required field '$field' present"
        fi
    done

    # Validate name format (kebab-case, no vendor prefix)
    local name
    name=$(jq -r '.name // ""' "$file")
    if [[ -n "$name" ]]; then
        if [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
            success "Plugin name '$name' follows kebab-case convention"
        else
            error "Plugin name '$name' should be kebab-case (lowercase, hyphens only)"
            echo "  Example: my-plugin-name"
            has_errors=1
        fi

        # Check for vendor prefixes (common anti-pattern)
        if [[ "$name" =~ ^(anspar|claude|anthropic)- ]]; then
            warn "Plugin name has vendor prefix '$name' - consider removing it"
            echo "  Suggested: ${name#*-}"
        fi
    fi

    # Validate version format (semver)
    local version
    version=$(jq -r '.version // ""' "$file")
    if [[ -n "$version" ]]; then
        if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
            success "Version '$version' follows semver format"
        else
            error "Version '$version' should follow semver (e.g., 1.0.0, 1.2.3-beta.1)"
            has_errors=1
        fi
    fi

    # Validate author object
    if jq -e '.author' "$file" >/dev/null 2>&1; then
        if ! jq -e '.author.name' "$file" >/dev/null 2>&1; then
            error "Author object must have 'name' field"
            echo "  Example: {\"author\": {\"name\": \"Your Name\"}}"
            has_errors=1
        else
            success "Author object has required 'name' field"
        fi

        # Optional author.url
        if jq -e '.author.url' "$file" >/dev/null 2>&1; then
            local author_url
            author_url=$(jq -r '.author.url' "$file")
            if [[ "$author_url" =~ ^https?:// ]]; then
                success "Author URL is valid"
            else
                warn "Author URL should start with http:// or https://"
            fi
        fi
    fi

    # Validate optional fields
    if jq -e '.keywords' "$file" >/dev/null 2>&1; then
        if jq -e '.keywords | type == "array"' "$file" >/dev/null 2>&1; then
            local keyword_count
            keyword_count=$(jq '.keywords | length' "$file")
            success "Keywords field is array with $keyword_count entries"
        else
            error "Keywords field must be an array"
            has_errors=1
        fi
    fi

    # Validate component paths if present
    local components=("commands" "agents" "skills" "hooks")
    for component in "${components[@]}"; do
        if jq -e ".$component" "$file" >/dev/null 2>&1; then
            local comp_path
            comp_path=$(jq -r ".$component" "$file")
            success "Component '$component' points to: $comp_path"

            # Note: Path validation will be handled by separate tool (#28)
            info "Path validation will check if '$comp_path' exists"
        fi
    done

    # Validate optional URL fields
    for url_field in "repository" "homepage"; do
        if jq -e ".$url_field" "$file" >/dev/null 2>&1; then
            local url_value
            url_value=$(jq -r ".$url_field" "$file")
            if [[ "$url_value" =~ ^https?:// ]]; then
                success "$url_field URL is valid"
            else
                warn "$url_field should be a full URL (http:// or https://)"
            fi
        fi
    done

    return $has_errors
}

# Validate hooks.json schema
validate_hooks_json() {
    local file="$1"
    local has_errors=0

    info "Validating hooks.json schema..."

    # Check root structure
    if ! jq -e '.hooks' "$file" >/dev/null 2>&1; then
        error "Missing required root field: hooks"
        echo "  hooks.json must have a 'hooks' object at root"
        echo "  Example: {\"hooks\": {\"SessionStart\": [...]}}"
        return 1
    fi
    success "Root 'hooks' object present"

    # Get all hook types
    local hook_types
    hook_types=$(jq -r '.hooks | keys[]' "$file")

    if [[ -z "$hook_types" ]]; then
        warn "No hooks defined in hooks.json"
        return 0
    fi

    # Validate each hook type
    local valid_hook_types=("SessionStart" "SessionEnd" "UserPromptSubmit" "PreToolUse" "PostToolUse")
    while IFS= read -r hook_type; do
        # Check if hook type is valid
        local is_valid=0
        for valid_type in "${valid_hook_types[@]}"; do
            if [[ "$hook_type" == "$valid_type" ]]; then
                is_valid=1
                break
            fi
        done

        if [[ $is_valid -eq 0 ]]; then
            warn "Unknown hook type: $hook_type (may be valid but uncommon)"
        else
            success "Hook type '$hook_type' is valid"
        fi

        # Validate hook type is an array
        if ! jq -e ".hooks.\"$hook_type\" | type == \"array\"" "$file" >/dev/null 2>&1; then
            error "Hook type '$hook_type' must be an array"
            has_errors=1
            continue
        fi

        # Validate each hook entry
        local hook_count
        hook_count=$(jq ".hooks.\"$hook_type\" | length" "$file")
        info "Hook type '$hook_type' has $hook_count entries"

        for ((i=0; i<hook_count; i++)); do
            # Check hooks array exists
            if ! jq -e ".hooks.\"$hook_type\"[$i].hooks" "$file" >/dev/null 2>&1; then
                error "Hook entry $hook_type[$i] missing 'hooks' array"
                has_errors=1
                continue
            fi

            # Validate each hook object in hooks array
            local inner_hook_count
            inner_hook_count=$(jq ".hooks.\"$hook_type\"[$i].hooks | length" "$file")

            for ((j=0; j<inner_hook_count; j++)); do
                # Check required fields: type, command
                if ! jq -e ".hooks.\"$hook_type\"[$i].hooks[$j].type" "$file" >/dev/null 2>&1; then
                    error "Hook $hook_type[$i].hooks[$j] missing 'type' field"
                    has_errors=1
                fi

                if ! jq -e ".hooks.\"$hook_type\"[$i].hooks[$j].command" "$file" >/dev/null 2>&1; then
                    error "Hook $hook_type[$i].hooks[$j] missing 'command' field"
                    has_errors=1
                else
                    local cmd_path
                    cmd_path=$(jq -r ".hooks.\"$hook_type\"[$i].hooks[$j].command" "$file")
                    success "Hook $hook_type[$i].hooks[$j] has command: $cmd_path"

                    # Check for ${CLAUDE_PLUGIN_ROOT} usage
                    if [[ "$cmd_path" =~ \$\{CLAUDE_PLUGIN_ROOT\} ]]; then
                        success "Command uses \${CLAUDE_PLUGIN_ROOT} variable"
                    elif [[ "$cmd_path" =~ ^/ ]]; then
                        warn "Command uses absolute path instead of \${CLAUDE_PLUGIN_ROOT}"
                        echo "  Consider: \${CLAUDE_PLUGIN_ROOT}/$(basename "$cmd_path")"
                    fi
                fi

                # Optional timeout field
                if jq -e ".hooks.\"$hook_type\"[$i].hooks[$j].timeout" "$file" >/dev/null 2>&1; then
                    local timeout
                    timeout=$(jq ".hooks.\"$hook_type\"[$i].hooks[$j].timeout" "$file")
                    if [[ "$timeout" =~ ^[0-9]+$ ]]; then
                        success "Timeout is valid: ${timeout}ms"
                    else
                        error "Timeout must be a number (milliseconds)"
                        has_errors=1
                    fi
                fi
            done
        done
    done <<< "$hook_types"

    return $has_errors
}

# Main validation logic
main() {
    if [[ $# -ne 1 ]]; then
        usage
    fi

    local file="$1"

    # Check file exists
    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        exit 1
    fi

    echo "Validating: $file"
    echo

    # Step 1: Validate JSON syntax
    if ! validate_json_syntax "$file"; then
        exit 1
    fi
    echo

    # Step 2: Schema validation based on filename
    local basename
    basename=$(basename "$file")

    case "$basename" in
        plugin.json)
            validate_plugin_json "$file"
            ;;
        hooks.json)
            validate_hooks_json "$file"
            ;;
        *)
            warn "Unknown JSON file type: $basename"
            echo "Only plugin.json and hooks.json are validated by this tool"
            exit 0
            ;;
    esac

    echo
    if [[ $ERRORS -eq 0 ]]; then
        success "Validation passed: $file"
        exit 0
    else
        error "$ERRORS validation error(s) found"
        exit 1
    fi
}

main "$@"
