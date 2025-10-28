# Platform Testing Guide
# Clinical Diary Development Environment

**Purpose**: Verify the Docker-based development environment works correctly across Linux, macOS, and Windows (WSL2).

**Version**: 1.0.0
**Date**: 2025-10-27

---

## Overview

This guide provides platform-specific instructions for testing the Clinical Diary development environment. Use this guide to verify the environment works on your specific platform before beginning development.

### Supported Platforms

| Platform | Docker Backend | Status | Notes |
|----------|---------------|--------|-------|
| Linux (x86_64) | Native Docker Engine | ✅ Fully Supported | Best performance |
| Linux (ARM64) | Native Docker Engine | ✅ Supported | Raspberry Pi, ARM servers |
| macOS (Intel) | Docker Desktop | ✅ Fully Supported | VM overhead |
| macOS (Apple Silicon) | Docker Desktop | ✅ Fully Supported | Some emulation for x86-only tools |
| Windows 10/11 (WSL2) | Docker Desktop | ✅ Fully Supported | Use WSL2 backend |

---

## Quick Platform Detection

Run this command to identify your platform:

```bash
uname -a
```

**Output Examples**:
- Linux: `Linux hostname 5.15.0 ... x86_64 GNU/Linux`
- macOS Intel: `Darwin hostname 22.1.0 ... x86_64`
- macOS ARM: `Darwin hostname 22.1.0 ... arm64`
- Windows WSL2: `Linux hostname 5.15.0-microsoft-standard-WSL2 ... x86_64 GNU/Linux`

---

## Platform-Specific Setup

### Linux (Native Docker)

#### Prerequisites

```bash
# Check Docker installation
docker --version
# Expected: Docker version 24.0.0 or higher

# Check Docker daemon
systemctl status docker
# Should show: active (running)

# Check user permissions
groups | grep docker
# Your username should be in docker group
```

#### If Docker Not Installed

**Ubuntu/Debian**:
```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker run hello-world
```

**Fedora/RHEL/CentOS**:
```bash
# Install using dnf
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### Platform Test

```bash
# Navigate to project
cd /path/to/clinical-diary

# Run setup
cd tools/dev-env
./setup.sh

# Verify all images built
docker images | grep clinical-diary

# Expected output:
# clinical-diary-base    latest   ...
# clinical-diary-dev     latest   ...
# clinical-diary-qa      latest   ...
# clinical-diary-ops     latest   ...
# clinical-diary-mgmt    latest   ...
```

**Expected Build Time**: 15-30 minutes (first build)

**Performance Characteristics**:
- ✅ Native performance (no VM overhead)
- ✅ Fastest build times
- ✅ Best file I/O performance
- ✅ Direct hardware access

---

### macOS (Intel & Apple Silicon)

#### Prerequisites

1. **Install Docker Desktop**: Download from https://www.docker.com/products/docker-desktop

2. **Verify Installation**:
```bash
# Check Docker Desktop is running
docker --version
# Expected: Docker version 24.0.0 or higher

docker info
# Should show Docker Desktop context
```

3. **Configure Docker Desktop**:
   - Open Docker Desktop
   - Settings → Resources → Advanced
   - Recommended settings:
     - CPUs: 4+ (half of available cores)
     - Memory: 8GB+
     - Swap: 2GB
     - Disk image size: 64GB+

#### Apple Silicon Specific

For Apple Silicon (M1/M2/M3), some tools may need emulation:

```bash
# Check architecture
uname -m
# Output: arm64

# Verify Rosetta 2 is available
softwareupdate --install-rosetta --agree-to-license
```

**Note**: Android SDK may run under emulation. Flutter itself has native ARM support.

#### Platform Test

```bash
# Navigate to project
cd /path/to/clinical-diary

# Run setup
cd tools/dev-env
./setup.sh

# Verify all images built
docker images | grep clinical-diary
```

**Expected Build Time**: 20-40 minutes (first build)

**Performance Characteristics**:
- ⚠️ VM overhead (slower than Linux)
- ⚠️ File sync latency (bind mounts)
- ✅ Good CPU performance
- ⚠️ Some emulation on ARM (x86-only tools)

**Optimization Tips**:
1. Store project in Docker VM filesystem (not macOS filesystem) for better performance
2. Use named volumes instead of bind mounts when possible
3. Increase Docker Desktop memory allocation if builds fail

---

### Windows 10/11 (WSL2)

#### Prerequisites

1. **Enable WSL2**:
```powershell
# Run in PowerShell (Administrator)
wsl --install

# Restart computer

# Set WSL2 as default
wsl --set-default-version 2

# Install Ubuntu (recommended)
wsl --install -d Ubuntu-22.04
```

2. **Install Docker Desktop**:
   - Download from https://www.docker.com/products/docker-desktop
   - During installation, ensure "Use WSL 2 instead of Hyper-V" is checked
   - Restart computer

3. **Configure Docker Desktop**:
   - Open Docker Desktop
   - Settings → General → "Use WSL 2 based engine" (checked)
   - Settings → Resources → WSL Integration
     - Enable integration with your WSL distro (Ubuntu-22.04)

4. **Verify in WSL**:
```bash
# Open WSL terminal
wsl -d Ubuntu-22.04

# Check Docker
docker --version
# Expected: Docker version 24.0.0 or higher

docker info
# Should show Docker Desktop context
```

#### Platform Test

**IMPORTANT**: Always work inside WSL2, not Windows Command Prompt or PowerShell.

```bash
# In WSL2 Ubuntu terminal
cd /home/$USER

# Clone repository (if not already)
git clone https://github.com/yourorg/clinical-diary.git
cd clinical-diary

# Run setup
cd tools/dev-env
./setup.sh

# Verify all images built
docker images | grep clinical-diary
```

**Expected Build Time**: 25-45 minutes (first build)

**Performance Characteristics**:
- ⚠️ VM overhead (slower than Linux)
- ✅ Better than Hyper-V
- ⚠️ File sync latency (especially /mnt/c/)
- ✅ Native Linux compatibility

**Optimization Tips**:
1. **CRITICAL**: Store project in WSL filesystem (`/home/$USER/`), NOT Windows filesystem (`/mnt/c/`)
   - WSL path: ✅ Fast
   - Windows path: ❌ Very slow (10-100x slower)

2. File location check:
```bash
pwd
# Good: /home/username/clinical-diary
# Bad:  /mnt/c/Users/username/clinical-diary
```

3. Increase WSL2 memory:
```powershell
# Create/edit C:\Users\<YourUsername>\.wslconfig
[wsl2]
memory=8GB
processors=4
swap=2GB
```

4. Restart WSL:
```powershell
wsl --shutdown
```

---

## Cross-Platform Verification Tests

### Test 1: Build Verification

Run on each platform:

```bash
cd tools/dev-env

# Clean rebuild
./setup.sh --rebuild

# Record results
echo "Platform: $(uname -s)"
echo "Build status: PASS/FAIL"
echo "Build time: X minutes"
```

**Acceptance Criteria**:
- [ ] All 5 images build successfully
- [ ] Build completes in < 60 minutes
- [ ] No platform-specific errors

### Test 2: Container Startup

```bash
# Start all containers
docker compose up -d

# Check health
docker compose ps

# Record results
```

**Acceptance Criteria**:
- [ ] All containers start
- [ ] All show "healthy" status
- [ ] Startup time < 30 seconds per container

### Test 3: Tool Verification

```bash
# Dev container
docker compose exec dev flutter --version
docker compose exec dev flutter doctor

# QA container
docker compose exec qa npx playwright --version

# Ops container
docker compose exec ops terraform --version
docker compose exec ops cosign version

# Record results
```

**Acceptance Criteria**:
- [ ] All tools report correct versions
- [ ] No "command not found" errors
- [ ] Flutter doctor shows no critical issues

### Test 4: File System Performance

```bash
# Bind mount test
time docker compose exec dev bash -c "
  cd /workspace/src
  for i in {1..100}; do
    echo 'test' > test-\$i.txt
  done
  rm test-*.txt
"

# Record time
```

**Acceptance Criteria**:
- [ ] Operation completes in < 5 seconds
- [ ] No permission errors
- [ ] Files visible on host immediately

### Test 5: Development Workflow

```bash
# Complete Flutter workflow
docker compose exec dev bash -c "
  cd /workspace/repos
  flutter create test_app
  cd test_app
  flutter pub get
  flutter test
"

# Record results
```

**Acceptance Criteria**:
- [ ] Project creates successfully
- [ ] Dependencies download
- [ ] Tests run
- [ ] Total time < 5 minutes

---

## Platform Comparison Results

**Fill in after testing**:

| Metric | Linux | macOS Intel | macOS ARM | Windows WSL2 |
|--------|-------|-------------|-----------|--------------|
| Build Time (min) | | | | |
| Startup Time (sec) | | | | |
| File Write (100 files) | | | | |
| Flutter Create | | | | |
| Flutter Test | | | | |
| Overall Performance | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## Troubleshooting by Platform

### Linux Issues

**Problem**: Permission denied for Docker socket
```bash
# Solution
sudo usermod -aG docker $USER
newgrp docker
```

**Problem**: systemd not starting Docker
```bash
# Solution
sudo systemctl enable --now docker
```

### macOS Issues

**Problem**: Docker Desktop not starting
- Check: System Preferences → Security & Privacy → Allow Docker
- Solution: Reinstall Docker Desktop

**Problem**: Slow performance
- Check file location (should be in Docker VM, not macOS filesystem)
- Increase Docker Desktop memory allocation
- Consider using lima or colima for better performance

**Problem**: "qemu" errors on Apple Silicon
- This is normal for x86-only tools
- Rosetta 2 will handle emulation automatically

### Windows WSL2 Issues

**Problem**: "The system cannot find the path specified"
- Check: Working in WSL, not Windows?
- Solution: Use `wsl -d Ubuntu-22.04` to enter WSL

**Problem**: Extremely slow builds
- Check: Is project in `/home/` or `/mnt/c/`?
- Solution: Move project to `/home/$USER/`

**Problem**: WSL2 using too much memory
- Create `.wslconfig` file (see optimization tips above)
- Run `wsl --shutdown` to restart

**Problem**: Docker not available in WSL
- Check: Docker Desktop → Settings → Resources → WSL Integration
- Enable integration with your distro

---

## Platform Testing Checklist

### Pre-Test Setup

- [ ] Docker installed and running
- [ ] User has Docker permissions
- [ ] Git installed
- [ ] Repository cloned
- [ ] Sufficient disk space (50GB+)
- [ ] Sufficient RAM (8GB+)

### Build Phase

- [ ] `./setup.sh` runs without errors
- [ ] All 5 images build successfully
- [ ] Build time is reasonable
- [ ] No platform-specific warnings

### Runtime Phase

- [ ] Containers start successfully
- [ ] Health checks pass
- [ ] Tools are accessible
- [ ] Versions are correct

### Functionality Phase

- [ ] Flutter creates projects
- [ ] Tests run successfully
- [ ] Git operations work
- [ ] File sharing works
- [ ] VS Code Dev Containers work (if using)

### Performance Phase

- [ ] File I/O is responsive
- [ ] Build times are acceptable
- [ ] Memory usage is stable
- [ ] CPU usage is reasonable

---

## Reporting Platform-Specific Issues

If you encounter platform-specific problems:

1. **Gather Information**:
```bash
# Platform details
uname -a
docker --version
docker info

# Error logs
docker compose logs > platform-error.log
```

2. **Document**:
   - Platform and version
   - Docker version
   - Exact error message
   - Steps to reproduce
   - Expected vs actual behavior

3. **Report**:
   - Create GitHub issue with platform-specific label
   - Include all gathered information
   - Attach logs if applicable

---

## Platform-Specific Recommendations

### For Best Performance

1. **Linux**: Use native Docker Engine (not Docker Desktop)
2. **macOS**: Consider Lima or Colima for better performance
3. **Windows**: Always use WSL2, never Hyper-V or native Windows

### For Team Consistency

- All team members should use the same major Docker version
- Document which platform each team member uses
- Test critical workflows on all platforms before release
- Use CI/CD (GitHub Actions) as the "source of truth" for builds

---

## Validation Sign-Off

**Platform Tester**: _________________ **Date**: _________________

**Platform**: ☐ Linux  ☐ macOS Intel  ☐ macOS ARM  ☐ Windows WSL2

**Result**: ☐ **PASSED** ☐ **FAILED**

**Notes**:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

---

**Next Steps**: After successful platform testing, proceed with development or report any platform-specific issues for resolution.
