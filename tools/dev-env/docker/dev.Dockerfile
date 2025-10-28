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
# ============================================================
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=/opt/android
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

RUN cd /tmp && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    unzip -q commandlinetools-linux-11076708_latest.zip && \
    mkdir -p ${ANDROID_HOME}/cmdline-tools/latest && \
    mv cmdline-tools/* ${ANDROID_HOME}/cmdline-tools/latest/ && \
    rm commandlinetools-linux-11076708_latest.zip && \
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
RUN yes | sdkmanager --licenses || true && \
    sdkmanager "platform-tools" \
               "build-tools;34.0.0" \
               "platforms;android-34" \
               "cmdline-tools;latest" && \
    sdkmanager --list | head -20

# ============================================================
# Flutter configuration
# ============================================================
RUN flutter --version && \
    flutter config --no-analytics && \
    flutter config --enable-web && \
    flutter config --enable-linux-desktop && \
    flutter precache --web --linux --android

# Add pub global bin to PATH
RUN echo 'export PATH="$HOME/.pub-cache/bin:$PATH"' >> /home/ubuntu/.profile

# ============================================================
# Supabase CLI
# ============================================================
USER root
RUN npm install -g supabase && \
    supabase --version

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
# Health check override for dev role
# ============================================================
RUN cat > /usr/local/bin/health-check.sh <<'EOF'
#!/bin/bash
set -e
# Base tools
git --version >/dev/null
gh --version >/dev/null
node --version >/dev/null
python3 --version >/dev/null
doppler --version >/dev/null
# Dev-specific tools
flutter --version >/dev/null
java -version >/dev/null 2>&1
sdkmanager --list >/dev/null 2>&1
echo "Dev health check passed"
EOF

RUN chmod +x /usr/local/bin/health-check.sh

USER ubuntu
WORKDIR /workspace/src

CMD ["/bin/bash", "-l"]

# Labels
LABEL com.clinical-diary.role="dev"
LABEL com.clinical-diary.tools="flutter,android-sdk,java,node,python"
LABEL com.clinical-diary.requirement="REQ-d00028,REQ-d00032"
