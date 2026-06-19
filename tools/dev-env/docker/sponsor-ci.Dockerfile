# Shared sponsor CI base image
# Includes shared application source + resolved dependencies
# Does NOT include sponsor content, compiled binaries, or runtime-only tooling

FROM ghcr.io/cure-hht/clinical-diary-ci@sha256:044a6171ff4f75b2e5f5d594ed24cac912ac9abfd4f5527ed6b18c2125c3ac28

WORKDIR /workspace/src

# Copy repo metadata / toolchain files first for better layer caching
COPY pubspec.yaml ./
COPY pubspec.lock ./
COPY melos.yaml ./
COPY analysis_options.yaml ./
COPY dart_test.yaml ./
COPY .github/versions.env ./.github/versions.env

# Copy only the shared source trees needed by sponsor builds
COPY apps/common-dart/trial_data_types ./apps/common-dart/trial_data_types
COPY apps/common-dart/shared_functions ./apps/common-dart/shared_functions
COPY apps/common-dart/otel_common ./apps/common-dart/otel_common
COPY apps/common-dart/grpc_health ./apps/common-dart/grpc_health
COPY apps/common-dart/comms ./apps/common-dart/comms
COPY apps/edc/rave-integration ./apps/edc/rave-integration
COPY apps/common-flutter/diary_design_system ./apps/common-flutter/diary_design_system

# Resolve dependencies for shared packages/apps
WORKDIR /workspace/src/apps/common-dart/trial_data_types
RUN dart pub get

WORKDIR /workspace/src/apps/common-dart/otel_common
RUN dart pub get

WORKDIR /workspace/src/apps/common-dart/grpc_health
RUN dart pub get

WORKDIR /workspace/src/apps/edc/rave-integration
RUN dart pub get

WORKDIR /workspace/src

# Validate expected image shape during build
RUN set -euo pipefail && \
    test -d /workspace/src/apps/common-dart/trial_data_types && \
    test -d /workspace/src/apps/common-dart/shared_functions && \
    test -d /workspace/src/apps/common-dart/otel_common && \
    test -d /workspace/src/apps/common-dart/grpc_health && \
    test -d /workspace/src/apps/common-dart/comms && \
    test -d /workspace/src/apps/edc/rave-integration && \
    test -d /workspace/src/apps/common-flutter/diary_design_system && \
    test ! -d /workspace/src/sponsor-content

# Create and use a non-root user
RUN groupadd --gid 10001 appuser && \
    useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /workspace

USER appuser

WORKDIR /workspace/src

CMD ["/bin/bash"]