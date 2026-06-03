# Compiled portal-server binary image
#
# Built from sponsor-ci (source + deps already resolved).
# Produces a minimal image containing just the compiled binary + VERSIONS.
# Sponsor repos COPY the binary from this image into their final containers.
#
# Usage in sponsor Dockerfile:
#   COPY --from=ghcr.io/cure-hht/portal-server:main-latest /app/server /app/portal-server
#   COPY --from=ghcr.io/cure-hht/portal-server:main-latest /app/VERSIONS /app/VERSIONS

ARG SPONSOR_CI_IMAGE=ghcr.io/cure-hht/sponsor-ci:main-latest
FROM ${SPONSOR_CI_IMAGE} AS build

WORKDIR /workspace/src/apps/sponsor-portal/portal_server_evs

# Ensure deps are resolved for this package (sponsor-ci may have stale .dart_tool)
RUN dart pub get --offline

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /workspace/out && \
    set -eu && \
    PORTAL_EVS_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //') && \
    echo "Compiling portal_server_evs ${PORTAL_EVS_VERSION}" && \
    dart compile exe bin/server.dart -o /workspace/out/server && \
    printf 'portal_server_evs=%s\n' "$PORTAL_EVS_VERSION" > /workspace/out/VERSIONS && \
    test -f /workspace/out/server

# Minimal image with just the binary
FROM debian:12-slim

RUN useradd -r -s /bin/false appuser
COPY --from=build /workspace/out/server /app/server
COPY --from=build /workspace/out/VERSIONS /app/VERSIONS
USER appuser

LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="Portal server (portal_server_evs) compiled binary"
