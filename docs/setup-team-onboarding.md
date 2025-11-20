# Clinical Diary Team Onboarding Guide

**Welcome to the Clinical Diary project!** This guide will get you set up and productive in 5-60 minutes depending on your chosen approach.

## REFERENCES REQUIREMENTS

- REQ-d00027: Containerized Development Environments
- REQ-d00055: Role-Based Environment Separation
- REQ-d00058: Secrets Management via Doppler

---

## Choose Your Setup Path

We support two development environments. Choose based on your preference:

| Approach | Setup Time | Best For | Requirements |
| --- | --- | --- | --- |
| **🌐 GitHub Codespaces** | **5 minutes** | Remote work, quick start | GitHub account |
| **💻 Local Dev Containers** | **1-2 hours** | Offline work, full control | Docker Desktop |

**Recommendation for remote team**: Start with Codespaces (you can always switch later).

---

## Path 1: GitHub Codespaces (Recommended) 🌐

### Prerequisites

✅ GitHub account (you'll receive an org invitation)

### Setup Steps

#### 1. Accept GitHub Organization Invitation

Check your email for invitation to the GitHub organization. Click the link and accept.

#### 2. Access the Repository

Navigate to: `https://github.com/yourorg/clinical-diary`

*Note: Replace `yourorg` with actual organization name*

#### 3. Create Your Codespace

1. Click the green **"Code"** button
2. Select the **"Codespaces"** tab
3. Click **"Create codespace on main"**

   **Choose your role**:
   - `Clinical Diary - Developer` ← Most common
   - `Clinical Diary - QA`
   - `Clinical Diary - DevOps`
   - `Clinical Diary - Management (Read-Only)`

4. Wait 2-5 minutes for first launch (subsequent: ~30 seconds)

#### 4. VS Code Opens in Browser

You'll see VS Code running in your browser with:
- ✅ All tools pre-installed (Flutter, Node, Python, etc.)
- ✅ Extensions auto-installed
- ✅ Terminal connected to container
- ✅ Git authentication handled automatically

#### 5. Verify Installation

In the VS Code terminal, run:

```bash
# Check tools
flutter --version
git config user.name  # Should show "Developer"
node --version
python3 --version

# Create test Flutter app
cd /workspace/repos
flutter create hello_test
cd hello_test
flutter pub get
flutter test

# Clean up
cd ..
rm -rf hello_test
```

#### 6. Configure Secrets (One-Time)

**Option A: Organization Secrets (Recommended)**
- Secrets are already configured by admin
- No action needed!

**Option B: Personal Secrets** (if needed)
1. Click your profile → Settings → Codespaces
2. Add secrets:
   - `DOPPLER_TOKEN` (get from team lead)
   - Other secrets as needed

#### 7. Start Coding!

```bash
# Navigate to project
cd /workspace/repos

# Clone if needed (usually not necessary)
# gh repo clone yourorg/clinical-diary

# Work on your branch
git checkout -b feature/my-feature

# Make changes, commit, push
git add .
git commit -m "My changes"
git push
```

**Total Time**: ~5 minutes ✅

---

## Path 2: Local Dev Containers 💻

### Prerequisites

**Required**:
- Docker Desktop installed
- Git installed
- 8GB+ RAM, 50GB+ free disk space

**Optional but Recommended**:
- VS Code with Dev Containers extension

### Setup Steps

#### 1. Install Docker Desktop

**macOS**: https://www.docker.com/products/docker-desktop
**Windows**: https://www.docker.com/products/docker-desktop (use WSL2 backend)
**Linux**: https://docs.docker.com/engine/install/

**Verify installation**:
```bash
docker --version
docker compose version
docker info
```

**Linux only**: Add user to docker group:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

#### 2. Clone Repository

```bash
# Create workspace directory
mkdir -p ~/clinical-diary-workspace
cd ~/clinical-diary-workspace

# Clone repository
gh repo clone yourorg/clinical-diary
# Or: git clone https://github.com/yourorg/clinical-diary.git

cd clinical-diary
```

#### 3. Run Setup Script

```bash
cd tools/dev-env
./setup.sh
```

This will:
- Detect your platform (Linux/macOS/Windows)
- Verify Docker installation
- Build all Docker images (15-30 minutes first time)
- Create necessary volumes
- Optionally start a container

**Coffee break recommended** ☕ (20-30 minutes)

#### 4. Validate Installation

```bash
./validate-environment.sh --full
```

Review the validation report. All tests should pass.

#### 5. Choose Your IDE Approach

**Option A: VS Code Dev Containers (Recommended)**

1. Install VS Code: https://code.visualstudio.com/
2. Install extension: "Dev Containers" (ms-vscode-remote.remote-containers)
3. Open project in VS Code
4. Press `F1` → "Dev Containers: Reopen in Container"
5. Choose: "Clinical Diary - Developer"
6. VS Code reopens inside container

**Option B: Command Line**

```bash
# Start dev container
docker compose up -d dev

# Enter container
docker compose exec dev bash

# You're now inside the container
flutter --version
git config user.name
```

#### 6. Configure Secrets

**Install Doppler CLI** (inside container or on host):
```bash
# Inside dev container
doppler login

# Setup project
doppler setup --project clinical-diary-dev --config dev

# Test
doppler run -- printenv | grep DOPPLER
```

**Get Doppler token** from team lead.

#### 7. Start Development

```bash
# If using VS Code Dev Containers, terminal is already in container

# If using command line, first enter container:
docker compose exec dev bash

# Then work normally:
cd /workspace/repos/clinical-diary
git checkout -b feature/my-feature
# ... develop, test, commit
```

**Total Time**: ~1-2 hours ✅

---

## Role-Based Development

### Understanding Roles

You have **4 different container environments**:

| Role | Purpose | Tools | Git Identity |
| --- | --- | --- | --- |
| **dev** | Feature development | Flutter, Android SDK, Node, Python | "Developer" |
| **qa** | Testing, QA automation | Playwright, test frameworks | "QA Automation Bot" |
| **ops** | Deployment, infrastructure | Terraform, Supabase, Cosign | "DevOps Engineer" |
| **mgmt** | Read-only oversight | Git viewing, reports | "Management Viewer" |

### Switching Roles

**In Codespaces**:
1. Stop current Codespace (or leave it running)
2. Create new Codespace
3. Choose different role

**In Local Dev Containers (VS Code)**:
1. `F1` → "Dev Containers: Reopen in Container"
2. Choose different role
3. VS Code reconnects to different container

**In Local Dev Containers (Command Line)**:
```bash
# Stop current container
docker compose stop dev

# Start different container
docker compose up -d qa
docker compose exec qa bash
```

### When to Use Each Role

**Developer**:
- Writing code
- Building features
- Running the app locally
- Daily development work

**QA**:
- Running test suites
- Writing tests
- Generating test reports
- Verifying bug fixes

**Ops**:
- Deploying to staging/production
- Managing infrastructure
- Database migrations
- Building and signing artifacts

**Management**:
- Viewing code changes
- Reading test reports
- Reviewing audit trails
- No write access (read-only)

---

## Daily Workflows

### Morning Routine

**Codespaces**:
1. Go to github.com/yourorg/clinical-diary
2. Click existing Codespace or create new
3. Start coding in ~30 seconds

**Local**:
```bash
cd ~/clinical-diary-workspace/clinical-diary/tools/dev-env
docker compose up -d dev
# VS Code: F1 → "Reopen in Container"
# CLI: docker compose exec dev bash
```

### Feature Development

```bash
# Create feature branch
git checkout -b feature/my-awesome-feature

# Develop
# ... edit files ...

# Test locally
flutter test

# Commit
git add .
git commit -m "[FEAT] Add awesome feature

Implements: REQ-d00XXX

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push
git push origin feature/my-awesome-feature

# Create PR
gh pr create --title "Add awesome feature" --body "Description here"
```

### Running Tests

**Developer role**:
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/
```

**QA role**:
```bash
# Switch to QA container/Codespace

# Run comprehensive test suite
qa-runner.sh

# Run specific test types
qa-runner.sh unit
qa-runner.sh integration
qa-runner.sh e2e

# View reports
cat /workspace/reports/test-summary.md
```

### End of Day

**Codespaces**:
- Just close the browser tab
- Codespace auto-stops after 30 min idle
- Your work is auto-saved

**Local**:
```bash
# Commit your work
git add .
git commit -m "WIP: End of day checkpoint"

# Optionally stop containers
docker compose down

# Or leave running (containers are lightweight)
```

---

## Common Tasks

### Clone Additional Repositories

```bash
cd /workspace/repos

# Using GitHub CLI (authenticated automatically)
gh repo clone yourorg/another-repo

# Using git (may need auth)
git clone https://github.com/yourorg/another-repo.git
```

### Share Files Between Roles

Use the **exchange volume**:

```bash
# In dev container
echo "Dev output" > /workspace/exchange/dev-data.txt

# In QA container
cat /workspace/exchange/dev-data.txt  # Can read it!
```

### View QA Reports

```bash
# In any container
ls -la /workspace/reports/

# View latest test summary
cat /workspace/reports/test-summary.md
```

### Update Your Environment

**Codespaces**: Automatically updated when prebuild runs

**Local**:
```bash
cd tools/dev-env

# Pull latest changes
git pull

# Rebuild images
./setup.sh --rebuild

# Or rebuild specific role
docker compose build dev
```

---

## Troubleshooting

### Codespaces Issues

**Problem**: Codespace won't start
- **Solution**: Check GitHub status page, wait a few minutes, try again

**Problem**: Codespace is slow
- **Solution**:
  1. Check your internet connection
  2. Try VS Code desktop app instead of browser
  3. Use smaller machine type (2-core) for light work

**Problem**: Tools not found
- **Solution**: Container may not have finished building. Wait for postCreateCommand to complete.

### Local Dev Container Issues

**Problem**: Docker daemon not running
```bash
# macOS/Windows: Start Docker Desktop

# Linux:
sudo systemctl start docker
```

**Problem**: Permission denied
```bash
# Linux only:
sudo usermod -aG docker $USER
newgrp docker
```

**Problem**: Build failures
```bash
# Clear build cache
docker builder prune

# Rebuild
cd tools/dev-env
./setup.sh --rebuild
```

**Problem**: Container won't start
```bash
# View logs
docker compose logs dev

# Restart
docker compose restart dev

# Nuclear option (removes containers, not volumes)
docker compose down
docker compose up -d dev
```

### Tool Issues

**Problem**: Flutter command not found
- **Check**: Are you in the dev or qa container? (not ops or mgmt)
- **Solution**: Switch to dev container

**Problem**: Git identity wrong
- **Check**: `git config user.name`
- **Solution**: You're in the wrong role container. Switch to correct role.

**Problem**: Can't write files (management role)
- **Expected**: Management role is read-only by design
- **Solution**: Switch to dev/qa/ops role

---

## Getting Help

### Documentation

**Quick Start**: `tools/dev-env/START_HERE.md`
**Complete Guide**: `tools/dev-env/README.md`
**Codespaces Info**: `tools/dev-env/GITHUB_CODESPACES.md`
**Architecture**: `docs/dev-environment-architecture.md`

### Team Support

**Questions**: Ask in team Slack/Discord channel
**Issues**: Create GitHub issue with `dev-environment` label
**Urgent**: Contact team lead

### Self-Service Debugging

1. **Check validation**:
   ```bash
   cd tools/dev-env
   ./validate-environment.sh --full
   ```

2. **Check logs**:
   ```bash
   docker compose logs dev
   ```

3. **Restart fresh**:
   ```bash
   docker compose down
   docker compose up -d dev
   ```

4. **Check platform guide**:
   See `docs/validation/dev-environment/platform-testing-guide.md`

---

## Best Practices

### Git Workflow

✅ **DO**:
- Create feature branches
- Write descriptive commit messages
- Reference requirements (REQ-d00XXX)
- Run tests before pushing
- Create PRs for review

❌ **DON'T**:
- Commit directly to main
- Push without testing
- Commit secrets or .env files
- Use generic commit messages

### Container Hygiene

**Codespaces**:
- Delete old Codespaces after PR merged
- Stop Codespaces when done for day (saves money)
- Keep max 1-2 Codespaces per person

**Local**:
- Run `docker system prune` monthly to clean up
- Keep Docker Desktop updated
- Don't commit with containers stopped (may lose uncommitted work)

### Secrets Management

✅ **DO**:
- Use Doppler for all secrets
- Use `doppler run -- command` to inject secrets
- Add secrets to Doppler/GitHub Secrets

❌ **DON'T**:
- Commit `.env` files
- Hardcode API keys
- Share secrets in Slack/email
- Store secrets in code comments

---

## Onboarding Checklist

Use this checklist for your first day:

### Access & Accounts
- [ ] GitHub organization invitation accepted
- [ ] Doppler account created (or access granted)
- [ ] Team communication channel joined (Slack/Discord)
- [ ] Access to Supabase dashboard (if needed)

### Environment Setup
- [ ] Codespace created OR local environment built
- [ ] Validation passed (`./validate-environment.sh --full`)
- [ ] Tools verified (flutter, git, node, etc.)
- [ ] Secrets configured (Doppler setup)

### First Steps
- [ ] Repository cloned/accessed
- [ ] Test feature branch created
- [ ] Test commit made
- [ ] Test PR created (if comfortable)
- [ ] Team lead notified of successful setup

### Understanding
- [ ] Read: `tools/dev-env/README.md`
- [ ] Understand role-based containers
- [ ] Know how to switch roles
- [ ] Know where to find documentation
- [ ] Know how to get help

---

## FAQ

**Q: Codespaces or Local?**
A: For remote team, try Codespaces first. Faster setup, consistent environment. Keep local as backup.

**Q: How do I switch roles?**
A: Codespaces: Create new Codespace with different role. Local: Use VS Code "Reopen in Container" or `docker compose exec <role> bash`

**Q: Where's my code stored?**
A: Codespaces: GitHub servers. Local: Your machine. Both: Git repository.

**Q: Can I work offline?**
A: Codespaces: No. Local: Yes.

**Q: How much does Codespaces cost?**
A: Free tier: 120 core-hours/month. Paid: ~$0.18-0.36/hour. Team lead monitors budget.

**Q: What if I break something?**
A: Codespaces: Delete and recreate. Local: `docker compose down && docker compose up -d`. Your git commits are safe!

**Q: Can I customize my environment?**
A: Yes! Add to `.devcontainer/*/devcontainer.json` and create PR.

**Q: What's with the different Git identities?**
A: Each role has a different Git identity to maintain audit trail. Dev is "Developer", QA is "QA Automation Bot", etc.

---

## Success Metrics

You're fully onboarded when you can:

✅ Create/enter your development environment in < 5 minutes
✅ Run `flutter --version` and see Flutter 3.24.0
✅ Create a feature branch and make a commit
✅ Switch between roles (dev/qa/ops)
✅ Run the test suite
✅ Create a pull request

---

## Next Steps

Now that you're set up:

1. **Review the codebase**: Start with `README.md` and `spec/` directory
2. **Pick a starter task**: Ask team lead for a good first issue
3. **Join team meetings**: Standup, planning, retro
4. **Set up your workflow**: Customize VS Code, learn shortcuts
5. **Ask questions**: No question is too basic!

---

**Welcome to the team! 🎉**

Questions? Ping the team channel or your buddy!
