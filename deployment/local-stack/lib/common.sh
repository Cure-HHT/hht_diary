#!/usr/bin/env bash
# Shared helpers for deployment/local-stack/ scripts.
# Expected to be sourced, not executed directly.

# NOTE: sourcing this file imposes `set -euo pipefail` on the calling script.
# All callers in deployment/local-stack/ already use strict mode, so this is
# a no-op for them. If you source this from somewhere that needs looser
# behavior, save and restore options around the source.
set -euo pipefail

# Resolve the directory containing this file (works when sourced).
_COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# _COMMON_DIR = <core>/deployment/local-stack/lib
# The toolkit root (where .local-stack.toml lives) is one level up.
LOCAL_STACK_DIR="$( cd "$_COMMON_DIR/.." && pwd )"
# This toolkit now lives in the CORE repo (hht_diary). CORE_PATH is the
# core source tree the images build FROM. By default it's the toolkit's own
# checkout (the top of the git working tree it sits in); override with the
# CORE_REPO env var to build from a DIFFERENT core worktree/branch (e.g. a
# feature branch under review) without moving the toolkit. Parallels
# SPONSOR_REPO. The legacy `REPO_ROOT` (formerly the sponsor repo) is gone:
# the sponsor repo is resolved separately via resolve_sponsor_path.
CORE_PATH="${CORE_REPO:-"$( cd "$LOCAL_STACK_DIR" && git rev-parse --show-toplevel )"}"

log() {
  printf '[local-stack] %s\n' "$*" >&2
}

die() {
  printf '[local-stack] FATAL: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "required command not found in PATH: $cmd"
}

require_env() {
  local var="$1"
  if [ -z "${!var:-}" ]; then
    die "required env var not set: $var (tip: run via 'doppler run --config dev -- ./local-stack ...')"
  fi
}

# Resolve the sponsor repo path. Prints absolute path to stdout, returns 0
# on success. Echoes diagnostic + exits 1 on failure.
#
# The toolkit lives in core; the *sponsor* repo is what needs resolving (it
# supplies base-config.json, the sponsor portal-final.Dockerfile, content/,
# and the portal seed-users file). Resolution order (in the Python resolver):
#   1. $SPONSOR_REPO env var (absolute path) — set by the sponsor wrapper.
#   2. [associated.sponsor].path in <toolkit>/.local-stack.toml, overlaid by
#      .local-stack.local.toml.
resolve_sponsor_path() {
  require_cmd python3
  # The resolver writes the abs path to stdout and diagnostics to stderr.
  # Let stderr pass through to the user's terminal — don't capture-and-reprint.
  local path
  if ! path="$(python3 "$LOCAL_STACK_DIR/lib/resolve-sponsor-path.py" --toolkit "$LOCAL_STACK_DIR")"; then
    die "could not resolve sponsor repo path (see message above)"
  fi
  printf '%s\n' "$path"
}

# Read the sponsor id from the sponsor repo's deployment/base-config.json.
# Prints it on stdout. Fails loudly if base-config.json is missing or lacks a
# `sponsor` field.
resolve_sponsor() {
  require_cmd python3
  local sponsor_repo; sponsor_repo="$(resolve_sponsor_path)"
  local cfg="$sponsor_repo/deployment/base-config.json"
  [ -f "$cfg" ] || die "missing $cfg (expected to contain a non-empty string \"sponsor\" field)"
  local sponsor
  if ! sponsor="$(python3 - "$cfg" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
v = data.get("sponsor")
if not isinstance(v, str) or not v:
    sys.exit('FATAL: "sponsor" must be a non-empty string in ' + sys.argv[1])
print(v)
PYEOF
  )"; then
    die "could not read \"sponsor\" from $cfg (see Python message above)"
  fi
  printf '%s\n' "$sponsor"
}

# Read the EDC module selection from deployment/base-config.json. Prints it
# on stdout. Defaults to "mock" if the key is missing or empty (graceful for
# older base-config.json files). Two recognized values today: "mock" (no
# live EDC; portal reads seeded sites/patients) and "rave" (live RAVE).
# Future modules will add new strings. Per CUR-1264.
resolve_edc_module() {
  require_cmd python3
  local sponsor_repo; sponsor_repo="$(resolve_sponsor_path)"
  local cfg="$sponsor_repo/deployment/base-config.json"
  [ -f "$cfg" ] || die "missing $cfg"
  local edc_module
  if ! edc_module="$(python3 - "$cfg" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
v = data.get("edc_module", "mock")
if not isinstance(v, str) or not v.strip():
    v = "mock"
print(v.strip().lower())
PYEOF
  )"; then
    die "could not read \"edc_module\" from $cfg (see Python message above)"
  fi
  printf '%s\n' "$edc_module"
}
