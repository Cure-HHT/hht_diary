#!/bin/bash
# Implements: DIARY-DEV-runtime-environment-resolution/A

# Build the Clinical Diary web app for the dev environment (manual/local preview).
# Usage: ./tool/build_web_dev.sh

set -e

echo "Building Clinical Diary for web (dev)..."

# Env = committed default (dev) in assets/config/env.json; no stamp needed.
# Web reads the bundled pointer at runtime; --dart-define=APP_FLAVOR is no longer read.
# --pwa-strategy=none disables service worker to prevent aggressive caching
flutter build web --release --pwa-strategy=none

echo ""
echo "Build complete! Output in build/web/"
echo "To preview locally: cd build/web && python3 -m http.server 8080"
