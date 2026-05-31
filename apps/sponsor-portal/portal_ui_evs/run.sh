#!/usr/bin/env bash
# Starts the portal_server_evs server and the portal_ui_evs Flutter web app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"   # apps/sponsor-portal
( cd "$ROOT/portal_server_evs" && dart run bin/server.dart ) &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
sleep 2
( cd "$ROOT/portal_ui_evs" && flutter run -d chrome --dart-define=PORTAL_SERVER_URL=http://localhost:8084 )
