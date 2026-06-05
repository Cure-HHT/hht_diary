#!/usr/bin/env bash
# Doppler token auto-creation + cleanup for local-stack.
# Sourced by ./local-stack -- defines functions only, does not run anything.

_DOPPLER_TOKEN_LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=common.sh
source "$_DOPPLER_TOKEN_LIB_DIR/common.sh"

TOKEN_STATE_FILE="$LOCAL_STACK_DIR/.token-slug"

# Ensure DOPPLER_TOKEN is set in env. If not, create a scoped service token
# and export it. Save the token slug to a state file so we can revoke later.
ensure_doppler_token() {
  if [ -n "${DOPPLER_TOKEN:-}" ]; then
    log "DOPPLER_TOKEN inherited from caller -- using as-is"
    return 0
  fi

  require_cmd doppler

  # Verify doppler CLI is authenticated (has a personal/CI token).
  local current_token
  current_token="$(doppler configure get token --plain 2>/dev/null || true)"
  if [ -z "$current_token" ]; then
    die "doppler is not authenticated. Run: doppler login && doppler setup"
  fi
  unset current_token

  local name
  name="local-stack-$(whoami)-$(date +%s)"
  log "creating short-lived doppler service token: $name"

  # Capture the JSON response so we get BOTH the token (secret) and the slug
  # (UUID — required by `doppler configs tokens revoke --slug`). Doppler's
  # human-readable token name is NOT the slug; the slug is auto-generated.
  local create_json stderr_file
  stderr_file="$(mktemp)"
  if ! create_json="$(doppler configs tokens create "$name" --config dev --max-age 24h --json 2>"$stderr_file")"; then
    local stderr_msg
    stderr_msg="$(cat "$stderr_file")"
    rm -f "$stderr_file"
    die "failed to create doppler token (name=$name): $stderr_msg"
  fi
  rm -f "$stderr_file"

  local token slug
  token="$(printf '%s' "$create_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')"
  slug="$(printf '%s' "$create_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["slug"])')"
  unset create_json

  # Persist slug (UUID) for cleanup. The state file holds only the slug —
  # not the token — so it is non-sensitive even if mode 600 is bypassed.
  (umask 177; printf '%s\n' "$slug" > "$TOKEN_STATE_FILE")

  export DOPPLER_TOKEN="$token"
  log "DOPPLER_TOKEN created (name=$name, slug=$slug, expires in 24h)"
}

# Revoke any token we created earlier. Idempotent -- safe to call when no token exists.
cleanup_doppler_token() {
  if [ ! -f "$TOKEN_STATE_FILE" ]; then
    return 0
  fi
  require_cmd doppler

  local slug
  slug="$(cat "$TOKEN_STATE_FILE")"
  if [ -z "$slug" ]; then
    rm -f "$TOKEN_STATE_FILE"
    return 0
  fi

  log "revoking doppler service token (slug=$slug)"
  # IMPORTANT: unset DOPPLER_TOKEN before the revoke call. ensure_doppler_token
  # exports a `read`-scope service token, and Doppler uses DOPPLER_TOKEN for
  # auth on every API call — including this revoke. A read-scope token cannot
  # revoke other tokens. We need to fall back to the developer's CLI session
  # token (full scope) for the revoke to succeed.
  # No --yes flag — doppler v3 doesn't support it; revoke is non-interactive
  # by default when --slug is supplied.
  if ! (unset DOPPLER_TOKEN; doppler configs tokens revoke --slug "$slug" --config dev >/dev/null 2>&1); then
    log "warning: failed to revoke token $slug (may already be expired or revoked)"
  fi
  rm -f "$TOKEN_STATE_FILE"
}
