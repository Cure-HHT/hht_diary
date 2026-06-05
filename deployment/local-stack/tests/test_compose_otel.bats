#!/usr/bin/env bats
# Invariants for OTel wiring in docker-compose.yml. String-grep based: deliberate.
# We want a regression check that survives without yq/python-yaml in CI.
bats_require_minimum_version 1.5.0

setup() {
  COMPOSE="$BATS_TEST_DIRNAME/../compose/docker-compose.yml"
  [ -f "$COMPOSE" ] || skip "compose file not found at $COMPOSE"
}

@test "compose declares an otel-lgtm service" {
  run grep -E '^[[:space:]]+otel-lgtm:[[:space:]]*$' "$COMPOSE"
  [ "$status" -eq 0 ]
}

@test "otel-lgtm uses the pinned grafana/otel-lgtm image" {
  run grep -E 'image:[[:space:]]+grafana/otel-lgtm:0\.8\.1' "$COMPOSE"
  [ "$status" -eq 0 ]
}

@test "otel-lgtm publishes ports 3000, 4317, 4318" {
  run grep -E '"3000:3000"' "$COMPOSE"; [ "$status" -eq 0 ]
  run grep -E '"4317:4317"' "$COMPOSE"; [ "$status" -eq 0 ]
  run grep -E '"4318:4318"' "$COMPOSE"; [ "$status" -eq 0 ]
}

@test "otel-lgtm joins the stack network" {
  # Look for the otel-lgtm block followed (within ~30 lines) by `- stack` under networks.
  # Use awk: print lines from "otel-lgtm:" until we see another top-level service or ports.
  run awk '
    /^[[:space:]]+otel-lgtm:[[:space:]]*$/ {flag=1; next}
    flag && /^[[:space:]]+[a-z][a-z0-9_-]*:[[:space:]]*$/ && !/^    / {flag=0}
    flag {print}
  ' "$COMPOSE"
  [[ "$output" == *"stack"* ]]
}

@test "portal-final sets OTEL_EXPORTER_OTLP_ENDPOINT to otel-lgtm:4317" {
  # One occurrence: the EVS portal is the only server service (no diary-final).
  count=$(grep -cE 'OTEL_EXPORTER_OTLP_ENDPOINT:[[:space:]]+"http://otel-lgtm:4317"' "$COMPOSE")
  [ "$count" -eq 1 ]
}

@test "portal-final sets OTEL_EXPORTER_OTLP_INSECURE=true" {
  count=$(grep -cE 'OTEL_EXPORTER_OTLP_INSECURE:[[:space:]]+"true"' "$COMPOSE")
  [ "$count" -eq 1 ]
}

@test "portal-final sets OTEL_EXPORTER_OTLP_PROTOCOL=grpc" {
  count=$(grep -cE 'OTEL_EXPORTER_OTLP_PROTOCOL:[[:space:]]+"grpc"' "$COMPOSE")
  [ "$count" -eq 1 ]
}

@test "portal-final depends on otel-lgtm being healthy" {
  # The EVS portal service should have an otel-lgtm depends_on block with
  # condition: service_healthy. Match the two-line pair.
  run awk '
    /otel-lgtm:[[:space:]]*$/ && prev ~ /depends_on:|^[[:space:]]+[a-z]/ {found_dep++}
    /condition:[[:space:]]+service_healthy/ && prev ~ /otel-lgtm:[[:space:]]*$/ {found_cond++}
    {prev=$0}
    END {print found_dep, found_cond}
  ' "$COMPOSE"
  read -r deps conds <<< "$output"
  [ "$deps" -ge 1 ]
  [ "$conds" -ge 1 ]
}
