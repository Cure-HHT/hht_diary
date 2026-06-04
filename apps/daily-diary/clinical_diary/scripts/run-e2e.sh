#!/usr/bin/env bash
# Build the clinical_diary Flutter web client and run the Playwright e2e
# suite (font-options coverage) against the served bundle.
#
# The diary runs fully offline on web — no dart backend process is needed
# (unlike the reaction-example reference harness). The sponsor-config fetch
# is forced to a dead port via --dart-define so the app keeps its default
# availableFonts (all three) and renders the font selector.
#
# Usage:  apps/daily-diary/clinical_diary/scripts/run-e2e.sh [playwright args]
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

# `flutter` may not be on PATH (this host keeps it under flutter-sdk/).
# Add the known location if the command is missing.
if ! command -v flutter >/dev/null 2>&1; then
  if [[ -x "$HOME/flutter-sdk/flutter/bin/flutter" ]]; then
    export PATH="$HOME/flutter-sdk/flutter/bin:$PATH"
  else
    echo "ERROR: flutter not found on PATH and not at \$HOME/flutter-sdk/flutter/bin" >&2
    exit 1
  fi
fi

echo "==> flutter pub get"
flutter pub get

# The web platform scaffold (web/index.html etc.) is normally committed,
# but regenerate it on demand if missing — `flutter build web` fails with
# "not configured for the web" otherwise.
if [[ ! -d web ]]; then
  echo "==> Scaffolding web platform (flutter create . --platforms web)"
  flutter create . --platforms web >/dev/null
fi

echo "==> Building Flutter web bundle (offline sponsor-config via dead port)"
flutter build web --dart-define=DIARY_API_BASE=http://127.0.0.1:9

echo "==> Running Playwright suite"
cd e2e
npm install
npx playwright test "$@"
