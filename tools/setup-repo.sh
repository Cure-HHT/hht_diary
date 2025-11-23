#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00053: Development Environment and Tooling Setup
#
# Repository Setup Script
# Configures Git hooks and other repository-level settings
#
# Usage:
#   ./scripts/setup-repo.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "🔧 Setting up repository configuration..."
echo

# Include repository Git configuration
echo "📌 Including repository Git configuration..."
if git config --local include.path ../.gitconfig; then
    echo "✅ Repository config included (.gitconfig)"
    echo "   This configures:"
    echo "     • core.hooksPath = .githooks"
else
    echo "❌ Failed to include repository config"
    exit 1
fi

echo
echo "✅ Repository setup complete!"
echo
echo "Git hooks provide:"
echo "  • Commit validation (require ticket + REQ references)"
echo "  • Secret scanning (gitleaks)"
echo "  • Workflow state tracking"
echo
