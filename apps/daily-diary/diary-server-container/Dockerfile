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

ARG DART_VERSION
ARG GCP_PROJECT_ID
FROM europe-west1-docker.pkg.dev/${GCP_PROJECT_ID}/hht-diary/dart-base:${DART_VERSION} AS build

# Copy shared dependencies first (for layer caching)
COPY apps/common-dart/trial_data_types /app/apps/common-dart/trial_data_types

# Copy diary_functions package
COPY apps/daily-diary/diary_functions /app/apps/daily-diary/diary_functions

# Copy diary_server package
COPY apps/daily-diary/diary_server /app/apps/daily-diary/diary_server

# Get dependencies and compile
WORKDIR /app/apps/daily-diary/diary_server
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

# Runtime stage - minimal image
# Using :nonroot tag for security (DS001, DS002)
FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=build /app/apps/daily-diary/diary_server/bin/server /app/server

# Cloud Run sets PORT environment variable
ENV PORT=8080
EXPOSE 8080

# Explicit non-root user (uid 65532 in distroless)
USER nonroot:nonroot

# Note: HEALTHCHECK not used - Cloud Run uses HTTP probes to /health endpoint
# See: https://cloud.google.com/run/docs/configuring/healthchecks

ENTRYPOINT ["/app/server"]
