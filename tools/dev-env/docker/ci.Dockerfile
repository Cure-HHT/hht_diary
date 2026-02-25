# syntax=docker/dockerfile:1.4
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#   REQ-d00059: Development Tool Specifications
#   REQ-d00030: CI/CD Environment Parity
#
# All-in-One CI Image for Clinical Diary
# Replaces the base -> dev -> qa chain with a single image.
# Contains everything needed for build, test, lint, and scan.
#
# Built on: Debian 12 (Bookworm) slim — matches production runtime
# Future: dev.Dockerfile will extend this image for interactive use

FROM debian:12-slim

LABEL maintainer="Clinical Diary Team"
LABEL description="All-in-one CI image: build, test, lint, scan"
LABEL org.opencontainers.image.source="https://github.com/cure-hht/clinical-diary"
LABEL org.opencontainers.image.licenses="MIT"
LABEL com.clinical-diary.role="ci"

# ============================================================
# Build arguments — sourced from .github/versions.env at build time
# ============================================================
ARG NODE_MAJOR_VERSION=20
ARG FLUTTER_VERSION=3.38.7
ARG GITLEAKS_VERSION=8.29.0
ARG SQUAWK_VERSION=2.41.0
ARG CLOUD_SQL_PROXY_VERSION=2.14.3
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_BUILD_TOOLS_VERSION=34.0.0
ARG ANDROID_PLATFORM_VERSION=34
ARG OPENJDK_VERSION=17
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
    # Core utilities
    curl \
    wget \
    git \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    # Build tools
    build-essential \
    # Text processing
    jq \
    # Network tools
    openssh-client \
    # Process management
    procps \
    # Privilege escalation
    sudo \
    # Report generation
    pandoc \
    # Flutter Linux desktop build dependencies
    libgtk-3-dev \
    libx11-dev \
    pkg-config \
    cmake \
    ninja-build \
    libblkid-dev \
    liblzma-dev \
    # Secure storage testing (gnome-keyring + dbus for Flutter secure_storage)
    libsecret-1-dev \
    gnome-keyring \
    dbus-x11 \
    xvfb \
    # Coverage tools
    lcov \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# GitHub CLI (2.40+)
# ============================================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends gh && \
    gh --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Node.js LTS + pnpm
# ============================================================
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x | bash - 2>&1 | grep -v "apt does not have a stable CLI" && \
    apt-get install -y --no-install-recommends nodejs && \
    node --version && \
    npm --version && \
    npm install -g pnpm && \
    pnpm --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Firebase CLI (integration testing)
# ============================================================
RUN npm install -g firebase-tools && \
    firebase --version

# ============================================================
# Python 3.11 (Debian 12 default)
# ============================================================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev && \
    python3 --version && \
    pip3 --version 2>/dev/null || true && \
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
# Gitleaks (secret scanning)
# ============================================================
RUN wget -q https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz && \
    tar -xzf gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz -C /usr/local/bin && \
    rm gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz && \
    gitleaks version

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
# Cloud SQL Auth Proxy
# ============================================================
RUN curl -o /usr/local/bin/cloud-sql-proxy \
    https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v${CLOUD_SQL_PROXY_VERSION}/cloud-sql-proxy.linux.amd64 && \
    chmod +x /usr/local/bin/cloud-sql-proxy && \
    cloud-sql-proxy --version

# ============================================================
# PostgreSQL Client (bookworm-pgdg — no lsb-release dependency)
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
# Squawk (PostgreSQL migration linter)
# ============================================================
RUN wget -q https://github.com/sbdchd/squawk/releases/download/v${SQUAWK_VERSION}/squawk-linux-x64 -O /usr/local/bin/squawk && \
    chmod +x /usr/local/bin/squawk && \
    squawk --version

# ============================================================
# OpenJDK (required for Android SDK)
# ============================================================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends openjdk-${OPENJDK_VERSION}-jdk-headless && \
    java -version && \
    rm -rf /var/lib/apt/lists/*

# Detect JAVA_HOME dynamically
RUN JAVA_BIN=$(update-alternatives --query java | grep 'Value:' | awk '{print $2}') && \
    DETECTED_JAVA_HOME=$(dirname $(dirname $JAVA_BIN)) && \
    ln -sf $DETECTED_JAVA_HOME /usr/lib/jvm/default-java && \
    echo "JAVA_HOME detected as: $DETECTED_JAVA_HOME"

ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# ============================================================
# Flutter
# ============================================================
ENV FLUTTER_ROOT=/opt/flutter
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

RUN cd /opt && \
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    tar -xJf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    rm flutter_linux_${FLUTTER_VERSION}-stable.tar.xz

# ============================================================
# Android SDK
# ============================================================
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=/opt/android
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

RUN cd /tmp && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip && \
    unzip -q commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip && \
    mkdir -p ${ANDROID_HOME}/cmdline-tools/latest && \
    mv cmdline-tools/* ${ANDROID_HOME}/cmdline-tools/latest/ && \
    rm commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip

# Pre-accept Android SDK licenses
RUN mkdir -p ${ANDROID_HOME}/licenses && \
    echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > ${ANDROID_HOME}/licenses/android-sdk-license && \
    echo "d56f5187479451eabf01fb78af6dfcb131a6481e" >> ${ANDROID_HOME}/licenses/android-sdk-license && \
    echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > ${ANDROID_HOME}/licenses/android-sdk-preview-license && \
    yes | sdkmanager --licenses >/dev/null || true && \
    sdkmanager "platform-tools" \
               "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
               "platforms;android-${ANDROID_PLATFORM_VERSION}"

# ============================================================
# Playwright (latest + browsers + system deps)
# ============================================================
RUN npm install -g playwright && \
    npx playwright --version && \
    DEBIAN_FRONTEND=noninteractive npx playwright install --with-deps

# ============================================================
# Create non-root user: devuser
# ============================================================
RUN useradd -m -s /bin/bash -u 1000 devuser && \
    usermod -aG sudo devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set ownership for Flutter and Android SDK
RUN chown -R devuser:devuser /opt/flutter ${ANDROID_HOME}

# ============================================================
# Set up workspace
# ============================================================
RUN mkdir -p /workspace/repos /workspace/exchange /workspace/src /workspace/reports && \
    chown -R devuser:devuser /workspace

# ============================================================
# Flutter configuration (as devuser)
# ============================================================
USER devuser
WORKDIR /home/devuser

RUN flutter --version && \
    flutter config --no-analytics && \
    flutter config --android-studio-dir=/opt/nonexistent && \
    flutter precache --android

# Add pub global bin to PATH
RUN echo 'export PATH="$HOME/.pub-cache/bin:$PATH"' >> /home/devuser/.profile

# Install junitreport
RUN PATH="/home/devuser/.pub-cache/bin:$PATH" flutter pub global activate junitreport || true

# Install Dart coverage formatter (LCOV generation for server packages)
RUN PATH="/home/devuser/.pub-cache/bin:$PATH" dart pub global activate coverage || true

# ============================================================
# Git configuration defaults
# ============================================================
RUN git config --global pull.rebase false && \
    git config --global init.defaultBranch main && \
    git config --global core.editor "vim"

# ============================================================
# Final configuration
# ============================================================
WORKDIR /workspace/src

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD flutter --version && node --version && gcloud --version

CMD ["/bin/bash", "-l"]

LABEL com.clinical-diary.version="2.0.0"
LABEL com.clinical-diary.tools="flutter,android-sdk,node,python,gcloud,playwright,gitleaks,squawk,psql,pandoc,firebase-cli,lcov"
LABEL com.clinical-diary.requirement="REQ-d00027,REQ-d00059,REQ-d00030"
