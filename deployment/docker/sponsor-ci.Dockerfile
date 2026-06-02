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
COPY --chown=10001:10001 apps/common-dart/otel_common/pubspec.yaml ./apps/common-dart/otel_common/pubspec.yaml
COPY --chown=10001:10001 apps/common-dart/grpc_health/pubspec.yaml ./apps/common-dart/grpc_health/pubspec.yaml
COPY --chown=10001:10001 apps/common-dart/comms/pubspec.yaml ./apps/common-dart/comms/pubspec.yaml
COPY --chown=10001:10001 apps/common-dart/diary_shared_model/pubspec.yaml ./apps/common-dart/diary_shared_model/pubspec.yaml
COPY --chown=10001:10001 apps/common-dart/portal_actions/pubspec.yaml ./apps/common-dart/portal_actions/pubspec.yaml
COPY --chown=10001:10001 apps/edc/rave-integration/pubspec.yaml ./apps/edc/rave-integration/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal_functions/pubspec.yaml ./apps/sponsor-portal/portal_functions/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal_server/pubspec.yaml ./apps/sponsor-portal/portal_server/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal-ui/pubspec.yaml ./apps/sponsor-portal/portal-ui/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal_identity/pubspec.yaml ./apps/sponsor-portal/portal_identity/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal_service/pubspec.yaml ./apps/sponsor-portal/portal_service/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal_server_evs/pubspec.yaml ./apps/sponsor-portal/portal_server_evs/pubspec.yaml
COPY --chown=10001:10001 apps/sponsor-portal/portal_ui_evs/pubspec.yaml ./apps/sponsor-portal/portal_ui_evs/pubspec.yaml
COPY --chown=10001:10001 apps/common-flutter/common_widgets/pubspec.yaml ./apps/common-flutter/common_widgets/pubspec.yaml
COPY --chown=10001:10001 apps/daily-diary/diary_functions/pubspec.yaml ./apps/daily-diary/diary_functions/pubspec.yaml
COPY --chown=10001:10001 apps/daily-diary/diary_server/pubspec.yaml ./apps/daily-diary/diary_server/pubspec.yaml

# -----------------------------
# Resolve dependencies
# -----------------------------
WORKDIR /workspace/src/apps/common-dart/trial_data_types
RUN dart pub get

WORKDIR /workspace/src/apps/common-dart/shared_functions
RUN dart pub get

WORKDIR /workspace/src/apps/common-dart/otel_common
RUN dart pub get

WORKDIR /workspace/src/apps/common-dart/grpc_health
RUN dart pub get

WORKDIR /workspace/src/apps/edc/rave-integration
RUN dart pub get

WORKDIR /workspace/src/apps/common-dart/diary_shared_model
RUN dart pub get

WORKDIR /workspace/src/apps/common-dart/portal_actions
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal_functions
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal_server
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal-ui
RUN flutter pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal_identity
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal_service
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal_server_evs
RUN dart pub get

WORKDIR /workspace/src/apps/sponsor-portal/portal_ui_evs
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
COPY --chown=10001:10001 apps/common-dart/otel_common ./apps/common-dart/otel_common
COPY --chown=10001:10001 apps/common-dart/grpc_health ./apps/common-dart/grpc_health
COPY --chown=10001:10001 apps/common-dart/comms ./apps/common-dart/comms
COPY --chown=10001:10001 apps/common-dart/diary_shared_model ./apps/common-dart/diary_shared_model
COPY --chown=10001:10001 apps/common-dart/portal_actions ./apps/common-dart/portal_actions
COPY --chown=10001:10001 apps/edc/rave-integration ./apps/edc/rave-integration
COPY --chown=10001:10001 apps/sponsor-portal/portal_functions ./apps/sponsor-portal/portal_functions
COPY --chown=10001:10001 apps/sponsor-portal/portal_server ./apps/sponsor-portal/portal_server
COPY --chown=10001:10001 apps/sponsor-portal/portal-ui ./apps/sponsor-portal/portal-ui
COPY --chown=10001:10001 apps/sponsor-portal/portal_identity ./apps/sponsor-portal/portal_identity
COPY --chown=10001:10001 apps/sponsor-portal/portal_service ./apps/sponsor-portal/portal_service
COPY --chown=10001:10001 apps/sponsor-portal/portal_server_evs ./apps/sponsor-portal/portal_server_evs
COPY --chown=10001:10001 apps/sponsor-portal/portal_ui_evs ./apps/sponsor-portal/portal_ui_evs
COPY --chown=10001:10001 apps/common-flutter/common_widgets ./apps/common-flutter/common_widgets
COPY --chown=10001:10001 apps/daily-diary/diary_functions ./apps/daily-diary/diary_functions
COPY --chown=10001:10001 apps/daily-diary/diary_server ./apps/daily-diary/diary_server

# -----------------------------
# Sanity checks
# -----------------------------
RUN set -euo pipefail && \
    test -d apps/common-dart/trial_data_types && \
    test -d apps/common-dart/shared_functions && \
    test -d apps/common-dart/otel_common && \
    test -d apps/common-dart/grpc_health && \
    test -d apps/common-dart/comms && \
    test -d apps/common-dart/diary_shared_model && \
    test -d apps/common-dart/portal_actions && \
    test -d apps/edc/rave-integration && \
    test -d apps/sponsor-portal/portal_functions && \
    test -d apps/sponsor-portal/portal_server && \
    test -d apps/sponsor-portal/portal-ui && \
    test -d apps/sponsor-portal/portal_identity && \
    test -d apps/sponsor-portal/portal_service && \
    test -d apps/sponsor-portal/portal_server_evs && \
    test -d apps/sponsor-portal/portal_ui_evs && \
    test -d apps/common-flutter/common_widgets && \
    test -d apps/daily-diary/diary_functions && \
    test -d apps/daily-diary/diary_server && \
    test ! -d sponsor-content && \
    test ! -f apps/sponsor-portal/portal_server/bin/server && \
    test ! -d apps/sponsor-portal/portal-ui/build/web && \
    test ! -d apps/sponsor-portal/portal_ui_evs/build/web

WORKDIR /workspace/src
USER 10001:10001
