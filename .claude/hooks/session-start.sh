#!/bin/bash
# SessionStart hook for Claude Code
# Sets up environment variables and installs dependencies
set -euo pipefail

# =============================================================================
# LINEAR ENVIRONMENT SETUP (runs for all environments)
# =============================================================================

# Setup LINEAR_API_TOKEN from Doppler if not already set
setup_linear_token() {
  if [ -n "${LINEAR_API_TOKEN:-}" ]; then
    return 0
  fi

  if command -v doppler &> /dev/null; then
    local token
    token=$(doppler secrets get LINEAR_API_TOKEN --plain 2>/dev/null || true)
    if [ -n "$token" ]; then
      echo "export LINEAR_API_TOKEN=\"$token\"" >> "$CLAUDE_ENV_FILE"
      export LINEAR_API_TOKEN="$token"
      echo "✓ LINEAR_API_TOKEN loaded from Doppler"
      return 0
    fi
  fi

  echo "⚠️  LINEAR_API_TOKEN not set. Linear API plugin will not work."
  echo "   Run with: doppler run -- claude"
}

# Auto-discover LINEAR_TEAM_ID if not set
setup_linear_team_id() {
  if [ -n "${LINEAR_TEAM_ID:-}" ]; then
    return 0
  fi

  # Need token to discover team ID
  if [ -z "${LINEAR_API_TOKEN:-}" ]; then
    return 1
  fi

  # Query Linear API for teams
  local response
  response=$(curl -s -H "Authorization: $LINEAR_API_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST https://api.linear.app/graphql \
    -d '{"query": "query { teams { nodes { id name key } }}"}' 2>/dev/null || true)

  if [ -z "$response" ]; then
    return 1
  fi

  # Extract team ID (assumes single team or first team)
  local team_id
  team_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [ -n "$team_id" ]; then
    echo "export LINEAR_TEAM_ID=\"$team_id\"" >> "$CLAUDE_ENV_FILE"
    export LINEAR_TEAM_ID="$team_id"
    echo "✓ LINEAR_TEAM_ID auto-discovered: $team_id"
    return 0
  fi

  return 1
}

# Run Linear setup (don't fail if Linear isn't configured)
setup_linear_token || true
setup_linear_team_id || true

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
