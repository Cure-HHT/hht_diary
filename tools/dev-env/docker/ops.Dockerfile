# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#   REQ-d00032: Development Tool Specifications
#
# DevOps Environment Dockerfile
# Extends base with: Terraform, Supabase CLI, deployment tools

ARG BASE_IMAGE_TAG=latest
FROM clinical-diary-base:${BASE_IMAGE_TAG}

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
# Supabase CLI (using Linux package manager)
# ============================================================
RUN apt-get update -y && \
    apt-get install -y ca-certificates && \
    curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz | tar -xz -C /usr/local/bin && \
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
# kubectl (Kubernetes CLI, optional)
# ============================================================
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl && \
    kubectl version --client

# ============================================================
# Cosign (for signing container images)
# ============================================================
RUN curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" && \
    mv cosign-linux-amd64 /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign && \
    cosign version

# ============================================================
# Syft (for generating SBOMs)
# ============================================================
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin && \
    syft version

# ============================================================
# Grype (for vulnerability scanning)
# ============================================================
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin && \
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
# Health check override for ops role
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
# Ops-specific tools
terraform --version >/dev/null
supabase --version >/dev/null
aws --version >/dev/null
kubectl version --client >/dev/null 2>&1
cosign version >/dev/null
syft version >/dev/null
grype version >/dev/null
echo "Ops health check passed"
EOF

RUN chmod +x /usr/local/bin/health-check.sh

USER ubuntu
WORKDIR /workspace/src

CMD ["/bin/bash", "-l"]

# Labels
LABEL com.clinical-diary.role="ops"
LABEL com.clinical-diary.tools="terraform,supabase,aws,kubectl,cosign,syft,grype"
LABEL com.clinical-diary.requirement="REQ-d00028,REQ-d00032"
