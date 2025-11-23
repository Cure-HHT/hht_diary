# Development Environment Docker Configuration

**See**: [Setup: Development Environment](../../docs/setup-dev-environment.md) for complete setup instructions and usage guide.

## ⚠️ IMPORTANT: First-Time Setup Required

**Before starting any containers**, you MUST run the setup script to build required Docker images:

```bash
cd tools/dev-env
./setup.sh
```

This builds the base image (`clinical-diary-base:latest`) and role-specific images. Without this step, container startup will fail with:
```
failed to resolve source metadata for docker.io/library/clinical-diary-base:latest:
pull access denied, repository does not exist or may require authorization
```

**Prerequisites checked by setup script**:
- Docker Desktop installed and running
- Node.js 18+ installed
- Doppler CLI installed and authenticated (required for secrets)
- GitHub Container Registry (GHCR) authentication (recommended for faster builds)

## This Directory

This directory contains the Docker Compose configuration and Dockerfiles for the role-based development containers:

- `docker-compose.yml` - Service definitions
- `docker/base.Dockerfile` - Base image with common tools
- `docker/dev.Dockerfile` - Development environment
- `docker/qa.Dockerfile` - QA/testing environment
- `docker/ops.Dockerfile` - Operations environment
- `docker/mgmt.Dockerfile` - Management (read-only) environment

## Scripts

- `setup.sh` - Build and initialize all containers
- `validate-environment.sh` - Validate container health and tools
- `test-local-registry.sh` - Test local Docker registry
- `validate-warnings.sh` - Check for configuration warnings

## Quick Start

### 1. Authenticate with GitHub Container Registry (Recommended)

For faster builds with cached layers:

```bash
# 1. Create GitHub Personal Access Token (PAT):
#    • Go to: https://github.com/settings/tokens/new
#    • Name: "GHCR Access for Clinical Diary"
#    • Expiration: 90 days (or longer)
#    • Scopes: Check "read:packages"
#    • Generate and copy the token

# 2. Store token in Doppler (secure secrets management):
doppler secrets set GITHUB_TOKEN
# Paste your token when prompted (input will be hidden)

# 3. Authenticate Docker with GHCR using Doppler:
doppler run -- bash -c 'echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin'

# 4. Verify authentication:
docker pull ghcr.io/cure-hht/clinical-diary-base:latest
```

**Why Doppler?**
- Tokens are encrypted and centrally managed
- Available across all development environments
- No risk of accidentally committing secrets to git
- Easy rotation and revocation

### 2. Run Setup Script

```bash
# Build environment (first time, takes 5-15 minutes with GHCR, 15-30 without)
./setup.sh

# Validate installation
./validate-environment.sh --full
```

### 3. Start Development Container

```bash
# Start development container
docker compose up -d dev

# Enter container
docker compose exec dev bash

# Or use VS Code Dev Containers extension
# F1 → "Dev Containers: Reopen in Container"
```

## Architecture

See [Development Environment Architecture](../../docs/setup-dev-environment-architecture.md) for detailed architecture documentation.

## Maintenance

See [Dev Environment Maintenance](../../docs/ops-dev-environment-maintenance.md) for maintenance procedures.

## Troubleshooting

See the [Troubleshooting](../../docs/setup-dev-environment.md#7-troubleshooting) section in the main setup guide for common issues and solutions.
