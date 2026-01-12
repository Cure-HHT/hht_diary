# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-p00013: GDPR compliance - EU-only regions
#   REQ-d00028: Portal Frontend Framework
#
# Sponsor Portal Container
# Hosts portal_server (Dart API) + portal-ui (Flutter web) via nginx
#
# Build args:
#   DART_VERSION - from .github/versions.env
#   FLUTTER_VERSION - from .github/versions.env
#   GCP_PROJECT_ID - GCP project for base image

ARG DART_VERSION
ARG FLUTTER_VERSION
ARG GCP_PROJECT_ID

# =============================================================================
# Stage 1: Build Flutter Web UI
# =============================================================================
FROM europe-west1-docker.pkg.dev/${GCP_PROJECT_ID}/hht-diary/flutter-base:${FLUTTER_VERSION} AS flutter-build

# Copy portal-ui source
COPY apps/sponsor-portal/portal-ui /app/apps/sponsor-portal/portal-ui

WORKDIR /app/apps/sponsor-portal/portal-ui

# Get dependencies and build for web
RUN flutter pub get
RUN flutter build web --release --web-renderer html

# =============================================================================
# Stage 2: Build Dart Server
# =============================================================================
FROM europe-west1-docker.pkg.dev/${GCP_PROJECT_ID}/hht-diary/dart-base:${DART_VERSION} AS dart-build

# Copy shared dependencies first (for layer caching)
COPY apps/common-dart/trial_data_types /app/apps/common-dart/trial_data_types

# Copy portal_functions package
COPY apps/sponsor-portal/portal_functions /app/apps/sponsor-portal/portal_functions

# Copy portal_server package
COPY apps/sponsor-portal/portal_server /app/apps/sponsor-portal/portal_server

# Get dependencies and compile
WORKDIR /app/apps/sponsor-portal/portal_server
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

# =============================================================================
# Stage 3: Runtime - nginx + Dart server
# =============================================================================
FROM debian:bookworm-slim

# Install nginx and required runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -r -s /bin/false appuser

# Copy Dart server binary
COPY --from=dart-build /app/apps/sponsor-portal/portal_server/bin/server /app/server

# Copy Flutter web build
COPY --from=flutter-build /app/apps/sponsor-portal/portal-ui/build/web /app/web

# Copy nginx configuration
COPY apps/sponsor-portal/portal-container/nginx.conf /etc/nginx/nginx.conf

# Copy startup script
COPY apps/sponsor-portal/portal-container/start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Create nginx runtime directories with correct permissions
RUN mkdir -p /var/cache/nginx /var/run /var/log/nginx \
    && chown -R appuser:appuser /var/cache/nginx /var/run /var/log/nginx /app

# Cloud Run sets PORT environment variable
ENV PORT=8080
EXPOSE 8080

# Run as non-root user
USER appuser

# Health check via nginx (proxies to Dart /health endpoint)
# Note: Cloud Run uses HTTP probes, not Docker HEALTHCHECK

ENTRYPOINT ["/app/start.sh"]
