#!/usr/bin/env bats
# Invariants for the firebase-emulator service block in docker-compose.yml.
# Companion to test_firebase_emulator_image.bats — that file guards the
# Dockerfile, this one guards the compose-side wiring that makes the cached
# image actually get used.
bats_require_minimum_version 1.5.0

setup() {
  COMPOSE="$BATS_TEST_DIRNAME/../compose/docker-compose.yml"
  [ -f "$COMPOSE" ] || skip "compose file not found at $COMPOSE"

  # Extract the firebase-emulator service block: from its key down to the
  # next top-level service (4-space-indented `name:`). Used by every test.
  FB_BLOCK=$(awk '
    /^[[:space:]]+firebase-emulator:[[:space:]]*$/ {flag=1; print; next}
    flag && /^[[:space:]]{2}[a-z][a-z0-9_-]*:[[:space:]]*$/ {flag=0}
    flag {print}
  ' "$COMPOSE")
}

@test "firebase-emulator uses cached firebase-emulator:local image" {
  echo "$FB_BLOCK" | grep -qE 'image:[[:space:]]+firebase-emulator:local'
}

@test "firebase-emulator does NOT use raw node:20-slim image" {
  # Regression guard against the original inline-install pattern.
  ! echo "$FB_BLOCK" | grep -qE 'image:[[:space:]]+node:20-slim'
}

@test "firebase-emulator command does NOT run apt-get install" {
  # The whole point of the cache image: install is baked in, not in runtime command.
  ! echo "$FB_BLOCK" | grep -qE 'apt-get install'
}

@test "firebase-emulator command does NOT run npm install" {
  # Same — npm install belongs in the Dockerfile, not the runtime command.
  ! echo "$FB_BLOCK" | grep -qE 'npm install'
}

@test "firebase-emulator command runs firebase emulators:start" {
  echo "$FB_BLOCK" | grep -qE 'firebase emulators:start'
}

@test "firebase-emulator publishes ports 9099 and 4000" {
  echo "$FB_BLOCK" | grep -qE '"9099:9099"'
  echo "$FB_BLOCK" | grep -qE '"4000:4000"'
}
