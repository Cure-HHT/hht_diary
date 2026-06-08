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
#   SC_BEARER     SC credential (email in dev mode, or session token). Set this
#                 AND P1_CODE together to skip provisioning entirely.
#   P1_CODE       pre-issued linking code. Set this AND SC_BEARER together to
#                 skip provisioning. (Set NEITHER to auto-provision on local-stack.)
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
# SC_BEARER and P1_CODE are a pair: set BOTH to skip provisioning and run against
# a pre-provisioned / deployed (session-auth) portal, or set NEITHER to
# auto-provision on local-stack. Supplying only one is ambiguous (provisioning
# would overwrite the one you set), so reject it.
if { [[ -n "$SC_BEARER" ]] && [[ -z "$P1_CODE" ]]; } || { [[ -z "$SC_BEARER" ]] && [[ -n "$P1_CODE" ]]; }; then
  echo "ERROR: SC_BEARER and P1_CODE must be set together, or neither." >&2
  echo "       Both set  => use a pre-issued code + SC creds (deployed portal)." >&2
  echo "       Neither   => auto-provision + issue a fresh code on local-stack." >&2
  exit 1
fi
if [[ -z "$SC_BEARER" ]]; then   # neither set -> auto-provision on local-stack
  ADMIN="e2e-admin@reference.local"
  # SC email is namespaced by SITE so per-site runs don't collide on one account.
  SC="e2e-sc-${SITE}@reference.local"
  FUT="2030-01-01T00:00:00Z"
  echo "==> Provisioning (idempotent): SystemOperator -> Administrator -> Study Coordinator"
  # Create + role-assign are stable-keyed: re-runs return the cached result.
  # Admin is site-independent; the SC and its scopes are namespaced by SITE so a
  # different SITE never returns a cached result bound to the wrong site.
  act "$SYSOP"  ACT-OPS-003 "{\"email\":\"$ADMIN\",\"name\":\"E2E Admin\"}"                                                              "e2e-mkadmin"  >/dev/null
  act "$SYSOP"  ACT-USR-007 "{\"userId\":\"$ADMIN\",\"role\":\"Administrator\",\"scope\":{\"class\":\"tier\",\"value\":\"staff\"}}"       "e2e-admrole"  >/dev/null
  act "$ADMIN"  ACT-USR-001 "{\"email\":\"$SC\",\"name\":\"E2E SC\",\"activationExpiresAt\":\"$FUT\",\"roles\":[\"StudyCoordinator\"],\"sites\":[\"$SITE\"]}" "e2e-mksc-$SITE" >/dev/null
  act "$ADMIN"  ACT-USR-007 "{\"userId\":\"$SC\",\"role\":\"StudyCoordinator\",\"scope\":{\"class\":\"tier\",\"value\":\"staff\"}}"       "e2e-scrole-$SITE"   >/dev/null
  act "$ADMIN"  ACT-USR-008 "{\"userId\":\"$SC\",\"role\":\"StudyCoordinator\",\"site\":\"$SITE\"}"                                       "e2e-scsite-$SITE"   >/dev/null
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
set -e   # restore fail-fast (disabled above only to capture SPEC_RC)
cd "$APP_DIR"

# --- 4. verify the sync watermark OPENED after Start Trial (event store) ---
# Synced epistaxis entries tie to the participant via initiator->>'user_id'.
# This assertion proves only the POSITIVE half: the 3 post-trial entries reached
# the store, i.e. the trial-start watermark opened outbound sync (a count of 0 is
# the classic trial-start watermark / timezone bug). It does NOT, on its own,
# prove the pre-link entries were gated OUT — that needs a known-empty baseline.
# On a FRESH DB the count is exactly 3 (post-trial only; the 2 pre-link entries
# are absent), which proves both halves; on a reused DB the count accumulates, so
# the portable gate here is ">= 3". For the pre-link-gating assertion, run on a
# fresh DB and check the count equals the number of post-trial entries (3).
# psql/docker errors are intentionally NOT silenced: under set -e a failure here
# (wrong PG_CONTAINER, psql missing, ...) aborts with the root cause visible.
echo "==> Verifying sync gating in the event store"
SYNCED="$(docker exec "$PG_CONTAINER" psql -U postgres -d hht_diary -t -A -c \
  "select count(*) from events where aggregate_type='DiaryEntry' and entry_type='epistaxis_event' and initiator->>'user_id'='$PARTICIPANT';" | tr -d '[:space:]')"
echo "    synced epistaxis events for $PARTICIPANT = ${SYNCED:-?}"
if [[ "${SYNCED:-0}" -ge 3 ]]; then
  echo "    PASS: post-trial entries synced (watermark opened sync after Start Trial)"
else
  echo "    FAIL: expected >= 3 synced post-trial entries, got ${SYNCED:-0}" >&2
  echo "          (a count of 0 is the classic trial-start watermark / timezone bug)" >&2
  if [[ $SPEC_RC -eq 0 ]]; then SPEC_RC=1; fi
fi

echo "==> Artifacts under e2e/test-results/ (screenshots, p1-link.json, p1-ingest-posts.json)"
exit $SPEC_RC
