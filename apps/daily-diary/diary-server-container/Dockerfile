# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-p00013: GDPR compliance - EU-only regions
#
# Diary Server Container
# Hosts diary_functions as HTTP endpoints via shelf
#
# Build args:
#   DART_VERSION - from .github/versions.env
#   GCP_PROJECT_ID - GCP project for base image

# Default values satisfy Docker's static linter; overridden by --build-arg in CI
ARG BASE_IMAGE=ghcr.io/cure-hht/dart-base:3.10.7
ARG DEBIAN_IMAGE=gcr.io/distroless/cc-debian12:nonroot
FROM ${BASE_IMAGE} AS base
# FROM europe-west1-docker.pkg.dev/${GCP_PROJECT_ID}/hht-diary/dart-base:${DART_VERSION} AS build

# Copy shared dependencies first (for layer caching)
COPY --chown=1000:1000 apps/common-dart/trial_data_types /app/apps/common-dart/trial_data_types

# Copy diary_functions package
COPY --chown=1000:1000 apps/daily-diary/diary_functions /app/apps/daily-diary/diary_functions

# Copy diary_server package
COPY --chown=1000:1000 apps/daily-diary/diary_server /app/apps/daily-diary/diary_server

# Get dependencies and compile
WORKDIR /app/apps/daily-diary/diary_server
RUN dart pub get

# Runtime stage - minimal image
# Using :nonroot tag for security (DS001, DS002)
FROM ${DEBIAN_IMAGE} AS runtime
# FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=base /app/apps/daily-diary/diary_server/bin/server.dart /app/server

# Cloud Run sets PORT environment variable
ENV PORT=8080
EXPOSE 8080

# Explicit non-root user (uid 65532 in distroless)
USER nonroot:nonroot

# Note: HEALTHCHECK not used - Cloud Run uses HTTP probes to /health endpoint
# See: https://cloud.google.com/run/docs/configuring/healthchecks

ENTRYPOINT ["/app/server"]
