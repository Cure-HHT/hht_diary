#!/usr/bin/env bash
# Local-stack variant of /app/start.sh baked into portal-final.
#
# Differences from production start.sh (deployment/scripts/start.sh):
#   - doppler run is invoked with --preserve-env so compose-level env
#     vars (DB_HOST, FIREBASE_AUTH_EMULATOR_HOST, PORTAL_IDENTITY_*, etc.)
#     beat the real dev secrets from Doppler.
#   - banner labels this as LOCAL-STACK.
#   - backend readiness timeout lengthened to 60s because cold starts
#     on a laptop can be slower than on Cloud Run.
#
# Bind-mounted into portal-final at /app/start.sh by docker-compose.yml.

set -euo pipefail

if [ -z "${_UNBUFFERED:-}" ]; then
    export _UNBUFFERED=1
    exec stdbuf -o0 -eL "$0" "$@"
fi

export PUBLIC_PORT="${PORT:-8080}"
export BACKEND_PORT=8081

if [ -z "${DOPPLER_TOKEN:-}" ]; then
  echo "FATAL: DOPPLER_TOKEN is not set in the container env."
  echo "Run the stack via: doppler run --config dev -- ./local-stack portal"
  exit 2
fi

# local-stack ships only the emulator bundle (FIREBASE_AUTH_EMULATOR_HOST baked)
# and the CSP relax below assumes the emulator, so ENVIRONMENT must be exactly
# `local`. Any other value would mis-report the environment to the SPA and skip
# the CSP patch, breaking emulator auth.
if [ "${ENVIRONMENT:-}" != "local" ]; then
  echo "FATAL: local-stack requires ENVIRONMENT=local (got '${ENVIRONMENT:-}')."
  echo "compose (docker-compose.yml) should set ENVIRONMENT=local for the portal."
  exit 1
fi

# The web bundle is environment-independent and served directly from /app/web
# (the local-stack image bakes FIREBASE_AUTH_EMULATOR_HOST so the SPA targets
# the emulator). There is no per-flavor directory to select.

# CUR-1263: relax the production CSP so the SPA (compiled with
# FIREBASE_AUTH_EMULATOR_HOST=localhost:9099) is allowed to call the
# emulator over plain http. This sed only fires inside the local-stack's
# portal-start-local.sh, never in deployment/scripts/start.sh.
if [ "$ENVIRONMENT" = "local" ]; then
  sed -i \
    "s|connect-src 'self' |connect-src 'self' http://localhost:9099 ws://localhost:9099 |" \
    /etc/nginx/nginx.conf
  echo "[local-stack] CSP connect-src patched to allow firebase emulator at localhost:9099"
fi

# CUR-1263: bind the sponsor-content overlay route in nginx.conf to
# this container's SPONSOR_ID. Same step as production start.sh; kept
# in sync because portal-start-local.sh shadows /app/start.sh in the
# local-stack and nginx.conf ships with __SPONSOR_ID__ as a placeholder.
if [ -n "${SPONSOR_ID:-}" ]; then
  sed -i "s|__SPONSOR_ID__|${SPONSOR_ID}|g" /etc/nginx/nginx.conf
  echo "[local-stack] nginx sponsor-content route bound to SPONSOR_ID=${SPONSOR_ID}"
else
  echo "[local-stack] WARNING: SPONSOR_ID not set; sponsor logos will 404"
fi

cat <<BANNER
==========================================
Reference Portal — LOCAL-STACK
==========================================
  nginx port:           ${PUBLIC_PORT}
  backend port:         ${BACKEND_PORT}
  environment:          ${ENVIRONMENT}
  DB_HOST:              ${DB_HOST:-<unset — expect crash>}
  FIREBASE_AUTH_HOST:   ${FIREBASE_AUTH_EMULATOR_HOST:-<unset>}
  IDENTITY_PROJECT_ID:  ${PORTAL_IDENTITY_PROJECT_ID:-<unset>}
==========================================
BANNER

unset PORT

# --preserve-env is the critical local-only bit: without it, doppler's dev
# secrets would clobber POSTGRES_HOST=postgres with the Cloud SQL host.
#
# CUR-1264: EDC module selection. Source of truth is
# deployment/base-config.json::edc_module, propagated as the EDC_MODULE env
# var via the local-stack CLI.
#
#   "mock" (default) - strip RAVE_UAT_* and set RAVE_MOCK_MODE so the portal
#     activates portal_functions' MockRaveClient (canned 3 sites + 3 subjects
#     by default; flip RAVE_MOCK_MODE=auth_fail or network_fail before launch
#     to exercise the CUR-1361 lockout state machine end-to-end without a
#     live Rave endpoint).
#   "rave" - let creds through for live RAVE work. Truncate seeded rows to
#     force a real sync.
#
# CUR-1361: RAVE_MOCK_MODE=ok is the default in mock mode so that
# /api/v1/portal/sites and /api/v1/portal/participants return live-shaped
# Rave-synced data instead of falling through to the seeded baseline. The
# seed_local_stack.sql edc_synced_at=now() trick still short-circuits the
# initial shouldSync*, so the mock only fires once the stale TTL elapses or
# the user manually clicks Refresh on the Dev Admin Rave Sync card.
echo "Starting portal backend on 127.0.0.1:${BACKEND_PORT} (EDC_MODULE=${EDC_MODULE:-mock} RAVE_MOCK_MODE=${RAVE_MOCK_MODE:-ok})"
if [ "${EDC_MODULE:-mock}" = "rave" ]; then
    HOST=127.0.0.1 PORT=${BACKEND_PORT} doppler run --preserve-env -- /app/portal-server &
else
    HOST=127.0.0.1 PORT=${BACKEND_PORT} doppler run --preserve-env -- \
        env -u RAVE_UAT_URL -u RAVE_UAT_USERNAME -u RAVE_UAT_PWD \
        RAVE_MOCK_MODE="${RAVE_MOCK_MODE:-ok}" \
        /app/portal-server &
fi
BACKEND_PID=$!

for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${BACKEND_PORT}/health" >/dev/null; then
    echo "Backend is ready"
    break
  fi
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo "FATAL: Backend process exited during startup"
    exit 7
  fi
  echo "Waiting for backend..."
  sleep 1
done

if ! curl -fsS "http://127.0.0.1:${BACKEND_PORT}/health" >/dev/null 2>&1; then
  echo "FATAL: Backend failed to respond to health check after 60s"
  exit 8
fi

echo "Starting gRPC health server on port 50051..."
/app/grpc_health_server &
GRPC_HEALTH_PID=$!

echo "Starting nginx on ${PUBLIC_PORT}"
nginx -g 'daemon off;' &
NGINX_PID=$!

term_handler() {
  echo "Shutting down..."
  kill -TERM "${GRPC_HEALTH_PID}" 2>/dev/null || true
  kill -TERM "${BACKEND_PID}" 2>/dev/null || true
  kill -TERM "${NGINX_PID}" 2>/dev/null || true
  wait "${GRPC_HEALTH_PID}" 2>/dev/null || true
  wait "${BACKEND_PID}" 2>/dev/null || true
  wait "${NGINX_PID}" 2>/dev/null || true
}
trap term_handler TERM INT

wait -n "${BACKEND_PID}" "${NGINX_PID}" "${GRPC_HEALTH_PID}"
EXIT_CODE=$?
echo "One process exited (${EXIT_CODE}), shutting down..."
term_handler
exit "${EXIT_CODE}"
