# Clinical Diary Development Environment

**Version**: 1.0.0
**Status**: Active
**Requirements**: REQ-d00027 through REQ-d00036

This directory contains the Docker-based development environment for the Clinical Diary project, providing role-separated containerized workspaces that enforce security boundaries and maintain dev/prod parity.

---

## Quick Start

### Prerequisites

1. **Docker Desktop** (Windows/Mac) or **Docker Engine** (Linux)
   - Windows: https://www.docker.com/products/docker-desktop
   - Mac: https://www.docker.com/products/docker-desktop
   - Linux: https://docs.docker.com/engine/install/

2. **VS Code** (recommended but optional)
   - Download: https://code.visualstudio.com/
   - Extension: Dev Containers (ms-vscode-remote.remote-containers)

3. **Doppler Account** (for secrets management)
   - Sign up: https://doppler.com/
   - See: [doppler-setup.md](doppler-setup.md)

### First-Time Setup

```bash
# Navigate to this directory
cd tools/dev-env

# Run interactive setup
./setup.sh

# Or build specific role
./setup.sh --role dev
```

The script will:
- ✅ Detect your platform (Windows/Linux/macOS)
- ✅ Verify Docker installation
- ✅ Build all Docker images
- ✅ Create necessary volumes
- ✅ Optionally start a container

**Estimated time**: 15-30 minutes (first run, includes downloads)

---

## Architecture Overview

```
Four Role-Based Containers:
├── dev   - Developer (Flutter, Android SDK, full tools)
├── qa    - QA/Testing (Playwright, test frameworks)
├── ops   - DevOps (Terraform, Supabase CLI, deployment)
└── mgmt  - Management (read-only access, audit tools)

Shared Resources:
├── clinical-diary-repos     - Git repositories
├── clinical-diary-exchange  - File sharing between roles
└── qa-reports               - Test reports and artifacts
```

See: [../../docs/dev-environment-architecture.md](../../docs/dev-environment-architecture.md)

---

## Usage

### Method 1: VS Code Dev Containers (Recommended)

1. Open project in VS Code
2. Press `F1` → "Dev Containers: Reopen in Container"
3. Select role:
   - `Clinical Diary - Developer`
   - `Clinical Diary - QA`
   - `Clinical Diary - DevOps`
   - `Clinical Diary - Management (Read-Only)`

4. VS Code reopens inside container with role-specific tools

**Benefits**:
- One-click environment switching
- Extensions auto-installed
- Integrated terminal
- Port forwarding automatic

### Method 2: Docker Compose (Command Line)

```bash
# Start container
docker compose up -d dev

# Enter container
docker compose exec dev bash

# Stop container
docker compose stop dev

# Remove container (data in volumes persists)
docker compose down
```

### Method 3: Docker CLI (Advanced)

```bash
# Run specific role
docker run -it --rm \
  -v $(pwd):/workspace/src \
  -v clinical-diary-repos:/workspace/repos \
  clinical-diary-dev:latest bash
```

---

## Role-Specific Guides

### Developer Role

**Tools**: Flutter, Android SDK, Node.js, Python, Supabase CLI

```bash
# Enter dev container
docker compose exec dev bash

# Setup Doppler
doppler login
doppler setup --project clinical-diary-dev --config dev

# Authenticate GitHub
doppler run -- gh auth login

# Clone repository
gh repo clone yourorg/clinical-diary ~/repos/clinical-diary

# Navigate and develop
cd /workspace/repos/clinical-diary

# Run Flutter app
flutter pub get
flutter run

# Hot reload works automatically
```

**Common Tasks**:
- Develop Flutter mobile app
- Write and test Dart code
- Run local Supabase instance
- Create feature branches
- Push commits

### QA Role

**Tools**: Playwright, Flutter test framework, report generators

```bash
# Enter QA container
docker compose exec qa bash

# Setup Doppler
doppler login
doppler setup --project clinical-diary-dev --config dev

# Run automated tests
cd /workspace/repos/clinical-diary
qa-runner.sh

# Run specific test suites
flutter test integration_test/
npx playwright test

# View reports
ls /workspace/reports/
```

**Common Tasks**:
- Run Flutter integration tests
- Execute Playwright E2E tests
- Generate test reports
- Post results to GitHub PRs
- Review test coverage

### DevOps Role

**Tools**: Terraform, Supabase CLI, kubectl, AWS CLI, Cosign, Syft

```bash
# Enter ops container
docker compose exec ops bash

# Setup Doppler
doppler login
doppler setup --project clinical-diary-dev --config dev

# Deploy infrastructure
cd /workspace/repos/clinical-diary/infrastructure
doppler run -- terraform init
doppler run -- terraform plan
doppler run -- terraform apply

# Database migrations
doppler run -- supabase db push

# Sign container images
cosign sign --key <key> clinical-diary-dev:1.0.0

# Generate SBOM
syft packages docker:clinical-diary-dev:latest
```

**Common Tasks**:
- Deploy infrastructure with Terraform
- Manage Supabase databases
- Build and sign Docker images
- Generate SBOMs for compliance
- Deploy to staging/production

### Management Role

**Tools**: Git (read-only), GitHub CLI (read-only), report viewers

```bash
# Enter mgmt container
docker compose exec mgmt bash

# View repository status
view-repo-status.sh

# View QA reports
view-qa-reports.sh

# Check PR status
gh pr list

# View commit history
cd /workspace/repos/clinical-diary
git log --oneline --graph

# Read documentation
cat /workspace/src/docs/adr/ADR-006-docker-dev-environments.md
```

**Common Tasks**:
- Review code changes
- Read audit trails
- View test reports
- Monitor project status
- Generate management reports

---

## Switching Between Roles

### VS Code Method

1. Command Palette (`F1`)
2. "Dev Containers: Reopen in Container"
3. Select different role

### Command Line Method

```bash
# Stop current role
docker compose stop dev

# Start different role
docker compose up -d qa
docker compose exec qa bash
```

### Run Multiple Roles Simultaneously

```bash
# Start all roles
docker compose up -d

# Access different terminals
docker compose exec dev bash    # Terminal 1
docker compose exec qa bash     # Terminal 2
docker compose exec ops bash    # Terminal 3
```

---

## Doppler Secrets Management

**Required Setup**: See [doppler-setup.md](doppler-setup.md)

### Quick Setup

```bash
# Inside any container
doppler login

# Configure project
doppler setup --project clinical-diary-dev --config dev

# Use secrets with commands
doppler run -- gh auth login
doppler run -- flutter build

# Or get entire shell with secrets
doppler run -- bash
```

### Secrets to Configure

- `GH_TOKEN_DEV` - GitHub token for dev role
- `GH_TOKEN_QA` - GitHub token for QA role
- `GH_TOKEN_OPS` - GitHub token for ops role
- `GH_TOKEN_MGMT` - GitHub token for mgmt role (read-only)
- `SUPABASE_SERVICE_TOKEN` - Supabase service role key
- `SUPABASE_PROJECT_REF` - Supabase project reference ID
- `ANTHROPIC_API_KEY` - Claude API key (optional)

---

## File System Layout

### Host Machine

```
project-root/
├── .devcontainer/          # VS Code Dev Container configs
│   ├── dev/
│   ├── qa/
│   ├── ops/
│   └── mgmt/
├── tools/dev-env/          # Docker environment (this directory)
│   ├── docker/
│   │   ├── base.Dockerfile
│   │   ├── dev.Dockerfile
│   │   ├── qa.Dockerfile
│   │   ├── ops.Dockerfile
│   │   └── mgmt.Dockerfile
│   ├── docker-compose.yml
│   ├── setup.sh
│   ├── README.md
│   └── doppler-setup.md
├── src/                    # Source code (bind-mounted)
├── database/               # Database schemas
└── docs/                   # Documentation
```

### Inside Containers

```
/workspace/
├── repos/                  # Git repositories (named volume)
│   └── clinical-diary/
├── exchange/               # File sharing between roles
├── src/                    # Bind mount from host
└── reports/                # QA test reports (qa container only)

/home/ubuntu/
├── .gitconfig              # Role-specific Git config
├── .ssh/                   # SSH keys (mounted from host)
└── .config/
    ├── gh/                 # GitHub CLI auth
    └── doppler/            # Doppler config
```

---

## Common Tasks

### Update Docker Images

```bash
# Rebuild all images
cd tools/dev-env
./setup.sh --rebuild

# Rebuild specific role
docker compose build dev

# Pull latest base OS
docker pull ubuntu:24.04
./setup.sh --rebuild
```

### View Container Logs

```bash
# All services
docker compose logs

# Specific service
docker compose logs dev

# Follow logs
docker compose logs -f qa
```

### Clean Up

```bash
# Stop all containers
docker compose down

# Remove containers and networks (volumes persist)
docker compose down

# Remove everything including volumes (⚠️ data loss)
docker compose down -v

# Remove unused images
docker image prune -a
```

### Health Checks

```bash
# Check container health
docker compose ps

# Run health check manually
docker compose exec dev /usr/local/bin/health-check.sh
```

---

## Troubleshooting

### Docker Daemon Not Running

```
Error: Cannot connect to the Docker daemon
```

**Fix**: Start Docker Desktop or Docker service

- Windows/Mac: Open Docker Desktop
- Linux: `sudo systemctl start docker`

### Permission Denied

```
Error: Got permission denied while trying to connect to the Docker daemon
```

**Fix**:

- Linux: Add user to docker group
  ```bash
  sudo usermod -aG docker $USER
  newgrp docker
  ```
- Windows/Mac: Docker Desktop should handle this

### Image Build Fails

```
Error: failed to solve with frontend dockerfile.v0
```

**Fix**:

1. Check internet connection
2. Clear Docker build cache: `docker builder prune`
3. Rebuild: `./setup.sh --rebuild`

### Container Won't Start

```
Error: container exited with code 1
```

**Fix**:

1. Check logs: `docker compose logs <role>`
2. Verify volumes: `docker volume ls`
3. Remove and recreate: `docker compose down && docker compose up -d`

### Flutter Command Not Found

```
bash: flutter: command not found
```

**Fix**:

1. Verify you're in dev or qa container (not ops/mgmt)
2. Check PATH: `echo $PATH | grep flutter`
3. Rebuild image: `docker compose build dev`

### Doppler Authentication Fails

```
Error: You are not logged in
```

**Fix**:

1. Login: `doppler login`
2. Setup project: `doppler setup --project clinical-diary-dev --config dev`
3. Verify: `doppler me`

### Volume Permission Issues

```
Error: permission denied
```

**Fix**:

- Named volumes: `docker volume rm <volume-name>` then recreate
- Bind mounts: Check host file permissions

---

## CI/CD Integration

These Docker images are used in GitHub Actions:

```.github/workflows/qa-automation.yml
- Uses qa-container for automated testing
- Same tools locally and in CI
- Guarantees environment parity
```

See: [../../.github/workflows/](../../.github/workflows/)

---

## Performance Tips

### Speed Up Builds

```bash
# Use Docker layer caching
docker compose build

# Build in parallel
docker compose build --parallel

# Use BuildKit
export DOCKER_BUILDKIT=1
docker compose build
```

### Reduce Resource Usage

Edit `docker-compose.yml` resource limits:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'      # Reduce from 4
      memory: 4G     # Reduce from 6G
```

### Cache Optimization

```bash
# Share package cache between builds (add to docker-compose.yml)
volumes:
  - npm-cache:/home/ubuntu/.npm
  - pub-cache:/home/ubuntu/.pub-cache
```

---

## Platform-Specific Notes

### Windows (WSL2)

- Docker Desktop uses WSL2 backend
- File performance best with: `/home/ubuntu/repos` (not Windows filesystem)
- Use WSL2 terminal for better performance

### macOS (Apple Silicon)

- Docker Desktop supports ARM64
- Some images may need platform specification:
  ```yaml
  platform: linux/amd64  # For x86-only tools
  ```

### Linux

- Native Docker performance (fastest)
- No VM overhead
- Can use Docker Engine (not just Desktop)

---

## Validation & Compliance

**FDA 21 CFR Part 11 Compliance**:

- ✅ Environment specification in Git (Dockerfiles)
- ✅ Image signing with Cosign
- ✅ SBOM generation with Syft
- ✅ Audit trails via Doppler logs
- ✅ Validation protocols (IQ/OQ/PQ)

See: [../../docs/validation/dev-environment/](../../docs/validation/dev-environment/)

---

## Additional Resources

### Documentation

- **Architecture**: [../../docs/dev-environment-architecture.md](../../docs/dev-environment-architecture.md)
- **Requirements**: [../../spec/dev-environment.md](../../spec/dev-environment.md)
- **ADR**: [../../docs/adr/ADR-006-docker-dev-environments.md](../../docs/adr/ADR-006-docker-dev-environments.md)
- **Doppler Setup**: [doppler-setup.md](doppler-setup.md)

### External Links

- Docker Documentation: https://docs.docker.com/
- Dev Containers: https://containers.dev/
- Doppler: https://docs.doppler.com/
- Flutter: https://flutter.dev/
- Playwright: https://playwright.dev/
- Terraform: https://www.terraform.io/

### Support

- Project Issues: GitHub Issues
- Internal Docs: `/workspace/src/docs/`
- Validation Protocols: `/workspace/src/docs/validation/`

---

**Last Updated**: 2025-10-26
**Version**: 1.0.0
**Maintainer**: Clinical Diary Team
