#!/usr/bin/env bats
# Guards the built-in reference sponsor (deployment/reference-sponsor) that the
# resolver falls back to for bare-core runs. It is a hand-maintained mirror of a
# sponsor repo's build inputs, so this test asserts it stays structurally
# complete: every path the reference portal-final.Dockerfile COPYs at build time
# must exist, and the sponsor id must be `reference`.

setup() {
  # tests/ -> local-stack -> deployment ; reference-sponsor is its sibling.
  REF="$( cd "$BATS_TEST_DIRNAME/../.." && pwd )/reference-sponsor"
}

@test "reference sponsor carries the base-config.json marker" {
  [ -f "$REF/deployment/base-config.json" ]
}

@test "reference sponsor id is 'reference'" {
  run python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['sponsor'])" \
    "$REF/deployment/base-config.json"
  [ "$status" -eq 0 ]
  [ "$output" = "reference" ]
}

@test "reference portal-final.Dockerfile is present" {
  [ -f "$REF/deployment/docker/portal-final.Dockerfile" ]
}

@test "reference portal-final.Dockerfile tags content under the reference id" {
  run grep -q 'COPY content /app/sponsor-content/reference' \
    "$REF/deployment/docker/portal-final.Dockerfile"
  [ "$status" -eq 0 ]
}

@test "reference portal-final.Dockerfile does not leak the callisto sponsor id" {
  run grep -n 'sponsor-content/callisto' "$REF/deployment/docker/portal-final.Dockerfile"
  [ "$status" -ne 0 ]
}

@test "build-time COPY inputs all exist (nginx, start, seed, content)" {
  [ -f "$REF/deployment/nginx/nginx.conf" ]
  [ -f "$REF/deployment/nginx/evs_proxy.conf" ]
  [ -f "$REF/deployment/scripts/start.sh" ]
  [ -f "$REF/deployment/seed/portal-users.json" ]
  [ -d "$REF/content" ]
  [ -f "$REF/content/sponsor-config.json" ]
}

@test "reference seed-users is valid JSON with at least one user" {
  run python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('users') else 1)" \
    "$REF/deployment/seed/portal-users.json"
  [ "$status" -eq 0 ]
}
