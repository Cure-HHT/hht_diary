#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00046: Uptime Monitoring
#   REQ-o00047: Performance Monitoring
#
# Deployment Doctor — Portal Server
# Diagnoses deployment health for the sponsor portal Cloud Run service.
#
# Usage:
#   ./deployment-doctor.sh                    # auto-discover via gcloud
#   ./deployment-doctor.sh --url <url>        # specify service URL directly
#   ./deployment-doctor.sh --env dev          # target a specific environment
#   ./deployment-doctor.sh --project <id>     # specify GCP project
#   ./deployment-doctor.sh --verbose          # show full response bodies

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
SERVICE_NAME="portal-server"
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
header "Portal Server Deployment Doctor"
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

# CORS headers
CORS_RESPONSE=$(curl -s -I -X OPTIONS \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: GET" \
  --max-time 10 "$SERVICE_URL/health" 2>&1 || true)

if echo "$CORS_RESPONSE" | grep -qi "access-control-allow-origin"; then
  pass "CORS headers present"
else
  warn "CORS headers not found on OPTIONS /health"
fi

# ── 3. Version Verification ───────────────────────────────────────
header "3. Version Verification"

# Get local pubspec versions from git main
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

LOCAL_PORTAL_SERVER_VER=$(grep '^version:' "$REPO_ROOT/apps/sponsor-portal/portal_server/pubspec.yaml" 2>/dev/null | sed 's/version: //' || echo "unknown")
LOCAL_PORTAL_FUNCTIONS_VER=$(grep '^version:' "$REPO_ROOT/apps/sponsor-portal/portal_functions/pubspec.yaml" 2>/dev/null | sed 's/version: //' || echo "unknown")
LOCAL_OTEL_COMMON_VER=$(grep '^version:' "$REPO_ROOT/apps/common-dart/otel_common/pubspec.yaml" 2>/dev/null | sed 's/version: //' || echo "unknown")

info "Local versions (from working tree):"
info "  portal_server:    $LOCAL_PORTAL_SERVER_VER"
info "  portal_functions: $LOCAL_PORTAL_FUNCTIONS_VER"
info "  otel_common:      $LOCAL_OTEL_COMMON_VER"

# Get Cloud Run revision info
if [[ -n "$PROJECT" ]]; then
  REVISION_INFO=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" --project="$PROJECT" \
    --format='json(status.latestReadyRevisionName,status.latestCreatedRevisionName,metadata.annotations)' \
    2>/dev/null || echo "{}")

  LATEST_REVISION=$(echo "$REVISION_INFO" | jq -r '.status.latestReadyRevisionName // "unknown"' 2>/dev/null || echo "unknown")
  info "Cloud Run revision: $LATEST_REVISION"

  # Get revision details
  if [[ "$LATEST_REVISION" != "unknown" ]]; then
    REV_IMAGE=$(gcloud run revisions describe "$LATEST_REVISION" \
      --region="$REGION" --project="$PROJECT" \
      --format='value(spec.containers[0].image)' 2>/dev/null || echo "unknown")
    info "Container image: $REV_IMAGE"

    REV_CREATE_TIME=$(gcloud run revisions describe "$LATEST_REVISION" \
      --region="$REGION" --project="$PROJECT" \
      --format='value(metadata.creationTimestamp)' 2>/dev/null || echo "unknown")
    info "Deployed at: $REV_CREATE_TIME"

    # Check if deployment is recent (within 24h)
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
  "$SERVICE_URL/api/v1/portal/config/sponsor?sponsorId=callisto" 2>&1 || true)
SPONSOR_STATUS=$(echo "$SPONSOR_RESPONSE" | tail -1)
SPONSOR_BODY=$(echo "$SPONSOR_RESPONSE" | head -1)

if [[ "$SPONSOR_STATUS" == "200" ]]; then
  pass "GET /api/v1/portal/config/sponsor?sponsorId=callisto → 200"
  if [[ "$VERBOSE" == "true" ]]; then
    info "Response: $(echo "$SPONSOR_BODY" | jq -c '.' 2>/dev/null || echo "$SPONSOR_BODY")"
  fi
else
  warn "GET /api/v1/portal/config/sponsor → HTTP $SPONSOR_STATUS"
fi

# Auth endpoint (should return 401 without token)
AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 10 \
  "$SERVICE_URL/api/v1/portal/me" 2>&1 || true)
AUTH_STATUS=$(echo "$AUTH_RESPONSE" | tail -1)

if [[ "$AUTH_STATUS" == "401" ]]; then
  pass "GET /api/v1/portal/me without auth → 401 (correct)"
elif [[ "$AUTH_STATUS" == "500" ]]; then
  fail "GET /api/v1/portal/me → 500 (server error)"
else
  warn "GET /api/v1/portal/me → HTTP $AUTH_STATUS (expected 401)"
fi

# Identity config (public endpoint)
IDENTITY_RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 10 \
  "$SERVICE_URL/api/v1/portal/config/identity" 2>&1 || true)
IDENTITY_STATUS=$(echo "$IDENTITY_RESPONSE" | tail -1)

if [[ "$IDENTITY_STATUS" == "200" ]]; then
  pass "GET /api/v1/portal/config/identity → 200"
else
  warn "GET /api/v1/portal/config/identity → HTTP $IDENTITY_STATUS"
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

    # Check for trace correlation fields
    TRACED_COUNT=$(echo "$RECENT_LOGS" | jq '[.[] | select(.jsonPayload."logging.googleapis.com/trace" != null)] | length' 2>/dev/null || echo "0")
    if [[ "$TRACED_COUNT" -gt 0 ]]; then
      pass "Trace-correlated logs: $TRACED_COUNT entries with trace IDs"
    else
      warn "No trace-correlated logs found — OTel trace integration may not be active"
    fi
  else
    warn "No recent logs found in Cloud Logging (last 1h)"
  fi

  # Check Cloud Trace for recent traces
  info "Checking Cloud Trace for recent spans..."
  TRACE_CHECK=$(gcloud traces list \
    --project="$PROJECT" --limit=3 \
    --format='json' 2>/dev/null || echo "error")

  if [[ "$TRACE_CHECK" == "error" ]]; then
    warn "Could not query Cloud Trace (may need cloudtrace.traces.list permission)"
  elif [[ $(echo "$TRACE_CHECK" | jq 'length' 2>/dev/null || echo "0") -gt 0 ]]; then
    pass "Cloud Trace: recent traces found"
  else
    warn "No recent traces found in Cloud Trace"
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

  # Check for Doppler env vars
  DOPPLER_PROJECT=$(echo "$SVC_JSON" | jq -r '.spec.template.spec.containers[0].env[]? | select(.name=="DOPPLER_PROJECT_ID") | .value // empty' 2>/dev/null || echo "")
  DOPPLER_CONFIG=$(echo "$SVC_JSON" | jq -r '.spec.template.spec.containers[0].env[]? | select(.name=="DOPPLER_CONFIG_NAME") | .value // empty' 2>/dev/null || echo "")

  if [[ -n "$DOPPLER_PROJECT" ]]; then
    pass "Doppler configured: project=$DOPPLER_PROJECT config=$DOPPLER_CONFIG"
  else
    warn "Doppler environment variables not found"
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
