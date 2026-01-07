# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-p01018: Security scanning compliance (non-root container)
#
# Base Dart Runtime Container
# Used as parent image for all Dart server containers
#
# DART_VERSION must be passed as build arg (from .github/versions.env)
# Build via Cloud Build: see cloudbuild.yaml

ARG DART_VERSION
FROM dart:${DART_VERSION} AS base

# Install minimal utilities for health checks and debugging
# curl: health check endpoints
# ca-certificates: HTTPS connections
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security (DS002)
RUN useradd --create-home --shell /bin/bash appuser

# Set working directory
WORKDIR /app

# Pre-create common directories with correct ownership
RUN mkdir -p /app/bin /app/lib && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Default command (overridden by child images)
CMD ["dart", "--version"]

# Labels for container registry
LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="Base Dart runtime for HHT Diary services"
