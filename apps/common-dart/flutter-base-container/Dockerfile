# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-p01018: Security scanning compliance (non-root container)
#
# Base Flutter Runtime Container
# Used as parent image for Flutter-based server containers
#
# FLUTTER_VERSION must be passed as build arg (from .github/versions.env)
# Build via Cloud Build: see cloudbuild.yaml

ARG FLUTTER_VERSION
FROM debian:stable-slim



# Install dependencies (minimal set for server use)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    curl \
    wget \
    xz-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
ENV FLUTTER_HOME=/usr/local/flutter
ARG FLUTTER_VERSION
ENV FLUTTER_VERSION=${FLUTTER_VERSION}

# Create non-root user for security (REQ-p01018)
RUN useradd --create-home --shell /bin/bash appuser

# Download specific Flutter version (shallow clone to reduce size)
# Note: .git directory must be kept - Flutter requires it to determine version
RUN git clone --depth 1 -b ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && chown -R appuser:appuser ${FLUTTER_HOME}

ENV PATH=${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}

# Switch to non-root user for Flutter setup
USER appuser

# Configure Flutter and precache (as non-root user)
RUN flutter precache --no-android --no-ios --no-web \
    && flutter config --no-analytics

# Verify versions
RUN flutter --version && dart --version

# Switch back to root temporarily for directory setup
USER root

# Set working directory
WORKDIR /app

# Pre-create common directories with correct ownership
RUN mkdir -p /app/bin /app/lib && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Health check - verify Dart runtime is functional
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD dart --version || exit 1

# Default command (overridden by child images)
CMD ["flutter", "--version"]

# Labels for container registry
LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="Base Flutter runtime for server containers"
