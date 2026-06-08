#!/usr/bin/env bash
# Run the FULL EVS participant-lifecycle e2e (tests/p1-lifecycle.spec.ts)
# against a running local-stack EVS portal.
#
# Unlike scripts/run-e2e.sh (which builds OFFLINE against a dead port for the
# font/link-redeem specs), the lifecycle spec drives the real diary web UI
# against the live single-backend `portal_server_evs` (portal + mobile diary
# API on one origin) and dispatches the portal-side Study-Coordinator actions
# (Start Trial / Disconnect / Mark-Not-Participating) at the correct moments
# relative to the trial-start sync watermark.
#
# This script:
#   1. Verifies the local-stack portal is up (PORTAL, default :8080).
#   2. Provisions, idempotently, via the dev-auth action API: SystemOperator
#      -> Administrator -> Study Coordinator(site-1), then issues a FRESH
#      single-use linking code for the participant (ACT-PAT-001 returns it in
#      its result; no need to read it back from view_rows).
#   3. Builds the diary Flutter-web bundle pointed at PORTAL.
#   4. Runs the lifecycle spec (Playwright serves ../build/web on :8000).
#   5. Verifies the sync watermark gated correctly: the post-trial epistaxis
#      entries reached the event store; the pre-link entries did not.
#
# Auth model: local-stack runs with PORTAL_AUTH_MODE unset => dev mode, where
# the bearer is simply the user's email (roles resolved from user_role_scopes).
# Against a deployed SESSION-auth portal, skip provisioning here and instead
# pass a minted session token via SC_BEARER plus a pre-issued P1_CODE (see
# e2e/LIFECYCLE.md, "Running against a deployed portal").
#
# Usage:
#   apps/daily-diary/clinical_diary/scripts/run-lifecycle-e2e.sh [playwright args]
#
# Env overrides:
#   PORTAL        portal+diary API base               (default http://localhost:8080)
#   PG_CONTAINER  local-stack postgres container       (default reference-local-postgres-1)
#   SITE          site id                              (default site-1)
#   PARTICIPANT   participant id (must exist in EDC seed)  (default REF-001-001)
#   SC_BEARER     skip provisioning; use this SC creds (default e2e-sc@reference.local)
#   P1_CODE       skip code issuance; use this code    (default: freshly issued)
#
# NOTE: the lifecycle leaves PARTICIPANT in a terminal not-participating state
# and consumes its code. Re-running against the same participant on the same DB
# accumulates state; for a clean slate use a fresh DB:
#   ./deployment/local-stack/local-stack down && ./deployment/local-stack/local-stack portal
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

PORTAL="${PORTAL:-http://localhost:8080}"
PG_CONTAINER="${PG_CONTAINER:-reference-local-postgres-1}"
SITE="${SITE:-site-1}"
PARTICIPANT="${PARTICIPANT:-REF-001-001}"
SYSOP="${SYSOP:-dev@reference.local}"
RUN_ID="$$"   # unique per invocation: namespaces fresh idempotency keys

# --- flutter on PATH (this host keeps it under flutter-sdk/) ---
if ! command -v flutter >/dev/null 2>&1; then
  if [[ -x "$HOME/flutter-sdk/flutter/bin/flutter" ]]; then
    export PATH="$HOME/flutter-sdk/flutter/bin:$PATH"
  else
    echo "ERROR: flutter not found on PATH and not at \$HOME/flutter-sdk/flutter/bin" >&2
    exit 1
  fi
fi

# --- 0. preflight: portal up? ---
echo "==> Checking portal at $PORTAL/health"
if ! curl -fsS -m 5 "$PORTAL/health" >/dev/null 2>&1; then
  echo "ERROR: portal not reachable at $PORTAL." >&2
  echo "       Start it first: ./deployment/local-stack/local-stack portal" >&2
  exit 1
fi

# Dispatch a dev-auth action. Args: <bearer> <actionName> <rawInputJson> <idempotencyKey>
# Echoes the response body; exits non-zero on a non-2xx portal response.
act() {
  local bearer="$1" name="$2" input="$3" key="$4"
  curl -fsS -m 20 -X POST "$PORTAL/actions" \
    -H "authorization: Bearer $bearer" -H 'content-type: application/json' \
    -d "{\"actionName\":\"$name\",\"rawInput\":$input,\"idempotencyKey\":\"$key\"}"
}

# --- 1. provision + issue code (skipped if caller supplied SC_BEARER + P1_CODE) ---
SC_BEARER="${SC_BEARER:-}"
P1_CODE="${P1_CODE:-}"
if [[ -z "$SC_BEARER" || -z "$P1_CODE" ]]; then
  ADMIN="e2e-admin@reference.local"
  SC="e2e-sc@reference.local"
  FUT="2030-01-01T00:00:00Z"
  echo "==> Provisioning (idempotent): SystemOperator -> Administrator -> Study Coordinator"
  # Create + role-assign are stable-keyed: re-runs return the cached result.
  act "$SYSOP"  ACT-OPS-003 "{\"email\":\"$ADMIN\",\"name\":\"E2E Admin\"}"                                                              "e2e-mkadmin"  >/dev/null
  act "$SYSOP"  ACT-USR-007 "{\"userId\":\"$ADMIN\",\"role\":\"Administrator\",\"scope\":{\"class\":\"tier\",\"value\":\"staff\"}}"       "e2e-admrole"  >/dev/null
  act "$ADMIN"  ACT-USR-001 "{\"email\":\"$SC\",\"name\":\"E2E SC\",\"activationExpiresAt\":\"$FUT\",\"roles\":[\"StudyCoordinator\"],\"sites\":[\"$SITE\"]}" "e2e-mksc" >/dev/null
  act "$ADMIN"  ACT-USR-007 "{\"userId\":\"$SC\",\"role\":\"StudyCoordinator\",\"scope\":{\"class\":\"tier\",\"value\":\"staff\"}}"       "e2e-scrole"   >/dev/null
  act "$ADMIN"  ACT-USR-008 "{\"userId\":\"$SC\",\"role\":\"StudyCoordinator\",\"site\":\"$SITE\"}"                                       "e2e-scsite"   >/dev/null
  SC_BEARER="$SC"

  echo "==> Issuing a fresh linking code for $PARTICIPANT @ $SITE (ACT-PAT-001)"
  ISSUE_RESP="$(act "$SC" ACT-PAT-001 "{\"siteId\":\"$SITE\",\"participantId\":\"$PARTICIPANT\"}" "e2e-issue-$PARTICIPANT-$RUN_ID")"
  P1_CODE="$(printf '%s' "$ISSUE_RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["linkingCode"])')"
  if [[ -z "$P1_CODE" ]]; then
    echo "ERROR: failed to extract linkingCode from: $ISSUE_RESP" >&2
    exit 1
  fi
  echo "    linking code = $P1_CODE   SC bearer = $SC_BEARER"
fi

# --- 2. build the diary web bundle pointed at the live portal ---
echo "==> flutter pub get"
flutter pub get
if [[ ! -d web ]]; then
  echo "==> Scaffolding web platform (flutter create . --platforms web)"
  flutter create . --platforms web >/dev/null
fi
echo "==> Building Flutter web bundle (DIARY_API_BASE=$PORTAL)"
flutter build web --dart-define=DIARY_API_BASE="$PORTAL"

# --- 3. run the lifecycle spec (Playwright serves ../build/web on :8000) ---
echo "==> Running lifecycle spec"
cd e2e
npm install
set +e
PORTAL="$PORTAL" SITE="$SITE" PARTICIPANT="$PARTICIPANT" \
  P1_CODE="$P1_CODE" SC_BEARER="$SC_BEARER" KEY_PREFIX="$PARTICIPANT-$RUN_ID" \
  npx playwright test tests/p1-lifecycle.spec.ts "$@"
SPEC_RC=$?
cd "$APP_DIR"

# --- 4. verify the sync watermark gated correctly (event store) ---
# Synced epistaxis entries tie to the participant via initiator->>'user_id'.
# Happy path: the 3 post-trial entries reach the store; the 2 pre-link entries
# do NOT (they predate the trial-start watermark). On a FRESH DB the count is
# exactly 3; on a reused DB it accumulates, so we gate on ">= 3 synced".
echo "==> Verifying sync gating in the event store"
SYNCED="$(docker exec "$PG_CONTAINER" psql -U postgres -d hht_diary -t -A -c \
  "select count(*) from events where aggregate_type='DiaryEntry' and entry_type='epistaxis_event' and initiator->>'user_id'='$PARTICIPANT';" 2>/dev/null | tr -d '[:space:]')"
echo "    synced epistaxis events for $PARTICIPANT = ${SYNCED:-?}"
if [[ "${SYNCED:-0}" -ge 3 ]]; then
  echo "    PASS: post-trial entries synced (watermark opened sync after Start Trial)"
else
  echo "    FAIL: expected >= 3 synced post-trial entries, got ${SYNCED:-0}" >&2
  echo "          (a count of 0 is the classic trial-start watermark / timezone bug)" >&2
  [[ $SPEC_RC -eq 0 ]] && SPEC_RC=1
fi

echo "==> Artifacts under e2e/test-results/ (screenshots, p1-link.json, p1-ingest-posts.json)"
exit $SPEC_RC
