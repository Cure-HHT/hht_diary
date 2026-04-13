# Compiled diary-server binary image
#
# Built from sponsor-ci (source + deps already resolved).
# Produces a minimal image containing just the compiled binary + VERSIONS.
# Sponsor repos COPY the binary from this image into their final containers.
#
# Usage in sponsor Dockerfile:
#   COPY --from=ghcr.io/cure-hht/diary-server:main-latest /app/server /app/diary-server
#   COPY --from=ghcr.io/cure-hht/diary-server:main-latest /app/VERSIONS /app/VERSIONS

ARG SPONSOR_CI_IMAGE=ghcr.io/cure-hht/sponsor-ci:main-latest
FROM ${SPONSOR_CI_IMAGE} AS build

WORKDIR /workspace/src/apps/daily-diary/diary_server

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /workspace/out && \
    set -eu && \
    DIARY_SERVER_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //') && \
    DIARY_FUNCTIONS_VERSION=$(grep '^version:' /workspace/src/apps/daily-diary/diary_functions/pubspec.yaml | sed 's/version: //') && \
    TRIAL_DATA_TYPES_VERSION=$(grep '^version:' /workspace/src/apps/common-dart/trial_data_types/pubspec.yaml | sed 's/version: //') && \
    OTEL_COMMON_VERSION=$(grep '^version:' /workspace/src/apps/common-dart/otel_common/pubspec.yaml | sed 's/version: //') && \
    echo "Compiling diary-server ${DIARY_SERVER_VERSION}" && \
    dart compile exe bin/server.dart -o /workspace/out/server \
      -DDIARY_SERVER_VERSION="$DIARY_SERVER_VERSION" \
      -DDIARY_FUNCTIONS_VERSION="$DIARY_FUNCTIONS_VERSION" \
      -DTRIAL_DATA_TYPES_VERSION="$TRIAL_DATA_TYPES_VERSION" && \
    printf 'diary_server=%s\ndiary_functions=%s\ntrial_data_types=%s\notel_common=%s\n' \
      "$DIARY_SERVER_VERSION" "$DIARY_FUNCTIONS_VERSION" "$TRIAL_DATA_TYPES_VERSION" "$OTEL_COMMON_VERSION" \
      > /workspace/out/VERSIONS && \
    test -f /workspace/out/server

# Minimal image with just the binary
FROM debian:12-slim

RUN useradd -r -s /bin/false appuser
COPY --from=build /workspace/out/server /app/server
COPY --from=build /workspace/out/VERSIONS /app/VERSIONS
USER appuser

LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="Diary server compiled binary"
