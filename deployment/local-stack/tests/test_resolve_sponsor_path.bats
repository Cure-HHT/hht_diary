#!/usr/bin/env bats
# Tests for lib/resolve-sponsor-path.py — the inverted resolver. The toolkit
# lives in core and resolves the *sponsor* repo, validated by the
# deployment/base-config.json marker. Resolution order: $SPONSOR_REPO env var,
# else [associated.sponsor].path in <toolkit>/.local-stack.toml (+ .local).

setup() {
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  RESOLVER="$BATS_TEST_DIRNAME/../lib/resolve-sponsor-path.py"
  # Don't let an inherited SPONSOR_REPO from the dev's shell short-circuit
  # the .toml-based tests below.
  unset SPONSOR_REPO
}

@test "resolves sponsor path using .local-stack.local.toml override" {
  run python3 "$RESOLVER" --toolkit "$FIXTURES/valid-toml"
  [ "$status" -eq 0 ]
  # Output is an absolute path ending in fixtures/fake-sponsor-repo
  [[ "$output" == /* ]]
  [[ "$output" == *fixtures/fake-sponsor-repo ]]
}

@test "SPONSOR_REPO env var wins outright and must be absolute" {
  # Absolute SPONSOR_REPO is used directly (ignores any .toml).
  run env SPONSOR_REPO="$FIXTURES/fake-sponsor-repo" \
    python3 "$RESOLVER" --toolkit "$FIXTURES/missing-associated"
  [ "$status" -eq 0 ]
  [[ "$output" == *fixtures/fake-sponsor-repo ]]
}

@test "relative SPONSOR_REPO is rejected" {
  run env SPONSOR_REPO="../somewhere" \
    python3 "$RESOLVER" --toolkit "$FIXTURES/valid-toml"
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be an absolute path"* ]]
}

@test "falls back to .local-stack.toml when no local override present (relative path)" {
  # Lay out: $tmp/toolkit/.local-stack.toml -> path = "../sponsor"
  #          $tmp/sponsor/deployment/base-config.json
  local toolkit="$BATS_TEST_TMPDIR/toolkit"
  local sponsor="$BATS_TEST_TMPDIR/sponsor"
  mkdir -p "$toolkit" "$sponsor/deployment"
  echo '{"sponsor":"fixture"}' > "$sponsor/deployment/base-config.json"
  cat > "$toolkit/.local-stack.toml" <<EOF
[associated.sponsor]
repo = "Cure-HHT/hht_diary_callisto"
path = "../sponsor"
EOF
  run python3 "$RESOLVER" --toolkit "$toolkit"
  [ "$status" -eq 0 ]
  [ "$output" = "$sponsor" ]
}

@test "falls back to built-in reference sponsor when no env and no sponsor config" {
  # Lay out a toolkit with no [associated.sponsor], plus a sibling
  # reference-sponsor/ carrying the marker (mirrors core's
  # <core>/deployment/{local-stack,reference-sponsor}). Bare core runs
  # resolve to the built-in reference sponsor.
  local deployment="$BATS_TEST_TMPDIR/deployment"
  local toolkit="$deployment/local-stack"
  local reference="$deployment/reference-sponsor"
  mkdir -p "$toolkit" "$reference/deployment"
  echo '{"sponsor":"reference"}' > "$reference/deployment/base-config.json"
  printf '# no [associated.sponsor] — bare core run\nversion = 3\n' > "$toolkit/.local-stack.toml"
  run python3 "$RESOLVER" --toolkit "$toolkit"
  [ "$status" -eq 0 ]
  [ "$output" = "$reference" ]
}

@test "fails with clear message when no config and no built-in reference sponsor" {
  # Toolkit with no [associated.sponsor] AND no sibling reference-sponsor/.
  local deployment="$BATS_TEST_TMPDIR/deployment-noref"
  local toolkit="$deployment/local-stack"
  mkdir -p "$toolkit"
  printf '# no [associated.sponsor]\nversion = 3\n' > "$toolkit/.local-stack.toml"
  run python3 "$RESOLVER" --toolkit "$toolkit"
  [ "$status" -eq 2 ]
  [[ "$output" == *"reference sponsor"* ]]
}

@test "fails with clear message when sponsor path does not exist" {
  local toolkit="$BATS_TEST_TMPDIR/bad-path"
  mkdir -p "$toolkit"
  cat > "$toolkit/.local-stack.toml" <<EOF
[associated.sponsor]
repo = "Cure-HHT/hht_diary_callisto"
path = "/definitely/does/not/exist/anywhere"
EOF
  run python3 "$RESOLVER" --toolkit "$toolkit"
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "fails with clear message when marker file is missing" {
  # Point at a directory that exists but isn't a sponsor repo.
  local toolkit="$BATS_TEST_TMPDIR/bad-marker"
  local fake_sponsor="$BATS_TEST_TMPDIR/not-a-sponsor"
  mkdir -p "$toolkit" "$fake_sponsor"
  cat > "$toolkit/.local-stack.toml" <<EOF
[associated.sponsor]
repo = "Cure-HHT/hht_diary_callisto"
path = "$fake_sponsor"
EOF
  run python3 "$RESOLVER" --toolkit "$toolkit"
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not look like a sponsor repo"* ]]
}
