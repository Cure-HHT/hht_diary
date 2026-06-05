#!/usr/bin/env bats
# Invariants for the CUR-1272 identity/GCP-project pinning in
# docker-compose.yml. Without these, Doppler dev's production values
# leak into local-stack containers and the SPA's first auth request
# hits prod Firebase. String-grep based to match test_compose_otel.bats
# (no yq/python-yaml dependency in CI).
bats_require_minimum_version 1.5.0

setup() {
  COMPOSE="$BATS_TEST_DIRNAME/../compose/docker-compose.yml"
  LOCAL_STACK="$BATS_TEST_DIRNAME/../local-stack"
  [ -f "$COMPOSE" ] || skip "compose file not found at $COMPOSE"
  [ -f "$LOCAL_STACK" ] || skip "local-stack CLI not found at $LOCAL_STACK"
}

@test "local-stack exports LOCAL_FIREBASE_PROJECT with demo-local-stack default" {
  run grep -E '^export LOCAL_FIREBASE_PROJECT="\$\{LOCAL_FIREBASE_PROJECT:-demo-local-stack\}"$' "$LOCAL_STACK"
  [ "$status" -eq 0 ]
}

@test "portal-final pins PORTAL_IDENTITY_PROJECT_ID to LOCAL_FIREBASE_PROJECT" {
  run grep -E 'PORTAL_IDENTITY_PROJECT_ID:[[:space:]]+"\$\{LOCAL_FIREBASE_PROJECT\}"' "$COMPOSE"
  [ "$status" -eq 0 ]
}

@test "portal-final pins PORTAL_IDENTITY_AUTH_DOMAIN to localhost (not a synthetic *.firebaseapp.com)" {
  # CUR-1280: a *.firebaseapp.com authDomain triggers the Firebase JS SDK's
  # GAPI iframe path → getProjectConfig hits real google APIs with
  # demo-api-key → 400. localhost skips the iframe path.
  run grep -E 'PORTAL_IDENTITY_AUTH_DOMAIN:[[:space:]]+"localhost"' "$COMPOSE"
  [ "$status" -eq 0 ]
}

@test "portal-final pins PORTAL_IDENTITY_API_KEY to the documented AIza dummy" {
  # The dummy value is intentionally low-entropy / human-readable so it
  # satisfies the Firebase JS SDK's /^AIza[a-zA-Z0-9_-]{35}$/ format check
  # without crossing gitleaks' entropy threshold. If you change this,
  # update the comment block at compose.yml:160-165 too.
  run grep -E 'PORTAL_IDENTITY_API_KEY:[[:space:]]+"AIzaSyD-LOCAL-EMULATOR-DUMMY-NOT-A-REAL"' "$COMPOSE"
  [ "$status" -eq 0 ]
}

@test "portal-final pins GCP_PROJECT_ID to LOCAL_FIREBASE_PROJECT" {
  # One occurrence: the EVS portal is the only server service (no diary-final).
  count=$(grep -cE 'GCP_PROJECT_ID:[[:space:]]+"\$\{LOCAL_FIREBASE_PROJECT\}"' "$COMPOSE")
  [ "$count" -eq 1 ]
}

@test "portal-final pins GOOGLE_CLOUD_PROJECT to LOCAL_FIREBASE_PROJECT" {
  count=$(grep -cE 'GOOGLE_CLOUD_PROJECT:[[:space:]]+"\$\{LOCAL_FIREBASE_PROJECT\}"' "$COMPOSE")
  [ "$count" -eq 1 ]
}

@test "firebase-emulator --project is sourced from LOCAL_FIREBASE_PROJECT" {
  # The emulator's startup --project arg must match what the SPA / server
  # ID-token verifier expect; LOCAL_FIREBASE_PROJECT is the single source.
  run grep -E -- '--project \$\{LOCAL_FIREBASE_PROJECT' "$COMPOSE"
  [ "$status" -eq 0 ]
}

@test "no executable compose path hardcodes the demo-local-stack literal" {
  # Strip lines starting with `#` before checking. Leading-`#` comments
  # are the only form currently used, so this matches reality. Inline
  # comments (`KEY: val  # ...`) would false-positive here, but a
  # YAML-aware strip means parsing YAML, which contradicts this file's
  # deliberate string-grep-only design; if it bites, just don't put
  # example text in inline comments.
  run bash -c "grep -vE '^[[:space:]]*#' '$COMPOSE' | grep -E 'demo-local-stack'"
  [ "$status" -ne 0 ]
}
