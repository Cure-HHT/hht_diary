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
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /app

# Report the environment variables for debugging
CMD ["env"]

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
