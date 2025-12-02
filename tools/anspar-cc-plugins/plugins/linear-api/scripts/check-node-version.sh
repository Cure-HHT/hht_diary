#!/usr/bin/env bash
# Check Node.js version for Linear API plugin
# Requires Node.js 18+ for native fetch() support

REQUIRED_MAJOR=18

# Get current Node.js version
if ! command -v node &> /dev/null; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         NODE.JS NOT FOUND                                      ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                                ║"
    echo "║  The Linear API plugin requires Node.js ${REQUIRED_MAJOR}+                                   ║"
    echo "║                                                                                ║"
    echo "║  Node.js is not installed or not in PATH.                                     ║"
    echo "║                                                                                ║"
    echo "║  To fix this:                                                                  ║"
    echo "║                                                                                ║"
    echo "║    Option 1: Use the dev container (RECOMMENDED)                              ║"
    echo "║      - Open VS Code                                                            ║"
    echo "║      - Cmd/Ctrl+Shift+P → \"Reopen in Container\"                               ║"
    echo "║                                                                                ║"
    echo "║    Option 2: Install Node.js 18+ directly                                     ║"
    echo "║      - Using nvm: nvm install 18 && nvm use 18                                ║"
    echo "║      - Using brew: brew install node@18                                       ║"
    echo "║      - Download: https://nodejs.org/                                          ║"
    echo "║                                                                                ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

CURRENT_VERSION=$(node --version)
MAJOR_VERSION=$(echo "$CURRENT_VERSION" | sed 's/v//' | cut -d. -f1)

if [ "$MAJOR_VERSION" -lt "$REQUIRED_MAJOR" ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         NODE.JS VERSION ERROR                                  ║"
    echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                                ║"
    echo "║  The Linear API plugin requires Node.js ${REQUIRED_MAJOR}+                                   ║"
    echo "║                                                                                ║"
    printf "║  Current version:  %-58s ║\n" "$CURRENT_VERSION"
    echo "║  Required version: v${REQUIRED_MAJOR}.0.0+                                                  ║"
    echo "║                                                                                ║"
    echo "║  The native fetch() API is required, which was added in Node.js 18.           ║"
    echo "║                                                                                ║"
    echo "║  To fix this:                                                                  ║"
    echo "║                                                                                ║"
    echo "║    Option 1: Use the dev container (RECOMMENDED)                              ║"
    echo "║      - Open VS Code                                                            ║"
    echo "║      - Cmd/Ctrl+Shift+P → \"Reopen in Container\"                               ║"
    echo "║                                                                                ║"
    echo "║    Option 2: Install Node.js 18+ directly                                     ║"
    echo "║      - Using nvm: nvm install 18 && nvm use 18                                ║"
    echo "║      - Using brew: brew install node@18                                       ║"
    echo "║      - Download: https://nodejs.org/                                          ║"
    echo "║                                                                                ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# Version is OK - exit successfully
exit 0
