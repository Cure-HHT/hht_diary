# infrastructure/docker/email-job/Dockerfile
#
# Cloud Run Job image for sending test emails via Gmail API.
# Uses WIF + domain-wide delegation (same auth flow as portal EmailService).
#
# Build:
#   docker build -t email-job infrastructure/docker/email-job/
#
# Run locally (requires gcloud auth):
#   docker run --rm \
#     -e EMAIL_SVC_ACCT=org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com \
#     -e EMAIL_SENDER=support@anspar.org \
#     -v "$HOME/.config/gcloud:/home/appuser/.config/gcloud:ro" \
#     email-job

FROM google/cloud-sdk:slim

# Set shell with pipefail for safer piped commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install jq (curl is already in google/cloud-sdk)
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for runtime (Trivy DS002)
RUN groupadd --gid 1001 appuser \
    && useradd --uid 1001 --gid appuser --shell /bin/bash --create-home appuser

WORKDIR /app

COPY send-email.sh /app/send-email.sh
RUN chmod +x /app/send-email.sh \
    && chown -R appuser:appuser /app

USER appuser

ENTRYPOINT ["/app/send-email.sh"]
