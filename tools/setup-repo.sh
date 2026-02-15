#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00053: Development Environment and Tooling Setup
#
# Repository Setup Script (Idempotent)
# Installs developer tools and configures the repository.
#
# Sections:
#   1. Python tools (elspais, anspar-wf)
#   2. Git hooks (via anspar-wf)
#   3. Claude Code plugins (via anspar-wf)
#   4. ANSPAR_WF_PLUGINS environment variable
#
# Usage:
#   ./tools/setup-repo.sh           # Full setup
#   ./tools/setup-repo.sh --check   # Check status only
#
# This script is idempotent - safe to run multiple times.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================
# Load pinned versions
# ============================================================

load_versions() {
    local versions_file="$REPO_ROOT/.github/versions.env"
    if [ -f "$versions_file" ]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            export "${key}=${value}"
        done < "$versions_file"
    else
        echo "WARNING: .github/versions.env not found, using defaults"
    fi
}

# ============================================================
# Helpers
# ============================================================

check_only=false
if [ "${1:-}" = "--check" ]; then
    check_only=true
fi

ok()   { echo "  [OK]  $1"; }
skip() { echo "  [--]  $1"; }
fail() { echo "  [!!]  $1"; }
info() { echo "  ...   $1"; }

# ============================================================
# 1. Python Tools
# ============================================================

install_pip_package() {
    local package="$1"
    local version="$2"
    local spec="${package}==${version}"

    # Check if already installed at correct version
    local installed
    installed=$(pip show "$package" 2>/dev/null | grep -i '^Version:' | awk '{print $2}') || true

    if [ "$installed" = "$version" ]; then
        ok "$package $version"
        return 0
    fi

    if $check_only; then
        if [ -n "$installed" ]; then
            fail "$package $installed (want $version)"
        else
            fail "$package not installed (want $version)"
        fi
        return 0
    fi

    if [ -n "$installed" ]; then
        info "Upgrading $package $installed -> $version"
    else
        info "Installing $package $version"
    fi

    pip install --quiet "$spec"
    ok "$package $version"
}

setup_python_tools() {
    echo ""
    echo "=== Python Tools ==="

    if ! command -v pip &>/dev/null && ! command -v pip3 &>/dev/null; then
        fail "pip not found - install Python 3.10+"
        return 1
    fi

    # elspais - requirement validation and traceability
    install_pip_package "elspais" "${ELSPAIS_VERSION:-0.57.0}"

    # anspar-wf - hook generation, plugins, MCP servers
    install_pip_package "anspar-wf" "${ANSPAR_WF_VERSION:-0.1.0}"
}

# ============================================================
# 2. Git Hooks (via anspar-wf)
# ============================================================

setup_git_hooks() {
    echo ""
    echo "=== Git Hooks ==="

    if ! command -v anspar-wf &>/dev/null; then
        fail "anspar-wf not installed - cannot configure hooks"
        return 1
    fi

    # Check if .anspar-wf.toml exists
    if [ ! -f "$REPO_ROOT/.anspar-wf.toml" ]; then
        fail ".anspar-wf.toml not found - run: anspar-wf init --project-dir $REPO_ROOT"
        return 1
    fi

    # Check hooks path configuration
    local hooks_path
    hooks_path=$(git -C "$REPO_ROOT" config --get core.hooksPath 2>/dev/null || echo "")

    if [ "$hooks_path" = ".githooks" ] || [ "$hooks_path" = ".githooks/" ]; then
        ok "core.hooksPath = .githooks"
    else
        if $check_only; then
            fail "core.hooksPath not set to .githooks (got: '${hooks_path:-<unset>}')"
        else
            anspar-wf hooks setup --project-dir "$REPO_ROOT"
            ok "core.hooksPath configured"
        fi
    fi

    # Check if hooks are up to date
    if [ -f "$REPO_ROOT/.githooks/.anspar-wf-meta" ]; then
        if $check_only; then
            # Use hooks update --force in check mode to see if regeneration needed
            ok "Generated hooks present"
        else
            anspar-wf hooks update --project-dir "$REPO_ROOT" --force
            ok "Hooks regenerated from .anspar-wf.toml"
        fi
    else
        if $check_only; then
            fail "Generated hooks not found - run: anspar-wf hooks generate"
        else
            anspar-wf hooks generate --project-dir "$REPO_ROOT"
            ok "Hooks generated from .anspar-wf.toml"
        fi
    fi
}

# ============================================================
# 3. Claude Code Plugins (via anspar-wf)
# ============================================================

setup_plugins() {
    echo ""
    echo "=== Claude Code Plugins ==="

    if ! command -v anspar-wf &>/dev/null; then
        fail "anspar-wf not installed - cannot register plugins"
        return 1
    fi

    local settings_file="$REPO_ROOT/.claude/settings.json"

    if [ ! -f "$settings_file" ]; then
        skip "No .claude/settings.json - skipping plugin registration"
        return 0
    fi

    if $check_only; then
        # Check if marketplace is registered
        if grep -q "anspar-cc-plugins" "$settings_file" 2>/dev/null; then
            ok "Plugin marketplace registered"
        else
            fail "Plugin marketplace not registered"
        fi
    else
        anspar-wf plugins register --project-dir "$REPO_ROOT"
        ok "Plugin marketplace registered"
    fi
}

# ============================================================
# 4. ANSPAR_WF_PLUGINS Environment Variable
# ============================================================

detect_shell_profile() {
    local shell_name
    shell_name=$(basename "${SHELL:-/bin/bash}")

    case "$shell_name" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash)
            # Prefer .bashrc for interactive shells, .profile as fallback
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            else
                echo "$HOME/.profile"
            fi
            ;;
        *)    echo "$HOME/.profile" ;;
    esac
}

get_plugins_path() {
    # Derive from installed anspar-wf package location
    local pkg_path
    pkg_path=$(python3 -c "import anspar_wf; import os; print(os.path.dirname(anspar_wf.__file__))" 2>/dev/null) || true

    if [ -n "$pkg_path" ] && [ -d "$pkg_path/../plugins/plugins" ]; then
        # Plugins bundled with pip package (future)
        echo "$(cd "$pkg_path/../plugins/plugins" && pwd)"
    elif [ -d "$HOME/anspar-wf/plugins/plugins" ]; then
        # Git clone fallback
        echo "$HOME/anspar-wf/plugins/plugins"
    else
        echo ""
    fi
}

setup_env_var() {
    echo ""
    echo "=== ANSPAR_WF_PLUGINS ==="

    local plugins_path
    plugins_path=$(get_plugins_path)

    if [ -z "$plugins_path" ]; then
        fail "Could not find anspar-wf plugins directory"
        info "Expected at ~/anspar-wf/plugins/plugins/"
        info "Clone: git clone git@github.com:Anspar-Org/anspar-wf.git ~/anspar-wf"
        return 1
    fi

    ok "Plugins found at: $plugins_path"

    # Check if already exported in current shell
    if [ "${ANSPAR_WF_PLUGINS:-}" = "$plugins_path" ]; then
        ok "ANSPAR_WF_PLUGINS already set in current shell"
    fi

    # Check if already in shell profile
    local profile
    profile=$(detect_shell_profile)

    if [ -f "$profile" ] && grep -qF "ANSPAR_WF_PLUGINS=" "$profile"; then
        # Already present - check if correct path is there
        if grep -qF "$plugins_path" "$profile"; then
            ok "Shell profile ($profile) already configured"
        else
            if $check_only; then
                fail "Shell profile has different ANSPAR_WF_PLUGINS path"
            else
                # Remove old lines and re-add with correct path
                grep -v "ANSPAR_WF_PLUGINS" "$profile" | grep -v "# anspar-wf plugin path" > "${profile}.tmp"
                mv "${profile}.tmp" "$profile"
                echo "" >> "$profile"
                echo "# anspar-wf plugin path (added by tools/setup-repo.sh)" >> "$profile"
                printf 'export ANSPAR_WF_PLUGINS="%s"\n' "$plugins_path" >> "$profile"
                ok "Updated path in $profile"
            fi
        fi
    else
        if $check_only; then
            fail "Not in shell profile ($profile)"
        else
            echo "" >> "$profile"
            echo "# anspar-wf plugin path (added by tools/setup-repo.sh)" >> "$profile"
            printf 'export ANSPAR_WF_PLUGINS="%s"\n' "$plugins_path" >> "$profile"
            ok "Added to $profile"
            info "Run: source $profile  (or open a new terminal)"
        fi
    fi
}

# ============================================================
# Main
# ============================================================

main() {
    echo "=== Repository Setup $([ "$check_only" = true ] && echo "(check only)" || echo "(install)") ==="

    load_versions
    setup_python_tools
    setup_git_hooks
    setup_plugins
    setup_env_var

    echo ""
    if $check_only; then
        echo "Run without --check to install/fix issues."
    else
        echo "Setup complete."
    fi
}

main
