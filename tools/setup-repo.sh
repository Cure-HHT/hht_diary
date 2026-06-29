#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00053: Development Environment and Tooling Setup
#
# Repository Setup Script (Idempotent)
# Installs developer tools and configures the repository.
#
# Sections:
#   1. Python tools (elspais)
#   2. Git hooks (core.hooksPath=.githooks)
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
    # Canonical pin: .github/versions.env (sourced above into ELSPAIS_VERSION);
    # the literal is only a fallback when that file is missing — keep it current.
    install_pip_package "elspais" "${ELSPAIS_VERSION:-0.117.81}"
}

# ============================================================
# 2. Git Hooks
# ============================================================

setup_git_hooks() {
    echo ""
    echo "=== Git Hooks ==="

    # Check hooks path configuration
    local hooks_path
    hooks_path=$(git -C "$REPO_ROOT" config --get core.hooksPath 2>/dev/null || echo "")

    if [ "$hooks_path" = ".githooks" ] || [ "$hooks_path" = ".githooks/" ]; then
        ok "core.hooksPath = .githooks"
    else
        if $check_only; then
            fail "core.hooksPath not set to .githooks (got: '${hooks_path:-<unset>}')"
        else
            # Git hooks are checked into .githooks/ and owned by this repo.
            git -C "$REPO_ROOT" config core.hooksPath .githooks
            ok "Git hooks configured (core.hooksPath=.githooks)"
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

    echo ""
    if $check_only; then
        echo "Run without --check to install/fix issues."
    else
        echo "Setup complete."
    fi
}

main
