# infrastructure/docker/db-schema-job/Dockerfile
#
# Container image for applying database schema to Cloud SQL PostgreSQL
# Used by Cloud Run Job for automated schema deployment
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00057: Automated database schema deployment
#   REQ-d00031: Identity Platform Integration (user seeding)
#   REQ-d00058: Secrets Management via Doppler

FROM google/cloud-sdk:slim

# Set shell with pipefail for safer piped commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install required tools (PostgreSQL client + utilities + Node.js for Identity Platform seeding)
# Note: google/cloud-sdk:slim is Debian-based and includes gcloud, gsutil, bq
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    jq \
    nodejs \
    npm \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Doppler CLI (pinned version for reproducibility)
ARG DOPPLER_VERSION=3.75.1
RUN curl -sfL "https://github.com/DopplerHQ/cli/releases/download/${DOPPLER_VERSION}/doppler_${DOPPLER_VERSION}_linux_amd64.tar.gz" \
    -o /tmp/doppler.tar.gz \
    && tar xzf /tmp/doppler.tar.gz -C /usr/local/bin \
    && chmod +x /usr/local/bin/doppler \
    && rm /tmp/doppler.tar.gz

# Create non-root user for runtime (Trivy DS002)
RUN groupadd --gid 1001 appuser \
    && useradd --uid 1001 --gid appuser --shell /bin/bash --create-home appuser

# Create working directory
WORKDIR /app

# Copy scripts and package manifest
COPY entrypoint.sh /app/entrypoint.sh
COPY seed_identity_users.js /app/seed_identity_users.js
COPY package.json /app/package.json

# Install npm dependencies (firebase-admin for Identity Platform user seeding)
# hadolint ignore=DL3016
RUN npm install --production \
    && chmod +x /app/entrypoint.sh \
    && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
