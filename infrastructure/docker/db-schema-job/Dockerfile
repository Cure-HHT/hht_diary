# infrastructure/docker/db-schema-job/Dockerfile
#
# Container image for applying database schema to Cloud SQL PostgreSQL
# Used by Cloud Run Job for automated schema deployment
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00057: Automated database schema deployment

FROM google/cloud-sdk:slim

# Set shell with pipefail for safer piped commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install required tools (PostgreSQL client + utilities)
# Note: google/cloud-sdk:slim is Debian-based and includes gcloud, gsutil, bq
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for runtime (Trivy DS002)
RUN groupadd --gid 1001 appuser \
    && useradd --uid 1001 --gid appuser --shell /bin/bash --create-home appuser

# Create working directory
WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh \
    && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
