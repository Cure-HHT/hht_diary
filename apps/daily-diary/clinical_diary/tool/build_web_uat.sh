#!/bin/bash
# Implements: DIARY-DEV-runtime-environment-resolution/A

# Build the Clinical Diary web app for the uat environment (manual/local preview).
# Usage: ./tool/build_web_uat.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Clinical Diary for web (uat)..."

# Stamp the bundled env pointer so the web build resolves uat at runtime;
# restored on exit by the sourced helper. (Web reads assets/config/env.json at
# runtime, same as mobile; --dart-define=APP_FLAVOR is no longer read.)
source "$SCRIPT_DIR/_write_env_pointer.sh" uat

# --pwa-strategy=none disables service worker to prevent aggressive caching
flutter build web --release --pwa-strategy=none

echo ""
echo "Build complete! Output in build/web/"
echo "To preview locally: cd build/web && python3 -m http.server 8080"
