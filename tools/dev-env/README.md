# Clinical Diary Development Environment

Docker-based development environment with role-separated containers for FDA-compliant clinical trial software.

## Prerequisites

1. **Docker Desktop** (or Docker Engine on Linux)
   - Windows/Mac: https://www.docker.com/products/docker-desktop
   - Linux: https://docs.docker.com/engine/install/

2. **VS Code** (optional, recommended)
   - Extension: Dev Containers (ms-vscode-remote.remote-containers)

## Quick Start

```bash
cd tools/dev-env
./setup.sh
```

First run takes 15-30 minutes (downloads and builds images).

## Daily Usage

### Method 1: VS Code (Recommended)

1. Open project in VS Code
2. Press `F1` → "Dev Containers: Reopen in Container"
3. Select role: Developer, QA, DevOps, or Management
4. VS Code reopens inside container

### Method 2: Command Line

```bash
# Start container
docker compose up -d dev

# Enter container
docker compose exec dev bash

# Stop container
docker compose stop dev
```

## Roles

| Role | Container | Tools | Use Case |
|------|-----------|-------|----------|
| Developer | `dev` | Flutter, Android SDK, Node, Python | Build mobile app |
| QA | `qa` | Playwright, test frameworks | Run automated tests |
| DevOps | `ops` | Terraform, Supabase CLI, Cosign, Syft | Deploy infrastructure |
| Management | `mgmt` | Git (read-only), report viewers | View status |

## Role Switching

### VS Code
1. `F1` → "Dev Containers: Reopen in Container"
2. Select different role

### Command Line
```bash
docker compose stop dev
docker compose up -d qa
docker compose exec qa bash
```

## Common Commands

```bash
# Start all containers
docker compose up -d

# Start specific role
docker compose up -d dev

# Enter container
docker compose exec dev bash

# View logs
docker compose logs dev

# Stop all containers
docker compose down

# Rebuild images
./setup.sh --rebuild

# Run validation
./validate-environment.sh --full
```

## Secrets Management (Doppler)

Inside any container:

```bash
# One-time setup
doppler login
doppler setup --project clinical-diary-dev --config dev

# Use secrets with commands
doppler run -- gh auth login
doppler run -- flutter build

# Or get shell with secrets
doppler run -- bash
```

See TODO.md for Doppler account setup.

## File Locations

### Host Machine
```
tools/dev-env/
├── docker/               # Dockerfiles
├── docker-compose.yml    # Container orchestration
├── setup.sh              # Setup script
└── README.md             # This file
```

### Inside Containers
```
/workspace/
├── repos/                # Git repositories (persisted)
├── exchange/             # Share files between roles
├── src/                  # Source code (bind mount)
└── reports/              # Test reports (QA only)
```

## Troubleshooting

### Docker Daemon Not Running
```bash
# Windows/Mac: Open Docker Desktop
# Linux:
sudo systemctl start docker
```

### Permission Denied
```bash
# Linux only
sudo usermod -aG docker $USER
newgrp docker
```

### Image Build Fails
```bash
# Clear cache and rebuild
docker builder prune
./setup.sh --rebuild
```

### Container Won't Start
```bash
# Check logs
docker compose logs dev

# Remove and recreate
docker compose down
docker compose up -d
```

### Flutter Command Not Found
You're in the wrong container. Flutter is only in `dev` and `qa` containers.

```bash
# Check which container
docker compose exec dev flutter --version  # Should work
docker compose exec ops flutter --version  # Won't work
```

## Platform Notes

### Windows (WSL2)
- Use WSL2 terminal for better performance
- Files in `/home/ubuntu/repos` faster than Windows filesystem

### macOS (Apple Silicon)
- Docker Desktop supports ARM64
- Some tools may be x86 only (handled automatically)

### Linux
- Native Docker performance (fastest)
- No VM overhead

## CI/CD Integration

GitHub Actions workflows use these same Docker images:
- `.github/workflows/qa-automation.yml` - Automated testing
- `.github/workflows/build-publish-images.yml` - Image builds

## File System

### Named Volumes (Persist Data)
- `clinical-diary-repos` - Git repositories
- `clinical-diary-exchange` - File sharing
- `qa-reports` - Test reports

### Bind Mounts (Direct Access)
- `/workspace/src` → Project root
- `/home/ubuntu/.ssh` → Your SSH keys (read-only)
- `/home/ubuntu/.gitconfig.host` → Your git config (read-only)

## Git Configuration

Each role has a default identity:
- dev: "Developer <dev@clinical-diary.local>"
- qa: "QA Automation Bot <qa@clinical-diary.local>"
- ops: "DevOps Engineer <ops@clinical-diary.local>"
- mgmt: "Manager <mgmt@clinical-diary.local>"

To use your personal identity:
```bash
git config --global include.path /home/ubuntu/.gitconfig.host
```

## Health Checks

```bash
# Check container status
docker compose ps

# Run health check manually
docker compose exec dev /usr/local/bin/health-check.sh
```

## Cleanup

```bash
# Stop containers (data persists)
docker compose down

# Remove containers and volumes (⚠️ data loss)
docker compose down -v

# Remove unused images
docker image prune -a
```

## Additional Resources

- Setup checklist: TODO.md
- Maintenance schedule: README-MAINTENANCE.md
- Architecture: ../../docs/dev-environment-architecture.md
- ADR: ../../docs/adr/ADR-006-docker-dev-environments.md
- Validation: ../../docs/validation/dev-environment/

## Support

- GitHub Issues: Project repository
- Internal Docs: `/workspace/src/docs/`
- Validation Protocols: `/workspace/src/docs/validation/`
