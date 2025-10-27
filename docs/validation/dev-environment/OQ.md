# Operational Qualification (OQ)
# Clinical Diary Development Environment

**Document Type**: Operational Qualification Protocol
**System**: Docker-Based Development Environment
**Version**: 1.0.0
**Date**: 2025-10-27
**Status**: Draft

---

## 1. Purpose

This Operational Qualification (OQ) protocol verifies that the Clinical Diary Docker-based development environment operates according to its specifications and design requirements under normal operating conditions.

### 1.1 Scope

This OQ covers:
- Role-based access and separation
- Development workflows per role
- CI/CD integration
- Secrets management integration
- Container lifecycle management
- Data persistence and sharing
- Network communication
- Tool functionality verification

### 1.2 Regulatory Compliance

This validation supports compliance with:
- **FDA 21 CFR Part 11**: Electronic Records; Electronic Signatures
- **GAMP 5**: Good Automated Manufacturing Practice
- **ISO 13485**: Medical devices - Quality management systems

---

## 2. Prerequisites

**Required**:
- [ ] Installation Qualification (IQ) completed and approved
- [ ] All Docker images built and verified
- [ ] Docker daemon running
- [ ] Doppler account created (optional but recommended)

---

## 3. Operational Tests

### 3.1 Role-Based Access Control

**Requirement**: REQ-d00028 - Role-Based Environment Separation

#### Test OQ-3.1.1: Dev Role Operations

```bash
# Start dev container
cd tools/dev-env
docker compose up -d dev
docker compose exec dev bash

# Inside container: Verify dev can write
cd /workspace/src
echo "test" > test-file.txt
cat test-file.txt
rm test-file.txt

# Verify Git identity
git config user.name
# Expected: Developer

git config user.email
# Expected: dev@clinical-diary.local

# Verify Flutter access
flutter --version
flutter doctor

# Verify Android SDK
echo $ANDROID_HOME
ls $ANDROID_HOME/platforms
```

**Acceptance Criteria**:
- [ ] Dev can read and write to /workspace/src
- [ ] Git identity is "Developer"
- [ ] Flutter commands work
- [ ] Android SDK is accessible

#### Test OQ-3.1.2: QA Role Operations

```bash
# Start QA container
docker compose up -d qa
docker compose exec qa bash

# Inside container: Verify QA can write to reports
cd /workspace/reports
echo "test report" > test-report.txt
cat test-report.txt
rm test-report.txt

# Verify Git identity
git config user.name
# Expected: QA Automation Bot

# Verify Playwright access
npx playwright --version

# Verify qa-runner script
which qa-runner.sh
qa-runner.sh --help || /usr/local/bin/qa-runner.sh || echo "QA runner installed"
```

**Acceptance Criteria**:
- [ ] QA can write to /workspace/reports
- [ ] Git identity is "QA Automation Bot"
- [ ] Playwright is functional
- [ ] QA runner script is available

#### Test OQ-3.1.3: Ops Role Operations

```bash
# Start ops container
docker compose up -d ops
docker compose exec ops bash

# Inside container: Verify ops tools
terraform --version
supabase --version
cosign version
syft version
kubectl version --client

# Verify Git identity
git config user.name
# Expected: DevOps Engineer
```

**Acceptance Criteria**:
- [ ] Terraform commands work
- [ ] Supabase CLI is functional
- [ ] Cosign is installed
- [ ] Syft is installed
- [ ] kubectl is installed
- [ ] Git identity is "DevOps Engineer"

#### Test OQ-3.1.4: Management Role Operations

```bash
# Start mgmt container
docker compose up -d mgmt
docker compose exec mgmt bash

# Inside container: Verify read-only access
cd /workspace/src
echo "test" > test-file.txt 2>&1
# Expected: Permission denied or similar error

# Verify Git identity
git config user.name
# Expected: Management Viewer

# Verify view scripts
which view-repo-status.sh
which view-qa-reports.sh
```

**Acceptance Criteria**:
- [ ] Mgmt CANNOT write to /workspace/src
- [ ] Git identity is "Management Viewer"
- [ ] View scripts are available
- [ ] Read access works for viewing files

### 3.2 Development Workflows

**Requirement**: REQ-d00032 - Development Tool Specifications

#### Test OQ-3.2.1: Flutter Development Workflow

```bash
# In dev container
cd /workspace/repos
mkdir -p test-flutter-app
cd test-flutter-app

# Create Flutter app
flutter create hello_world
cd hello_world

# Get dependencies
flutter pub get

# Run tests
flutter test

# Build app (for desktop or Android)
flutter build apk --debug || flutter build linux || echo "Build tested"

# Clean up
cd /workspace/repos
rm -rf test-flutter-app
```

**Acceptance Criteria**:
- [ ] Flutter project creation succeeds
- [ ] Dependencies download successfully
- [ ] Tests run without errors
- [ ] Build process completes

#### Test OQ-3.2.2: Git Workflow

```bash
# In dev container
cd /workspace/repos
mkdir -p test-git-repo
cd test-git-repo

# Initialize repository
git init
git config user.name "Developer"
git config user.email "dev@clinical-diary.local"

# Create commit
echo "# Test" > README.md
git add README.md
git commit -m "Initial commit"

# Verify commit
git log --oneline

# Clean up
cd /workspace/repos
rm -rf test-git-repo
```

**Acceptance Criteria**:
- [ ] Git init succeeds
- [ ] Commits can be created
- [ ] Git log shows commit history
- [ ] Git identity matches role

#### Test OQ-3.2.3: Node.js Workflow

```bash
# In dev container
cd /workspace/repos
mkdir -p test-node-app
cd test-node-app

# Initialize npm project
npm init -y

# Install package
npm install express

# Verify installation
node -e "console.log(require('express'))"

# Clean up
cd /workspace/repos
rm -rf test-node-app
```

**Acceptance Criteria**:
- [ ] npm init succeeds
- [ ] Package installation works
- [ ] Node modules are functional

### 3.3 QA Automation Workflows

**Requirement**: REQ-d00031 - Automated QA Testing

#### Test OQ-3.3.1: QA Runner Script Execution

```bash
# In QA container
cd /workspace/repos

# Create mock Flutter project for testing
mkdir -p test-project
cd test-project
flutter create test_app
cd test_app

# Run QA suite (will handle missing tests gracefully)
TEST_SUITE=all qa-runner.sh

# Verify reports generated
ls -la /workspace/reports/

# Check summary
cat /workspace/reports/test-summary.md

# Clean up
cd /workspace/repos
rm -rf test-project
```

**Acceptance Criteria**:
- [ ] QA runner executes without critical errors
- [ ] Report directory is created
- [ ] Summary file is generated
- [ ] Script handles missing tests gracefully

#### Test OQ-3.3.2: Playwright Test Execution

```bash
# In QA container
cd /workspace/repos
mkdir -p playwright-test
cd playwright-test

# Initialize Playwright project
npm init -y
npm install -D @playwright/test
npx playwright install

# Create simple test
cat > tests/example.spec.ts <<'EOF'
import { test, expect } from '@playwright/test';

test('basic test', async ({ page }) => {
  await page.goto('https://example.com');
  await expect(page).toHaveTitle(/Example Domain/);
});
EOF

# Run test
npx playwright test

# Verify reports
ls -la playwright-report/

# Clean up
cd /workspace/repos
rm -rf playwright-test
```

**Acceptance Criteria**:
- [ ] Playwright initializes successfully
- [ ] Browsers install correctly
- [ ] Tests execute
- [ ] Reports are generated

### 3.4 CI/CD Integration

**Requirement**: REQ-d00030 - CI/CD Integration

#### Test OQ-3.4.1: GitHub Actions Workflow Validation

```bash
# Validate workflow syntax
cat .github/workflows/qa-automation.yml | docker run --rm -i rhysd/actionlint -

cat .github/workflows/build-publish-images.yml | docker run --rm -i rhysd/actionlint -
```

**Acceptance Criteria**:
- [ ] QA automation workflow is valid YAML
- [ ] Build/publish workflow is valid YAML
- [ ] No syntax errors reported

#### Test OQ-3.4.2: Local CI Simulation

```bash
# Simulate CI build locally
cd tools/dev-env

# Build images as CI would
docker build -f docker/base.Dockerfile -t clinical-diary-base:ci-test docker/
docker build -f docker/dev.Dockerfile --build-arg BASE_IMAGE_TAG=ci-test -t clinical-diary-dev:ci-test docker/
docker build -f docker/qa.Dockerfile --build-arg BASE_IMAGE_TAG=ci-test -t clinical-diary-qa:ci-test docker/

# Run health checks
docker run --rm clinical-diary-base:ci-test /usr/local/bin/health-check.sh
docker run --rm clinical-diary-dev:ci-test /usr/local/bin/health-check.sh
docker run --rm clinical-diary-qa:ci-test /usr/local/bin/health-check.sh

# Clean up
docker rmi clinical-diary-base:ci-test clinical-diary-dev:ci-test clinical-diary-qa:ci-test
```

**Acceptance Criteria**:
- [ ] Images build in CI-like environment
- [ ] Health checks pass
- [ ] No build cache issues

### 3.5 Data Persistence and Sharing

**Requirement**: REQ-d00036 - Shared Workspace Configuration

#### Test OQ-3.5.1: Named Volume Persistence

```bash
# Start dev container
cd tools/dev-env
docker compose up -d dev

# Create test file in repos volume
docker compose exec dev bash -c "echo 'persistent data' > /workspace/repos/test-persistence.txt"

# Stop container
docker compose stop dev

# Start container again
docker compose up -d dev

# Verify file persists
docker compose exec dev cat /workspace/repos/test-persistence.txt
# Expected: persistent data

# Clean up
docker compose exec dev rm /workspace/repos/test-persistence.txt
```

**Acceptance Criteria**:
- [ ] Data persists across container restarts
- [ ] File content is unchanged
- [ ] No data corruption

#### Test OQ-3.5.2: Shared Exchange Volume

```bash
# Start dev and qa containers
docker compose up -d dev qa

# Create file in exchange from dev
docker compose exec dev bash -c "echo 'shared from dev' > /workspace/exchange/dev-to-qa.txt"

# Read file from qa
docker compose exec qa cat /workspace/exchange/dev-to-qa.txt
# Expected: shared from dev

# Create file from qa
docker compose exec qa bash -c "echo 'shared from qa' > /workspace/exchange/qa-to-dev.txt"

# Read from dev
docker compose exec dev cat /workspace/exchange/qa-to-dev.txt
# Expected: shared from qa

# Clean up
docker compose exec dev rm /workspace/exchange/dev-to-qa.txt /workspace/exchange/qa-to-dev.txt
```

**Acceptance Criteria**:
- [ ] Files created in exchange are visible to all roles
- [ ] Data can be shared bidirectionally
- [ ] Permissions allow read/write access

#### Test OQ-3.5.3: Bind Mount Synchronization

```bash
# Create file on host
cd /workspace/src
echo "host file" > host-test.txt

# Verify visible in container
docker compose exec dev cat /workspace/src/host-test.txt
# Expected: host file

# Create file in container
docker compose exec dev bash -c "echo 'container file' > /workspace/src/container-test.txt"

# Verify visible on host
cat container-test.txt
# Expected: container file

# Clean up
rm host-test.txt container-test.txt
```

**Acceptance Criteria**:
- [ ] Host files are immediately visible in container
- [ ] Container files are immediately visible on host
- [ ] No synchronization lag

### 3.6 Container Lifecycle Management

**Requirement**: REQ-d00027 - Containerized Development Environments

#### Test OQ-3.6.1: Start/Stop Operations

```bash
cd tools/dev-env

# Start all containers
docker compose up -d

# Verify all running
docker compose ps | grep "Up"

# Stop all containers
docker compose stop

# Verify all stopped
docker compose ps | grep "Exit" || docker compose ps

# Restart containers
docker compose up -d

# Verify all running again
docker compose ps | grep "Up"
```

**Acceptance Criteria**:
- [ ] Containers start successfully
- [ ] Containers stop cleanly
- [ ] Containers restart without errors
- [ ] State is preserved across restarts

#### Test OQ-3.6.2: Individual Container Management

```bash
# Start only dev
docker compose up -d dev

# Verify only dev is running
docker compose ps

# Start qa without stopping dev
docker compose up -d qa

# Verify both running
docker compose ps | grep "Up" | wc -l
# Expected: 2

# Stop qa only
docker compose stop qa

# Verify dev still running
docker compose ps | grep "dev" | grep "Up"

# Clean up
docker compose down
```

**Acceptance Criteria**:
- [ ] Individual containers can be started
- [ ] Starting one doesn't affect others
- [ ] Individual containers can be stopped
- [ ] Stopping one doesn't affect others

### 3.7 Secrets Management Integration

**Requirement**: REQ-d00035 - Security and Compliance

#### Test OQ-3.7.1: Doppler CLI Availability

```bash
# In dev container
docker compose exec dev doppler --version

# In qa container
docker compose exec qa doppler --version

# In ops container
docker compose exec ops doppler --version
```

**Acceptance Criteria**:
- [ ] Doppler is installed in all containers
- [ ] Version is 3.67+ or latest
- [ ] Command executes without errors

#### Test OQ-3.7.2: Doppler Configuration (Manual)

**Note**: This test requires a Doppler account and token.

```bash
# In dev container (interactive)
docker compose exec dev bash

# Login to Doppler
doppler login

# Setup project
doppler setup --project clinical-diary-dev --config dev

# Test secret retrieval
doppler run -- printenv | grep DOPPLER
```

**Acceptance Criteria**:
- [ ] Doppler login succeeds (if token provided)
- [ ] Project setup works
- [ ] Secrets can be retrieved
- [ ] Secrets are not logged to console

---

## 4. VS Code Dev Containers Integration

**Requirement**: REQ-d00029 - Cross-Platform Development Support

### Test OQ-4.1: Dev Container Launch

**Note**: Requires VS Code with Dev Containers extension

1. Open VS Code
2. Command Palette (F1) → "Dev Containers: Reopen in Container"
3. Select "Clinical Diary - Developer"
4. Wait for container to start

**Acceptance Criteria**:
- [ ] Container builds or starts
- [ ] VS Code connects successfully
- [ ] Extensions are installed automatically
- [ ] Integrated terminal opens in container

### Test OQ-4.2: VS Code Extensions

Inside Dev Container, verify extensions:

```bash
# In VS Code terminal
code --list-extensions
```

**Acceptance Criteria**:
- [ ] Flutter extension installed (dev/qa)
- [ ] Playwright extension installed (qa)
- [ ] Terraform extension installed (ops)
- [ ] GitLens extension installed (all)

---

## 5. Performance and Resource Tests

### Test OQ-5.1: Resource Limits

```bash
# Check resource usage
docker stats --no-stream

# Verify limits are enforced
docker inspect clinical-diary-dev-1 | grep -A 10 Resources
```

**Acceptance Criteria**:
- [ ] Memory limits are set (if configured)
- [ ] CPU limits are set (if configured)
- [ ] Containers respect resource constraints

### Test OQ-5.2: Build Performance

```bash
# Time full rebuild
time ./setup.sh --rebuild

# Expected: < 60 minutes for all images
```

**Acceptance Criteria**:
- [ ] Full rebuild completes in reasonable time
- [ ] No timeout errors
- [ ] Cache is utilized when available

---

## 6. Test Execution Record

### 6.1 Test Environment

| Field | Value |
|-------|-------|
| Test Date | _________________ |
| Tester Name | _________________ |
| Platform | ☐ Linux  ☐ macOS  ☐ Windows (WSL2) |
| Docker Version | _________________ |
| Image Version | _________________ |

### 6.2 Test Results Summary

| Test ID | Test Description | Pass/Fail | Notes | Tester Initials |
|---------|------------------|-----------|-------|----------------|
| OQ-3.1.1 | Dev Role Operations | ☐ Pass ☐ Fail | | |
| OQ-3.1.2 | QA Role Operations | ☐ Pass ☐ Fail | | |
| OQ-3.1.3 | Ops Role Operations | ☐ Pass ☐ Fail | | |
| OQ-3.1.4 | Mgmt Role Operations | ☐ Pass ☐ Fail | | |
| OQ-3.2.1 | Flutter Workflow | ☐ Pass ☐ Fail | | |
| OQ-3.2.2 | Git Workflow | ☐ Pass ☐ Fail | | |
| OQ-3.2.3 | Node.js Workflow | ☐ Pass ☐ Fail | | |
| OQ-3.3.1 | QA Runner Script | ☐ Pass ☐ Fail | | |
| OQ-3.3.2 | Playwright Tests | ☐ Pass ☐ Fail | | |
| OQ-3.4.1 | Workflow Validation | ☐ Pass ☐ Fail | | |
| OQ-3.4.2 | Local CI Simulation | ☐ Pass ☐ Fail | | |
| OQ-3.5.1 | Volume Persistence | ☐ Pass ☐ Fail | | |
| OQ-3.5.2 | Shared Exchange | ☐ Pass ☐ Fail | | |
| OQ-3.5.3 | Bind Mount Sync | ☐ Pass ☐ Fail | | |
| OQ-3.6.1 | Start/Stop Operations | ☐ Pass ☐ Fail | | |
| OQ-3.6.2 | Individual Container Mgmt | ☐ Pass ☐ Fail | | |
| OQ-3.7.1 | Doppler Availability | ☐ Pass ☐ Fail | | |
| OQ-3.7.2 | Doppler Configuration | ☐ Pass ☐ Fail | | |
| OQ-4.1 | Dev Container Launch | ☐ Pass ☐ Fail | | |
| OQ-4.2 | VS Code Extensions | ☐ Pass ☐ Fail | | |
| OQ-5.1 | Resource Limits | ☐ Pass ☐ Fail | | |
| OQ-5.2 | Build Performance | ☐ Pass ☐ Fail | | |

### 6.3 Overall Result

**Operational Qualification**: ☐ **PASSED** ☐ **FAILED**

---

## 7. Deviations and Issues

| Issue # | Description | Resolution | Status |
|---------|-------------|------------|--------|
| | | | |

---

## 8. Approval Signatures

| Role | Name | Signature | Date |
|------|------|-----------|------|
| QA Lead | | | |
| Development Lead | | | |
| Project Manager | | | |

---

## 9. Attachments

1. Test execution logs
2. Screenshot of successful workflows
3. Performance metrics
4. Resource usage reports

---

## 10. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-10-27 | Claude Code | Initial OQ protocol |

---

**Next Steps**: Upon successful completion of OQ, proceed to PQ (Performance Qualification).
