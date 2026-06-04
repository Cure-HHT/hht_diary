#!/usr/bin/env bash
# Probe the env vars actually injected into the running portal-server
# process inside the local-stack container. Looks at /proc/<pid>/environ
# of the bare /app/portal-server child (NOT the doppler-run wrapper —
# the wrapper's env doesn't reflect Doppler-injected secrets).
#
# Usage:
#   ./probe-portal-env.sh                      # default container
#   ./probe-portal-env.sh some-other-portal-1  # explicit container
#
# Output: full env of the portal-server process, plus a filtered summary
# of the slack/rave/edc/doppler/environment vars that matter for CUR-1361.

set -euo pipefail

CONTAINER="${1:-callisto-local-portal-final-1}"

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "ERROR: container '$CONTAINER' not found." >&2
  echo "Usage: $0 [container-name]" >&2
  exit 1
fi

# Inner script: walk /proc, find the portal-server child (skip wrappers).
INNER='
for d in /proc/[0-9]*; do
  [ -f "$d/cmdline" ] || continue
  cmd=$(tr "\0" " " < "$d/cmdline")
  case "$cmd" in
    *doppler*) continue ;;
    */portal-server*)
      echo "=== PID $(basename $d) ==="
      echo "cmdline: $cmd"
      echo "--- environ ---"
      tr "\0" "\n" < "$d/environ"
      echo ""
      ;;
  esac
done
'

# Copy the inner script into the container, then exec it.
# mktemp creates 0600; the container runs as a different uid, so widen to
# 0644 before docker cp so the in-container sh can read it.
TMP=$(mktemp /tmp/probe-portal-env.XXXX.sh)
trap 'rm -f "$TMP"' EXIT
printf '%s\n' "$INNER" > "$TMP"
chmod 0644 "$TMP"

docker cp "$TMP" "$CONTAINER:/tmp/probe-portal-env.sh" >/dev/null
RAW=$(docker exec "$CONTAINER" sh /tmp/probe-portal-env.sh)
docker exec "$CONTAINER" rm -f /tmp/probe-portal-env.sh >/dev/null 2>&1 || true

if [ -z "$RAW" ]; then
  echo "ERROR: no /app/portal-server process found in '$CONTAINER'." >&2
  echo "Is the stack running? Try: ./deployment/local-stack/local-stack status" >&2
  exit 2
fi

echo "$RAW"
echo ""
echo "=================================================================="
echo "FILTERED SUMMARY (slack / rave / edc / doppler / environment)"
echo "=================================================================="
# `set -euo pipefail` would otherwise treat grep's "no matches" exit 1 as
# a script failure; suppress so the raw env above still counts as success
# even if the filter happens to match nothing.
printf '%s\n' "$RAW" | grep -iE 'slack|rave|edc_module|doppler|^environment=' | sort -u || true
