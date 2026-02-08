#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00053: Development Environment and Tooling Setup
#
# Repository Setup Script (Idempotent)
# Installs developer tools and configures the repository.
#
# Sections:
#   1. Git hooks configuration
#   2. Python tools (elspais, anspar-wf)
#   3. ANSPAR_WF_PLUGINS environment variable
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
# 1. Git Hooks
# ============================================================

setup_git_hooks() {
    echo ""
    echo "=== Git Hooks ==="

    if git -C "$REPO_ROOT" config --local include.path ../.gitconfig 2>/dev/null; then
        ok "core.hooksPath = .githooks (via .gitconfig include)"
    else
        if $check_only; then
            fail "Git hooks not configured"
        else
            git -C "$REPO_ROOT" config --local include.path ../.gitconfig
            ok "Git hooks configured"
        fi
    fi
}

# ============================================================
# 2. Python Tools
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
    install_pip_package "elspais" "${ELSPAIS_VERSION:-0.43.5}"

    # anspar-wf - workflow plugins and MCP servers
    install_pip_package "anspar-wf" "${ANSPAR_WF_VERSION:-0.1.0}"
}

# ============================================================
# 3. ANSPAR_WF_PLUGINS Environment Variable
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
    setup_git_hooks
    setup_python_tools
    setup_env_var

    echo ""
    if $check_only; then
        echo "Run without --check to install/fix issues."
    else
        echo "Setup complete."
    fi
}

main
