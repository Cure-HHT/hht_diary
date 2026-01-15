# Development Environment Setup Guide

**Document Version**: 1.0
**Date**: 2025-10-27
**Audience**: Developers, DevOps Engineers
**Status**: Active

**IMPLEMENTS REQUIREMENTS**:
- REQ-d00027: Containerized Development Environments
- REQ-d00055: Role-Based Environment Separation
- REQ-d00058: Secrets Management via Doppler
- REQ-d00060: VS Code Dev Containers Integration

---

## Executive Summary

This guide provides comprehensive setup instructions for the Clinical Trial Diary development environment, including IDE configuration, tooling, and Claude Code integration for AI-assisted development with requirement traceability.

**Estimated Setup Time**: 2-4 hours for complete environment

---

## 1. Prerequisites

### 1.1 Development Environment Options

This project supports two development approaches:

1. **Docker-based Development** (Recommended): Role-separated containers with consistent tooling
2. **Local Development**: Direct installation on your machine

**Docker-based development** is recommended for:
- Consistent environments across team
- FDA validation requirements
- Role-based access control (Developer, QA, DevOps, Management)
- Quick onboarding (5 minutes vs 2 hours)

**Local development** is suitable for:
- Offline work requirements
- Specific IDE integrations
- Custom tooling preferences

### 1.2 Required Software

#### Docker-Based Development

**Required**:
- **Docker Desktop** (Windows/Mac): https://www.docker.com/products/docker-desktop
- **Docker Engine** (Linux): https://docs.docker.com/engine/install/
- **VS Code** (optional, recommended): With Dev Containers extension (ms-vscode-remote.remote-containers)
- **gcloud CLI** : https://docs.cloud.google.com/sdk/docs/install

**Platform-Specific Notes**:
- **Windows WSL2**: Use WSL2 terminal for better performance. Files in `/home/ubuntu/repos` are faster than Windows filesystem.
- **macOS Apple Silicon**: Docker Desktop supports ARM64. Some tools may be x86 only (handled automatically).
- **Linux**: Native Docker performance (fastest), no VM overhead.

#### Local Development

**Core Tools**:
- **Git**: Version 2.30+ (`git --version`)
- **Node.js**: Version 18+ via nvm (`node --version`)
- **Python**: Version 3.10+ (`python3 --version`)
- **PostgreSQL Client**: psql 15+ (for local database testing)
- **unzip**: Required for Flutter SDK updates (`unzip --version`)

**IDE/Editor**:
- **Visual Studio Code**: Latest version (recommended)
- **Claude Code**: VS Code extension for AI assistance

**Platform-Specific**:
- **macOS**: Xcode Command Line Tools (`xcode-select --install`)
- **Linux**: build-essential, libpq-dev, unzip
  ```bash
  sudo apt-get update
  sudo apt-get install -y build-essential libpq-dev unzip
  ```
- **Windows**: WSL2 with Ubuntu 22.04+

### 1.3 Required Accounts

- **GitHub**: Access to project repository
- **Linear**: Project management and issue tracking
- **Google Cloud Platform**: Cloud Run, Cloud SQL, IAM, etc. (provided per sponsor)
- **Doppler**: Secrets management (team access required)

---

## 2. Initial Setup

### 2.1 Docker-Based Setup (Recommended)

#### Quick Start

```bash
cd tools/dev-env
./setup.sh
```

First run takes 15-30 minutes (downloads and builds images).

#### Roles and Capabilities

| Role | Container | Tools | Use Case |
| --- | --- | --- | --- |
| Developer | `dev` | Flutter, Android SDK, Node, Python | Build mobile app |
| QA | `qa` | Playwright, test frameworks | Run automated tests |
| DevOps | `ops` | Terraform, Supabase CLI, Cosign, Syft | Deploy infrastructure |
| Management | `mgmt` | Git (read-only), report viewers | View status |

#### Daily Usage - Method 1: VS Code (Recommended)

1. Open project in VS Code
2. Press `F1` → "Dev Containers: Reopen in Container"
3. Select role: Developer, QA, DevOps, or Management
4. VS Code reopens inside container

#### Daily Usage - Method 2: Command Line

```bash
# Start container
docker compose up -d dev

# Enter container
docker compose exec dev bash

# Stop container
docker compose stop dev
```

#### Role Switching

**VS Code**:
1. `F1` → "Dev Containers: Reopen in Container"
2. Select different role

**Command Line**:
```bash
docker compose stop dev
docker compose up -d qa
docker compose exec qa bash
```

#### Common Docker Commands

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

#### Secrets Management (Doppler)

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

#### File System Structure

**Host Machine**:
```
tools/dev-env/
├── docker/               # Dockerfiles
├── docker-compose.yml    # Container orchestration
├── setup.sh              # Setup script
└── README.md             # Quick reference (redirects to this doc)
```

**Inside Containers**:
```
/workspace/
├── repos/                # Git repositories (persisted)
├── exchange/             # Share files between roles
├── src/                  # Source code (bind mount)
└── reports/              # Test reports (QA only)
```

**Named Volumes (Persist Data)**:
- `clinical-diary-repos` - Git repositories
- `clinical-diary-exchange` - File sharing
- `qa-reports` - Test reports

**Bind Mounts (Direct Access)**:
- `/workspace/src` → Project root
- `/home/ubuntu/.ssh` → Your SSH keys (read-only)
- `/home/ubuntu/.gitconfig.host` → Your git config (read-only)

#### Git Configuration in Containers

Each role has a default identity:
- dev: "Developer <dev@clinical-diary.local>"
- qa: "QA Automation Bot <qa@clinical-diary.local>"
- ops: "DevOps Engineer <ops@clinical-diary.local>"
- mgmt: "Manager <mgmt@clinical-diary.local>"

To use your personal identity:
```bash
git config --global include.path /home/ubuntu/.gitconfig.host
```

#### Health Checks

```bash
# Check container status
docker compose ps

# Run health check manually
docker compose exec dev /usr/local/bin/health-check.sh
```

#### Cleanup

```bash
# Stop containers (data persists)
docker compose down

# Remove containers and volumes (⚠️ data loss)
docker compose down -v

# Remove unused images
docker image prune -a
```

#### CI/CD Integration

GitHub Actions workflows use these same Docker images:
- `.github/workflows/qa-automation.yml` - Automated testing
- `.github/workflows/build-publish-images.yml` - Image builds

**See**:
- [Development Environment Architecture](/home/mclew/dev24/diary-worktrees/clean-docs/docs/setup-dev-environment-architecture.md)
- [Dev Environment Maintenance](/home/mclew/dev24/diary-worktrees/clean-docs/docs/ops-dev-environment-maintenance.md)

---

### 2.2 Local Development Setup

#### Clone Repository

```bash
# Clone the repository
git clone https://github.com/YOUR_ORG/clinical-trial-diary.git
cd clinical-trial-diary

# Configure git hooks
git config core.hooksPath .githooks

# Test pre-commit hook
.githooks/pre-commit
```

**Verification**: Git hooks should validate requirement traceability.

---

#### Install Node.js via nvm

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Reload shell configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Install Node.js
nvm install 18
nvm use 18
nvm alias default 18

# Verify installation
node --version  # Should show v18.x.x
npm --version   # Should show 9.x.x or higher
```

**Verification**: `node --version` shows v18.x.x

---

#### Install Python Dependencies

```bash
# Ensure Python 3.10+ is installed
python3 --version

# Install requirement validation tools
cd tools/requirements
pip3 install --user -r requirements.txt  # If requirements.txt exists

# Verify validation tools work
cd ../..
python3 tools/requirements/validate_requirements.py
```

**Verification**: Should show requirement validation summary with no errors.

---

## 3. IDE Setup: Visual Studio Code

### 3.1 Install VS Code Extensions

**Required Extensions**:
1. **Claude Code** (`anthropic.claude-code`) - AI assistant with requirement traceability
2. **Linear** (`linear.linear`) - Issue tracking integration
3. **GitLens** (`eamodio.gitlens`) - Git visualization
4. **ESLint** (`dbaeumer.vscode-eslint`) - JavaScript linting
5. **Prettier** (`esbenp.prettier-vscode`) - Code formatting
6. **PostgreSQL** (`ckolkman.vscode-postgres`) - Database client
7. **Markdown All in One** (`yzhang.markdown-all-in-one`) - Documentation editing

**Install via Command Palette**:
```
Ctrl+Shift+P (Cmd+Shift+P on macOS)
> Extensions: Install Extension
Search for each extension and install
```

**Or via command line**:
```bash
code --install-extension anthropic.claude-code
code --install-extension linear.linear
code --install-extension eamodio.gitlens
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension ckolkman.vscode-postgres
code --install-extension yzhang.markdown-all-in-one
```

---

### 3.2 Configure VS Code Settings

Create or update `.vscode/settings.json`:

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.tabSize": 2,
  "editor.rulers": [80, 120],
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.exclude": {
    "**/.git": true,
    "**/node_modules": true,
    "**/.DS_Store": true,
    "**/untracked-notes": true
  },
  "[markdown]": {
    "editor.wordWrap": "on",
    "editor.quickSuggestions": false
  },
  "[sql]": {
    "editor.defaultFormatter": "ckolkman.vscode-postgres"
  },
  "git.enableCommitSigning": false,
  "git.confirmSync": false
}
```

---

### 3.3 Configure VS Code Tasks

Create `.vscode/tasks.json` for common development tasks:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Validate Requirements",
      "type": "shell",
      "command": "python3",
      "args": ["tools/requirements/validate_requirements.py"],
      "group": "test",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      },
      "problemMatcher": []
    },
    {
      "label": "Generate Traceability Matrix",
      "type": "shell",
      "command": "python3",
      "args": [
        "tools/requirements/generate_traceability.py",
        "--format",
        "both"
      ],
      "group": "build",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      },
      "problemMatcher": []
    },
    {
      "label": "Fetch Linear Tickets",
      "type": "shell",
      "command": "${env:NVM_DIR}/nvm-exec",
      "args": [
        "node",
        "tools/linear-cli/fetch-tickets.js",
        "--token=${env:LINEAR_API_TOKEN}",
        "--format=json"
      ],
      "group": "none",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      },
      "problemMatcher": []
    }
  ]
}
```

---

## 4. Claude Code Integration

### 4.1 Install Claude Code Extension

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X / Cmd+Shift+X)
3. Search for "Claude Code"
4. Click "Install"
5. Sign in with Anthropic account (or create one)

---

### 4.2 Configure Claude Code for Project

Claude Code automatically reads `CLAUDE.md` (project-level) and `~/.claude/CLAUDE.md` (user-level) for custom instructions.

**Project-level configuration** (already in repo):
- `CLAUDE.md` - Project structure, SOPs, requirement traceability guidelines
- `.claude/commands/` - Custom slash commands (e.g., `/implement-tickets`)

**User-level configuration** (optional):
Create `~/.claude/CLAUDE.md` for personal preferences:

```markdown
# Personal Claude Code Preferences

## Code Style
- Prefer functional programming over OOP when appropriate
- Use TypeScript strict mode
- Prefer async/await over promises

## Documentation
- Always add JSDoc comments for public functions
- Include examples in documentation
- Update README when adding features
```

---

### 4.3 Claude Code Slash Commands

This project includes custom slash commands in `.claude/commands/`:

**Available Commands**:
1. `/remove-prd-code` - Remove implementation code from PRD files to enforce audience scope
2. `/implement-tickets` - Systematically implement high-priority Linear tickets with traceability

**Usage**:
```
Type "/" in Claude Code chat to see available commands
Select command from dropdown
Claude Code will execute the command workflow
```

---

### 4.4 Claude Code Workflow Monitoring

**Enable Claude Code Monitoring**:
Claude Code provides built-in monitoring via:
1. **Status Bar**: Shows active model, token usage
2. **Output Panel**: View > Output > Select "Claude Code" from dropdown
3. **Command History**: Review previous commands and outputs

**Monitor Key Metrics**:
- Token usage per session (avoid exceeding budget)
- Response quality (review generated code/docs)
- Tool usage (Bash, Read, Edit, Write)
- Error rates (failed tool calls, syntax errors)

**Best Practices**:
1. **Review all generated code** before committing
2. **Verify requirement traceability** in all new files
3. **Run validation tools** after Claude Code makes changes:
   ```bash
   python3 tools/requirements/validate_requirements.py
   git status  # Check what changed
   git diff    # Review changes in detail
   ```
4. **Monitor token usage**: Close/restart session if approaching budget limits
5. **Use specific prompts**: Provide context and clear requirements

---

### 4.5 Claude Code + Linear Integration

**Setup Linear Integration**:
1. Get Linear API token: https://linear.app/settings/api
2. Store token securely:
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   export LINEAR_API_TOKEN="lin_api_YOUR_TOKEN_HERE"
   ```
3. Test Linear CLI tools:
   ```bash
   cd tools/linear-cli
   node fetch-tickets.js --token=$LINEAR_API_TOKEN --format=json
   ```

**Workflow**:
1. **Fetch tickets**: `/implement-tickets` command fetches assigned Linear tickets
2. **Review requirements**: Claude Code checks ticket descriptions for REQ-xxx references
3. **Implement**: Claude Code generates code with requirement headers
4. **Verify**: Run requirement validation before committing
5. **Update ticket**: Claude Code can update Linear ticket status (if configured)

**See**: `tools/linear-cli/README.md` for detailed Linear integration docs

---

## 5. Development Tools

### 5.1 Requirement Validation

**Pre-Commit Hook** (automatic):
```bash
# Configured via: git config core.hooksPath .githooks
# Runs automatically on every commit
# Validates:
# - Requirement format and IDs
# - Implementation headers in code files
# - Requirement hierarchy (PRD -> Ops -> Dev)
```

**Manual Validation**:
```bash
# Validate all requirements
python3 tools/requirements/validate_requirements.py

# Generate traceability matrix
python3 tools/requirements/generate_traceability.py --format markdown
python3 tools/requirements/generate_traceability.py --format html
python3 tools/requirements/generate_traceability.py --format both
```

**Validation Errors**:
If validation fails, fix issues before committing:
- Missing `IMPLEMENTS REQUIREMENTS:` headers in code files
- Invalid requirement IDs (format: `REQ-{level}{number}`)
- Broken requirement hierarchy
- Duplicate requirement IDs

---

### 5.2 Linear CLI Tools

**Available Tools** (in `tools/linear-cli/`):
- `fetch-tickets.js` - Fetch all assigned tickets
- `fetch-tickets-by-label.js` - Fetch tickets by label
- `create-requirement-tickets.js` - Batch create tickets from requirements
- `update-ticket-with-requirement.js` - Link existing ticket to requirement
- `add-subsystem-checklists.js` - Add sub-system checklists to tickets
- `check-duplicates.js` - Find duplicate requirement-ticket mappings

**Example Workflows**:

```bash
# Fetch your assigned tickets
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
cd tools/linear-cli
node fetch-tickets.js --token=$LINEAR_API_TOKEN --format=json

# Create tickets for all new requirements
./create-tickets.sh

# Add sub-system checklists to existing tickets
node add-subsystem-checklists.js --token=$LINEAR_API_TOKEN
```

---

### 5.3 Database Tools

**Local PostgreSQL Testing** (optional):
```bash
# Install PostgreSQL 17
# macOS:
brew install postgresql@17

# Linux:
sudo apt-get install postgresql-17 postgresql-client-17

# Start PostgreSQL
brew services start postgresql@17  # macOS
sudo systemctl start postgresql    # Linux

# Create test database
createdb clinical_trial_diary_test

# Load schema
psql -d clinical_trial_diary_test -f database/schema.sql
psql -d clinical_trial_diary_test -f database/triggers.sql
psql -d clinical_trial_diary_test -f database/rls_policies.sql
psql -d clinical_trial_diary_test -f database/indexes.sql

# Run tests
psql -d clinical_trial_diary_test -f database/tests/test_audit_trail.sql
```

**Supabase Studio** (remote):
Access via: https://app.supabase.com/project/YOUR_PROJECT_ID/editor

---

## 6. Workflow Guidelines

### 6.1 Feature Development Workflow

**Standard Process**:
1. **Get assignment**: Check Linear for assigned tickets
2. **Check requirements**: Verify ticket has REQ-xxx reference
3. **Create feature branch**:
   ```bash
   git checkout main
   git pull
   git checkout -b feature/CUR-XXX-descriptive-name
   ```
4. **Develop**:
   - Add `IMPLEMENTS REQUIREMENTS:` headers to all new files
   - Follow coding standards in `spec/dev-*.md`
   - Test locally
5. **Validate**:
   ```bash
   python3 tools/requirements/validate_requirements.py
   git status
   git diff
   ```
6. **Commit**:
   ```bash
   git add .
   git commit -m "[CUR-XXX] Brief description

   Detailed changes.

   Implements: REQ-xxx
   Status: Complete | Partial

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```
7. **Push and create PR**:
   ```bash
   git push -u origin feature/CUR-XXX-descriptive-name
   gh pr create --title "CUR-XXX: Brief description" --body "..."
   ```

**See**: `CLAUDE.md` for detailed workflow instructions

---

### 6.2 Code Review Checklist

**Before Submitting PR**:
- [ ] All new code has `IMPLEMENTS REQUIREMENTS:` headers
- [ ] Requirement validation passes (no errors)
- [ ] Tests pass (if applicable)
- [ ] Documentation updated (if needed)
- [ ] Commit message references ticket and requirements
- [ ] No secrets or credentials committed
- [ ] Traceability matrix updated (automatic via validation)

**Reviewer Checklist**:
- [ ] Code implements stated requirements
- [ ] Requirement traceability maintained
- [ ] Code follows project standards
- [ ] Tests adequate (if applicable)
- [ ] Documentation clear and accurate
- [ ] No security vulnerabilities introduced

---

## 7. Troubleshooting

### 7.1 Docker-Specific Issues

#### Docker Daemon Not Running

**Problem**: Docker commands return "Cannot connect to Docker daemon".

**Solution**:
```bash
# Windows/Mac: Open Docker Desktop

# Linux:
sudo systemctl start docker
sudo systemctl enable docker  # Start on boot
```

---

#### Permission Denied (Linux Only)

**Problem**: "Permission denied" when running Docker commands.

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes without logout
newgrp docker

# Verify
docker ps
```

---

#### Image Build Fails

**Problem**: Docker build fails with errors.

**Solution**:
```bash
# Clear Docker build cache
docker builder prune

# Rebuild from scratch
cd tools/dev-env
./setup.sh --rebuild
```

---

#### Container Won't Start

**Problem**: Container fails to start or immediately exits.

**Solution**:
```bash
# Check logs for errors
docker compose logs dev

# Remove and recreate container
docker compose down
docker compose up -d dev

# Check container status
docker compose ps
```

---

#### Flutter Command Not Found in Container

**Problem**: Flutter command not working inside container.

**Solution**:
You're in the wrong container. Flutter is only in `dev` and `qa` containers.

```bash
# Check which container you're in
docker compose exec dev flutter --version  # Should work
docker compose exec ops flutter --version  # Won't work

# Switch to dev container
docker compose stop ops
docker compose up -d dev
docker compose exec dev bash
```

---

### 7.2 Git Hooks Not Running

**Problem**: Pre-commit hook doesn't run.

**Solution**:
```bash
# Ensure hooks directory is configured
git config core.hooksPath .githooks

# Make hooks executable
chmod +x .githooks/pre-commit

# Test manually
.githooks/pre-commit
```

---

### 7.3 Node.js Command Not Found

**Problem**: `node` or `npm` commands not found.

**Solution**:
```bash
# Load nvm in current shell
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Or add to ~/.bashrc or ~/.zshrc permanently
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> ~/.bashrc
source ~/.bashrc
```

---

### 7.4 Linear API Token Not Working

**Problem**: Linear CLI tools return authentication errors.

**Solution**:
```bash
# Verify token is set
echo $LINEAR_API_TOKEN

# If empty, set it:
export LINEAR_API_TOKEN="lin_api_YOUR_TOKEN_HERE"

# Or add to ~/.bashrc for persistence
echo 'export LINEAR_API_TOKEN="lin_api_YOUR_TOKEN_HERE"' >> ~/.bashrc
source ~/.bashrc

# Test token
cd tools/linear-cli
node fetch-tickets.js --token=$LINEAR_API_TOKEN --format=json
```

---

### 7.5 Requirement Validation Fails

**Problem**: Pre-commit hook blocks commit due to validation errors.

**Solution**:
```bash
# Run validation manually to see errors
python3 tools/requirements/validate_requirements.py

# Common issues:
# 1. Missing requirement header in new code files
#    Add to top of file:
#    -- IMPLEMENTS REQUIREMENTS:
#    --   REQ-xxx: Requirement Title

# 2. Invalid requirement ID format
#    Use: REQ-p00001, REQ-o00001, REQ-d00001
#    Not: req-p1, REQ-P1, etc.

# 3. Broken requirement hierarchy
#    Ensure: PRD -> Ops -> Dev
#    Not: PRD -> Dev (skipping Ops)

# After fixing, retry commit
git commit
```

---

### 7.6 Claude Code Not Responding

**Problem**: Claude Code extension not working or slow.

**Solution**:
1. Check status bar for errors (bottom-right of VS Code)
2. View output panel: View > Output > Select "Claude Code"
3. Restart extension: Ctrl+Shift+P > "Developer: Reload Window"
4. Check internet connection (Claude Code requires API access)
5. Verify Anthropic account is active
6. Check token budget (restart session if needed)

---

## 8. Monitoring and Productivity

### 8.1 Development Metrics

**Track these metrics** to monitor productivity and code quality:
- **Ticket velocity**: Tickets completed per week/sprint
- **Requirement coverage**: % of requirements with implementing code
- **Code review time**: Time from PR creation to merge
- **Validation failures**: Pre-commit hook failures (aim for <5%)
- **Claude Code assistance**: % of code generated vs hand-written

**Tools**:
- Linear reports: https://linear.app/cure-hht-diary/reports
- GitHub Insights: Repository > Insights
- Traceability matrix: `traceability_matrix.md`

---

### 8.2 Claude Code Usage Tracking

**Monitor Claude Code effectiveness**:
1. **Token usage**: Track tokens per session (budget: 200K per session typically)
2. **Code quality**: Review acceptance rate of Claude-generated code
3. **Time savings**: Compare development time with/without Claude Code
4. **Requirement traceability**: Verify Claude Code maintains traceability

**Best Practices**:
- Use Claude Code for:
  - Boilerplate code generation
  - Documentation writing
  - Requirement analysis
  - Code review assistance
  - Refactoring suggestions
- Review and test all generated code
- Provide clear, specific prompts
- Include requirement context in prompts

---

## 9. Additional Resources

### 9.1 Documentation

- **Project README**: `README.md`
- **Architecture Docs**: `docs/adr/` (Architecture Decision Records)
- **Requirements**: `spec/` directory
- **Database Docs**: `database/schema.sql` (with inline comments)
- **Linear Integration**: `tools/linear-cli/README.md`
- **Claude Code Docs**: https://docs.claude.com/en/docs/claude-code/

### 9.2 Support Channels

- **Technical Questions**: Linear Q&A board
- **Claude Code Issues**: https://github.com/anthropics/claude-code/issues
- **Linear Support**: https://linear.app/help
- **Team Chat**: [Your team chat platform]

---

## 10. Onboarding Checklist

### Docker-Based Development (Recommended)

**New Developer Onboarding**:
- [ ] Access granted: GitHub, Linear, Supabase, Doppler
- [ ] Docker Desktop installed and running
- [ ] Repository cloned
- [ ] Docker environment built (`cd tools/dev-env && ./setup.sh`)
- [ ] Docker environment validated (`./validate-environment.sh --full`)
- [ ] VS Code with Dev Containers extension (optional)
- [ ] Successfully entered dev container (via VS Code or `docker compose exec dev bash`)
- [ ] Doppler configured inside container (`doppler login && doppler setup`)
- [ ] Git hooks configured and tested
- [ ] Claude Code extension installed and authenticated (if using VS Code)
- [ ] Requirement validation tested (runs without errors)
- [ ] Sample feature branch created and tested
- [ ] Pre-commit hook tested (blocks invalid commits)
- [ ] Read project documentation: README.md, CLAUDE.md, spec/README.md
- [ ] Understand requirement traceability workflow
- [ ] First ticket assigned and implemented
- [ ] Code reviewed by team member
- [ ] PR created and merged

**Estimated completion time**: 1-2 hours (spread over 1 day)

---

### Local Development

**New Developer Onboarding**:
- [ ] Access granted: GitHub, Linear, Supabase, Doppler
- [ ] Repository cloned
- [ ] Git hooks configured and tested
- [ ] Node.js (via nvm) installed
- [ ] Python 3.10+ installed
- [ ] VS Code installed with required extensions
- [ ] Claude Code extension installed and authenticated
- [ ] Linear API token configured
- [ ] Requirement validation tested (runs without errors)
- [ ] Sample feature branch created and tested
- [ ] Pre-commit hook tested (blocks invalid commits)
- [ ] Read project documentation: README.md, CLAUDE.md, spec/README.md
- [ ] Understand requirement traceability workflow
- [ ] First ticket assigned and implemented
- [ ] Code reviewed by team member
- [ ] PR created and merged

**Estimated completion time**: 2-4 hours (spread over 1-2 days)

---

**Document Control**:
- **Version**: 1.0
- **Effective Date**: 2025-10-27
- **Next Review**: 2026-04-27 (Semi-annual)
- **Owner**: Dev Lead
- **Last Updated**: 2025-10-27

---

**Change Log**:
- 2025-10-27 v1.0: Initial version (CUR-81)
