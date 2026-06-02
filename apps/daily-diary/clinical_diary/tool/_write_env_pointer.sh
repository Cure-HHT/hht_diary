#!/bin/bash
# Implements: DIARY-DEV-runtime-environment-resolution/E
# Stamp the bundled env pointer for a target environment, then restore it
# on exit so the working tree is not left dirty.
# Usage: source _write_env_pointer.sh <env>
#
# Validates <env> against flavorizr.yaml (the single source of truth) when yq
# is available; falls back to the historical local|dev|qa|uat|prod allowlist
# otherwise so this helper still works in minimal environments. Adding a new
# env to flavorizr.yaml is sufficient — no edit to this helper required.
#
# This is sourced into caller scripts so the restore-on-EXIT trap installs in
# the caller's shell. It deliberately does NOT `set -e`: sourcing must not
# change the caller's error-handling mode. The few operations below guard
# themselves, so a caller that does not run `set -e` is unaffected.
ENV_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || { echo "ERROR: cannot resolve script dir" >&2; exit 1; }
ENV_FILE="$SCRIPT_DIR/../assets/config/env.json"
MANIFEST="$SCRIPT_DIR/../flavorizr.yaml"
if command -v yq >/dev/null 2>&1 && [ -f "$MANIFEST" ]; then
  if ! yq -r '.flavors | keys | .[]' "$MANIFEST" 2>/dev/null | grep -qx "$ENV_NAME"; then
    known="$(yq -r '.flavors | keys | join(" ")' "$MANIFEST")"
    echo "ERROR: unknown env '$ENV_NAME' (flavorizr.yaml lists: $known)" >&2
    return 1 2>/dev/null || exit 1
  fi
else
  case "$ENV_NAME" in
    local|dev|qa|uat|prod) ;;
    *) echo "ERROR: unknown env '$ENV_NAME' (yq unavailable; fell back to legacy allowlist)" >&2; return 1 2>/dev/null || exit 1 ;;
  esac
fi
restore_env_pointer() { git -C "$SCRIPT_DIR/.." checkout -- assets/config/env.json 2>/dev/null || true; }
trap restore_env_pointer EXIT
printf '{ "env": "%s" }\n' "$ENV_NAME" > "$ENV_FILE" || { echo "ERROR: could not write env pointer to $ENV_FILE" >&2; exit 1; }
echo "Stamped env pointer -> $ENV_NAME"
