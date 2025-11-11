# Development Environment Setup TODO

## Before First Use

### Install Docker
- [ ] Install Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- [ ] Verify: `docker --version` and `docker compose version`
- [ ] Start Docker daemon
- [ ] Linux only: Add user to docker group: `sudo usermod -aG docker $USER`

### Build Environment
- [ ] Navigate to `tools/dev-env`
- [ ] Run `./setup.sh`
- [ ] Wait 15-30 minutes for first build
- [ ] Run `./validate-environment.sh --full`
- [ ] Verify all tests pass

### Set Up Doppler (Secrets Management)
- [ ] Create Doppler account: https://doppler.com/
- [ ] Create project: `clinical-diary-dev`
- [ ] Create configs: `dev`, `qa`, `ops`, `staging`, `prod`
- [ ] Add secrets (see "Required Secrets" below)
- [ ] Test in container: `doppler login && doppler setup`

### Configure GitHub
- [ ] Verify GitHub organization exists
- [ ] Enable GitHub Container Registry (GHCR)
- [ ] Configure branch protection on `main`
- [ ] Add GitHub Actions secrets:
  - `DOPPLER_TOKEN_DEV` - Doppler service token
- [ ] Test CI/CD with a demo PR

### Optional: VS Code Setup
- [ ] Install VS Code
- [ ] Install extension: Dev Containers (ms-vscode-remote.remote-containers)
- [ ] Test: F1 → "Dev Containers: Reopen in Container"

## Required Secrets (Add to Doppler)

### GitHub Personal Access Tokens
Generate at: https://github.com/settings/tokens

- `GH_TOKEN_DEV` - Scopes: `repo`, `read:org`
- `GH_TOKEN_QA` - Scopes: `repo`, `checks:write`, `pull_requests:write`
- `GH_TOKEN_OPS` - Scopes: `workflow`, `repo_deployment`, `packages:write`
- `GH_TOKEN_MGMT` - Scopes: `read:org`, `read:repo_hook` (read-only)

### Supabase
From: Supabase Dashboard → Settings

- `SUPABASE_SERVICE_TOKEN` - API → service_role key
- `SUPABASE_PROJECT_REF` - General → Reference ID

### Optional
- `ANTHROPIC_API_KEY` - For Claude Code integration: https://console.anthropic.com/

## Not Yet Working / Requires Manual Setup

### Set Up Supabase
- [ ] Create Supabase project (or use existing)
- [ ] Note project reference ID (16 characters)
- [ ] Get service role key from Dashboard → Settings → API
- [ ] Add to Doppler: `SUPABASE_PROJECT_REF` and `SUPABASE_SERVICE_TOKEN`
- [ ] Test connection from ops container: `doppler run -- supabase link`

### Platform Testing
- [ ] Test on your primary platform (Linux/Mac/Windows WSL2)
- [ ] Document platform-specific issues
- [ ] If team uses multiple platforms, test on each

### Doppler Integration
**Status**: Framework in place, requires account configuration

**Actions Needed**:
1. Create Doppler account and project
2. Add all secrets listed above
3. Generate service token for CI/CD
4. Test in all 4 container roles

**Timeline**: 1-2 hours

### GitHub Actions Secrets
**Status**: Workflows exist, need org-level configuration

**Actions Needed**:
1. Add `DOPPLER_TOKEN_DEV` to repository secrets
2. Verify GitHub Container Registry is enabled
3. Test workflows with demo PR
4. Verify image signing (Cosign) works

**Timeline**: 30 minutes

### Supabase Connection
**Status**: CLI installed, needs project configuration

**Actions Needed**:
1. Create Supabase project (if not exists)
2. Add credentials to Doppler
3. Test link from ops container
4. Run database migrations if needed

**Timeline**: 30 minutes (if project exists)

### Platform Testing
**Status**: Tested on [ADD YOUR PLATFORM], needs broader testing

**Actions Needed**:
1. Test on Linux (if team uses)
2. Test on macOS (if team uses)
3. Test on Windows WSL2 (if team uses)
4. Document platform-specific issues in README

**Timeline**: 1 hour per platform

### FDA Validation Protocols
**Status**: Documentation exists, needs execution

**Actions Needed**:
1. Execute IQ protocol: `docs/validation/dev-environment/IQ.md`
2. Execute OQ protocol: `docs/validation/dev-environment/OQ.md`
3. Schedule 7-day PQ protocol: `docs/validation/dev-environment/PQ.md`
4. Document results

**Timeline**: IQ/OQ 1 day, PQ 7 days

### Documentation Updates
**Status**: Generic templates, need org-specific values

**Actions Needed**:
1. Replace `yourorg` with actual GitHub org name (global find/replace)
2. Update `clinical-diary-dev` if using different Doppler project name
3. Add platform-specific notes based on testing
4. Create team onboarding checklist

**Timeline**: 1 hour

## Alternatives to Consider

### GitHub Codespaces vs Local Development

**GitHub Codespaces**:
- **What**: Cloud-hosted VS Code environment (uses same Dev Container configs)
- **Cost**: ~$300-600/month for 3-person team (full-time usage)
- **Free Tier**: 120 core-hours/month per user (~60 hours on 2-core machine)
- **Pros**:
  - Zero local setup
  - Work from anywhere (even iPad)
  - Consistent environments for entire team
  - Fast onboarding (5 minutes vs 2 hours)
- **Cons**:
  - Requires internet connection
  - Monthly cost
  - Data stored on GitHub servers
- **Recommendation**: Try free tier first, evaluate after 1 week

**Local Development** (Current Setup):
- **Cost**: Free (but need Docker-capable machine)
- **Pros**:
  - No ongoing costs
  - Works offline
  - Full control
- **Cons**:
  - Local setup required (1-2 hours)
  - Platform-specific issues possible
  - Need capable hardware

**Hybrid Approach**:
Since Dev Container configs work identically in both environments, team members can choose based on preference. Switch anytime.

**How to Enable Codespaces**:
1. GitHub org settings → Enable Codespaces
2. Set spending limit (e.g., $100/month)
3. Navigate to repo → Code → Codespaces → Create codespace
4. Choose role (uses existing `.devcontainer/` configs)
5. Wait ~2 minutes first time, ~30 seconds after

## Quick Reference

### First-Time Setup Flow
```bash
# 1. Install Docker
# 2. Clone repo
cd tools/dev-env

# 3. Build environment
./setup.sh

# 4. Validate
./validate-environment.sh --full

# 5. Set up Doppler (see checklist above)
docker compose exec dev bash
doppler login
doppler setup --project clinical-diary-dev --config dev

# 6. Configure GitHub auth
doppler run -- gh auth login

# 7. Start working
cd /workspace/repos
doppler run -- gh repo clone yourorg/clinical-diary
```

### Daily Commands After Setup
```bash
# Start environment
docker compose up -d dev

# Enter container (or use VS Code)
docker compose exec dev bash

# Work with secrets
doppler run -- bash

# Stop when done
docker compose down
```

## Next Steps After Completing Checklist

1. **Team Onboarding**: Schedule training session, demonstrate environment
2. **Production Use**: Begin using for daily development work
3. **Continuous Validation**: Run PQ protocol over 7 days
4. **Maintenance**: Set quarterly review reminders (see README-MAINTENANCE.md)
5. **Iterate**: Gather feedback, adjust resource limits, optimize

## Questions or Issues?

- Check README.md troubleshooting section
- Review validation docs: `docs/validation/dev-environment/`
- Check Docker logs: `docker compose logs dev`
- Run validation: `./validate-environment.sh --full`
