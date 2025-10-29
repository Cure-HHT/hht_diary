# syntax=docker/dockerfile:1.4
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#   REQ-d00032: Development Tool Specifications
#
# Management Environment Dockerfile
# Minimal, read-only environment for management and audit access

ARG BASE_IMAGE_TAG=latest
FROM clinical-diary-base:${BASE_IMAGE_TAG}

LABEL com.clinical-diary.role="mgmt"
LABEL description="Management environment with read-only tools"

USER root

# ============================================================
# Additional utilities for viewing and analyzing
# ============================================================
RUN apt-get update -y && \
    apt-get install -y \
    # Text viewing
    less \
    vim \
    # Log analysis
    gawk \
    # PDF viewing (if terminal supports)
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Git configuration for mgmt role (read-only indicator)
# ============================================================
USER ubuntu
RUN git config --global user.name "Manager" && \
    git config --global user.email "mgmt@clinical-diary.local"

# ============================================================
# Helper scripts for common management tasks
# ============================================================
USER root

# Script to view repository status
RUN cat > /usr/local/bin/view-repo-status.sh <<'EOF'
#!/bin/bash
# View status of all repositories in /workspace/repos
set -e

REPOS_DIR="${1:-/workspace/repos}"

if [ ! -d "$REPOS_DIR" ]; then
  echo "No repositories directory found at: $REPOS_DIR"
  exit 1
fi

echo "==================================================="
echo "Repository Status Report"
echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "==================================================="
echo ""

find "$REPOS_DIR" -maxdepth 2 -name ".git" -type d | while read -r gitdir; do
  repo_dir=$(dirname "$gitdir")
  repo_name=$(basename "$repo_dir")

  echo "Repository: $repo_name"
  echo "Path: $repo_dir"

  cd "$repo_dir"

  # Branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  echo "  Branch: $branch"

  # Latest commit
  commit=$(git log -1 --format="%h - %s (%ar)" 2>/dev/null || echo "no commits")
  echo "  Latest: $commit"

  # Status
  if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "  Status: Clean"
  else
    echo "  Status: Modified files present"
  fi

  echo ""
done

EOF

RUN chmod +x /usr/local/bin/view-repo-status.sh

# Script to view QA reports
RUN cat > /usr/local/bin/view-qa-reports.sh <<'EOF'
#!/bin/bash
# List available QA reports
set -e

REPORTS_DIR="${1:-/workspace/reports}"

if [ ! -d "$REPORTS_DIR" ]; then
  echo "No reports directory found at: $REPORTS_DIR"
  exit 0
fi

echo "==================================================="
echo "QA Reports"
echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "==================================================="
echo ""

find "$REPORTS_DIR" -type f \( -name "*.xml" -o -name "*.json" -o -name "*.html" -o -name "*.pdf" \) | \
  sort -r | \
  while read -r report; do
    size=$(du -h "$report" | cut -f1)
    modified=$(stat -c %y "$report" | cut -d'.' -f1)
    echo "File: $(basename "$report")"
    echo "  Path: $report"
    echo "  Size: $size"
    echo "  Modified: $modified"
    echo ""
  done

EOF

RUN chmod +x /usr/local/bin/view-qa-reports.sh

# ============================================================
# Health check for mgmt role (COPY from file)
# ============================================================
COPY mgmt-health-check.sh /usr/local/bin/health-check.sh
RUN chmod +x /usr/local/bin/health-check.sh

# ============================================================
# Reminder about read-only nature
# ============================================================
RUN cat > /etc/motd <<'EOF'

╔═══════════════════════════════════════════════════════════╗
║          MANAGEMENT ENVIRONMENT (READ-ONLY)               ║
╚═══════════════════════════════════════════════════════════╝

This environment has READ-ONLY access to:
  - Source code repositories
  - QA reports
  - Project documentation

Available commands:
  - view-repo-status.sh     View all repository statuses
  - view-qa-reports.sh      List available QA reports
  - gh pr list              View open pull requests
  - git log                 View commit history (read-only)

Note: Modifications require switching to dev/qa/ops role.

EOF

# Make MOTD display on login
RUN echo 'cat /etc/motd' >> /etc/profile

USER ubuntu
WORKDIR /workspace/src

CMD ["/bin/bash", "-l"]

# Labels
LABEL com.clinical-diary.role="mgmt"
LABEL com.clinical-diary.tools="git,gh,jq,read-only-viewers"
LABEL com.clinical-diary.access="read-only"
LABEL com.clinical-diary.requirement="REQ-d00028,REQ-d00032"
