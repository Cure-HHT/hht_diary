# syntax=docker/dockerfile:1.4
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#   REQ-d00059: Development Tool Specifications
#
# Audit Image for Clinical Diary
# Minimal read-only audit tools with live system access.
# Replaces mgmt.Dockerfile.
#
# Built on: Debian 12 (Bookworm) slim — matches production runtime

FROM debian:12-slim

LABEL maintainer="Clinical Diary Team"
LABEL description="Audit environment: read-only access to DB, cloud, code, OTS"
LABEL org.opencontainers.image.source="https://github.com/cure-hht/clinical-diary"
LABEL org.opencontainers.image.licenses="MIT"
LABEL com.clinical-diary.role="audit"

# ============================================================
# Build arguments — sourced from .github/versions.env at build time
# ============================================================
ARG CLOUD_SQL_PROXY_VERSION=2.14.3
ARG POSTGRESQL_CLIENT_VERSION=16

# ============================================================
# Environment
# ============================================================
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Exclude documentation to reduce image size
RUN mkdir -p /etc/dpkg/dpkg.cfg.d && \
    echo "path-exclude=/usr/share/man/*" > /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo "path-exclude=/usr/share/doc/*" >> /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo "path-exclude=/usr/share/groff/*" >> /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo "path-exclude=/usr/share/info/*" >> /etc/dpkg/dpkg.cfg.d/01_nodoc

# ============================================================
# System Packages
# ============================================================
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    gnupg \
    jq \
    sudo \
    # Viewing tools
    less \
    vim \
    # Network access
    openssh-client \
    # Python for ots and scripts
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# PostgreSQL Client (bookworm-pgdg)
# ============================================================
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" | \
    tee /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends postgresql-client-${POSTGRESQL_CLIENT_VERSION} && \
    psql --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Google Cloud SDK (gcloud CLI)
# ============================================================
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends google-cloud-cli && \
    gcloud --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Doppler CLI (secrets management)
# ============================================================
RUN curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
    gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | \
    tee /etc/apt/sources.list.d/doppler-cli.list && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends doppler && \
    doppler --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Cloud SQL Auth Proxy
# ============================================================
RUN curl -o /usr/local/bin/cloud-sql-proxy \
    https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v${CLOUD_SQL_PROXY_VERSION}/cloud-sql-proxy.linux.amd64 && \
    chmod +x /usr/local/bin/cloud-sql-proxy && \
    cloud-sql-proxy --version

# ============================================================
# OpenTimestamps client (pip)
# ============================================================
RUN pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore opentimestamps-client

# ============================================================
# Create non-root user: devuser
# ============================================================
RUN useradd -m -s /bin/bash -u 1000 devuser && \
    usermod -aG sudo devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ============================================================
# Set up workspace
# ============================================================
RUN mkdir -p /workspace/src /workspace/terraform && \
    chown -R devuser:devuser /workspace

# ============================================================
# Git configuration defaults
# ============================================================
USER devuser
RUN git config --global pull.rebase false && \
    git config --global init.defaultBranch main && \
    git config --global core.editor "vim"

# ============================================================
# Final configuration
# ============================================================
WORKDIR /workspace

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s \
    CMD psql --version && gcloud --version && ots --help

CMD ["/bin/bash", "-l"]

LABEL com.clinical-diary.version="2.0.0"
LABEL com.clinical-diary.tools="psql,gcloud,doppler,cloud-sql-proxy,ots,git"
LABEL com.clinical-diary.access="read-only"
LABEL com.clinical-diary.requirement="REQ-d00027,REQ-d00059"
