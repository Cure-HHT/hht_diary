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
#     deployment/seed/portal-users.json. With no sponsor checkout this resolves
#     to the built-in reference sponsor in core (deployment/reference-sponsor),
#     so "$sponsor_repo" below may point back into the core tree.
#
# Per-sponsor tags carry a sponsor suffix so two sponsor repos on one dev
# box don't overwrite each other's images. NO registry namespace — they
# cannot be pushed anywhere by accident.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Build clinical-diary-ci:local from core's tools/dev-env/docker/ci.Dockerfile.
# This is the CI toolchain image (Flutter + Android SDK + JDK + gcloud + ...)
# that sponsor-ci builds FROM. Built with the SAME pinned versions CI uses
# (sourced from .github/versions.env) so the local base matches CI's inputs.
# The image has no sponsor suffix, so it is shared across sponsor stacks and
# (like firebase-emulator:local) survives `down`. Always invoked so a
# ci.Dockerfile / versions.env edit is picked up; Docker's layer cache keeps
# the warm path fast. Cold build pulls the Flutter + Android SDK (minutes).
build_clinical_diary_ci_local() {
  local core="$1"
  local dockerfile="$core/tools/dev-env/docker/ci.Dockerfile"
  local ctx="$core/tools/dev-env/docker"
  local versions="$core/.github/versions.env"
  # Existence already validated by resolve_ci_base(); re-checked defensively.
  [ -f "$dockerfile" ] || die "missing CI Dockerfile: $dockerfile"
  [ -f "$versions" ]   || die "missing versions file: $versions"

  # Pull pinned tool versions into the environment (parity with CI's
  # build-ghcr-containers.yml build-args). versions.env is KEY=value + comments.
  set -a
  # shellcheck disable=SC1090
  source "$versions"
  set +a

  log "[ci-base] building clinical-diary-ci:local from $dockerfile"
  log "[ci-base] cold build downloads the Flutter + Android SDK (several minutes); cached after"
  docker build \
    --file "$dockerfile" \
    --build-arg "NODE_MAJOR_VERSION=${NODE_MAJOR_VERSION}" \
    --build-arg "FLUTTER_VERSION=${FLUTTER_VERSION}" \
    --build-arg "GITLEAKS_VERSION=${GITLEAKS_VERSION}" \
    --build-arg "SQUAWK_VERSION=${SQUAWK_VERSION}" \
    --build-arg "ELSPAIS_VERSION=${ELSPAIS_VERSION}" \
    --build-arg "MARKDOWNLINT_CLI_VERSION=${MARKDOWNLINT_CLI_VERSION}" \
    --build-arg "CLOUD_SQL_PROXY_VERSION=${CLOUD_SQL_PROXY_VERSION}" \
    --build-arg "ANDROID_CMDLINE_TOOLS_VERSION=${ANDROID_CMDLINE_TOOLS_VERSION}" \
    --build-arg "ANDROID_BUILD_TOOLS_VERSION=${ANDROID_BUILD_TOOLS_VERSION}" \
    --build-arg "ANDROID_PLATFORM_VERSION=${ANDROID_PLATFORM_VERSION}" \
    --build-arg "OPENJDK_VERSION=${OPENJDK_VERSION}" \
    --build-arg "POSTGRESQL_CLIENT_VERSION=${POSTGRESQL_CLIENT_VERSION}" \
    --tag  "clinical-diary-ci:local" \
    "$ctx"
}

build_images() {
  local core sponsor sponsor_repo ci_base
  core="$CORE_PATH"
  sponsor_repo="$(resolve_sponsor_path)"
  sponsor="$(resolve_sponsor)"
  # Validate the CI base-image source up front (fails fast, before any build).
  ci_base="$(resolve_ci_base)"

  require_cmd docker
  log "sponsor:      $sponsor"
  log "core repo:    $core"
  log "sponsor repo: $sponsor_repo"
  log "ci base:      $ci_base"

  # Resolve the clinical-diary-ci base image that sponsor-ci builds FROM.
  #   local (default): build clinical-diary-ci:local from core's ci.Dockerfile
  #                    and override sponsor-ci's CI_BASE_IMAGE with it. No GHCR.
  #   ghcr:            leave CI_BASE_IMAGE unset so sponsor-ci.Dockerfile's
  #                    digest-pinned default (pulled from GHCR) is used.
  local ci_base_image=""
  if [ "$ci_base" = "local" ]; then
    build_clinical_diary_ci_local "$core"
    ci_base_image="clinical-diary-ci:local"
  fi

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
  local ci_build_args=()
  [ -n "$ci_base_image" ] && ci_build_args+=(--build-arg "CI_BASE_IMAGE=$ci_base_image")
  docker build \
    --file "$core/deployment/docker/sponsor-ci.Dockerfile" \
    "${ci_build_args[@]}" \
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
