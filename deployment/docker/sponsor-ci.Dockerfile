# syntax=docker/dockerfile:1.7

##
## Sponsor CI base image
##
## Purpose:
## - Shared CI/build environment for sponsor-owned final images
## - Built in hht_diary, consumed by hht_diary_callisto
##
## Notes:
## - Keeps toolchain in one reusable base layer
## - Does NOT contain sponsor-specific content
## - Final images should extend this image via SPONSOR_CI_IMAGE
##

FROM debian:12-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG FLUTTER_VERSION=3.32.8
ARG DART_VERSION=3.8.1
ARG USERNAME=builder
ARG USER_UID=10001
ARG USER_GID=10001

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    FLUTTER_HOME=/opt/flutter \
    PUB_CACHE=/opt/pub-cache \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/pub-cache/bin:${PATH}

# Base OS packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-client \
    python3 \
    python3-pip \
    rsync \
    unzip \
    xz-utils \
    zip \
    file \
    make \
    pkg-config \
    libc6 \
    libstdc++6 \
    xz-utils \
    gnupg \
    dirmngr \
    # Common runtime/build libs often needed by Flutter/Dart tooling
    libglu1-mesa \
    libgtk-3-0 \
    libnss3 \
    libx11-6 \
    libxext6 \
    libxi6 \
    libxrender1 \
    libxtst6 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcairo2 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0 \
    libnspr4 \
    libpango-1.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libasound2 \
    fonts-liberation \
    procps \
    tini \
 && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
 && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}" \
 && mkdir -p /workspace /opt/pub-cache \
 && chown -R "${USERNAME}:${USERNAME}" /workspace /opt/pub-cache

# Install Flutter SDK
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz \
 && mkdir -p /opt \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm -f /tmp/flutter.tar.xz \
 && flutter --version \
 && dart --version

# Warm Flutter/Dart caches a bit
RUN flutter config --no-analytics \
 && dart --disable-analytics \
 && flutter precache --linux --web

# Optional: install a specific standalone Dart SDK if you want hard pinning separate from Flutter.
# In most Flutter-based stacks, the Dart bundled with Flutter is the right source of truth.
# Keeping this as a label for visibility instead of overriding the bundled SDK.
LABEL sponsor-ci.flutter-version="${FLUTTER_VERSION}"
LABEL sponsor-ci.dart-version="${DART_VERSION}"

WORKDIR /workspace

# Switch to non-root for normal CI usage
USER ${USERNAME}

# Final sanity checks
RUN flutter doctor -v || true

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash"]