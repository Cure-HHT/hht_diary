# syntax=docker/dockerfile:1.4
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#   REQ-d00032: Development Tool Specifications
#
# DevOps Environment Dockerfile
# Extends base with: Terraform, Supabase CLI, deployment tools

ARG BASE_IMAGE_REF=clinical-diary-base:latest
FROM ${BASE_IMAGE_REF}

LABEL com.clinical-diary.role="ops"
LABEL description="DevOps environment with infrastructure and deployment tools"

USER root

# ============================================================
# Terraform (1.9+)
# ============================================================
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update -y && \
    apt-get install -y terraform && \
    terraform --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Supabase CLI v2.54.10 (pinned for FDA 21 CFR Part 11 compliance)
# Version pinned: 2025-10-28
# ============================================================
ENV SUPABASE_CLI_VERSION=v2.54.10
RUN apt-get update -y && \
    apt-get install -y ca-certificates && \
    curl -fsSL https://github.com/supabase/cli/releases/download/${SUPABASE_CLI_VERSION}/supabase_linux_amd64.tar.gz | tar -xz -C /usr/local/bin && \
    supabase --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Docker CLI (for container operations)
# ============================================================
RUN apt-get update -y && \
    apt-get install -y \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# AWS CLI (optional, for multi-cloud deployment)
# ============================================================
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip -q awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws && \
    aws --version

# ============================================================
# kubectl v1.34.1 (Kubernetes CLI, pinned for compliance)
# Version pinned: 2025-10-28
# ============================================================
ENV KUBECTL_VERSION=v1.34.1
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl && \
    kubectl version --client

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
LABEL com.clinical-diary.tools="terraform,supabase,aws,kubectl,cosign,syft,grype"
LABEL com.clinical-diary.requirement="REQ-d00028,REQ-d00032"
