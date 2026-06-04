#!/usr/bin/env bash
# Run the coordinator link-code browser e2e (Playwright) against a live,
# Postgres-backed portal_server_evs.
#
# The test issues a code for a seeded participant, which flips that participant
# to "pending" — so the run is NOT idempotent against an existing store. This
# script therefore resets the database and re-seeds (fresh notConnected
# participants) before each run, then builds the web bundle and runs the suite.
#
# Prereqs: a local Postgres reachable as configured below (the repo's
# tools/dev-env or a throwaway `docker run ... postgres`), flutter, node.
#
# Usage:  apps/sponsor-portal/portal_ui_evs/scripts/run-link-e2e.sh [playwright args]
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$APP_DIR/../../.." && pwd)"
SERVER_DIR="$REPO_DIR/apps/sponsor-portal/portal_server_evs"

# --- config -----------------------------------------------------------------
# Fixed LOCAL throwaway values — deliberately NOT inherited from the ambient
# environment. The shell may carry DB_* / DOPPLER vars that point at a real
# (e.g. callisto4_dev) database; this harness must only ever touch the local
# throwaway Postgres. Override by editing these lines, not via env.
PG_CONTAINER="evs-pg"     # docker container running the throwaway Postgres
DB_HOST="localhost"
DB_PORT="5433"
DB_USER="postgres"
DB_PASSWORD="devroot"
DB_NAME="hht_diary"
PORTAL_PORT="8084"

if ! command -v flutter >/dev/null 2>&1; then
  export PATH="$HOME/flutter-sdk/flutter/bin:$PATH"
fi

echo "==> Resetting database ($PG_CONTAINER:$DB_NAME) for a clean seed"
docker exec "$PG_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
  -c "drop schema public cascade; create schema public;" >/dev/null

echo "==> (Re)starting portal_server_evs on :$PORTAL_PORT (durable Postgres backend)"
# Stop any server already on the port, then boot a fresh one that recreates the
# event-store schema and re-seeds the DevSeedRaveClient participants.
fuser -k "${PORTAL_PORT}/tcp" 2>/dev/null || true
sleep 2
( cd "$SERVER_DIR" && env -u RAVE_UAT_USERNAME -u RAVE_UAT_PASSWORD -u RAVE_UAT_BASE_URL \
    DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" DB_USER="$DB_USER" DB_PASSWORD="$DB_PASSWORD" \
    DB_NAME="$DB_NAME" DB_SSL=false PORT="$PORTAL_PORT" PORTAL_AUTH_MODE=dev \
    dart run bin/server.dart > /tmp/portal_evs_e2e.log 2>&1 & )
for _ in $(seq 1 40); do
  curl -s "http://localhost:${PORTAL_PORT}/health" 2>/dev/null | grep -q ok && break
  sleep 1
done
echo "    portal_server_evs ready"

echo "==> Building the portal web bundle (pointed at the live server)"
( cd "$APP_DIR" && flutter pub get >/dev/null && \
    flutter build web --release \
      --dart-define=PORTAL_SERVER_URL="http://localhost:${PORTAL_PORT}" )

echo "==> Running Playwright"
cd "$APP_DIR/e2e"
npm install >/dev/null
npx playwright test "$@"
status=$?

echo "==> Stopping the e2e portal server"
fuser -k "${PORTAL_PORT}/tcp" 2>/dev/null || true
exit $status
