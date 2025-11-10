#!/bin/bash
# Workflow2 Plugin Test Suite
# Basic tests to verify plugin functionality

set -e

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PLUGIN_ROOT/scripts"
HOOKS_DIR="$PLUGIN_ROOT/hooks"

echo "🧪 Testing Workflow2 Plugin Structure"
echo "======================================"
echo ""

# Test 1: Check plugin structure
echo "✓ Test 1: Plugin structure"
test -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" || { echo "❌ Missing plugin.json"; exit 1; }
test -d "$SCRIPTS_DIR" || { echo "❌ Missing scripts directory"; exit 1; }
test -d "$HOOKS_DIR" || { echo "❌ Missing hooks directory"; exit 1; }
echo "  ✅ Plugin structure valid"
echo ""

# Test 2: Check scripts are executable
echo "✓ Test 2: Scripts executability"
for script in "$SCRIPTS_DIR"/*.sh; do
    test -x "$script" || { echo "❌ Script not executable: $script"; exit 1; }
done
echo "  ✅ All scripts executable"
echo ""

# Test 3: Check hooks are executable
echo "✓ Test 3: Hooks executability"
for hook in pre-commit commit-msg post-commit session-start; do
    test -x "$HOOKS_DIR/$hook" || { echo "❌ Hook not executable: $hook"; exit 1; }
done
echo "  ✅ All hooks executable"
echo ""

# Test 4: Validate plugin.json
echo "✓ Test 4: Plugin metadata"
if command -v jq &>/dev/null; then
    jq empty "$PLUGIN_ROOT/.claude-plugin/plugin.json" || { echo "❌ Invalid plugin.json"; exit 1; }
    echo "  ✅ Plugin metadata valid"
else
    echo "  ⚠️  jq not installed, skipping JSON validation"
fi
echo ""

echo "======================================"
echo "✅ All tests passed!"
echo ""
