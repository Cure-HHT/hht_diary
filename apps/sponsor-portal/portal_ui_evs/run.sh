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

# Show the auth-related env the SERVER process will inherit, so it's obvious at
# launch (not only at failure time) whether activation will reach the emulator.
# These are read by the server from its own environment; this script does NOT
# set them — `export` them (or prefix this script) before launching.
echo "[run.sh] server auth env -> PORTAL_AUTH_MODE=${PORTAL_AUTH_MODE:-dev}" \
  "FIREBASE_AUTH_EMULATOR_HOST=${FIREBASE_AUTH_EMULATOR_HOST:-<unset>}" \
  "PORTAL_IDENTITY_PROJECT_ID=${PORTAL_IDENTITY_PROJECT_ID:-<unset>}"
if [ -z "${FIREBASE_AUTH_EMULATOR_HOST:-}" ]; then
  echo "[run.sh] NOTE: FIREBASE_AUTH_EMULATOR_HOST is unset — account activation" \
    "will try REAL Identity Platform via gcloud ADC (likely fails locally). For" \
    "dev, start the auth emulator and re-launch with" \
    "FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 PORTAL_IDENTITY_PROJECT_ID=demo-local-stack." >&2
fi

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

# Session-auth mode is opt-in. The server reads PORTAL_AUTH_MODE / PORTAL_SESSION_*
# / FIREBASE_AUTH_EMULATOR_HOST / PORTAL_IDENTITY_PROJECT_ID straight from the
# environment (inherited by the server subshell above), so just export them when
# invoking this script. The client login flow is behind a compile-time flag, so
# it must be passed as a --dart-define here; we derive it from PORTAL_AUTH_MODE so
# `PORTAL_AUTH_MODE=session run.sh` lights up the LoginScreen automatically. When
# PORTAL_AUTH_MODE is unset/dev, PORTAL_SESSION_AUTH stays false and the dev
# ConnectScreen + activation flow are unchanged.
SESSION_AUTH=false
if [ "${PORTAL_AUTH_MODE:-dev}" = "session" ]; then
  SESSION_AUTH=true
fi
(
  cd "$ROOT/portal_ui_evs" &&
    flutter run -d chrome \
      --web-port "${UI_PORT}" \
      --dart-define=PORTAL_SERVER_URL="http://localhost:${SERVER_PORT}" \
      --dart-define=PORTAL_SESSION_AUTH="${SESSION_AUTH}"
)
