#!/usr/bin/env bats
# Invariants for the cached firebase-emulator base image Dockerfile.
# String-grep based for the same reason as test_compose_otel.bats: no
# YAML/Dockerfile parsers needed in CI.
bats_require_minimum_version 1.5.0

setup() {
  DOCKERFILE="$BATS_TEST_DIRNAME/../firebase-emulator/Dockerfile"
  [ -f "$DOCKERFILE" ] || skip "Dockerfile not found at $DOCKERFILE"
}

@test "firebase-emulator Dockerfile uses node:20-slim base" {
  run grep -E '^FROM[[:space:]]+node:20-slim[[:space:]]*$' "$DOCKERFILE"
  [ "$status" -eq 0 ]
}

@test "firebase-emulator Dockerfile pins firebase-tools via ARG" {
  # ARG must declare a non-empty default. We reject bare `ARG FIREBASE_TOOLS_VERSION`
  # because that would let runtime un-pin the version via build-arg-or-default.
  run grep -E '^ARG[[:space:]]+FIREBASE_TOOLS_VERSION=[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*$' "$DOCKERFILE"
  [ "$status" -eq 0 ]
}

@test "firebase-emulator Dockerfile installs firebase-tools at the pinned version" {
  # The npm install line must reference the ARG, not @latest or a literal.
  run grep -E 'npm install -g "firebase-tools@\$\{FIREBASE_TOOLS_VERSION\}"' "$DOCKERFILE"
  [ "$status" -eq 0 ]
}

@test "firebase-emulator Dockerfile does not pull firebase-tools@latest" {
  # Regression guard: never silently revert to floating @latest.
  run grep -E 'firebase-tools@latest' "$DOCKERFILE"
  [ "$status" -ne 0 ]
}

@test "firebase-emulator Dockerfile installs JRE-17" {
  run grep -E 'openjdk-17-jre-headless' "$DOCKERFILE"
  [ "$status" -eq 0 ]
}

@test "firebase-emulator Dockerfile cleans apt lists in same RUN as apt-get install" {
  # Layer hygiene: rm -rf /var/lib/apt/lists/* must live in the same RUN
  # that installs packages, not a later RUN where it would have no effect
  # (and would still bloat the install layer). To check that, flatten
  # backslash-newline continuations into single logical lines, then assert
  # `apt-get install` and `rm -rf /var/lib/apt/lists/*` co-occur on one.
  local flat
  flat="$(awk 'BEGIN{buf=""}
    /\\$/  { sub(/\\$/, ""); buf=buf $0; next }
            { print buf $0; buf="" }' "$DOCKERFILE")"
  echo "$flat" | grep -qE 'apt-get install.*rm -rf /var/lib/apt/lists/\*'
}
