FROM ghcr.io/cure-hht/clinical-diary-ci@sha256:044a6171ff4f75b2e5f5d594ed24cac912ac9abfd4f5527ed6b18c2125c3ac28

WORKDIR /workspace/src

# Keep versions metadata if needed by downstream logic
COPY .github/versions.env ./.github/versions.env

# -----------------------------
# Dependency manifests first
# -----------------------------

# common-dart/trial_data_types
COPY apps/common-dart/trial_data_types/pubspec.yaml ./apps/common-dart/trial_data_types/pubspec.yaml

# edc/rave-integration
COPY apps/edc/rave-integration/pubspec.yaml ./apps/edc/rave-integration/pubspec.yaml

# sponsor-portal/portal_functions
COPY apps/sponsor-portal/portal_functions/pubspec.yaml ./apps/sponsor-portal/portal_functions/pubspec.yaml

# sponsor-portal/portal_server
COPY apps/sponsor-portal/portal_server/pubspec.yaml ./apps/sponsor-portal/portal_server/pubspec.yaml

# sponsor-portal/portal-ui
COPY apps/sponsor-portal/portal-ui/pubspec.yaml ./apps/sponsor-portal/portal-ui/pubspec.yaml

# daily-diary/diary_functions
COPY apps/daily-diary/diary_functions/pubspec.yaml ./apps/daily-diary/diary_functions/pubspec.yaml

# daily-diary/diary_server
COPY apps/daily-diary/diary_server/pubspec.yaml ./apps/daily-diary/diary_server/pubspec.yaml

# -----------------------------
# Permission fix before pub get
# -----------------------------
RUN mkdir -p /workspace/src && \
    chmod -R u+rwX /workspace

# -----------------------------
# Resolve dependencies
# -----------------------------
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

# -----------------------------
# Copy full source after deps
# -----------------------------
WORKDIR /workspace/src

COPY apps/common-dart/trial_data_types ./apps/common-dart/trial_data_types
COPY apps/edc/rave-integration ./apps/edc/rave-integration
COPY apps/sponsor-portal/portal_functions ./apps/sponsor-portal/portal_functions
COPY apps/sponsor-portal/portal_server ./apps/sponsor-portal/portal_server
COPY apps/sponsor-portal/portal-ui ./apps/sponsor-portal/portal-ui
COPY apps/daily-diary/diary_functions ./apps/daily-diary/diary_functions
COPY apps/daily-diary/diary_server ./apps/daily-diary/diary_server

# -----------------------------
# Sanity checks
# -----------------------------
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

# -----------------------------
# Non-root final image
# -----------------------------
RUN groupadd --gid 10001 appuser && \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /workspace

WORKDIR /workspace/src
USER 10001:10001

