FROM ghcr.io/cure-hht/clinical-diary-ci@sha256:044a6171ff4f75b2e5f5d594ed24cac912ac9abfd4f5527ed6b18c2125c3ac28

USER root
WORKDIR /workspace/src

# Create app user and fix writable locations needed before switching to non-root
RUN groupadd --gid 10001 appuser && \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash appuser && \
    mkdir -p /workspace/src /opt/flutter/bin/cache && \
    chown -R 10001:10001 /workspace /opt/flutter/bin/cache

# Switch to non-root before running Dart/Flutter tooling
USER 10001:10001

# Allow Git operations against the Flutter checkout used internally by Dart/Flutter
RUN git config --global --add safe.directory /opt/flutter

# Keep versions metadata if needed by downstream logic
COPY --chown=10001:10001 .github/versions.env ./.github/versions.env

# -----------------------------
# Dependency manifests first (cache-friendly)
# -----------------------------
COPY --chown=10001:10001 apps/common-dart/trial_data_types/pubspec.yaml ./apps/common-dart/trial_data_types/pubspec.yaml
COPY --chown=10001:10001 apps/common-dart/shared_functions/pubspec.yaml ./apps/common-dart/shared_functions/pubspec.yaml
COPY --chown=10001:10001 apps/edc/rave-integration/pubspec.yaml ./apps/edc/rave-integration/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal_functions/pubspec.yaml ./apps/sponsor-portal/portal_functions/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal_server/pubspec.yaml ./apps/sponsor-portal/portal_server/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal-ui/pubspec.yaml ./apps/sponsor-portal/portal-ui/pubspec.yaml
COPY --chown=10001:10001 apps/daily-diary/diary_functions/pubspec.yaml ./apps/daily-diary/diary_functions/pubspec.yaml
COPY --chown=10001:10001 apps/daily-diary/diary_server/pubspec.yaml ./apps/daily-diary/diary_server/pubspec.yaml

# -----------------------------
# Resolve dependencies
# -----------------------------
WORKDIR /workspace/src/apps/common-dart/trial_data_types
RUN dart pub get

WORKDIR /workspace/src/apps/common-dart/shared_functions
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

# -----------------------------
# Copy full source after deps
# -----------------------------
WORKDIR /workspace/src

COPY --chown=10001:10001 apps/common-dart/trial_data_types ./apps/common-dart/trial_data_types
COPY --chown=10001:10001 apps/common-dart/shared_functions ./apps/common-dart/shared_functions
COPY --chown=10001:10001 apps/edc/rave-integration ./apps/edc/rave-integration
COPY --chown=10001:10001 apps/sponsor-portal/portal_functions ./apps/sponsor-portal/portal_functions
COPY --chown=10001:10001 apps/sponsor-portal/portal_server ./apps/sponsor-portal/portal_server
COPY --chown=10001:10001 apps/sponsor-portal/portal-ui ./apps/sponsor-portal/portal-ui
COPY --chown=10001:10001 apps/daily-diary/diary_functions ./apps/daily-diary/diary_functions
COPY --chown=10001:10001 apps/daily-diary/diary_server ./apps/daily-diary/diary_server

# -----------------------------
# Sanity checks
# -----------------------------
RUN set -euo pipefail && \
    test -d apps/common-dart/trial_data_types && \
    test -d apps/common-dart/shared_functions && \
    test -d apps/edc/rave-integration && \
    test -d apps/sponsor-portal/portal_functions && \
    test -d apps/sponsor-portal/portal_server && \
    test -d apps/sponsor-portal/portal-ui && \
    test -d apps/daily-diary/diary_functions && \
    test -d apps/daily-diary/diary_server && \
    test ! -d sponsor-content && \
    test ! -f apps/sponsor-portal/portal_server/bin/server && \
    test ! -d apps/sponsor-portal/portal-ui/build/web

WORKDIR /workspace/src
USER 10001:10001
