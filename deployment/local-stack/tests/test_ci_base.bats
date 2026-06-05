#!/usr/bin/env bats
# Tests for resolve_ci_base / ensure_ghcr_auth in lib/common.sh — the
# clinical-diary-ci base-image source selector. Default "local" builds the CI
# toolchain base from core's ci.Dockerfile (no GHCR auth); "ghcr" pulls the
# digest-pinned image and requires docker login ghcr.io.
#
# Each case runs in its own subshell (`bash -c 'source common.sh && ...'`) so
# common.sh's `set -euo pipefail` and die()'s `exit 1` stay isolated.

setup() {
  LIB="$BATS_TEST_DIRNAME/../lib"
}

@test "ci-base defaults to 'local' when unset" {
  run env -u LOCAL_STACK_CI_BASE bash -c 'source "'"$LIB"'/common.sh" && resolve_ci_base'
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}

@test "ci-base 'local' resolves (core ci.Dockerfile + versions.env present)" {
  run env LOCAL_STACK_CI_BASE=local bash -c 'source "'"$LIB"'/common.sh" && resolve_ci_base'
  [ "$status" -eq 0 ]
  [ "$output" = "local" ]
}

@test "ci-base rejects an invalid value and names both accepted values" {
  run env LOCAL_STACK_CI_BASE=bogus bash -c 'source "'"$LIB"'/common.sh" && resolve_ci_base'
  [ "$status" -ne 0 ]
  [[ "$output" == *"local"* ]]
  [[ "$output" == *"ghcr"* ]]
}

@test "ci-base 'ghcr' fails clearly when no ghcr.io credentials exist" {
  local dc="$BATS_TEST_TMPDIR/docker-empty"
  mkdir -p "$dc"   # no config.json at all
  run env LOCAL_STACK_CI_BASE=ghcr DOCKER_CONFIG="$dc" \
    bash -c 'source "'"$LIB"'/common.sh" && resolve_ci_base'
  [ "$status" -ne 0 ]
  [[ "$output" == *"docker login ghcr.io"* ]]
}

@test "ci-base 'ghcr' passes when ghcr.io appears in docker auths" {
  local dc="$BATS_TEST_TMPDIR/docker-ghcr"
  mkdir -p "$dc"
  printf '{"auths":{"ghcr.io":{"auth":"x"}}}' > "$dc/config.json"
  run env LOCAL_STACK_CI_BASE=ghcr DOCKER_CONFIG="$dc" \
    bash -c 'source "'"$LIB"'/common.sh" && resolve_ci_base'
  [ "$status" -eq 0 ]
  [ "$output" = "ghcr" ]
}

@test "ci-base 'ghcr' passes when a ghcr.io credential helper is configured" {
  local dc="$BATS_TEST_TMPDIR/docker-helper"
  mkdir -p "$dc"
  printf '{"credHelpers":{"ghcr.io":"gh"}}' > "$dc/config.json"
  run env LOCAL_STACK_CI_BASE=ghcr DOCKER_CONFIG="$dc" \
    bash -c 'source "'"$LIB"'/common.sh" && resolve_ci_base'
  [ "$status" -eq 0 ]
  [ "$output" = "ghcr" ]
}
