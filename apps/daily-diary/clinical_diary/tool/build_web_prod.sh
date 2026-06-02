#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary web app with PROD flavor
# Usage: ./tool/build_web_prod.sh

set -e

echo "Building Clinical Diary for web (PROD flavor)..."

# --pwa-strategy=none disables service worker to prevent aggressive caching
flutter build web --release --dart-define=APP_FLAVOR=prod --pwa-strategy=none

echo ""
echo "Build complete! Output in build/web/"
echo "To preview locally: cd build/web && python3 -m http.server 8080"
