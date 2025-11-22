# Dev Container Setup

## ⚠️ CRITICAL: First-Time Setup Required

**DO NOT** open this project in a Dev Container until you have completed the setup steps below.

### Why This Is Required

The dev containers depend on pre-built base Docker images that must be created on your local machine first. Without these images, VS Code will fail with:

```
failed to resolve source metadata for docker.io/library/clinical-diary-base:latest:
pull access denied, repository does not exist or may require authorization
```

This error is misleading - it's not a permissions issue. The base image simply doesn't exist yet.

### First-Time Setup (Required)

**1. Close VS Code** (if it's open)

**2. Install prerequisites:**
- Docker Desktop (must be running)
- Node.js 18+
- Doppler CLI (for secrets management)

**3. Authenticate with Doppler:**
```bash
doppler login
```

**4. (Optional but Recommended) Authenticate with GitHub Container Registry:**

This enables faster builds by pulling cached layers:

```bash
# Create GitHub PAT at: https://github.com/settings/tokens/new
# Scopes: read:packages only
# Expiration: 90 days

# Store in Doppler:
doppler secrets set GITHUB_TOKEN

# Authenticate Docker:
doppler run -- bash -c 'echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin'
```

**5. Run the setup script:**
```bash
cd tools/dev-env
./setup.sh
```

This will:
- Check all prerequisites (Docker, Node.js, Doppler, GHCR)
- Build `clinical-diary-base:latest` (5-15 minutes)
- Build all role-specific images (dev, qa, ops, mgmt)
- Validate the installation

**6. NOW you can open in Dev Container:**
- Open project in VS Code
- Click "Reopen in Container" when prompted
- Or: Cmd/Ctrl+Shift+P → "Dev Containers: Reopen in Container"

## Available Dev Container Configurations

This project has multiple dev container configurations for different roles:

### Default (Developer)
- **File**: `.devcontainer/devcontainer.json`
- **Container**: `dev`
- **Tools**: Flutter, Android SDK, Node.js, Python, Git
- **Use case**: Application development

### QA/Testing
- **File**: `.devcontainer/qa/devcontainer.json`
- **Container**: `qa`
- **Tools**: Playwright, testing frameworks, Flutter
- **Use case**: Test automation, QA workflows

### Operations
- **File**: `.devcontainer/ops/devcontainer.json`
- **Container**: `ops`
- **Tools**: Terraform, Kubernetes, deployment tools
- **Use case**: Infrastructure, deployments, DevOps

### Management
- **File**: `.devcontainer/mgmt/devcontainer.json`
- **Container**: `mgmt`
- **Tools**: Read-only access, reporting tools
- **Use case**: Project oversight, reports, audits

## Switching Between Containers

If you need to switch roles:

1. Close current dev container
2. Select different devcontainer.json file
3. Reopen in container

Or use the command palette:
- Cmd/Ctrl+Shift+P → "Dev Containers: Reopen in Container"
- Choose from available configurations

## Troubleshooting

### Error: "failed to resolve source metadata for clinical-diary-base"

**Cause**: Base image not built locally yet.

**Solution**: Exit VS Code and run `tools/dev-env/setup.sh` first.

### Error: "Doppler not configured"

**Cause**: Doppler CLI not authenticated.

**Solution**:
```bash
doppler login
doppler whoami  # Verify authentication
```

### Error: "Build takes 30+ minutes"

**Cause**: No GHCR authentication, building without cache.

**Solution**: Set up GHCR authentication (see step 4 above).

### Error: "Container won't start"

**Cause**: Secrets not available or Docker issues.

**Solutions**:
1. Verify Doppler: `doppler whoami`
2. Check Docker: `docker ps`
3. Rebuild container: "Dev Containers: Rebuild Container"

## Post-Setup Notes

### Git Hooks

Git hooks are automatically enabled via `postCreateCommand` in devcontainer.json:
```bash
git config core.hooksPath .githooks
```

These hooks enforce:
- Requirement references in commits (REQ-xxxxx)
- Secret scanning (gitleaks)
- Markdown linting

### Environment Variables

Environment variables are injected from Doppler:
- `DOPPLER_PROJECT`: Set per container role
- `DOPPLER_CONFIG`: Set per container role
- Secrets available: `LINEAR_API_TOKEN`, etc.

### Updating Containers

When Dockerfiles or docker-compose.yml change:

1. Rebuild container: Cmd/Ctrl+Shift+P → "Dev Containers: Rebuild Container"
2. Or from terminal: `docker compose build <role>`

## Documentation

- **Setup Guide**: `docs/setup-dev-environment.md`
- **Architecture**: `docs/setup-dev-environment-architecture.md`
- **Prerequisites**: `docs/development-prerequisites.md`
- **Docker Config**: `tools/dev-env/README.md`

## Security Notes

- **Never commit secrets** (Doppler handles this)
- **GitHub PAT** stored in Doppler, not in files
- **SSH keys** mounted read-only from host
- **Git config** mounted read-only from host

## Getting Help

If you encounter issues not covered here:

1. Check `tools/dev-env/README.md` for detailed setup
2. Run `tools/dev-env/validate-environment.sh --full`
3. Check Linear ticket: CUR-327 for common issues
4. Ask in team chat with error details
