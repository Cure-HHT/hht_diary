#!/bin/bash
# SessionStart hook for Claude Code
# Sets up environment variables and installs dependencies
set -euo pipefail

# =============================================================================
# FLUTTER SETUP (remote/web environment only)
# =============================================================================
# Only run Flutter setup in remote (web) environment
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Setting up Flutter development environment..."

FLUTTER_DIR="/opt/flutter"
FLUTTER_VERSION="3.38.7"

# Install Flutter SDK if not present
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Installing Flutter SDK $FLUTTER_VERSION..."

  cd /opt
  curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" | tar xJ

  # Fix git safe directory issue
  git config --global --add safe.directory "$FLUTTER_DIR"

  # Disable analytics and precache web
  "$FLUTTER_DIR/bin/flutter" --disable-analytics || true
  "$FLUTTER_DIR/bin/flutter" precache --web || true

  echo "Flutter SDK installed successfully"
else
  echo "Flutter SDK already installed"
  # Ensure safe directory is configured
  git config --global --add safe.directory "$FLUTTER_DIR" 2>/dev/null || true
fi

# Export Flutter to PATH for this session
echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Verify installation
"$FLUTTER_DIR/bin/flutter" --version
"$FLUTTER_DIR/bin/dart" --version

# Install Flutter dependencies for main app
if [ -f "$CLAUDE_PROJECT_DIR/apps/daily-diary/clinical_diary/pubspec.yaml" ]; then
  echo "Installing Flutter dependencies for clinical_diary..."
  cd "$CLAUDE_PROJECT_DIR/apps/daily-diary/clinical_diary"
  "$FLUTTER_DIR/bin/flutter" pub get
fi

# Install Node.js dependencies for Firebase Functions
if [ -f "$CLAUDE_PROJECT_DIR/apps/daily-diary/clinical_diary/functions/package.json" ]; then
  echo "Installing Node.js dependencies for Firebase Functions..."
  cd "$CLAUDE_PROJECT_DIR/apps/daily-diary/clinical_diary/functions"
  npm install
fi

# =============================================================================
# GIT HOOKS SETUP
# =============================================================================
# Configure git to use the project's custom hooks directory
# This enables pre-commit checks for dart format, dart analyze, etc.

echo "Configuring git hooks..."

if [ -d "$CLAUDE_PROJECT_DIR/.githooks" ]; then
  git config --global core.hooksPath "$CLAUDE_PROJECT_DIR/.githooks"
  echo "✓ Git hooks configured: $CLAUDE_PROJECT_DIR/.githooks"
else
  echo "⚠️  .githooks directory not found - git hooks not configured"
fi

echo "Development environment setup complete!"
