# Installation Qualification (IQ)
# Clinical Diary Development Environment

**Document Type**: Installation Qualification Protocol
**System**: Docker-Based Development Environment
**Version**: 1.0.0
**Date**: 2025-10-27
**Status**: Draft

---

## 1. Purpose

This Installation Qualification (IQ) protocol verifies that the Clinical Diary Docker-based development environment has been installed correctly and all required components are present and properly configured.

### 1.1 Scope

This IQ covers:
- Docker Engine installation and configuration
- Docker Compose installation
- Docker image builds (base, dev, qa, ops, mgmt)
- Docker volume creation
- VS Code Dev Container configuration
- Network connectivity and isolation
- File permissions and user configurations

### 1.2 Regulatory Compliance

This validation supports compliance with:
- **FDA 21 CFR Part 11**: Electronic Records; Electronic Signatures
- **GAMP 5**: Good Automated Manufacturing Practice
- **ISO 13485**: Medical devices - Quality management systems

---

## 2. Prerequisites

### 2.1 Hardware Requirements

| Component | Minimum Specification |
|-----------|----------------------|
| CPU | 4 cores (x86_64 or ARM64) |
| RAM | 8 GB |
| Disk Space | 50 GB available |
| Network | Internet connectivity for package downloads |

### 2.2 Software Requirements

| Software | Version | Purpose |
|----------|---------|---------|
| Docker Engine | 24.0+ | Container runtime |
| Docker Compose | v2.20+ | Multi-container orchestration |
| VS Code | 1.80+ | Development IDE (optional) |
| Git | 2.40+ | Version control |

### 2.3 Personnel Requirements

- System Administrator with Docker experience
- QA Personnel for verification
- Optional: Developer for acceptance testing

---

## 3. Installation Steps

### 3.1 Docker Engine Installation

**Platform-Specific Instructions**:

#### Linux
```bash
# Verify Docker installation
docker --version

# Expected output format: Docker version 24.0.0 or higher

# Verify Docker daemon is running
docker info

# Add user to docker group (if needed)
sudo usermod -aG docker $USER
newgrp docker
```

#### macOS
```bash
# Verify Docker Desktop is installed
docker --version

# Verify Docker Desktop is running
docker info
```

#### Windows (WSL2)
```bash
# In WSL2 terminal
docker --version
docker info
```

**Acceptance Criteria**:
- [ ] Docker version 24.0.0 or higher
- [ ] Docker daemon is running
- [ ] User has permissions to run Docker commands

### 3.2 Docker Compose Installation

```bash
# Verify Docker Compose v2
docker compose version

# Expected output: Docker Compose version v2.20.0 or higher
```

**Acceptance Criteria**:
- [ ] Docker Compose v2.20+ installed
- [ ] `docker compose` command works (not legacy `docker-compose`)

### 3.3 Repository Clone

```bash
# Clone repository
git clone https://github.com/yourorg/clinical-diary.git
cd clinical-diary

# Verify repository structure
ls -la tools/dev-env/
```

**Acceptance Criteria**:
- [ ] Repository cloned successfully
- [ ] `tools/dev-env/` directory exists
- [ ] `tools/dev-env/docker/` directory contains Dockerfiles
- [ ] `tools/dev-env/docker-compose.yml` exists

### 3.4 Docker Image Build

```bash
# Navigate to dev-env directory
cd tools/dev-env

# Run setup script
./setup.sh --build-only

# Alternatively, build manually
docker build -f docker/base.Dockerfile -t clinical-diary-base:latest docker/
docker build -f docker/dev.Dockerfile -t clinical-diary-dev:latest --build-arg BASE_IMAGE_TAG=latest docker/
docker build -f docker/qa.Dockerfile -t clinical-diary-qa:latest --build-arg BASE_IMAGE_TAG=latest docker/
docker build -f docker/ops.Dockerfile -t clinical-diary-ops:latest --build-arg BASE_IMAGE_TAG=latest docker/
docker build -f docker/mgmt.Dockerfile -t clinical-diary-mgmt:latest --build-arg BASE_IMAGE_TAG=latest docker/
```

**Acceptance Criteria**:
- [ ] All 5 images build without errors
- [ ] Images are tagged with `:latest`
- [ ] Images appear in `docker images` output
- [ ] Build completes in reasonable time (< 60 minutes)

### 3.5 Verify Image Contents

```bash
# Verify base image
docker run --rm clinical-diary-base:latest git --version
docker run --rm clinical-diary-base:latest gh --version
docker run --rm clinical-diary-base:latest node --version
docker run --rm clinical-diary-base:latest python3 --version
docker run --rm clinical-diary-base:latest doppler --version

# Verify dev image
docker run --rm clinical-diary-dev:latest flutter --version

# Verify QA image
docker run --rm clinical-diary-qa:latest npx playwright --version

# Verify ops image
docker run --rm clinical-diary-ops:latest terraform --version
docker run --rm clinical-diary-ops:latest supabase --version
docker run --rm clinical-diary-ops:latest cosign version
docker run --rm clinical-diary-ops:latest syft --version

# Verify mgmt image
docker run --rm clinical-diary-mgmt:latest git --version
```

**Acceptance Criteria**:
- [ ] Base image: Git, GitHub CLI, Node.js, Python, Doppler all present
- [ ] Dev image: Flutter 3.24.0 installed
- [ ] QA image: Playwright installed
- [ ] Ops image: Terraform, Supabase CLI, Cosign, Syft installed
- [ ] Mgmt image: Git tools present

### 3.6 Docker Volume Creation

```bash
# Volumes are created automatically by docker compose
# Verify volumes exist or will be created
docker volume ls | grep clinical-diary || echo "Volumes will be created on first run"
```

**Acceptance Criteria**:
- [ ] Docker volume system is functional
- [ ] Permissions allow volume creation

### 3.7 VS Code Dev Container Configuration (Optional)

```bash
# Verify Dev Container configs exist
ls -la .devcontainer/dev/devcontainer.json
ls -la .devcontainer/qa/devcontainer.json
ls -la .devcontainer/ops/devcontainer.json
ls -la .devcontainer/mgmt/devcontainer.json
```

**Acceptance Criteria**:
- [ ] All 4 devcontainer.json files exist
- [ ] Files are valid JSON
- [ ] Each references correct docker-compose service

---

## 4. Verification Tests

### 4.1 Container Startup Test

```bash
# Start all services
cd tools/dev-env
docker compose up -d

# Wait for containers to be healthy
sleep 10

# Check container status
docker compose ps
```

**Expected Result**:
```
NAME                    STATUS
clinical-diary-dev-1    Up X seconds (healthy)
clinical-diary-qa-1     Up X seconds (healthy)
clinical-diary-ops-1    Up X seconds (healthy)
clinical-diary-mgmt-1   Up X seconds (healthy)
```

**Acceptance Criteria**:
- [ ] All 4 containers start successfully
- [ ] All containers report "healthy" status
- [ ] No error messages in logs

### 4.2 Health Check Verification

```bash
# Run health checks for each role
docker compose exec dev /usr/local/bin/health-check.sh
docker compose exec qa /usr/local/bin/health-check.sh
docker compose exec ops /usr/local/bin/health-check.sh
docker compose exec mgmt /usr/local/bin/health-check.sh
```

**Acceptance Criteria**:
- [ ] All health checks pass
- [ ] Each outputs "health check passed"
- [ ] No errors or missing tools

### 4.3 Network Isolation Test

```bash
# Each container should be on the clinical-diary network
docker network inspect clinical-diary-network
```

**Acceptance Criteria**:
- [ ] Network `clinical-diary-network` exists
- [ ] All 4 containers are connected
- [ ] Network mode is bridge

### 4.4 Volume Mount Test

```bash
# Verify bind mount works
docker compose exec dev ls -la /workspace/src

# Verify named volumes
docker compose exec dev ls -la /workspace/repos
docker compose exec dev ls -la /workspace/exchange
docker compose exec qa ls -la /workspace/reports
```

**Acceptance Criteria**:
- [ ] Bind mount `/workspace/src` shows project files
- [ ] Named volumes are accessible
- [ ] Permissions are correct (ubuntu:ubuntu)

### 4.5 User Configuration Test

```bash
# Verify non-root user
docker compose exec dev whoami
# Expected: ubuntu

docker compose exec dev id
# Expected: uid=1000(ubuntu) gid=1000(ubuntu)

# Verify Git config per role
docker compose exec dev git config user.name
# Expected: Developer

docker compose exec qa git config user.name
# Expected: QA Automation Bot

docker compose exec ops git config user.name
# Expected: DevOps Engineer

docker compose exec mgmt git config user.name
# Expected: Management Viewer
```

**Acceptance Criteria**:
- [ ] All containers run as `ubuntu` user (UID 1000)
- [ ] Git identity is configured per role
- [ ] Git email addresses are role-specific

### 4.6 Tool Version Verification

Create a verification script:

```bash
# tools/dev-env/verify-installation.sh
#!/bin/bash

echo "=== Base Tools (All Containers) ==="
docker compose exec -T dev git --version
docker compose exec -T dev gh --version
docker compose exec -T dev node --version
docker compose exec -T dev python3 --version
docker compose exec -T dev doppler --version

echo ""
echo "=== Dev Tools ==="
docker compose exec -T dev flutter --version | head -1

echo ""
echo "=== QA Tools ==="
docker compose exec -T qa npx playwright --version

echo ""
echo "=== Ops Tools ==="
docker compose exec -T ops terraform --version | head -1
docker compose exec -T ops supabase --version
docker compose exec -T ops cosign version | head -1
docker compose exec -T ops syft version | head -1

echo ""
echo "=== Installation Verification Complete ==="
```

**Acceptance Criteria**:
- [ ] All tools report expected versions
- [ ] No errors or "command not found"
- [ ] Versions match requirements in spec/dev-environment.md

---

## 5. Documentation Verification

### 5.1 Required Documentation

**Acceptance Criteria**:
- [ ] `tools/dev-env/README.md` exists and is complete
- [ ] `tools/dev-env/doppler-setup.md` exists
- [ ] `docs/dev-environment-architecture.md` exists
- [ ] `docs/adr/ADR-006-docker-dev-environments.md` exists
- [ ] `spec/dev-environment.md` exists with requirements

### 5.2 Code Traceability

```bash
# Verify requirement references in code
grep -r "IMPLEMENTS REQUIREMENTS" tools/dev-env/docker/
```

**Acceptance Criteria**:
- [ ] All Dockerfiles have requirement headers
- [ ] Requirements reference REQ-d00027 through REQ-d00036
- [ ] Requirements exist in spec/dev-environment.md

---

## 6. Test Execution Record

### 6.1 Installation Information

| Field | Value |
|-------|-------|
| Installation Date | _________________ |
| Installed By | _________________ |
| Platform | ☐ Linux  ☐ macOS  ☐ Windows (WSL2) |
| Docker Version | _________________ |
| Docker Compose Version | _________________ |

### 6.2 Test Results

| Test ID | Test Description | Pass/Fail | Notes | Tester Initials |
|---------|------------------|-----------|-------|----------------|
| IQ-3.1 | Docker Engine Installation | ☐ Pass ☐ Fail | | |
| IQ-3.2 | Docker Compose Installation | ☐ Pass ☐ Fail | | |
| IQ-3.3 | Repository Clone | ☐ Pass ☐ Fail | | |
| IQ-3.4 | Docker Image Build | ☐ Pass ☐ Fail | | |
| IQ-3.5 | Verify Image Contents | ☐ Pass ☐ Fail | | |
| IQ-3.6 | Docker Volume Creation | ☐ Pass ☐ Fail | | |
| IQ-3.7 | VS Code Dev Container Config | ☐ Pass ☐ Fail | | |
| IQ-4.1 | Container Startup Test | ☐ Pass ☐ Fail | | |
| IQ-4.2 | Health Check Verification | ☐ Pass ☐ Fail | | |
| IQ-4.3 | Network Isolation Test | ☐ Pass ☐ Fail | | |
| IQ-4.4 | Volume Mount Test | ☐ Pass ☐ Fail | | |
| IQ-4.5 | User Configuration Test | ☐ Pass ☐ Fail | | |
| IQ-4.6 | Tool Version Verification | ☐ Pass ☐ Fail | | |
| IQ-5.1 | Required Documentation | ☐ Pass ☐ Fail | | |
| IQ-5.2 | Code Traceability | ☐ Pass ☐ Fail | | |

### 6.3 Overall Result

**Installation Qualification**: ☐ **PASSED** ☐ **FAILED**

---

## 7. Deviations and Issues

| Issue # | Description | Resolution | Status |
|---------|-------------|------------|--------|
| | | | |

---

## 8. Approval Signatures

| Role | Name | Signature | Date |
|------|------|-----------|------|
| System Administrator | | | |
| QA Lead | | | |
| Project Manager | | | |

---

## 9. Attachments

1. Docker build logs
2. Container health check outputs
3. Tool version verification output
4. Screenshot of successful deployment

---

## 10. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-10-27 | Claude Code | Initial IQ protocol |

---

**Next Steps**: Upon successful completion of IQ, proceed to OQ (Operational Qualification).
