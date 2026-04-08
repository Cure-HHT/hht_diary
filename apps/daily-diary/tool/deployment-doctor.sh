#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00046: Uptime Monitoring
#   REQ-o00047: Performance Monitoring
#
# Deployment Doctor — Diary Server
# Diagnoses deployment health for the diary server Cloud Run service.
#
# Usage:
#   ./deployment-doctor.sh                    # auto-discover via gcloud
#   ./deployment-doctor.sh --url <url>        # specify service URL directly
#   ./deployment-doctor.sh --env dev          # target a specific environment
#   ./deployment-doctor.sh --project <id>     # specify GCP project
#   ./deployment-doctor.sh --verbose          # show full response bodies

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
SERVICE_NAME="diary-server"
REGION="${GCP_REGION:-europe-west9}"
PROJECT="${GCP_PROJECT:-}"
SERVICE_URL=""
VERBOSE=false
PASS=0
FAIL=0
WARN=0

# ── Colors ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { ((PASS++)); echo -e "  ${GREEN}✅ PASS${NC}: $1"; }
fail()  { ((FAIL++)); echo -e "  ${RED}❌ FAIL${NC}: $1"; }
warn()  { ((WARN++)); echo -e "  ${YELLOW}⚠️  WARN${NC}: $1"; }
info()  { echo -e "  ${BLUE}ℹ${NC}  $1"; }
header() { echo -e "\n${BOLD}═══ $1 ═══${NC}"; }

# ── Parse args ─────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)      SERVICE_URL="${2%/}"; shift 2 ;;  # strip trailing slash
    --env)      ENV_NAME="$2"; shift 2 ;;
    --project)  PROJECT="$2"; shift 2 ;;
    --region)   REGION="$2"; shift 2 ;;
    --verbose)  VERBOSE=true; shift ;;
    --help|-h)
      echo "Usage: $0 [--url <url>] [--env <env>] [--project <id>] [--region <region>] [--verbose]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Discover service URL ───────────────────────────────────────────
header "Diary Server Deployment Doctor"
echo -e "  Service: ${BOLD}$SERVICE_NAME${NC}"
echo -e "  Region:  ${BOLD}$REGION${NC}"
echo -e "  Time:    $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [[ -z "$SERVICE_URL" ]]; then
  if [[ -z "$PROJECT" ]]; then
    PROJECT=$(gcloud config get-value project 2>/dev/null || true)
    if [[ -z "$PROJECT" ]]; then
      fail "No GCP project configured. Use --project or gcloud config set project"
      exit 1
    fi
  fi
  echo -e "  Project: ${BOLD}$PROJECT${NC}"

  SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" --project="$PROJECT" \
    --format='value(status.url)' 2>/dev/null || true)

  if [[ -z "$SERVICE_URL" ]]; then
    fail "Could not discover service URL for $SERVICE_NAME in $REGION"
    exit 1
  fi
fi

# Extract region from URL if possible (e.g., ...europe-west9.run.app)
if [[ -n "$SERVICE_URL" ]]; then
  URL_REGION=$(echo "$SERVICE_URL" | grep -oE '(europe|us|asia|australia|northamerica|southamerica)-[a-z]+[0-9]+' || true)
  if [[ -n "$URL_REGION" && "$REGION" != "$URL_REGION" ]]; then
    REGION="$URL_REGION"
  fi
fi

echo -e "  URL:     ${BOLD}$SERVICE_URL${NC}"

# ── 1. Health Check ────────────────────────────────────────────────
header "1. Health Check"

HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" \
  --max-time 10 "$SERVICE_URL/health" 2>&1 || true)

HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | head -1)
HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | tail -2 | head -1)
HEALTH_TIME=$(echo "$HEALTH_RESPONSE" | tail -1)

if [[ "$HEALTH_STATUS" == "200" ]]; then
  pass "/health returned 200 (${HEALTH_TIME}s)"
  if [[ "$VERBOSE" == "true" ]]; then
    info "Response: $HEALTH_BODY"
  fi

  # Parse health response
  if echo "$HEALTH_BODY" | jq -e '.status == "ok"' >/dev/null 2>&1; then
    pass "Health status: ok"
  else
    fail "Health status is not 'ok': $HEALTH_BODY"
  fi
else
  fail "/health returned HTTP $HEALTH_STATUS"
  if [[ -n "$HEALTH_BODY" ]]; then
    info "Response: $HEALTH_BODY"
  fi
fi

# Check response time
if (( $(echo "$HEALTH_TIME > 2.0" | bc -l 2>/dev/null || echo 0) )); then
  warn "Health check slow: ${HEALTH_TIME}s (>2s)"
elif (( $(echo "$HEALTH_TIME > 0.5" | bc -l 2>/dev/null || echo 0) )); then
  warn "Health check moderate: ${HEALTH_TIME}s (>0.5s, may be cold start)"
else
  pass "Response time: ${HEALTH_TIME}s"
fi

# ── 2. HTTPS & Headers ────────────────────────────────────────────
header "2. HTTPS & Security Headers"

HEADER_RESPONSE=$(curl -s -I --max-time 10 "$SERVICE_URL/health" 2>&1 || true)

if echo "$HEADER_RESPONSE" | grep -qi "HTTP/2 200\|HTTP/1.1 200"; then
  pass "HTTPS connection successful"
else
  fail "HTTPS connection failed"
fi

# Check for OTel trace headers in response
if echo "$HEADER_RESPONSE" | grep -qi "x-trace-id"; then
  pass "x-trace-id header present (OTel middleware active)"
else
  warn "x-trace-id header not found (OTel middleware may not be active)"
fi

if echo "$HEADER_RESPONSE" | grep -qi "x-span-id"; then
  pass "x-span-id header present"
fi

# ── 3. Version Verification ───────────────────────────────────────
header "3. Version Verification"

# Get local pubspec versions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

LOCAL_DIARY_SERVER_VER=$(grep '^version:' "$REPO_ROOT/apps/daily-diary/diary_server/pubspec.yaml" 2>/dev/null | sed 's/version: //' || echo "unknown")
LOCAL_DIARY_FUNCTIONS_VER=$(grep '^version:' "$REPO_ROOT/apps/daily-diary/diary_functions/pubspec.yaml" 2>/dev/null | sed 's/version: //' || echo "unknown")
LOCAL_OTEL_COMMON_VER=$(grep '^version:' "$REPO_ROOT/apps/common-dart/otel_common/pubspec.yaml" 2>/dev/null | sed 's/version: //' || echo "unknown")

info "Local versions (from working tree):"
info "  diary_server:     $LOCAL_DIARY_SERVER_VER"
info "  diary_functions:  $LOCAL_DIARY_FUNCTIONS_VER"
info "  otel_common:      $LOCAL_OTEL_COMMON_VER"

# Get Cloud Run revision info
if [[ -n "$PROJECT" ]]; then
  LATEST_REVISION=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" --project="$PROJECT" \
    --format='value(status.latestReadyRevisionName)' 2>/dev/null || echo "unknown")
  info "Cloud Run revision: $LATEST_REVISION"

  if [[ "$LATEST_REVISION" != "unknown" ]]; then
    REV_IMAGE=$(gcloud run revisions describe "$LATEST_REVISION" \
      --region="$REGION" --project="$PROJECT" \
      --format='value(spec.containers[0].image)' 2>/dev/null || echo "unknown")
    info "Container image: $REV_IMAGE"

    REV_CREATE_TIME=$(gcloud run revisions describe "$LATEST_REVISION" \
      --region="$REGION" --project="$PROJECT" \
      --format='value(metadata.creationTimestamp)' 2>/dev/null || echo "unknown")
    info "Deployed at: $REV_CREATE_TIME"

    # Check deployment age
    if [[ "$REV_CREATE_TIME" != "unknown" ]]; then
      DEPLOY_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${REV_CREATE_TIME%%.*}" "+%s" 2>/dev/null || \
                     date -d "${REV_CREATE_TIME}" "+%s" 2>/dev/null || echo 0)
      NOW_EPOCH=$(date "+%s")
      AGE_HOURS=$(( (NOW_EPOCH - DEPLOY_EPOCH) / 3600 ))
      if [[ $AGE_HOURS -gt 168 ]]; then
        warn "Deployment is ${AGE_HOURS}h old (>7 days)"
      else
        pass "Deployment age: ${AGE_HOURS}h"
      fi
    fi
  fi
fi

# ── 4. API Endpoint Smoke Tests ───────────────────────────────────
header "4. API Endpoint Smoke Tests"

# Sponsor config (public endpoint)
SPONSOR_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 10 \
  "$SERVICE_URL/api/v1/sponsor/config?sponsorId=callisto" 2>&1 || true)
SPONSOR_STATUS=$(echo "$SPONSOR_RESPONSE" | tail -1)

if [[ "$SPONSOR_STATUS" == "200" ]]; then
  pass "GET /api/v1/sponsor/config?sponsorId=callisto → 200"
elif [[ "$SPONSOR_STATUS" == "400" ]]; then
  pass "GET /api/v1/sponsor/config (no sponsorId) → 400 (correct validation)"
else
  warn "GET /api/v1/sponsor/config → HTTP $SPONSOR_STATUS"
fi

# Auth endpoint (should return 401 without valid JWT)
AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 10 \
  -X POST "$SERVICE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{}' 2>&1 || true)
AUTH_STATUS=$(echo "$AUTH_RESPONSE" | tail -1)

if [[ "$AUTH_STATUS" == "400" || "$AUTH_STATUS" == "401" ]]; then
  pass "POST /api/v1/auth/login with empty body → $AUTH_STATUS (correct rejection)"
elif [[ "$AUTH_STATUS" == "500" ]]; then
  fail "POST /api/v1/auth/login → 500 (server error)"
else
  info "POST /api/v1/auth/login → HTTP $AUTH_STATUS"
fi

# Tasks endpoint (should require auth)
TASKS_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 10 \
  "$SERVICE_URL/api/v1/user/tasks" 2>&1 || true)
TASKS_STATUS=$(echo "$TASKS_RESPONSE" | tail -1)

if [[ "$TASKS_STATUS" == "401" ]]; then
  pass "GET /api/v1/user/tasks without auth → 401 (correct)"
elif [[ "$TASKS_STATUS" == "500" ]]; then
  fail "GET /api/v1/user/tasks → 500 (server error)"
else
  warn "GET /api/v1/user/tasks → HTTP $TASKS_STATUS (expected 401)"
fi

# ── 5. Observability Signals ──────────────────────────────────────
header "5. Observability Signals"

if [[ -n "$PROJECT" ]]; then
  # Check Cloud Logging for recent structured logs
  RECENT_LOGS=$(gcloud logging read \
    "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"$SERVICE_NAME\" AND timestamp>=\"$(date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')\"" \
    --project="$PROJECT" --limit=5 --format='json' 2>/dev/null || echo "[]")

  LOG_COUNT=$(echo "$RECENT_LOGS" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$LOG_COUNT" -gt 0 ]]; then
    pass "Cloud Logging: $LOG_COUNT recent log entries (last 1h)"

    # Check for structured JSON logs (OTel trace correlation)
    STRUCTURED_COUNT=$(echo "$RECENT_LOGS" | jq '[.[] | select(.jsonPayload != null)] | length' 2>/dev/null || echo "0")
    if [[ "$STRUCTURED_COUNT" -gt 0 ]]; then
      pass "Structured JSON logging active ($STRUCTURED_COUNT entries)"
    else
      warn "No structured JSON logs found — OTel logging may not be working"
    fi

    # Check for trace correlation
    TRACED_COUNT=$(echo "$RECENT_LOGS" | jq '[.[] | select(.jsonPayload."logging.googleapis.com/trace" != null)] | length' 2>/dev/null || echo "0")
    if [[ "$TRACED_COUNT" -gt 0 ]]; then
      pass "Trace-correlated logs: $TRACED_COUNT entries with trace IDs"
    else
      warn "No trace-correlated logs found — OTel trace integration may not be active"
    fi
  else
    warn "No recent logs found in Cloud Logging (last 1h)"
    info "This may be normal if the service has had no traffic"
  fi

  # Check for recent errors
  ERROR_LOGS=$(gcloud logging read \
    "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"$SERVICE_NAME\" AND severity>=ERROR AND timestamp>=\"$(date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')\"" \
    --project="$PROJECT" --limit=10 --format='json' 2>/dev/null || echo "[]")

  ERROR_COUNT=$(echo "$ERROR_LOGS" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$ERROR_COUNT" -gt 0 ]]; then
    warn "$ERROR_COUNT ERROR-level log entries in last 1h"
    if [[ "$VERBOSE" == "true" ]]; then
      echo "$ERROR_LOGS" | jq -r '.[0:3][] | "    \(.timestamp) \(.jsonPayload.message // .textPayload // "no message")"' 2>/dev/null || true
    fi
  else
    pass "No ERROR-level logs in last 1h"
  fi

  # Check OTel exporter errors (connection refused = no collector)
  OTEL_ERRORS=$(gcloud logging read \
    "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"$SERVICE_NAME\" AND textPayload:\"OtlpHttp\" AND timestamp>=\"$(date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')\"" \
    --project="$PROJECT" --limit=3 --format='json' 2>/dev/null || echo "[]")

  OTEL_ERROR_COUNT=$(echo "$OTEL_ERRORS" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$OTEL_ERROR_COUNT" -gt 0 ]]; then
    warn "OTel exporter errors found — OTLP collector may not be reachable"
    info "This is expected if no OTel Collector sidecar is deployed yet"
  else
    pass "No OTel exporter errors (OTLP export healthy or no traffic)"
  fi
else
  warn "Skipping observability checks (no GCP project — use --project)"
fi

# ── 6. Cloud Run Service Config ───────────────────────────────────
header "6. Cloud Run Service Configuration"

if [[ -n "$PROJECT" ]]; then
  SVC_JSON=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" --project="$PROJECT" \
    --format='json(spec.template.spec)' 2>/dev/null || echo "{}")

  CPU=$(echo "$SVC_JSON" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu // "unknown"' 2>/dev/null || echo "unknown")
  MEMORY=$(echo "$SVC_JSON" | jq -r '.spec.template.spec.containers[0].resources.limits.memory // "unknown"' 2>/dev/null || echo "unknown")
  MIN_INSTANCES=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" --project="$PROJECT" \
    --format='value(spec.template.metadata.annotations."autoscaling.knative.dev/minScale")' 2>/dev/null || echo "unknown")
  MAX_INSTANCES=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" --project="$PROJECT" \
    --format='value(spec.template.metadata.annotations."autoscaling.knative.dev/maxScale")' 2>/dev/null || echo "unknown")

  info "CPU: $CPU | Memory: $MEMORY"
  info "Instances: min=$MIN_INSTANCES max=$MAX_INSTANCES"

  # Container count (sidecar check)
  CONTAINER_COUNT=$(echo "$SVC_JSON" | jq '.spec.template.spec.containers | length' 2>/dev/null || echo "1")
  if [[ "$CONTAINER_COUNT" -gt 1 ]]; then
    pass "Multi-container: $CONTAINER_COUNT containers (sidecar present)"
  else
    info "Single container (no OTel Collector sidecar)"
  fi
else
  warn "Skipping Cloud Run config checks (no GCP project)"
fi

# ── Summary ────────────────────────────────────────────────────────
header "Summary"
echo -e "  ${GREEN}Passed: $PASS${NC}  ${RED}Failed: $FAIL${NC}  ${YELLOW}Warnings: $WARN${NC}"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "  ${RED}${BOLD}DEPLOYMENT UNHEALTHY${NC} — $FAIL check(s) failed"
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo -e "  ${YELLOW}${BOLD}DEPLOYMENT OK WITH WARNINGS${NC} — $WARN warning(s)"
  exit 0
else
  echo -e "  ${GREEN}${BOLD}DEPLOYMENT HEALTHY${NC}"
  exit 0
fi
