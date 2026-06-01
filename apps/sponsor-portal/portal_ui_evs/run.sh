#!/usr/bin/env bash
# Starts the portal_server_evs server and the portal_ui_evs Flutter web app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # apps/sponsor-portal

# Free :8084 from any stale server before starting. Killing the `dart run` wrapper
# does NOT kill the spawned dart VM, so a previous run can leave the port bound —
# then the new server can't take over and the browser keeps hitting the old
# (stale) one. `fuser -k` kills whatever holds the port.
fuser -k 8084/tcp 2>/dev/null || true

( cd "$ROOT/portal_server_evs" && dart run bin/server.dart ) &
trap 'fuser -k 8084/tcp 2>/dev/null || true' EXIT
sleep 2
( cd "$ROOT/portal_ui_evs" && flutter run -d chrome --dart-define=PORTAL_SERVER_URL=http://localhost:8084 )
