#!/usr/bin/env bash
# Run the WS-push transport e2e (tests/p2-push-transport.spec.ts) against a
# running local-stack EVS portal in PUSH_MODE=local.
#
# Unlike run-lifecycle-e2e.sh (which exercises the lifecycle over the POLL
# backup path), this builds the diary web bundle with:
#   - env=local              -> the diary selects LocalSocketPushReceiver and
#                               holds a /api/v1/user/push WS to the portal,
#   - a HUGE periodic poll    -> --dart-define=DIARY_SYNC_PERIODIC_SECONDS so the
#                               /state poll cannot fire during the test.
# The spec then fires a portal disconnect WITHOUT any reload/focus/connectivity
# trigger; a "Disconnected from Study" banner that appears is proof the WS push
# delivered it. Implements: DIARY-DEV-pluggable-push-transport/C+D
#
# Usage:
#   apps/daily-diary/clinical_diary/scripts/run-push-e2e.sh [playwright args]
#
# Env overrides (same shape as run-lifecycle-e2e.sh):
#   PORTAL        portal+diary API base   (default http://localhost:8080)
#   SITE          site id                 (default site-1)
#   PARTICIPANT   participant id (must exist in EDC seed)  (default REF-001-001)
#   SYSOP         SystemOperator login    (default dev@reference.local)
#   POLL_SECONDS  stretched poll interval (default 86400 = effectively never)
#
# NOTE: consumes the participant's linking code and leaves it disconnected; use
# a fresh participant or a fresh DB per run.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

PORTAL="${PORTAL:-http://localhost:8080}"
SITE="${SITE:-site-1}"
PARTICIPANT="${PARTICIPANT:-REF-001-001}"
SYSOP="${SYSOP:-dev@reference.local}"
POLL_SECONDS="${POLL_SECONDS:-86400}"
RUN_ID="$$"

# --- flutter on PATH (this host keeps it under flutter-sdk/) ---
if ! command -v flutter >/dev/null 2>&1; then
  if [[ -x "$HOME/flutter-sdk/flutter/bin/flutter" ]]; then
    export PATH="$HOME/flutter-sdk/flutter/bin:$PATH"
  else
    echo "ERROR: flutter not found on PATH and not at \$HOME/flutter-sdk/flutter/bin" >&2
    exit 1
  fi
fi

# --- 0. preflight: portal up + PUSH_MODE=local ---
echo "==> Checking portal at $PORTAL/health"
if ! curl -fsS -m 5 "$PORTAL/health" >/dev/null 2>&1; then
  echo "ERROR: portal not reachable at $PORTAL." >&2
  echo "       Start it first: ./deployment/local-stack/local-stack portal" >&2
  exit 1
fi

act() {
  local bearer="$1" name="$2" input="$3" key="$4"
  curl -fsS -m 20 -X POST "$PORTAL/actions" \
    -H "authorization: Bearer $bearer" -H 'content-type: application/json' \
    -d "{\"actionName\":\"$name\",\"rawInput\":$input,\"idempotencyKey\":\"$key\"}"
}

# --- 1. provision (idempotent) + issue a fresh linking code ---
ADMIN="e2e-admin@reference.local"
SC="e2e-sc-${SITE}@reference.local"
FUT="2030-01-01T00:00:00Z"
echo "==> Provisioning (idempotent): SystemOperator -> Administrator -> Study Coordinator @ $SITE"
act "$SYSOP" ACT-OPS-003 "{\"email\":\"$ADMIN\",\"name\":\"E2E Admin\"}" "e2e-mkadmin" >/dev/null
act "$SYSOP" ACT-USR-007 "{\"userId\":\"$ADMIN\",\"role\":\"Administrator\",\"scope\":{\"class\":\"tier\",\"value\":\"staff\"}}" "e2e-admrole" >/dev/null
act "$ADMIN" ACT-USR-001 "{\"email\":\"$SC\",\"name\":\"E2E SC\",\"activationExpiresAt\":\"$FUT\",\"roles\":[\"StudyCoordinator\"],\"sites\":[\"$SITE\"]}" "e2e-mksc-$SITE" >/dev/null
act "$ADMIN" ACT-USR-007 "{\"userId\":\"$SC\",\"role\":\"StudyCoordinator\",\"scope\":{\"class\":\"tier\",\"value\":\"staff\"}}" "e2e-scrole-$SITE" >/dev/null
act "$ADMIN" ACT-USR-008 "{\"userId\":\"$SC\",\"role\":\"StudyCoordinator\",\"site\":\"$SITE\"}" "e2e-scsite-$SITE" >/dev/null

echo "==> Issuing a fresh linking code for $PARTICIPANT @ $SITE (ACT-PAT-001)"
ISSUE_RESP="$(act "$SC" ACT-PAT-001 "{\"siteId\":\"$SITE\",\"participantId\":\"$PARTICIPANT\"}" "e2e-issue-$PARTICIPANT-$RUN_ID")"
P1_CODE="$(printf '%s' "$ISSUE_RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["linkingCode"])')"
[[ -n "$P1_CODE" ]] || { echo "ERROR: no linkingCode from: $ISSUE_RESP" >&2; exit 1; }
echo "    linking code = $P1_CODE   SC bearer = $SC"

# --- 2. build the diary web bundle: env=local + stretched poll ---
# The env pointer is the SINGLE source of truth for the runtime environment;
# stamp it to local for the build and restore it on exit (clean working tree).
restore_env() { git -C "$APP_DIR" checkout -- assets/config/env.json 2>/dev/null || true; }
trap restore_env EXIT
printf '{ "env": "local" }\n' > assets/config/env.json
echo "==> env pointer stamped: $(cat assets/config/env.json)"

echo "==> flutter pub get"
flutter pub get
if [[ ! -d web ]]; then
  echo "==> Scaffolding web platform"
  flutter create . --platforms web >/dev/null
fi
echo "==> Building Flutter web bundle (env=local, DIARY_API_BASE=$PORTAL, poll=${POLL_SECONDS}s)"
flutter build web \
  --dart-define=DIARY_API_BASE="$PORTAL" \
  --dart-define=DIARY_SYNC_PERIODIC_SECONDS="$POLL_SECONDS"

# --- 3. run the push-transport spec ---
echo "==> Running push-transport spec"
cd e2e
npm install
set +e
PORTAL="$PORTAL" SITE="$SITE" PARTICIPANT="$PARTICIPANT" \
  P1_CODE="$P1_CODE" SC_BEARER="$SC" KEY_PREFIX="$PARTICIPANT-$RUN_ID" \
  npx playwright test tests/p2-push-transport.spec.ts "$@"
SPEC_RC=$?
set -e
cd "$APP_DIR"

if [[ $SPEC_RC -eq 0 ]]; then
  echo "==> PASS: portal disconnect delivered to the diary over the local-push WS (no poll)"
else
  echo "==> FAIL: push-transport spec exited $SPEC_RC" >&2
fi
exit $SPEC_RC
