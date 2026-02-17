# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-d00058: Secrets Management via Doppler
#
# Minimal container for Cloud Run Jobs that tests Secret Manager access.
# Uses the same gcloud install pattern as diary-server-container.

ARG DEBIAN_IMAGE=debian:12-slim

# =============================================================================
# Stage 1: Install Google Cloud CLI
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
# Stage 2: Runtime
# =============================================================================
FROM ${DEBIAN_IMAGE} AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates=20230311+deb12u1 \
    python3=3.11.2-1+b1 \
    && rm -rf /var/lib/apt/lists/*

# Copy gcloud CLI from install stage
COPY --from=gcloud-install /opt/google-cloud-sdk /opt/google-cloud-sdk
ENV PATH="/opt/google-cloud-sdk/bin:${PATH}"

# Create non-root user
RUN useradd -r -m -d /home/appuser -s /bin/false appuser

# Copy test script
COPY --chmod=755 test-secret-access.sh /app/test-secret-access.sh

RUN chown -R appuser:appuser /app

USER appuser:appuser

LABEL org.opencontainers.image.source="https://github.com/Cure-HHT/hht_diary"
LABEL org.opencontainers.image.description="GCP Secret Manager access test job"

ENTRYPOINT ["/app/test-secret-access.sh"]
