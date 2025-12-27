# syntax=docker/dockerfile:1.4
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#   REQ-d00032: Development Tool Specifications
#
# DevOps Environment Dockerfile
# Extends base with: container security tools (cosign, syft, grype)
# Note: gcloud, cloud-sql-proxy, psql, and pulumi are in base image

ARG BASE_IMAGE_NAME=clinical-diary-base
ARG BASE_IMAGE_TAG=latest
ARG BASE_IMAGE_REF=${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

# Trivy DS001 Compliance: Tag explicitly specified via BASE_IMAGE_TAG
# CI/CD can override entire REF with registry path (e.g., ghcr.io/cure-hht/clinical-diary-base:latest)
FROM ${BASE_IMAGE_REF}

LABEL com.clinical-diary.role="ops"
LABEL com.clinical-diary.base-image="${BASE_IMAGE_REF}"
LABEL description="DevOps environment with container security and deployment tools"

USER root

# ============================================================
# Docker CLI (for container operations)
# ============================================================
RUN apt-get update -y && \
    apt-get install -y \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Cosign v3.0.2 (container image signing, pinned for compliance)
# Version pinned: 2025-10-28
# ============================================================
ENV COSIGN_VERSION=v3.0.2
RUN curl -O -L "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" && \
    mv cosign-linux-amd64 /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign && \
    cosign version

# ============================================================
# Syft v1.36.0 (SBOM generation, pinned for compliance)
# Version pinned: 2025-10-28
# ============================================================
ENV SYFT_VERSION=v1.36.0
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin ${SYFT_VERSION} && \
    syft version

# ============================================================
# Grype v0.102.0 (vulnerability scanning, pinned for compliance)
# Version pinned: 2025-10-28
# ============================================================
ENV GRYPE_VERSION=v0.102.0
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin ${GRYPE_VERSION} && \
    grype version

# ============================================================
# Git configuration for ops role
# ============================================================
USER ubuntu
RUN git config --global user.name "DevOps Engineer" && \
    git config --global user.email "ops@clinical-diary.local"

# ============================================================
# Deployment scripts directory
# ============================================================
USER root
RUN mkdir -p /opt/deployment-scripts && \
    chown -R ubuntu:ubuntu /opt/deployment-scripts

# ============================================================
# Health check override for ops role (COPY from file)
# ============================================================
COPY ops-health-check.sh /usr/local/bin/health-check.sh
RUN chmod +x /usr/local/bin/health-check.sh

USER ubuntu
WORKDIR /workspace/src

CMD ["/bin/bash", "-l"]

# Labels
LABEL com.clinical-diary.role="ops"
LABEL com.clinical-diary.tools="gcloud,pulumi,psql,cloud-sql-proxy,docker,cosign,syft,grype"
LABEL com.clinical-diary.requirement="REQ-d00028,REQ-d00032"
