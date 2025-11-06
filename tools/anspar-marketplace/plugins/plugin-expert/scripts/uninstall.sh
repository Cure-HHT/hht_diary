#!/bin/bash
# =====================================================
# uninstall.sh - Plugin-Expert Uninstallation Script
# =====================================================
#
# Removes plugin-expert permissions from Claude Code settings.
# Only removes permissions that are not used by other plugins.
#
# This is idempotent - safe to run multiple times.
#
# =====================================================

set -e

# Find repository root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$REPO_ROOT" ]; then
    echo "⚠️  Not in a git repository. Skipping permission removal."
    exit 0
fi

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🗑️  Uninstalling plugin-expert..."
echo

# =====================================================
# Remove Claude Code Permissions
# =====================================================

echo "🔐 Removing Claude Code permissions..."

PERMISSIONS_SCRIPT="$PLUGIN_DIR/utilities/manage-permissions.sh"

if [ -f "$PERMISSIONS_SCRIPT" ]; then
    cd "$REPO_ROOT"
    if "$PERMISSIONS_SCRIPT" remove "plugin-expert"; then
        echo "  ✅ Permissions removed"
    else
        echo "  ⚠️  Permission removal failed (non-fatal)"
    fi
else
    echo "  ⚠️  Permission management script not found"
fi

echo
echo "✅ Plugin-expert uninstallation complete"
echo
echo "Note: Cache directory and gitignore entries remain for safety."
echo "Remove manually if needed:"
echo "  - $PLUGIN_DIR/cache/"
echo "  - .gitignore entries for plugin-expert"

exit 0
