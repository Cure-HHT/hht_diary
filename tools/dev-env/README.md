# Development Environment Docker Configuration

**See**: [Setup: Development Environment](../../docs/setup-dev-environment.md) for complete setup instructions and usage guide.

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

```bash
# Build environment (first time, takes 15-30 minutes)
./setup.sh

# Validate installation
./validate-environment.sh --full

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
