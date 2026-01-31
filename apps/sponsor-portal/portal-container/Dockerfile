# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-p00013: GDPR compliance - EU-only regions
#   REQ-d00028: Portal Frontend Framework
#
# Sponsor Portal Container
# Hosts portal_server (Dart API) + portal-ui (Flutter web) via nginx
#
# Build args:
#   FLUTTER_IMAGE - from .github/workflows/build-portal-server.yml

ARG FLUTTER_IMAGE=ghcr.io/cure-hht/flutter-base:3.38.7
ARG DART_BASE_IMAGE=ghcr.io/cure-hht/dart-base:3.10.7
ARG DEBIAN_IMAGE=debian:12-slim
# =============================================================================
# Stage 1: Build Flutter Web UI
# =============================================================================
FROM ${FLUTTER_IMAGE} AS flutter-build

# Copy portal-ui source (use --chown because flutter-base runs as appuser)
COPY --chown=appuser:appuser apps/sponsor-portal/portal-ui /app/apps/sponsor-portal/portal-ui

WORKDIR /app/apps/sponsor-portal/portal-ui

# Get dependencies and build for web
# APP_FLAVOR=prod means the app will fetch Identity Platform config from server
# at runtime via /api/v1/portal/config/identity (Doppler provides the values)
# This allows the same Docker image to work across all environments
# APP_VERSION is extracted from pubspec.yaml so it's always in sync
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN flutter pub get && \
    APP_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //;s/+.*//') && \
    flutter build web --release \
      --dart-define=APP_FLAVOR=prod \
      --dart-define=APP_VERSION="$APP_VERSION" \
      --pwa-strategy=none

# =============================================================================
# Stage 2: Build Dart Server
# =============================================================================
FROM ${DART_BASE_IMAGE} AS dart-build

# Copy shared dependencies first (for layer caching)
# Use --chown because dart-base runs as appuser
COPY --chown=appuser:appuser apps/common-dart/trial_data_types /app/apps/common-dart/trial_data_types

# Copy EDC integration (dependency of portal_functions)
COPY --chown=appuser:appuser apps/edc/rave-integration /app/apps/edc/rave-integration

# Copy portal_functions package
COPY --chown=appuser:appuser apps/sponsor-portal/portal_functions /app/apps/sponsor-portal/portal_functions

# Copy portal_server package
COPY --chown=appuser:appuser apps/sponsor-portal/portal_server /app/apps/sponsor-portal/portal_server

# Get dependencies and compile
WORKDIR /app/apps/sponsor-portal/portal_server
RUN dart pub get && \
    dart compile exe bin/server.dart -o bin/server

# =============================================================================
# Stage 3a: Download Doppler CLI
# =============================================================================
FROM ${DEBIAN_IMAGE} AS doppler-download

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget=1.21.3-1+deb12u1 \
    ca-certificates=20230311+deb12u1 \
    && rm -rf /var/lib/apt/lists/*

# Download and install Doppler CLI
# Pinned to specific version for reproducibility
ARG DOPPLER_VERSION=3.75.1
RUN wget -q https://github.com/DopplerHQ/cli/releases/download/${DOPPLER_VERSION}/doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz && \
    tar xzf doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz && \
    chmod +x doppler && \
    rm doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz

# =============================================================================
# Stage 3b: Runtime - nginx + Dart server + Doppler
# =============================================================================
FROM ${DEBIAN_IMAGE} AS runtime

# Install nginx and required runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx=1.22.1-9+deb12u3 \
    curl=7.88.1-10+deb12u14 \
    ca-certificates=20230311+deb12u1 \
     && rm -rf /var/lib/apt/lists/*

# Copy Doppler CLI from download stage
COPY --from=doppler-download /doppler /usr/local/bin/doppler

# Create non-root user with home directory for Doppler config
RUN useradd -r -m -d /home/appuser -s /bin/false appuser

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
RUN mkdir -p /var/cache/nginx /var/run /var/log/nginx /var/lib/nginx \
    && chown -R appuser:appuser /var/cache/nginx /var/run /var/log/nginx /var/lib/nginx /app

# Cloud Run sets PORT environment variable
ENV PORT=8080
EXPOSE 8080

# Run as non-root user
USER appuser

# Health check via nginx (proxies to Dart /health endpoint)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Labels for container registry
LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="Sponsor Portal - nginx + Dart API server"

ENTRYPOINT ["/app/start.sh"]
