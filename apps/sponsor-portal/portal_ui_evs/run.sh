#!/usr/bin/env bash
# Starts the portal_server_evs server (:8084) and the portal_ui_evs Flutter web
# app (:8088).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # apps/sponsor-portal

SERVER_PORT=8084
UI_PORT=8088

# Free both ports from any stale process before starting. Killing the `dart run`
# wrapper does NOT kill the spawned dart VM, so a previous run can leave the
# server port bound — then the new server can't take over and the browser keeps
# hitting the old (stale) one. `fuser -k` kills whatever holds the port.
fuser -k "${SERVER_PORT}/tcp" "${UI_PORT}/tcp" 2>/dev/null || true

# PORTAL_URL is the portal UI origin (NOT the server). The activation magic link
# is built as $PORTAL_URL/?code=... and must open the Flutter activation page,
# which reads ?code= from its own URL and then calls the server itself. The UI
# is pinned to ${UI_PORT} below so this URL is stable.
#
# EMAIL_CONSOLE_MODE=true keeps local dev from sending real email and prints the
# activation link to the server console (the whole point in dev). Drop it only
# when deliberately exercising live Gmail-over-WIF delivery.
(
  cd "$ROOT/portal_server_evs" &&
    PORTAL_URL="http://localhost:${UI_PORT}" \
    EMAIL_CONSOLE_MODE=true \
    dart run bin/server.dart
) &
trap 'fuser -k "${SERVER_PORT}/tcp" "${UI_PORT}/tcp" 2>/dev/null || true' EXIT
sleep 2
(
  cd "$ROOT/portal_ui_evs" &&
    flutter run -d chrome \
      --web-port "${UI_PORT}" \
      --dart-define=PORTAL_SERVER_URL="http://localhost:${SERVER_PORT}"
)
