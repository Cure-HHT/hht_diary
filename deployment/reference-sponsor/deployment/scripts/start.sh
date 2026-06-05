#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-d00058: Secrets Management via Doppler
#   REQ-o00002: Environment-Specific Configuration Management
#
# Startup script for Callisto Portal container.
# Runs Dart API server, gRPC health server, and nginx together.

set -euo pipefail

# Re-exec with unbuffered stdout/stderr so Cloud Run captures all log output
if [ -z "${_UNBUFFERED:-}" ]; then
    export _UNBUFFERED=1
    exec stdbuf -o0 -eL "$0" "$@"
fi

export PUBLIC_PORT="${PORT:-8080}"
export BACKEND_PORT=8081

# ── Validate required Doppler config ─────────────────────────
if [ -z "${DOPPLER_TOKEN:-}" ]; then
  echo "FATAL: DOPPLER_TOKEN is not set."
  echo "Cloud Run must set DOPPLER_TOKEN at deploy time."
  exit 2
fi

# ── Validate ENVIRONMENT (dev/qa/uat/prod) ───────────────────
# The web bundle is environment-independent and served directly from /app/web;
# it discovers its environment at runtime from the server. The portal-server
# reads ENVIRONMENT and reports it via /api/v1/portal/config/identity, so the
# SPA resolves its banner, dev-tools, and prod gating.
#
# Validate against the known set and fail closed. With the single bundle there
# is no longer a per-flavor /app/web-$ENVIRONMENT directory whose absence would
# implicitly reject a typo, so an unrecognized value (e.g. "prodd") would
# otherwise start fine and silently resolve to the dev profile — banner and
# dev-tools visible in what was meant to be prod. Reject it up front.
case "${ENVIRONMENT:-}" in
  dev | qa | uat | prod) ;;
  "")
    echo "FATAL: ENVIRONMENT is not set."
    echo "Cloud Run must set ENVIRONMENT=dev|qa|uat|prod at deploy time."
    exit 1
    ;;
  *)
    echo "FATAL: ENVIRONMENT='${ENVIRONMENT}' is not a recognized deploy environment (dev|qa|uat|prod)."
    echo "Refusing to start so a typo cannot silently resolve to the dev profile."
    exit 1
    ;;
esac

# Bind the sponsor-content overlay route in nginx.conf to this container's
# SPONSOR_ID. The placeholder __SPONSOR_ID__ in the location block is
# inert until rewritten; if SPONSOR_ID is unset (misconfigured deploy),
# we leave the placeholder so the route is a no-op rather than aliasing
# to /app/sponsor-content//portal/.
if [ -n "${SPONSOR_ID:-}" ]; then
  sed -i "s|__SPONSOR_ID__|${SPONSOR_ID}|g" /etc/nginx/nginx.conf
  echo "nginx sponsor-content route bound to SPONSOR_ID=${SPONSOR_ID}"
else
  echo "WARNING: SPONSOR_ID is not set; sponsor-content assets (logos) will 404"
fi

echo "=========================================="
echo "Callisto Portal Startup"
echo "=========================================="
echo "  Cloud Run PORT (nginx): ${PUBLIC_PORT}"
echo "  Backend forced port:    ${BACKEND_PORT}"
echo "  Environment:            ${ENVIRONMENT}"
echo "  Web root:               $(readlink -f /app/web)"

# Output component versions (generated during Docker build)
if [ -f /app/VERSIONS ]; then
  echo "  ── Component Versions ──"
  while IFS='=' read -r key value; do
    printf '  %-22s%s\n' "$key:" "$value"
  done < /app/VERSIONS
fi
echo "=========================================="

unset PORT

# ── Start Dart API server ────────────────────────────────────
echo "Starting portal backend on 127.0.0.1:${BACKEND_PORT}"
HOST=127.0.0.1 PORT=${BACKEND_PORT} doppler run -- /app/portal-server &
BACKEND_PID=$!

for i in $(seq 1 30); do
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
  echo "FATAL: Backend failed to respond to health check after 30s"
  exit 8
fi

# ── Start gRPC health server ────────────────────────────────
# Responds to Cloud Run gRPC liveness probes on port 50051.
# nginx proxies /grpc.health.v1.Health from 8080 to this server.
echo "Starting gRPC health server on port 50051..."
/app/grpc_health_server &
GRPC_HEALTH_PID=$!

# ── Start nginx ──────────────────────────────────────────────
echo "Starting nginx on ${PUBLIC_PORT} (HTTP/2)"
nginx -g 'daemon off;' &
NGINX_PID=$!

# ── Signal handling ──────────────────────────────────────────
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
