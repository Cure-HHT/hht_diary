# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#   REQ-d00032: Development Tool Specifications
#
# Developer Environment Dockerfile
# Extends base with: Flutter, Android SDK, development tools

ARG BASE_IMAGE_TAG=latest
FROM clinical-diary-base:${BASE_IMAGE_TAG}

LABEL com.clinical-diary.role="dev"
LABEL description="Developer environment with Flutter and Android SDK"

USER root

# ============================================================
# OpenJDK 17 (LTS, required for Android builds)
# ============================================================
RUN apt-get update -y && \
    apt-get install -y openjdk-17-jdk && \
    java -version && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# ============================================================
# Flutter 3.24.0 (stable channel)
# ============================================================
ENV FLUTTER_VERSION=3.24.0
ENV FLUTTER_ROOT=/opt/flutter
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

RUN cd /opt && \
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    tar -xJf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    rm flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    chown -R ubuntu:ubuntu /opt/flutter

# ============================================================
# Android SDK (cmdline-tools latest)
# Version pinned: 2025-10-28
# ============================================================
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=/opt/android
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"
ENV ANDROID_CMDLINE_TOOLS_VERSION=11076708

RUN cd /tmp && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip && \
    unzip -q commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip && \
    mkdir -p ${ANDROID_HOME}/cmdline-tools/latest && \
    mv cmdline-tools/* ${ANDROID_HOME}/cmdline-tools/latest/ && \
    rm commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip && \
    chown -R ubuntu:ubuntu ${ANDROID_HOME}

# ============================================================
# Accept Android SDK licenses and install platform tools
# ============================================================
USER ubuntu

# Pre-accept licenses
RUN mkdir -p ${ANDROID_HOME}/licenses && \
    echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > ${ANDROID_HOME}/licenses/android-sdk-license && \
    echo "d56f5187479451eabf01fb78af6dfcb131a6481e" >> ${ANDROID_HOME}/licenses/android-sdk-license && \
    echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > ${ANDROID_HOME}/licenses/android-sdk-preview-license

# Install Android SDK components (PATH now includes sdkmanager)
# Note: cmdline-tools already installed manually above - don't reinstall
RUN yes | sdkmanager --licenses || true && \
    sdkmanager "platform-tools" \
               "build-tools;34.0.0" \
               "platforms;android-34" && \
    sdkmanager --list | head -20

# ============================================================
# Flutter configuration
# ============================================================
# Suppress warnings for unused platforms (mobile-first app)
RUN flutter --version && \
    flutter config --no-analytics && \
    flutter config --android-studio-dir=/opt/nonexistent && \
    flutter precache --android

# Add pub global bin to PATH
RUN echo 'export PATH="$HOME/.pub-cache/bin:$PATH"' >> /home/ubuntu/.profile

# ============================================================
# Supabase CLI v2.54.10 (pinned for FDA 21 CFR Part 11 compliance)
# Version pinned: 2025-10-28
# Update policy: Manual update with testing required
# ============================================================
USER root
ENV SUPABASE_CLI_VERSION=v2.54.10
RUN apt-get update -y && \
    apt-get install -y ca-certificates && \
    curl -fsSL https://github.com/supabase/cli/releases/download/${SUPABASE_CLI_VERSION}/supabase_linux_amd64.tar.gz | tar -xz -C /usr/local/bin && \
    supabase --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Git configuration for dev role
# ============================================================
USER ubuntu
RUN git config --global user.name "Developer" && \
    git config --global user.email "dev@clinical-diary.local"

# Note: Actual credentials will be configured via Doppler or host .gitconfig

# ============================================================
# Development-specific utilities
# ============================================================
USER root
RUN apt-get update -y && \
    apt-get install -y \
    # For debugging
    strace \
    ltrace \
    # For network debugging
    netcat-openbsd \
    # For file watching (Flutter hot reload)
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Health check override for dev role (COPY from file)
# ============================================================
COPY dev-health-check.sh /usr/local/bin/health-check.sh
RUN chmod +x /usr/local/bin/health-check.sh

USER ubuntu
WORKDIR /workspace/src

CMD ["/bin/bash", "-l"]

# Labels
LABEL com.clinical-diary.role="dev"
LABEL com.clinical-diary.tools="flutter,android-sdk,java,node,python"
LABEL com.clinical-diary.requirement="REQ-d00028,REQ-d00032"
