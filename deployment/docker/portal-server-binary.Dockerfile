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

# Core git short_sha of the commit this binary was compiled from. CI passes
# build-sponsor-ci's short_sha; a standalone build leaves it "unknown". This is
# the AXIS-A provenance pointer (exact source of THESE bytes) that pairs with
# the human-facing portal_server_evs=<semver>+N. Because the binary build is
# gated on +N (build-sponsor-ci.yml), this is "the commit that last changed the
# binary" — truthful by construction.
ARG SERVER_COMMIT=unknown

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /workspace/out && \
    set -eu && \
    PORTAL_EVS_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //') && \
    echo "Compiling portal_server_evs ${PORTAL_EVS_VERSION} (commit ${SERVER_COMMIT})" && \
    dart compile exe bin/server.dart -o /workspace/out/server && \
    { printf 'portal_server_evs=%s\n' "$PORTAL_EVS_VERSION"; \
      printf 'server_commit=%s\n' "$SERVER_COMMIT"; } > /workspace/out/VERSIONS && \
    test -f /workspace/out/server

# Minimal image with just the binary
FROM debian:12-slim

RUN useradd -r -s /bin/false appuser
COPY --from=build /workspace/out/server /app/server
COPY --from=build /workspace/out/VERSIONS /app/VERSIONS
USER appuser

LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="Portal server (portal_server_evs) compiled binary"
