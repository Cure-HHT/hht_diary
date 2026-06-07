#!/usr/bin/env bash
# Run the WHOLE link loop UI-to-UI (Playwright) against a live, Postgres-backed
# portal_server_evs: the coordinator portal issues a code in its UI and the
# diary redeems it in its UI, in one browser session.
#
# Resets + reseeds the throwaway database (the run issues + consumes a code, so
# it is not idempotent), builds BOTH web bundles, serves them, and runs the
# full-loop spec. Prereqs: a local throwaway Postgres, flutter, node.
#
# Usage:  apps/sponsor-portal/portal_ui_evs/scripts/run-full-loop-e2e.sh [pw args]
set -euo pipefail

PORTAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$PORTAL_DIR/../../.." && pwd)"
SERVER_DIR="$REPO_DIR/apps/sponsor-portal/portal_server_evs"
DIARY_DIR="$REPO_DIR/apps/daily-diary/clinical_diary"

# Fixed LOCAL throwaway values — deliberately NOT inherited from the ambient
# environment (which may point DB_* at a real database).
PG_CONTAINER="evs-pg"; DB_HOST="localhost"; DB_PORT="5433"
DB_USER="postgres"; DB_PASSWORD="devroot"; DB_NAME="hht_diary"
PORTAL_PORT="8084"; PORTAL_WEB_PORT="8010"; DIARY_WEB_PORT="8000"

if ! command -v flutter >/dev/null 2>&1; then
  export PATH="$HOME/flutter-sdk/flutter/bin:$PATH"
fi

cleanup() {
  [[ -n "${DIARY_SERVE_PID:-}" ]] && kill "$DIARY_SERVE_PID" 2>/dev/null || true
  fuser -k "${PORTAL_PORT}/tcp" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Resetting database ($PG_CONTAINER:$DB_NAME)"
docker exec "$PG_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
  -c "drop schema public cascade; create schema public;" >/dev/null

echo "==> (Re)starting portal_server_evs on :$PORTAL_PORT"
fuser -k "${PORTAL_PORT}/tcp" 2>/dev/null || true; sleep 2
( cd "$SERVER_DIR" && env -u RAVE_UAT_USERNAME -u RAVE_UAT_PASSWORD -u RAVE_UAT_BASE_URL \
    DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" DB_USER="$DB_USER" DB_PASSWORD="$DB_PASSWORD" \
    DB_NAME="$DB_NAME" DB_SSL=false PORT="$PORTAL_PORT" PORTAL_AUTH_MODE=dev \
    dart run bin/server.dart > /tmp/portal_evs_e2e.log 2>&1 & )
for _ in $(seq 1 40); do
  curl -s "http://localhost:${PORTAL_PORT}/health" 2>/dev/null | grep -q ok && break; sleep 1
done
echo "    server ready"

echo "==> Building web bundles (portal + diary), pointed at the live server"
( cd "$PORTAL_DIR" && flutter pub get >/dev/null && flutter build web --release \
    --dart-define=PORTAL_SERVER_URL="http://localhost:${PORTAL_PORT}" )
( cd "$DIARY_DIR" && flutter pub get >/dev/null && flutter build web --release \
    --dart-define=DIARY_API_BASE="http://localhost:${PORTAL_PORT}" )

echo "==> Serving the diary bundle on :$DIARY_WEB_PORT"
npx --yes serve "$DIARY_DIR/build/web" -l "$DIARY_WEB_PORT" -s --no-clipboard \
  >/tmp/diary_serve.log 2>&1 &
DIARY_SERVE_PID=$!
for _ in $(seq 1 30); do
  curl -s -o /dev/null "http://localhost:${DIARY_WEB_PORT}" && break; sleep 1
done

echo "==> Running the full-loop spec (portal served on :$PORTAL_WEB_PORT by playwright)"
cd "$PORTAL_DIR/e2e"
npm install >/dev/null
npx playwright test full-loop "$@"
