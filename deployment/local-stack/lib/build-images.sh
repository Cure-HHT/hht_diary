#!/usr/bin/env bash
# Build the :local images needed to run the EVS stack from local worktrees.
#
#   firebase-emulator:local        — sponsor-agnostic cached base (JRE +
#                                     firebase-tools); built once, reused
#                                     across all sponsor stacks on this box.
#   {sponsor-ci,portal-server-binary,portal-final}-${SPONSOR}:local
#                                  — three per-sponsor builds.
#
# Inputs come from two repos:
#   • CORE (this toolkit's home, hht_diary): sponsor-ci.Dockerfile +
#     portal-server-binary.Dockerfile + the Dart sources.
#   • SPONSOR (e.g. hht_diary_callisto): portal-final.Dockerfile + content/ +
#     deployment/seed/portal-users.json.
#
# Per-sponsor tags carry a sponsor suffix so two sponsor repos on one dev
# box don't overwrite each other's images. NO registry namespace — they
# cannot be pushed anywhere by accident.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

build_images() {
  local core sponsor sponsor_repo
  core="$CORE_PATH"
  sponsor_repo="$(resolve_sponsor_path)"
  sponsor="$(resolve_sponsor)"

  require_cmd docker
  log "sponsor:      $sponsor"
  log "core repo:    $core"
  log "sponsor repo: $sponsor_repo"

  # firebase-emulator:local — sponsor-agnostic cached base image (JRE +
  # firebase-tools). The tag carries no sponsor suffix so cmd_down's
  # removal loop ignores it; the image survives `down` cycles for free.
  # We always invoke `docker build` rather than skipping on tag-existence
  # so a Dockerfile edit (e.g. bumping FIREBASE_TOOLS_VERSION) is picked
  # up automatically. Docker's layer cache keeps the warm path to ~1-3s;
  # cold-build is ~45s.
  local fb="firebase-emulator:local"
  log "[cache] $fb (~1-3s warm, ~45s cold)"
  docker build \
    --file "$SCRIPT_DIR/../firebase-emulator/Dockerfile" \
    --tag  "$fb" \
    "$SCRIPT_DIR/../firebase-emulator"

  local ci="sponsor-ci-${sponsor}:local"
  local pbin="portal-server-binary-${sponsor}:local"
  local pfinal="portal-final-${sponsor}:local"

  log "[1/3] building $ci"
  docker build \
    --file "$core/deployment/docker/sponsor-ci.Dockerfile" \
    --tag  "$ci" \
    "$core"

  log "[2/3] building $pbin"
  docker build \
    --file "$core/deployment/docker/portal-server-binary.Dockerfile" \
    --build-arg "SPONSOR_CI_IMAGE=$ci" \
    --tag  "$pbin" \
    "$core"

  log "[3/3] building $pfinal"
  # Local-stack bakes FIREBASE_AUTH_EMULATOR_HOST into the SPA so it talks to
  # the Firebase emulator (browser-side; Flutter web reads it at compile time).
  # CI/Cloud Run builds leave this empty and ship one environment-independent
  # bundle that resolves its environment from the server at runtime. The
  # portal-final image is owned by the SPONSOR repo and built in its context.
  docker build \
    --file "$sponsor_repo/deployment/docker/portal-final.Dockerfile" \
    --build-arg "SPONSOR_CI_IMAGE=$ci" \
    --build-arg "PORTAL_SERVER_IMAGE=$pbin" \
    --build-arg "FIREBASE_AUTH_EMULATOR_HOST=localhost:9099" \
    --tag  "$pfinal" \
    "$sponsor_repo"

  log "all :local images built for sponsor=$sponsor"
}

# Allow this script to be sourced (for testing) or executed directly.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  build_images
fi
