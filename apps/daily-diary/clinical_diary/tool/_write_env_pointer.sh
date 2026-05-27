#!/bin/bash
# Implements: DIARY-DEV-runtime-environment-resolution/E
# Stamp the bundled env pointer for a target environment, then restore it
# on exit so the working tree is not left dirty.
# Usage: source _write_env_pointer.sh <local|dev|qa|uat|prod>
set -e
ENV_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../assets/config/env.json"
case "$ENV_NAME" in
  local|dev|qa|uat|prod) ;;
  *) echo "ERROR: unknown env '$ENV_NAME'"; exit 1 ;;
esac
restore_env_pointer() { git -C "$SCRIPT_DIR/.." checkout -- assets/config/env.json 2>/dev/null || true; }
trap restore_env_pointer EXIT
printf '{ "env": "%s" }\n' "$ENV_NAME" > "$ENV_FILE"
echo "Stamped env pointer -> $ENV_NAME"
