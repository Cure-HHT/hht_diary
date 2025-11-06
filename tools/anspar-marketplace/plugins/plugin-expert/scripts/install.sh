#!/bin/bash
# =====================================================
# install.sh - Plugin-Expert Installation Script
# =====================================================
#
# Ensures plugin-expert cache directories are properly
# gitignored in the project root.
#
# This is idempotent - safe to run multiple times.
#
# =====================================================

set -e

# Find repository root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$REPO_ROOT" ]; then
    echo "⚠️  Not in a git repository. Skipping gitignore setup."
    exit 0
fi

GITIGNORE="$REPO_ROOT/.gitignore"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_RELATIVE_PATH="$(realpath --relative-to="$REPO_ROOT" "$PLUGIN_DIR")"

# =====================================================
# Gitignore Entries
# =====================================================

CACHE_PATTERNS=(
    "# Plugin-expert documentation cache"
    "${PLUGIN_RELATIVE_PATH}/cache/docs/"
    "${PLUGIN_RELATIVE_PATH}/cache/.cache-metadata.json"
)

# =====================================================
# Add to .gitignore if not present
# =====================================================

add_to_gitignore() {
    local pattern="$1"

    # Check if already present
    if grep -qF "$pattern" "$GITIGNORE" 2>/dev/null; then
        return 0
    fi

    # Add to gitignore
    echo "$pattern" >> "$GITIGNORE"
    echo "  ✅ Added: $pattern"
}

echo "📝 Configuring plugin-expert gitignore..."

# Ensure .gitignore exists
if [ ! -f "$GITIGNORE" ]; then
    touch "$GITIGNORE"
    echo "  Created .gitignore"
fi

# Add cache patterns
ADDED=false
for pattern in "${CACHE_PATTERNS[@]}"; do
    if ! grep -qF "$pattern" "$GITIGNORE" 2>/dev/null; then
        if [ "$ADDED" = false ]; then
            echo "" >> "$GITIGNORE"  # Add blank line before section
            ADDED=true
        fi
        add_to_gitignore "$pattern"
    fi
done

if [ "$ADDED" = false ]; then
    echo "  ✓ Cache patterns already in .gitignore"
fi

# =====================================================
# Create cache directory structure
# =====================================================

CACHE_DIR="$PLUGIN_DIR/cache/docs"

if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR"
    echo "  ✅ Created cache directory: $CACHE_DIR"
fi

echo "✅ Plugin-expert installation complete"

exit 0
