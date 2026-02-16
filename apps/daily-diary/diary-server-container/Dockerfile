# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-p00013: GDPR compliance - EU-only regions
#   REQ-d00027: Containerized Development Environments
#   REQ-o00043: Automated Deployment Pipeline
#   REQ-d00058: Secrets Management via Doppler
#   REQ-o00002: Environment-Specific Configuration Management
#
# Diary Server Container
# Hosts diary_functions as HTTP endpoints via shelf
#
# Build args:
ARG DART_BASE_IMAGE=ghcr.io/cure-hht/dart-base:3.10.7
ARG DEBIAN_IMAGE=debian:12-slim 
# =============================================================================
# Stage 1: Build Dart Server
# =============================================================================
FROM ${DART_BASE_IMAGE} AS dart-build
# Copy shared dependencies first (for layer caching)
# Use --chown because dart-base runs as appuser
COPY --chown=appuser:appuser apps/common-dart/trial_data_types /app/apps/common-dart/trial_data_types

# Copy diary_functions package
COPY --chown=appuser:appuser apps/daily-diary/diary_functions /app/apps/daily-diary/diary_functions

# Copy diary_server package
COPY --chown=appuser:appuser apps/daily-diary/diary_server /app/apps/daily-diary/diary_server

# Get dependencies and compile to native executable
WORKDIR /app/apps/daily-diary/diary_server
RUN dart pub get && \
    dart compile exe bin/server.dart -o bin/server

# =============================================================================
# Stage 2: Install Doppler CLI
# =============================================================================
FROM ${DEBIAN_IMAGE} AS doppler-install

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget=1.21.3-1+deb12u1 \
    ca-certificates=20230311+deb12u1 \
    && rm -rf /var/lib/apt/lists/*

# Pinned to specific version for reproducibility
ARG DOPPLER_VERSION=3.75.1
# Download and install Doppler CLI
RUN wget -q https://github.com/DopplerHQ/cli/releases/download/${DOPPLER_VERSION}/doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz && \
    tar xzf doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz && \
    chmod +x doppler && \
    rm doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz

# =============================================================================
# Stage 3: Install Google Cloud CLI
# =============================================================================
FROM ${DEBIAN_IMAGE} AS gcloud-install

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl=7.88.1-10+deb12u14 \
    ca-certificates=20230311+deb12u1 \
    python3=3.11.2-1+b1 \
    && rm -rf /var/lib/apt/lists/*

ARG GCLOUD_VERSION=514.0.0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sfL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION}-linux-x86_64.tar.gz" | \
    tar xz -C /opt && \
    /opt/google-cloud-sdk/install.sh --quiet --usage-reporting false --path-update false && \
    /opt/google-cloud-sdk/bin/gcloud components remove --quiet \
        bq gsutil gcloud-crc32c 2>/dev/null || true && \
    rm -rf /opt/google-cloud-sdk/.install/.backup

# =============================================================================
# Stage 4: Runtime - nginx + Dart server + Doppler + gcloud
# =============================================================================
FROM ${DEBIAN_IMAGE} AS runtime

# Install nginx, runtime libraries, and python3 (required by gcloud)
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx=1.22.1-9+deb12u4 \
    curl=7.88.1-10+deb12u14 \
    ca-certificates=20230311+deb12u1 \
    python3=3.11.2-1+b1 \
    && rm -rf /var/lib/apt/lists/*

# Copy Doppler CLI from download stage
COPY --from=doppler-install /doppler /usr/local/bin/doppler

# Copy gcloud CLI from install stage
COPY --from=gcloud-install /opt/google-cloud-sdk /opt/google-cloud-sdk
ENV PATH="/opt/google-cloud-sdk/bin:${PATH}"

# Create non-root user with home directory for Doppler config
RUN useradd -r -m -d /home/appuser -s /bin/false appuser

# Copy Dart server binary and startup script
COPY --from=dart-build --chmod=755 /app/apps/daily-diary/diary_server/bin/server /app/server
COPY --chmod=755 apps/daily-diary/diary-server-container/start.sh /app/start.sh

# Create nginx runtime directories with correct permissions
RUN mkdir -p /var/cache/nginx /var/run /var/log/nginx /var/lib/nginx \
    && chown -R appuser:appuser /var/cache/nginx /var/run /var/log/nginx /var/lib/nginx /app

# Cloud Run sets PORT environment variable
ENV PORT=8080
EXPOSE 8080

# Required runtime inputs - must be set via Cloud Run environment variables
ENV DOPPLER_PROJECT_ID=""
ENV DOPPLER_CONFIG_NAME=""

# Explicit non-root user (uid 65532 in distroless)
# USER nonroot:nonroot
USER appuser:appuser

# Note: HEALTHCHECK not used - Cloud Run uses HTTP probes to /health endpoint
# See: https://cloud.google.com/run/docs/configuring/healthchecks

# Labels for container registry
LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="Diary Service - nginx + Dart API server"

# Startup script fetches DOPPLER_TOKEN from Secret Manager, then runs
# Doppler to inject secrets (DB_HOST, DB_PASSWORD, etc.) before starting the server.
# Requires DOPPLER_PROJECT_ID, DOPPLER_CONFIG_NAME env vars, and
# secretmanager.versions.access permission on the Cloud Run service account.
ENTRYPOINT ["/app/start.sh"]
