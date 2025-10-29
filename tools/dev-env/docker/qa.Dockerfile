# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#   REQ-d00032: Development Tool Specifications
#   REQ-d00034: Automated QA Workflow
#
# QA Environment Dockerfile
# Extends dev with: Playwright, testing tools, report generation

ARG BASE_IMAGE_TAG=latest
# QA inherits from dev since it needs Flutter for integration tests
FROM clinical-diary-dev:${BASE_IMAGE_TAG}

LABEL com.clinical-diary.role="qa"
LABEL description="QA environment with testing frameworks and report generation"

USER root

# ============================================================
# Playwright (latest stable)
# ============================================================
RUN npm install -g playwright && \
    npx playwright --version

# Install Playwright browsers and dependencies (needs root for system packages)
# Safe: DEBIAN_FRONTEND=noninteractive prevents debconf prompts in Playwright's apt-get subprocess
RUN DEBIAN_FRONTEND=noninteractive npx playwright install --with-deps

# ============================================================
# Report generation tools
# ============================================================
USER root

# Pandoc (for document conversion)
RUN apt-get update -y && \
    apt-get install -y pandoc && \
    pandoc --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Flutter test tooling
# ============================================================
USER ubuntu

# Install Flutter test report generators (configure PATH inline to avoid warning)
# Safe: PATH set inline for this command only - pub cache bin not needed in permanent PATH
RUN PATH="/home/ubuntu/.pub-cache/bin:$PATH" flutter pub global activate junitreport || true

# ============================================================
# Git configuration for QA role
# ============================================================
USER ubuntu
RUN git config --global user.name "QA Automation Bot" && \
    git config --global user.email "qa@clinical-diary.local"

# ============================================================
# QA-specific directories
# ============================================================
USER root
RUN mkdir -p /workspace/reports && \
    chown -R ubuntu:ubuntu /workspace/reports

# ============================================================
# QA runner script (comprehensive test suite)
# ============================================================
COPY qa-runner.sh /usr/local/bin/qa-runner.sh
RUN chmod +x /usr/local/bin/qa-runner.sh

# ============================================================
# Health check override for QA role (COPY from file)
# ============================================================
COPY qa-health-check.sh /usr/local/bin/health-check.sh
RUN chmod +x /usr/local/bin/health-check.sh

USER ubuntu
WORKDIR /workspace/src

CMD ["/bin/bash", "-l"]

# Labels
LABEL com.clinical-diary.role="qa"
LABEL com.clinical-diary.tools="playwright,flutter,pandoc,testing"
LABEL com.clinical-diary.requirement="REQ-d00028,REQ-d00032,REQ-d00034"
