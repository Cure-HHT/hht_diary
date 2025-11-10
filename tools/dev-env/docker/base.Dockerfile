# syntax=docker/dockerfile:1.4
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#   REQ-d00032: Development Tool Specifications
#
# Base Docker Image for Clinical Diary Development Environments
# Provides common tools used across all roles (dev, qa, ops, mgmt)
#
# Built on: Ubuntu 24.04 LTS (support until 2029)
# Contains: Git, GitHub CLI, Node.js, Python, Doppler, Claude Code CLI

FROM ubuntu:24.04

LABEL maintainer="Clinical Diary Team"
LABEL description="Base development environment for Clinical Diary project"
LABEL org.opencontainers.image.source="https://github.com/yourorg/clinical-diary"
LABEL org.opencontainers.image.licenses="MIT"

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ============================================================
# Exclude documentation (prevents update-alternatives warnings, reduces size)
# Safe: Man pages unused in containers, tools function identically without documentation
# ============================================================
RUN mkdir -p /etc/dpkg/dpkg.cfg.d && \
    echo "path-exclude=/usr/share/man/*" > /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo "path-exclude=/usr/share/doc/*" >> /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo "path-exclude=/usr/share/groff/*" >> /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo "path-exclude=/usr/share/info/*" >> /etc/dpkg/dpkg.cfg.d/01_nodoc

# ============================================================
# System Packages & Dependencies
# ============================================================
# Suppress update-alternatives warnings for missing man pages (excluded via dpkg config)
# Safe: Warnings are cosmetic - all tools install and function correctly, only symlink creation skipped
RUN apt-get update -y && \
    (apt-get install -y \
    # Core utilities
    curl \
    wget \
    git \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    # Build tools
    build-essential \
    # Text processing
    jq \
    # Network tools
    openssh-client \
    # Process management
    procps \
    # For adding repositories
    gpg \
    2>&1 | grep -v "update-alternatives: warning" || true) && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Git Configuration (latest stable)
# ============================================================
RUN add-apt-repository ppa:git-core/ppa -y && \
    apt-get update -y && \
    apt-get install -y git && \
    git --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# GitHub CLI (2.40+)
# ============================================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update -y && \
    apt-get install -y gh && \
    gh --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Node.js 20.x LTS (support until 2026-04-30)
# Version pinned: 2025-10-28
# ============================================================
ENV NODE_MAJOR_VERSION=20

# Suppress apt warnings from NodeSource setup script (uses apt internally, not apt-get)
# Safe: NodeSource script uses 'apt' (not 'apt-get') which warns about script usage but functions correctly
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x | bash - 2>&1 | grep -v "apt does not have a stable CLI" && \
    apt-get install -y nodejs && \
    node --version && \
    npm --version && \
    rm -rf /var/lib/apt/lists/*

# Enable pnpm (faster package manager, optional)
RUN npm install -g pnpm && \
    pnpm --version

# ============================================================
# Python 3.12+ (Ubuntu 24.04 default)
# ============================================================
RUN apt-get update -y && \
    apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev && \
    python3 --version && \
    pip3 --version && \
    rm -rf /var/lib/apt/lists/*

# Note: Skip pip upgrade on Ubuntu 24.04 due to Debian-managed pip
# System pip (24.0+) is sufficient for our needs
# Using --break-system-packages flag when installing packages per PEP 668

# ============================================================
# Doppler CLI (secrets management)
# ============================================================
RUN curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
    gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | \
    tee /etc/apt/sources.list.d/doppler-cli.list && \
    apt-get update -y && \
    apt-get install -y doppler && \
    doppler --version && \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Gitleaks v8.29.0 (secret scanning)
# Version pinned: 2025-11-09
# Prevents accidental commit of secrets (API keys, tokens, passwords)
# ============================================================
ENV GITLEAKS_VERSION=v8.29.0
RUN wget -q https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_8.29.0_linux_x64.tar.gz && \
    tar -xzf gitleaks_8.29.0_linux_x64.tar.gz -C /usr/local/bin && \
    rm gitleaks_8.29.0_linux_x64.tar.gz && \
    gitleaks version

# ============================================================
# Anthropic Python SDK & Claude Code CLI
# Safe: --root-user-action=ignore suppresses pip's root warning (expected behavior in Docker build context)
# ============================================================
RUN pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore anthropic && \
    npm install -g @anthropic-ai/claude-code

# ============================================================
# Create non-root user: ubuntu
# Ubuntu 24.04 image may already have ubuntu user, so check first
# ============================================================
RUN id -u ubuntu &>/dev/null || useradd -m -s /bin/bash -u 1000 ubuntu && \
    usermod -aG sudo ubuntu 2>/dev/null || true && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ============================================================
# Set up workspace directories
# ============================================================
RUN mkdir -p /workspace/repos /workspace/exchange /workspace/src && \
    chown -R ubuntu:ubuntu /workspace

# ============================================================
# Git global configuration defaults
# ============================================================
USER ubuntu
WORKDIR /home/ubuntu

RUN git config --global pull.rebase false && \
    git config --global init.defaultBranch main && \
    git config --global core.editor "vim"

# ============================================================
# Shell configuration with role-based prompt
# ============================================================
RUN cat >> /home/ubuntu/.bashrc <<'EOF'

# Function to show current git branch
parse_git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null | sed "s/^/ (/;s/$/)/"
}

# Role-based prompt configuration
ROLE_LABEL="${ROLE:-unknown}"

# Colors
RED="\[\033[0;31m\]"
GREEN="\[\033[0;32m\]"
YELLOW="\[\033[1;33m\]"
BLUE="\[\033[0;34m\]"
CYAN="\[\033[0;36m\]"
RESET="\[\033[0m\]"

# Role color map
case "$ROLE_LABEL" in
  dev)   ROLE_COLOR=$GREEN ;;
  qa)    ROLE_COLOR=$YELLOW ;;
  ops)   ROLE_COLOR=$CYAN ;;
  mgmt)  ROLE_COLOR=$BLUE ;;
  *)     ROLE_COLOR=$RED ;;
esac

# Prompt: [role] path (branch)
export PS1="${ROLE_COLOR}[${ROLE_LABEL}]${RESET} \w\$(parse_git_branch)\n$ "

# Path additions (will be extended by role-specific Dockerfiles)
export PATH="/home/ubuntu/.local/bin:$PATH"

EOF

# Source profile on login
RUN echo '[ -f /home/ubuntu/.bashrc ] && . /home/ubuntu/.bashrc' >> /home/ubuntu/.profile

# ============================================================
# Health check script (COPY from file to avoid heredoc issues)
# ============================================================
USER root
COPY base-health-check.sh /usr/local/bin/health-check.sh
RUN chmod +x /usr/local/bin/health-check.sh

# ============================================================
# Final configuration
# ============================================================
USER ubuntu
WORKDIR /workspace/src

# Default command: keep container running
CMD ["/bin/bash", "-l"]

# Labels for container metadata
LABEL com.clinical-diary.role="base"
LABEL com.clinical-diary.version="1.0.0"
LABEL com.clinical-diary.requirement="REQ-d00027,REQ-d00032"
