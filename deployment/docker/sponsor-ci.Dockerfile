# Sponsor CI base image
# Purpose:
# - provide a reusable CI/build image for sponsor-specific downstream builds
# - include the shared app source trees needed by downstream portal/diary final images
# - avoid assuming monorepo root files exist when they do not

FROM ghcr.io/cure-hht/clinical-diary-ci@sha256:044a6171ff4f75b2e5f5d594ed24cac912ac9abfd4f5527ed6b18c2125c3ac28

WORKDIR /workspace/src

# Copy only files/directories that are confirmed to exist in this repo layout.
# The previous build failed because it tried to copy missing root-level files like:
#   pubspec.yaml
#   pubspec.lock
#   melos.yaml
#   analysis_options.yaml
#   dart_test.yaml
#
# Keep versions.env if it exists in the repo and is needed by the build.
COPY .github/versions.env ./.github/versions.env

# Shared/common packages
COPY apps/common-dart/trial_data_types ./apps/common-dart/trial_data_types
COPY apps/edc/rave-integration ./apps/edc/rave-integration

# Sponsor portal apps
COPY apps/sponsor-portal/portal_functions ./apps/sponsor-portal/portal_functions
COPY apps/sponsor-portal/portal_server ./apps/sponsor-portal/portal_server
COPY apps/sponsor-portal/portal-ui ./apps/sponsor-portal/portal-ui

# Daily diary apps
COPY apps/daily-diary/diary_functions ./apps/daily-diary/diary_functions
COPY apps/daily-diary/diary_server ./apps/daily-diary/diary_server

# Resolve package dependencies per package/app directory.
WORKDIR /workspace/src/apps/common-dart/trial_data_types
RUN dart pub get

WORKDIR /workspace/src/apps/edc/rave-integration
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal_functions
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal_server
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal-ui
RUN flutter pub get

WORKDIR /workspace/src/apps/daily-diary/diary_functions
RUN dart pub get

WORKDIR /workspace/src/apps/daily-diary/diary_server
RUN dart pub get

# Sanity checks so downstream builds fail early if the expected layout changes.
WORKDIR /workspace/src
RUN set -euo pipefail && \
    test -d /workspace/src/apps/common-dart/trial_data_types && \
    test -d /workspace/src/apps/edc/rave-integration && \
    test -d /workspace/src/apps/sponsor-portal/portal_functions && \
    test -d /workspace/src/apps/sponsor-portal/portal_server && \
    test -d /workspace/src/apps/sponsor-portal/portal-ui && \
    test -d /workspace/src/apps/daily-diary/diary_functions && \
    test -d /workspace/src/apps/daily-diary/diary_server && \
    test ! -d /workspace/src/sponsor-content && \
    test ! -f /workspace/src/apps/sponsor-portal/portal_server/bin/server && \
    test ! -d /workspace/src/apps/sponsor-portal/portal-ui/build/web

# Non-root runtime/user compatibility for downstream stages.
RUN groupadd --gid 10001 appuser && \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /workspace

WORKDIR /workspace/src
