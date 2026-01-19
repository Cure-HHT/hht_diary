# infrastructure/docker/db-schema-job/Dockerfile
#
# Container image for applying database schema to Cloud SQL PostgreSQL
# Used by Cloud Run Job for automated schema deployment
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00057: Automated database schema deployment

FROM postgres:17-alpine

# Set shell with pipefail for safer piped commands
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Install required tools
RUN apk add --no-cache \
    bash=5.3.3-r1 \
    curl=8.17.0-r1 \
    jq=1.8.1-r0 \
    python3=3.12.12-r0 \
    py3-pip=25.1.1-r1

# Install Google Cloud SDK for GCS access
RUN curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/opt
ENV PATH="/opt/google-cloud-sdk/bin:${PATH}"

# Create working directory
WORKDIR /app

# Report the environment variables for debugging
CMD ["env"]

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
