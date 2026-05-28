#!/bin/bash
# Implements: DIARY-DEV-runtime-environment-resolution/E
# Stamp the bundled env pointer for a target environment, then restore it
# on exit so the working tree is not left dirty.
# Usage: source _write_env_pointer.sh <local|dev|qa|uat|prod>
#
# This is sourced into caller scripts so the restore-on-EXIT trap installs in
# the caller's shell. It deliberately does NOT `set -e`: sourcing must not
# change the caller's error-handling mode. The few operations below guard
# themselves, so a caller that does not run `set -e` is unaffected.
ENV_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || { echo "ERROR: cannot resolve script dir" >&2; exit 1; }
ENV_FILE="$SCRIPT_DIR/../assets/config/env.json"
case "$ENV_NAME" in
  local|dev|qa|uat|prod) ;;
  *) echo "ERROR: unknown env '$ENV_NAME'"; exit 1 ;;
esac
restore_env_pointer() { git -C "$SCRIPT_DIR/.." checkout -- assets/config/env.json 2>/dev/null || true; }
trap restore_env_pointer EXIT
printf '{ "env": "%s" }\n' "$ENV_NAME" > "$ENV_FILE" || { echo "ERROR: could not write env pointer to $ENV_FILE" >&2; exit 1; }
echo "Stamped env pointer -> $ENV_NAME"
