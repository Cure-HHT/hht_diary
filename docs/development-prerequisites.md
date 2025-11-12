# Development Prerequisites Guide

This guide consolidates all tool installation and environment setup requirements for working on the Clinical Diary Platform. It serves as the single source of truth for development environment setup.

## Overview

The Clinical Diary Platform requires several core tools and optional utilities depending on your role. This document covers:

- Prerequisites by role (developer, QA, operations)
- Core tools required for all developers
- Optional tools for specific use cases
- Installation instructions by operating system
- Environment variable configuration
- Installation verification and troubleshooting

**Recommended approach**: Use the pre-configured dev container (see [Dev Container Setup](#dev-container-setup)) for consistent environment across the team. Manual setup is supported but requires careful attention to tool versions.

## Prerequisites by Role

### Developer Role

**Minimum requirements**:
- Git (2.30+)
- jq (1.6+)
- Python 3.8+
- Node.js 18+ and npm
- Bash 4.0+
- Docker Desktop (for dev container)

**Recommended additions**:
- GitHub CLI (gh)
- Linear CLI
- VS Code with Dev Containers extension

### QA Role

**Minimum requirements**:
- Git
- Docker Desktop
- Chrome or Firefox (for test automation)

**Recommended additions**:
- Node.js (for test runners)
- Python (for test scripts)

### Operations Role

**Minimum requirements**:
- Git
- Docker Desktop
- kubectl (for Kubernetes deployments)
- Doppler CLI (for secret management)

**Recommended additions**:
- yq (for YAML manipulation)
- jq (for JSON processing)
- aws-cli (if using AWS)

## Core Tools

These tools are required for all developers working on this project.

### Git

**Minimum version**: 2.30

Git is used for version control, requirement traceability, and workflow enforcement via git hooks.

**Installation**:

**macOS**:
```bash
brew install git
git --version  # Verify
```

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install -y git
git --version  # Verify
```

**Windows (WSL2)**:
```bash
sudo apt-get update
sudo apt-get install -y git
git --version  # Verify
```

**Configuration**:
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**Verification**:
```bash
git --version        # Should be 2.30 or higher
git config user.name
```

### jq - JSON Query Tool

**Minimum version**: 1.6

jq is used by workflow plugins for JSON parsing and manipulation. Required by the workflow plugin for state management.

**Installation**:

**macOS**:
```bash
brew install jq
jq --version
```

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install -y jq
jq --version
```

**Windows (WSL2)**:
```bash
sudo apt-get update
sudo apt-get install -y jq
jq --version
```

**Verification**:
```bash
jq --version        # Should be 1.6 or higher
echo '{"test": "value"}' | jq .test
```

### yq - YAML Query Tool

**Minimum version**: 4.0

Optional but recommended for ops roles and YAML configuration management.

**Installation**:

**macOS**:
```bash
brew install yq
yq --version
```

**Ubuntu/Debian**:
```bash
sudo add-apt-repository ppa:rmescandon/yq
sudo apt-get update
sudo apt-get install -y yq
yq --version
```

**Windows (WSL2)**:
```bash
sudo add-apt-repository ppa:rmescandon/yq
sudo apt-get update
sudo apt-get install -y yq
yq --version
```

**Verification**:
```bash
yq --version
echo 'test: value' | yq .test
```

### Python 3.x and pip

**Minimum version**: Python 3.8, pip 20.0+

Python is used for:
- Requirement validation scripts (`tools/requirements/`)
- Testing and automation
- Development utilities

**Installation**:

**macOS**:
```bash
# Using Homebrew
brew install python@3.12
python3 --version
pip3 --version
```

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv
python3 --version
pip3 --version
```

**Windows (WSL2)**:
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv
python3 --version
pip3 --version
```

**Verification**:
```bash
python3 --version     # Should be 3.8 or higher
pip3 --version        # Should be 20.0 or higher
python3 -m venv test_env  # Test venv creation
rm -rf test_env
```

### Node.js and npm

**Minimum version**: Node.js 18.x, npm 9.0+

Node.js is used for:
- Linear API plugin operations
- JavaScript/TypeScript development
- Build tools and automation

**Installation**:

**macOS** (using nvm - recommended):
```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Reload shell configuration
source ~/.bashrc
# or source ~/.zshrc

# Install Node.js
nvm install 20
nvm use 20
node --version
npm --version
```

**macOS** (using Homebrew):
```bash
brew install node@20
node --version
npm --version
```

**Ubuntu/Debian** (using NodeSource):
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version
npm --version
```

**Windows (WSL2)** (using NodeSource):
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
sudo apt-get install -y nodejs
node --version
npm --version
```

**Verification**:
```bash
node --version        # Should be 18.0 or higher
npm --version         # Should be 9.0 or higher
npm list -g           # List global packages
```

### Bash

**Minimum version**: 4.0

Required for workflow plugin git hooks and many automation scripts.

**Check current version**:
```bash
bash --version
```

**macOS** (upgrade if needed):
```bash
# macOS includes older bash by default
brew install bash
# Add to ~/.zprofile or ~/.bash_profile:
# export SHELL=/usr/local/bin/bash
```

**Ubuntu/Debian**:
Bash 4.0+ is usually included. If not:
```bash
sudo apt-get update
sudo apt-get install -y bash
bash --version
```

## Optional Tools

These tools are not required but provide enhanced functionality for specific tasks.

### GitHub CLI (gh)

**Purpose**: GitHub operations from command line

**Minimum version**: 2.0

Used for:
- Creating and managing pull requests
- Viewing PR checks
- GitHub Actions management

**Installation**:

**macOS**:
```bash
brew install gh
gh --version
```

**Ubuntu/Debian**:
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh
gh --version
```

**Windows (WSL2)**:
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh
gh --version
```

**Authentication**:
```bash
gh auth login
# Follow prompts to authenticate with GitHub
```

### Linear CLI

**Purpose**: Linear ticket operations from command line

**Minimum version**: Latest

Used for:
- Creating and searching tickets
- Updating ticket status
- Viewing requirement traceability

**Installation**:

**macOS**:
```bash
brew install linear-cli
linear --version
```

**Ubuntu/Debian**:
```bash
# Via npm (requires Node.js)
npm install -g @linear/cli
linear --version
```

**Windows (WSL2)**:
```bash
npm install -g @linear/cli
linear --version
```

**Authentication**:
```bash
linear login
# Follow prompts to authenticate with Linear
```

### Docker Desktop

**Purpose**: Dev container support and containerized environments

**Minimum version**: Docker Engine 24.0+, Docker Compose 2.0+

Required for:
- Dev container development environments
- Running pre-configured development containers
- Building and testing container images

See [Dev Container Setup](#dev-container-setup) below.

### gitleaks

**Purpose**: Secret scanning for git commits

**Minimum version**: 8.18.0

Used by the workflow plugin to prevent accidental secret commits.

**Installation**:

**macOS**:
```bash
brew install gitleaks
gitleaks --version
```

**Ubuntu/Debian**:
```bash
# Download latest release
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks-linux-x64
chmod +x gitleaks-linux-x64
sudo mv gitleaks-linux-x64 /usr/local/bin/gitleaks
gitleaks --version
```

**Windows (WSL2)**:
```bash
# Download latest release
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks-linux-x64
chmod +x gitleaks-linux-x64
sudo mv gitleaks-linux-x64 /usr/local/bin/gitleaks
gitleaks --version
```

**Verification**:
```bash
gitleaks --version  # Should be 8.18.0 or higher
```

### Doppler CLI

**Purpose**: Secret management and environment variable handling

**Minimum version**: Latest

Used for:
- Accessing secrets stored in Doppler
- Running commands with injected secrets
- Environment-specific configuration

**Installation**:

**macOS**:
```bash
brew install doppler/cli/doppler
doppler --version
```

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install -y doppler
doppler --version
```

**Windows (WSL2)**:
```bash
sudo apt-get update
sudo apt-get install -y doppler
doppler --version
```

**Authentication**:
```bash
doppler login
# Follow prompts to authenticate with Doppler
```

## Installation Instructions by OS

### macOS (Intel & Apple Silicon)

#### Quick Setup Using Homebrew

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install core tools
brew install git python@3.12 node@20 jq yq gh doppler gitleaks

# Verify installations
git --version
python3 --version
node --version
npm --version
jq --version
yq --version
gh --version
doppler --version
gitleaks --version
```

#### Manual Setup

Follow the individual tool sections above.

### Linux (Ubuntu 22.04 / 24.04 LTS)

#### Quick Setup Using apt

```bash
# Update package lists
sudo apt-get update

# Install core tools
sudo apt-get install -y \
  git \
  python3 \
  python3-pip \
  python3-venv \
  nodejs \
  npm \
  jq

# Install yq (from PPA)
sudo add-apt-repository ppa:rmescandon/yq -y
sudo apt-get update
sudo apt-get install -y yq

# Install gh (GitHub CLI)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh

# Install gitleaks
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks-linux-x64
chmod +x gitleaks-linux-x64
sudo mv gitleaks-linux-x64 /usr/local/bin/gitleaks

# Verify installations
git --version
python3 --version
node --version
npm --version
jq --version
yq --version
gh --version
gitleaks --version
```

### Windows (WSL2 - Ubuntu 22.04 / 24.04)

#### Setup WSL2

```bash
# In PowerShell (Admin)
wsl --install
wsl --set-default-version 2
```

#### Install Tools in WSL2 Ubuntu

Follow the Linux installation steps above.

#### VS Code Integration

```bash
# In WSL2 terminal
code .
```

This opens VS Code connected to your WSL2 instance.

## Dev Container Setup

The project includes pre-configured dev containers with all tools pre-installed and properly configured.

### Prerequisites

1. **Docker Desktop** (or equivalent Docker+Compose setup)
   - macOS: [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
   - Windows: [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
   - Linux: [Docker Engine + Docker Compose](https://docs.docker.com/engine/install/)

2. **VS Code** with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Setup Steps

1. **Clone or open the repository**:
   ```bash
   git clone https://github.com/yourorg/clinical-diary.git
   cd clinical-diary
   ```

2. **Open in VS Code**:
   ```bash
   code .
   ```

3. **Reopen in Container**:
   - Press `Cmd/Ctrl + Shift + P`
   - Type: "Dev Containers: Reopen in Container"
   - Select "Clinical Diary - Developer (Default)" or your preferred role

4. **Wait for container to build and start**
   - First build may take 2-3 minutes
   - Subsequent starts are faster

5. **Verify setup**:
   ```bash
   flutter --version  # If Flutter dev environment
   git config core.hooksPath  # Should show: .githooks
   ```

### What's Included in Dev Container

The dev container includes:
- All core tools (Git, Python, Node.js, jq, yq)
- Flutter SDK (dev role)
- Docker (for running nested containers)
- VS Code extensions pre-configured
- Git hooks enabled
- Doppler CLI configured (requires DOPPLER_TOKEN)

### Container Roles

Different container configurations for different roles:

- **dev** (default): Flutter development, full tool suite
- **qa**: QA/testing tools
- **ops**: Operations/deployment tools
- **mgmt**: Management/monitoring tools

### Using Multiple Containers

You can work with different roles in parallel:

```bash
# Terminal 1: Dev container for coding
code diary-dev/

# Terminal 2: Ops container for deployment
code diary-ops/
```

Each can be in its own dev container with role-specific tools.

## Environment Variables

### Required Variables

#### DOPPLER_TOKEN

Used to authenticate with Doppler for secret management.

**Obtain token**:
1. Go to [Doppler Dashboard](https://dashboard.doppler.com)
2. Navigate to Settings → Tokens
3. Create a service token for your project/config
4. Copy the token

**Set in environment**:

**Permanently (shell config)**:
```bash
# macOS/Linux ~/.zshrc or ~/.bash_profile
echo 'export DOPPLER_TOKEN="dp_live_xxxxx"' >> ~/.zshrc
source ~/.zshrc
```

**Session only**:
```bash
export DOPPLER_TOKEN="dp_live_xxxxx"
```

**Dev container** (via .devcontainer/devcontainer.json):
- Already configured via Doppler context
- Just run: `doppler login`

**Verification**:
```bash
doppler status
# Should show your project/config
```

### Optional Variables

#### LINEAR_API_TOKEN

Used by Linear API plugin for ticket operations.

**Obtain token**:
1. Go to [Linear Settings → API](https://linear.app/settings/api)
2. Create a new API key
3. Copy the token

**Set in environment**:
```bash
export LINEAR_API_TOKEN="lin_api_xxxxx"
```

**Verification**:
```bash
node tools/anspar-cc-plugins/plugins/linear-api/scripts/test-config.js
```

#### LINEAR_TEAM_ID

Team ID for Linear workspace (auto-discovered if not set).

**Optional unless multiple teams exist**:
```bash
export LINEAR_TEAM_ID="team-xxxxx"
```

#### GitHub Token (for gh CLI)

Set automatically by `gh auth login`.

For automation/CI:
```bash
export GITHUB_TOKEN="ghp_xxxxx"
gh auth status
```

## Verification

### Quick Verification Script

Run this to verify all core tools are installed:

```bash
#!/bin/bash

echo "=== Development Environment Verification ==="
echo

tools=(
  "git:Git version control:2.30"
  "jq:JSON query tool:1.6"
  "python3:Python interpreter:3.8"
  "pip3:Python package manager:20.0"
  "node:Node.js runtime:18.0"
  "npm:Node package manager:9.0"
  "bash:Bash shell:4.0"
)

failed=0

for tool_check in "${tools[@]}"; do
  IFS=':' read -r cmd name min_version <<< "$tool_check"

  if command -v "$cmd" &> /dev/null; then
    version=$($cmd --version 2>&1 | head -n 1)
    echo "✅ $name: $version"
  else
    echo "❌ $name: NOT INSTALLED (required >= $min_version)"
    failed=$((failed + 1))
  fi
done

# Optional tools
optional_tools=(
  "gh:GitHub CLI"
  "linear:Linear CLI"
  "yq:YAML query tool"
  "doppler:Doppler CLI"
  "gitleaks:Secret scanner"
)

echo
echo "=== Optional Tools ==="
for tool_check in "${optional_tools[@]}"; do
  IFS=':' read -r cmd name <<< "$tool_check"

  if command -v "$cmd" &> /dev/null; then
    version=$($cmd --version 2>&1 | head -n 1)
    echo "✅ $name: $version"
  else
    echo "⚠️  $name: Not installed (optional)"
  fi
done

echo
if [ $failed -eq 0 ]; then
  echo "✅ All required tools installed!"
  exit 0
else
  echo "❌ $failed required tool(s) missing"
  exit 1
fi
```

### Manual Verification

```bash
# Git
git --version                    # Should be 2.30+
git config user.name            # Should show configured name

# Python
python3 --version               # Should be 3.8+
pip3 --version                  # Should be 20.0+
python3 -m venv test && rm -rf test  # Test venv creation

# Node.js
node --version                  # Should be 18.0+
npm --version                   # Should be 9.0+
npm list -g                     # List global packages

# jq
jq --version                    # Should be 1.6+
echo '{"test": 1}' | jq .test   # Should output: 1

# Bash
bash --version                  # Should be 4.0+

# Optional tools
gh --version                    # If installed
linear --version                # If installed
yq --version                    # If installed
doppler --version               # If installed
gitleaks --version              # Should be 8.18.0+
```

### Testing Requirement Tools

```bash
# Validate requirements
python3 tools/requirements/validate_requirements.py

# Generate traceability matrix
python3 tools/requirements/generate_traceability.py --format both
```

## Common Issues and Solutions

### jq command not found

**Problem**: Workflow plugin fails with "jq: command not found"

**Solution**:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install -y jq

# Verify
jq --version
```

### Node version mismatch

**Problem**: npm or Node tools fail with version errors

**Solution**:
```bash
# Check current version
node --version
npm --version

# If too old, upgrade
# macOS
brew upgrade node@20

# Ubuntu/Debian (using nvm)
nvm install 20
nvm use 20

# Verify
node --version  # Should be 18.0+
```

### Python not found

**Problem**: Scripts fail with "python3: command not found"

**Solution**:
```bash
# macOS
brew install python@3.12

# Ubuntu/Debian
sudo apt-get install -y python3 python3-pip

# Verify
python3 --version
pip3 --version
```

### Git hooks not running

**Problem**: Commits allowed without REQ references or active tickets

**Solution**:
```bash
# Verify git hooks path is configured
git config core.hooksPath

# Should show: .githooks

# If not set:
git config core.hooksPath .githooks

# Verify hook files are executable
ls -la .githooks/
chmod +x .githooks/*

# Test by attempting commit without ticket
cd tools/anspar-cc-plugins/plugins/workflow
./scripts/claim-ticket.sh TEST-001
cd /path/to/repo
git add README.md
git commit -m "Test"  # Should fail if no REQ reference
```

### Dev container fails to build

**Problem**: VS Code can't build or start container

**Solution**:
```bash
# Rebuild container
# VS Code: Command Palette → "Dev Containers: Rebuild Container"

# Or from terminal:
docker system prune -a  # Clean all images
# Then reopen in container

# Check Docker is running:
docker ps
docker --version
docker compose --version
```

### Docker daemon not running (WSL2)

**Problem**: Docker commands fail in WSL2

**Solution**:
```bash
# In WSL2 Ubuntu terminal:
# Start Docker daemon
sudo service docker start

# Or configure to auto-start:
echo 'sudo service docker start' >> ~/.bashrc
```

### Permission denied errors

**Problem**: Scripts fail with "Permission denied"

**Solution**:
```bash
# Make scripts executable
chmod +x tools/anspar-cc-plugins/plugins/workflow/scripts/*.sh
chmod +x .githooks/*

# Verify
ls -la .githooks/
ls -la tools/anspar-cc-plugins/plugins/workflow/scripts/
```

## References

- **Project CLAUDE.md**: `/CLAUDE.md` - Project-specific instructions
- **Spec Directory**: `spec/README.md` - Requirement structure and format
- **Requirements Format**: `spec/requirements-format.md` - Detailed requirement syntax
- **Workflow Plugin**: `tools/anspar-cc-plugins/plugins/workflow/README.md` - Ticket workflow enforcement
- **Linear API Plugin**: `tools/anspar-cc-plugins/plugins/linear-api/README.md` - Linear integration
- **Requirements Tools**: `tools/requirements/README.md` - Validation and traceability
- **Dev Environment**: `tools/dev-env/docker/base.Dockerfile` - Container tool specifications
- **VS Code Dev Containers**: https://code.visualstudio.com/docs/devcontainers/containers
- **Docker Desktop**: https://www.docker.com/products/docker-desktop
- **GitHub CLI Docs**: https://cli.github.com/manual
- **Linear API Docs**: https://developers.linear.app/docs
- **Doppler Documentation**: https://docs.doppler.com
