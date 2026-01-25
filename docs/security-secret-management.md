# Security: Secret Management

> **Purpose**: Central guide for managing secrets, API tokens, and credentials securely across the Diary Platform.
>
> **Compliance**: FDA 21 CFR Part 11, HIPAA, GDPR

---

## IMPLEMENTS REQUIREMENTS

- REQ-d00058: Secrets Management via Doppler
- REQ-o00015: Secrets management (ops level)
- REQ-p00017: Data Encryption

---

## Overview

Secret management is critical for security compliance. This guide consolidates best practices for handling all types of secrets in this project: API tokens, database credentials, signing keys, and other sensitive data.

**Key Principle**: Never commit secrets to version control. Always use Doppler for centralized secret management.

**What This Covers**:
- Doppler infrastructure and setup
- All secret types used in this project
- Setup procedures for developers and CI/CD
- What to commit and what not to commit
- API token lifecycle management
- Emergency response for leaked credentials
- Best practices and troubleshooting

---

## Doppler Secret Management

### What is Doppler?

Doppler is a centralized secrets management platform that provides:

- **Secure Storage**: Encrypted storage for all secrets
- **Environment Separation**: Different secrets for dev, staging, and production
- **Access Control**: Role-based permissions for team members
- **Audit Trail**: Complete history of who accessed what secrets
- **CI/CD Integration**: Service tokens for GitHub Actions and other platforms
- **Secrets Rotation**: Automated key rotation

**Why Doppler?**
- Single source of truth for all secrets
- No `.env` files with real secrets in git history
- Team members always have latest secrets
- Easy onboarding for new developers
- Sponsor isolation with per-sponsor projects
- Compliance-ready audit trails

### How This Project Uses Doppler

The Diary Platform uses a nested Doppler project structure:

```
hht-diary-core (Main Project)
├── dev config           (Local development)
├── staging config       (Staging environment)
└── production config    (Production deployment)

hht-diary-{sponsor} (Per-Sponsor Projects)
├── staging config       (Sponsor staging)
└── production config    (Sponsor production)
```

**Architecture Rationale**:
- Core project: Shared application secrets and sponsor manifest
- Sponsor projects: Isolated sponsor-specific secrets
- This enforces sponsor isolation per REQ-p00001

### Per-Environment Secrets

**Development (`dev` config)**:
- Local development secrets
- Test database credentials
- Non-production API keys
- Staging external service tokens

**Staging (`staging` config)**:
- Staging environment secrets
- Staging database credentials
- Pre-production external APIs
- Sponsor staging databases

**Production (`production` config)**:
- Live application secrets
- Production database credentials
- Real external API keys
- Sponsor production databases
- Restricted access - admin approval required

### Per-Sponsor Secrets

Each pharmaceutical sponsor has an isolated Doppler project:

**Example**: `hht-diary-callisto`
- Separate staging and production configs
- Sponsor-specific Supabase database credentials
- Sponsor-specific AWS infrastructure keys
- Sponsor-specific API keys and integrations
- No cross-sponsor secret sharing

**Why Per-Sponsor?**
- Complete sponsor isolation (REQ-p00001)
- No accidental cross-sponsor data leaks
- Revoke sponsor access without affecting others
- Sponsor-specific onboarding and offboarding

---

## Secret Types in This Project

### Supabase Credentials

**What they are**: Database connection credentials

**Secrets**:
- `SUPABASE_PROJECT_ID`: Project identifier (e.g., `callisto-portal-prod`)
- `SUPABASE_ACCESS_TOKEN`: Service role token for API access
- `SUPABASE_URL`: Database connection URL

**Where stored**:
- Core project: `hht-diary-core` (dev/staging/production)
- Sponsor projects: `hht-diary-{sponsor}` (staging/production only)

**Usage**:
```bash
# Local development
doppler run -- flutter run

# CI/CD builds
doppler secrets get SUPABASE_ACCESS_TOKEN --token $DOPPLER_TOKEN_CORE
```

**Rotation**: Annual or when access is compromised

### Linear API Tokens

**What they are**: Authentication for Linear project management API

**Secrets**:
- `LINEAR_API_KEY`: Personal API key for Linear workspace
- `LINEAR_TEAM_ID`: Team identifier (optional)

**Where stored**:
- Core project `dev` config (developers only)
- Not in staging/production (used only locally)

**Usage**:
```bash
# VS Code Linear Requirement Inserter
# Configured in: Settings > Linear Req Inserter: Api Token

# Manual API calls
curl -H "Authorization: Bearer $LINEAR_API_KEY" \
  https://api.linear.app/graphql
```

**Scopes**: Read-only access to tickets and requirements

**Rotation**: Every 90 days or when leaked

### AWS Credentials

**What they are**: Authentication for AWS infrastructure

**Secrets**:
- `CORE_AWS_ACCESS_KEY_ID`: Core infrastructure access key
- `CORE_AWS_SECRET_ACCESS_KEY`: Core infrastructure secret key
- `SPONSOR_AWS_ACCESS_KEY_ID`: Sponsor-specific access key
- `SPONSOR_AWS_SECRET_ACCESS_KEY`: Sponsor-specific secret key

**Where stored**:
- Core project: `hht-diary-core` (all configs)
- Sponsor projects: `hht-diary-{sponsor}` (staging/production)

**Usage**:
```bash
# Local development
doppler run -- aws s3 ls

# CI/CD
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_CALLISTO
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_CALLISTO
aws deploy push --service-role-arn arn:aws:iam::...
```

**Permissions**: Minimal required (principle of least privilege)

**Rotation**: Every 90 days or annually

### GitHub Personal Access Tokens

**What they are**: Authentication for GitHub API and repository access

**Secrets**:
- `GITHUB_TOKEN`: Personal access token for developer
- `SPONSOR_REPO_TOKEN`: Token for cloning sponsor repositories (future multi-repo)

**Where stored**:
- `GITHUB_TOKEN`: In developer's local environment (GitHub Codespaces auto-injects)
- `SPONSOR_REPO_TOKEN`: Core project production config (for multi-repo setup)

**Usage**:
```bash
# GitHub CLI (auto-authenticated)
gh pr create --title "My PR"

# Manual API calls
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user/repos
```

**Scopes**:
- `repo`: Full repository access
- `workflow`: Modify GitHub Actions workflows
- `read:org`: Read organization data

**Rotation**: When access is compromised or quarterly

### App Store Credentials

**What they are**: Credentials for publishing to app stores

**Secrets**:
- `APP_STORE_CREDENTIALS`: JSON blob containing Apple and Google credentials

**Where stored**:
- Core project production config only
- Restricted to CI/CD and deployment team

**Usage**:
```bash
# During build process
doppler run -- flutter build appbundle

# Secrets automatically injected into build environment
```

**Structure** (example):
```json
{
  "apple": {
    "app_id": "com.example.diary",
    "team_id": "ABC123DEF4",
    "key_id": "2X9R4HXF34",
    "issuer_id": "69a6de79-...",
    "private_key": "-----BEGIN PRIVATE KEY-----\n..."
  },
  "google": {
    "package_name": "com.example.diary",
    "service_account_json": {...}
  }
}
```

**Rotation**: Annual or when access is compromised

---

## Setting Up Secrets

### For Developers (Using doppler run)

**One-time setup**:

1. **Install Doppler CLI**:
   ```bash
   # macOS
   brew install dopplerhq/cli/doppler

   # Linux (Ubuntu/Debian)
   sudo apt-get update
   curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
     'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' \
 | sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] \
     https://packages.doppler.com/public/cli/deb/debian any-version main" \
 | sudo tee /etc/apt/sources.list.d/doppler-cli.list
   sudo apt-get update && sudo apt-get install doppler
   ```

2. **Login to Doppler**:
   ```bash
   doppler login
   ```
   This opens a browser for authentication and stores your token locally.

3. **Configure project**:
   ```bash
   cd /path/to/hht-diary
   doppler setup
   ```
   Select:
   - Project: `hht-diary-core`
   - Config: `dev`

4. **Verify setup**:
   ```bash
   doppler secrets list
   ```

**Daily usage**:

Prefix all commands that need secrets with `doppler run --`:

```bash
# Flutter development
doppler run -- flutter run

# Web development
doppler run -- npm start

# Database migrations
doppler run -- npm run migrate

# Run tests
doppler run -- flutter test
```

**Switching environments**:

```bash
# Use staging secrets
doppler run --config staging -- flutter build apk

# Use production secrets (careful!)
doppler run --config production -- flutter build appbundle
```

**Working with sponsor code**:

```bash
cd sponsor/callisto
doppler setup --project hht-diary-callisto --config staging
doppler run -- flutter run
```

**Viewing secrets**:

```bash
# List all secrets
doppler secrets list

# Get specific secret
doppler secrets get SUPABASE_PROJECT_ID --plain

# Download all secrets (for debugging, never commit!)
doppler secrets download --no-file --format env
```

### For CI/CD (Service Tokens)

**GitHub Actions Integration**:

1. **Create service tokens** (one-time, by DevOps admin):
   ```bash
   doppler configs tokens create github-actions \
     --project hht-diary-core --config production

   doppler configs tokens create github-actions \
     --project hht-diary-callisto --config production
   ```

2. **Add to GitHub repository secrets** (Settings > Secrets and variables > Actions):
   ```
   DOPPLER_TOKEN_CORE=dp_prod_xxxx...
   DOPPLER_TOKEN_CALLISTO=dp_prod_yyyy...
   ```

3. **Use in GitHub Actions**:
   ```yaml
   - name: Install Doppler
     uses: dopplerhq/cli-action@v3

   - name: Build with production secrets
     run: |
       doppler run --token ${{ secrets.DOPPLER_TOKEN_CORE }} \
         -- flutter build appbundle
   ```

**CI/CD Best Practices**:
- Use service tokens, never personal tokens
- Create separate tokens per project
- Rotate tokens annually
- Audit token access in Doppler dashboard

### For Sponsors (Sponsor-Specific Projects)

**Onboarding new sponsors**:

1. **Create sponsor Doppler project**:
   ```bash
   doppler projects create hht-diary-sponsor-name
   doppler configs create staging --project hht-diary-sponsor-name
   doppler configs create production --project hht-diary-sponsor-name
   ```

2. **Set sponsor secrets**:
   ```bash
   # Supabase
   doppler secrets set SUPABASE_PROJECT_ID="sponsor-portal-staging" \
     --project hht-diary-sponsor-name --config staging

   # AWS
   doppler secrets set SPONSOR_AWS_ACCESS_KEY_ID="AKIA..." \
     --project hht-diary-sponsor-name --config staging
   ```

3. **Update sponsor manifest** in core project:
   ```bash
   doppler secrets set SPONSOR_MANIFEST --project hht-diary-core \
     --config production <<'EOF'
   sponsors:
     - name: callisto
       code: CAL
       enabled: true
       region: eu-west-1
     - name: sponsor-name
       code: SPN
       enabled: true
       region: us-west-2
   EOF
   ```

4. **Generate CI/CD tokens**:
   ```bash
   doppler configs tokens create github-actions \
     --project hht-diary-sponsor-name --config production
   ```

5. **Add GitHub Actions secrets** and update workflows

See `docs/setup-doppler-new-sponsor.md` for complete step-by-step instructions.

---

## What NOT to Commit

### Files to Never Commit

**Environment files**:
- `.env` - Contains plaintext secrets
- `.env.local` - Local development overrides
- `.env.*.local` - Environment-specific overrides
- `.doppler.yaml` - Contains your Doppler configuration (already in `.gitignore`)

**Configuration files with secrets**:
- `config/secrets.json` - Hard-coded credentials
- `settings.json` - IDE settings with tokens
- `.aws/credentials` - AWS CLI credentials
- `~/.ssh/config` - SSH private key configurations

**Keys and certificates**:
- `*.key` - Private keys (SSH, TLS, signing)
- `*.pem` - Private certificates
- `*.p12` - Packaged certificates
- `*.keystore` - Java keystores

**Credentials**:
- Passwords in any file
- API keys or tokens
- Database connection strings
- AWS access keys
- Google service account JSON

### Protection Mechanisms

**`.gitignore` already includes**:
```
.env
.env.local
.env.*.local
.doppler.yaml
*.key
*.pem
*.p12
.aws/credentials
```

**Pre-commit hook blocks**:
- Commits containing secrets (via gitleaks integration)
- API keys matching common patterns
- Generic high-entropy strings (likely secrets)

**GitHub secret scanning**:
- Scans all pushes for known patterns
- Blocks commits with detected secrets
- Notifies collaborators of exposed secrets

### If You Accidentally Commit a Secret

1. **Immediately stop** - Don't push if not yet pushed
2. **Remove the file** from history:
   ```bash
   git filter-branch --tree-filter 'rm -f secrets.env' HEAD
   ```
3. **Force push** (carefully):
   ```bash
   git push --force-with-lease origin feature-branch
   ```
4. **Rotate the secret**:
   - Change password in original system
   - Generate new API key
   - Revoke old token
5. **Notify team** - Report to security team
6. **Document** in incident log

---

## Secret Scanning

### gitleaks Integration

The workflow plugin includes integrated secret scanning using gitleaks to prevent accidental commits of secrets.

**How it works**:
- **Pre-commit Hook**: Scans staged files before allowing commits
- **Gitleaks Tool**: Detects patterns for common secret types
- **Configurable Rules**: Defined in `.gitleaks.toml`
- **Graceful Degradation**: Warns if gitleaks not installed

**What it detects**:
- API keys (AWS, Stripe, Linear, GitHub, etc.)
- Database credentials
- Private keys (SSH, TLS, JWT)
- OAuth tokens and client secrets
- Passwords in configuration files
- Generic high-entropy strings (likely secrets)

**Example workflow**:

```bash
# Try to commit a secret
echo "API_KEY=sk_live_abcd1234" > config.sh
git add config.sh
git commit -m "Add config"

# Output:
# 🔍 Scanning staged files for secrets...
# ❌ SECRETS DETECTED IN STAGED FILES!
#
# To fix:
#   1. Remove the secrets from staged files
#   2. Use environment variables or Doppler
#   3. Unstage: git restore --staged <file>
#   4. Try committing again

# Fix
echo "API_KEY=${API_KEY}" > config.sh
git add config.sh
git commit -m "Add config (using env var)"
# ✅ No secrets detected
```

### Pre-Commit Hook Configuration

**Location**: `.githooks/pre-commit`

**What it checks**:
1. Active ticket claimed (workflow plugin)
2. No secrets in staged files (gitleaks)

**Bypass** (not recommended):
```bash
git commit --no-verify
```

### Installation

**In dev containers**: Auto-installed
**On local machine**:
```bash
# Install gitleaks
brew install gitleaks                # macOS
sudo apt-get install gitleaks        # Ubuntu/Debian
# Or see: https://github.com/gitleaks/gitleaks#installation
```

**Verify installation**:
```bash
gitleaks --version
```

### Configuration

**`.gitleaks.toml`**: Project-specific rules

- Define secret patterns to detect
- Add allowlist for false positives
- Customize sensitivity level

**Example**:
```toml
[allowlist]
description = "Allowlist for false positives"
regexes = [
    "example.com",           # Not a real secret
    "test_value_\\d{3}",     # Test patterns
]
```

---

## API Token Management

### Linear API Token Setup

**Getting your token**:

1. Go to [Linear Settings > API](https://linear.app/settings/api)
2. Click "Create New" under "Personal API Keys"
3. Copy the token (starts with `lin_api_`)
4. Never share this token

**Setting up in Doppler**:

```bash
doppler secrets set LINEAR_API_KEY="lin_api_xxxxxxxxxxxxx" \
  --project hht-diary-core --config dev
```

**Using with VS Code extension**:

1. Install "Linear Requirement Inserter" extension
2. Open VS Code Settings (Ctrl+,)
3. Search for "Linear Req Inserter"
4. Paste token into "Api Token" field
5. Settings automatically encrypted and never synced

**Scopes**: Read access to tickets, workspace, and requirements

**Rotation**: Every 90 days via Linear dashboard

### GitHub Personal Access Tokens

**Getting your token**:

1. Go to [GitHub Settings > Developer Settings > Personal Access Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Select scopes:
   - `repo` - Full repository access
   - `workflow` - Modify GitHub Actions workflows
   - `read:org` - Read organization data
4. Copy and store securely

**Never use in environment variables**:
- GitHub Codespaces auto-injects token
- CLI tools auto-authenticate
- Only set manually for direct API calls

**Scopes and Permissions**:

| Scope | Permission | Usage |
| --- | --- | --- |
| `repo` | Full repository access | Clone, push, pull |
| `workflow` | Modify workflows | Update GitHub Actions |
| `read:org` | Read organization data | View team members |

**Never grant**:
- `admin:org` - Full organization control
- `write:enterprise` - Enterprise access
- `delete_repo` - Repository deletion

**Rotation**: Every 90 days or when compromised

### Token Rotation Strategy

**Planned rotation** (every 90 days):

1. **Generate new token** with same scopes
2. **Update Doppler** with new token
3. **Test with Doppler**: `doppler run -- gh api user`
4. **Revoke old token** in service dashboard
5. **Document in changelog**

**Emergency rotation** (when leaked):

1. **Immediately revoke** the token
2. **Generate new token**
3. **Update Doppler** (takes effect immediately)
4. **Restart any running CI/CD** jobs
5. **Report incident** to security team

**Token expiration tracking**:

Create reminder calendar events for rotation dates:
```bash
# Example: Linear API token expires on date
echo "Linear API token - schedule rotation" \
 | at "3 months from now"
```

### Service Account Tokens

**For CI/CD systems** (not personal tokens):

1. Create service tokens in Doppler:
   ```bash
   doppler configs tokens create github-actions \
     --project hht-diary-core --config production
   ```

2. Store in GitHub (not in Doppler):
   - Settings > Secrets and variables > Actions
   - Create `DOPPLER_TOKEN_CORE`, `DOPPLER_TOKEN_CALLISTO`

3. Use in workflows:
   ```yaml
   - run: doppler run --token ${{ secrets.DOPPLER_TOKEN_CORE }} -- flutter build
   ```

**Benefits**:
- Separate from personal tokens
- Can be revoked independently
- Easier to rotate
- Audit trail per service

---

## Emergency Response

### What to Do If Secrets Are Leaked

**Immediate actions** (within 15 minutes):

1. **Confirm the leak**:
   - Check if secret is in git history
   - Check if it was pushed to remote
   - Determine scope (which files, which people have access)

2. **Revoke the credential**:
   - For API tokens: Revoke in service dashboard (Linear, GitHub, etc.)
   - For database: Change password immediately
   - For AWS: Deactivate access key, generate new one
   - For signing keys: Issue new key

3. **Notify team**:
   - Report to security team
   - Alert affected services/teams
   - Document in incident tracker

**Short-term actions** (within 1 hour):

4. **Remove from git history**:
   ```bash
   # Option 1: Rewrite history (if not yet pushed)
   git filter-branch --tree-filter 'rm -f path/to/secret' HEAD

   # Option 2: Force push (only if you have permission)
   git push --force-with-lease origin branch-name
   ```

5. **Update Doppler**:
   ```bash
   doppler secrets set LEAKED_SECRET="new-secure-value" \
     --project hht-diary-core --config production
   ```

6. **Restart services**:
   - Restart CI/CD pipeline
   - Restart running applications
   - Force new deployments

**Long-term actions** (24-48 hours):

7. **Investigation**:
   - Check logs for unauthorized access using leaked secret
   - Audit affected data/resources
   - Review user access during exposure period

8. **Post-mortem**:
   - Document what happened
   - Root cause analysis
   - Prevention measures
   - Process improvements

9. **Monitoring**:
   - Monitor affected services for suspicious activity
   - Check git repositories for re-exposure
   - Set up alerts for similar incidents

### Rotating Compromised Credentials

**AWS Access Keys**:

```bash
# 1. Create new key
aws iam create-access-key --user-name service-user

# 2. Update Doppler
doppler secrets set AWS_ACCESS_KEY_ID="AKIA..." \
  --project hht-diary-core --config production
doppler secrets set AWS_SECRET_ACCESS_KEY="new_secret" \
  --project hht-diary-core --config production

# 3. Restart services to pick up new key
# (Services using doppler run will get new key automatically)

# 4. Delete old key
aws iam delete-access-key --access-key-id AKIA_OLD \
  --user-name service-user
```

**API Tokens** (Linear, GitHub, etc.):

```bash
# 1. Revoke old token in service dashboard

# 2. Generate new token

# 3. Update Doppler
doppler secrets set LINEAR_API_KEY="lin_api_new..." \
  --project hht-diary-core --config dev

# 4. Update any IDE extensions/tools
# (Often auto-sync from environment variables)
```

**Database Passwords**:

```bash
# 1. Change password in database
ALTER ROLE db_user WITH PASSWORD 'new_secure_password';

# 2. Update Doppler
doppler secrets set SUPABASE_ACCESS_TOKEN="new_token" \
  --project hht-diary-core --config production

# 3. Restart database connections
```

### Notifying the Team

**Security incident notification**:

1. **To team lead** (immediately):
   - What leaked
   - Scope (which files, when)
   - Impact assessment
   - Immediate actions taken

2. **To security team** (within 1 hour):
   - Detailed incident report
   - Root cause analysis (if known)
   - Remediation steps
   - Timeline

3. **To affected stakeholders** (within 2 hours):
   - What to know
   - What has been done
   - What they need to do
   - Timeline for resolution

**Incident report template**:

```markdown
## Security Incident: Exposed Secret

**Type**: Exposed [SECRET_TYPE]
**Discovered**: [DATE_TIME]
**Scope**: [DESCRIPTION]
**Files Affected**: [LIST]

### Immediate Actions
- [ ] Secret revoked
- [ ] New credential generated
- [ ] Doppler updated
- [ ] Services restarted

### Investigation
- [ ] Audit logs reviewed
- [ ] Unauthorized access detected: [YES/NO]
- [ ] Scope of unauthorized access: [DESCRIPTION]

### Prevention
- [ ] Root cause identified
- [ ] Process improvements implemented
- [ ] Team trained on prevention
```

---

## Best Practices

### Core Principles

1. **Use Doppler for ALL secrets**
   - Never commit secrets to git
   - Never use `.env` files with real secrets
   - Always prefix with `doppler run --`

2. **Never commit `.env` files**
   - Even `.env.example` can leak patterns
   - Use Doppler instead
   - Document required secrets in code comments

3. **Rotate tokens regularly**
   - API tokens: Every 90 days
   - AWS keys: Every 90 days
   - Database passwords: Annually
   - Use calendar reminders

4. **Use minimal scopes**
   - Only request permissions you need
   - Remove unused permissions
   - Principle of least privilege

5. **Document secret requirements**
   - List all secrets your service needs
   - Document when/how to rotate
   - Keep setup guides current

### Setup Checklist

**For new developers**:
- [ ] Doppler CLI installed
- [ ] Logged in with personal account
- [ ] Project configured (`doppler setup`)
- [ ] Test: `doppler secrets list`
- [ ] Test: `doppler run -- env | grep DOPPLER`
- [ ] IDE configured (if using extensions)
- [ ] `.gitignore` updated (don't commit Doppler config)

**For new secrets**:
- [ ] Documented in setup guide
- [ ] Set in Doppler (not in `.env`)
- [ ] Rotated from previous value
- [ ] Team notified of addition
- [ ] CI/CD updated if needed

**For new services**:
- [ ] Doppler project created (if sponsor-specific)
- [ ] Service token generated for CI/CD
- [ ] GitHub Actions secrets added
- [ ] Workflows updated with new secret names
- [ ] Local setup documented
- [ ] Team trained on setup

### Development Workflow

**Starting work**:
```bash
# Configure Doppler (first time only)
doppler setup

# Daily work
doppler run -- flutter run
doppler run -- npm start
doppler run -- npm test

# View what's available
doppler secrets list
```

**Adding a new secret**:
```bash
# 1. Request access from team lead

# 2. Ask DevOps to add to Doppler
# (You cannot add secrets yourself for security)

# 3. Verify it's available
doppler secrets list | grep MY_SECRET

# 4. Use in code
export MY_SECRET=$(doppler secrets get MY_SECRET --plain)
# Or just use: doppler run -- [your command]
```

**Team sharing**:
```bash
# Never send secrets in chat/email
# Instead: Ask DevOps to add to Doppler
# Team members auto-get latest values
```

### Security Hardening Checklist

**Local development**:
- [ ] Doppler CLI installed and working
- [ ] Using `doppler run --` for all commands
- [ ] No `.env` files with real secrets
- [ ] IDE extensions using environment variables
- [ ] `.gitignore` includes all secret files
- [ ] Pre-commit hooks installed and working

**Team setup**:
- [ ] All developers use Doppler
- [ ] New developers have onboarding guide
- [ ] Secret rotation schedule established
- [ ] Token expiration tracking in place
- [ ] Emergency procedures documented
- [ ] Security training completed

**CI/CD setup**:
- [ ] Service tokens (not personal) in GitHub
- [ ] Tokens rotated annually
- [ ] Minimal scopes for each token
- [ ] GitHub secret scanning enabled
- [ ] Secret scanning in CI pipeline
- [ ] Pre-commit hooks in use

**Compliance**:
- [ ] Audit trail enabled in Doppler
- [ ] Access logs reviewed monthly
- [ ] Secrets rotation documented
- [ ] Incident response procedure tested
- [ ] Security awareness training current
- [ ] FDA compliance requirements met

---

## Troubleshooting

### Common Issues

**"Project not found" error**

**Cause**: No access to Doppler project

**Solution**:
1. Verify you have Doppler account
2. Ask team lead to invite you to workspace
3. Accept invitation in Doppler dashboard
4. Try `doppler setup` again

```bash
doppler me  # Check account status
```

**"Config not found" error**

**Cause**: Selected config doesn't exist

**Solution**:
```bash
# List available configs
doppler configs list --project hht-diary-core

# Select existing one
doppler setup --project hht-diary-core --config dev
```

**"Secrets not loading" in application**

**Cause**: Not running with doppler, or wrong config selected

**Solution**:
```bash
# Verify active config
doppler configure get

# Verify running with doppler
doppler run -- env | grep SUPABASE

# Test secret access
doppler secrets get SUPABASE_PROJECT_ID --plain
```

**"gitleaks: command not found"**

**Cause**: Secret scanning tool not installed

**Solution**:
```bash
# macOS
brew install gitleaks

# Ubuntu/Debian
sudo apt-get install gitleaks

# Verify
gitleaks --version
```

If gitleaks not installed, pre-commit hook warns but doesn't block commits.

**"Too many requests" from Doppler**

**Cause**: Rate limiting (rare)

**Solution**:
1. Wait 5-10 minutes
2. For frequent local runs, cache temporarily:
   ```bash
   doppler secrets download --no-file --format env > .env.local.temp
   # Use temporarily (NOT committing!)
   source .env.local.temp
   rm .env.local.temp
   ```

**"Wrong secrets loaded"**

**Cause**: Using different config than expected

**Solution**:
```bash
# Check current config
cat .doppler.yaml

# Check environment-specific config
doppler run --config staging -- echo $SUPABASE_PROJECT_ID

# Manually specify config
doppler run --config dev -- flutter run
```

### Debugging

**View all environment variables**:
```bash
doppler run -- printenv | sort
```

**Test specific secret**:
```bash
doppler secrets get SECRET_NAME --plain
```

**Check Doppler status**:
```bash
doppler me
doppler configure get
doppler projects list
doppler configs list --project hht-diary-core
```

**Test CI/CD token**:
```bash
doppler secrets list --token $DOPPLER_TOKEN_CORE
```

---

## References

### Internal Documentation

- **Doppler Setup Guides**:
  - `docs/setup-doppler.md` - Overview and quick links
  - `docs/setup-doppler-project.md` - Project infrastructure setup
  - `docs/setup-doppler-new-sponsor.md` - Sponsor onboarding
  - `docs/setup-doppler-new-dev.md` - Developer setup

- **Security Documentation**:
  - `spec/ops-security.md` - Database security architecture
  - `CLAUDE.md` - Project instructions and requirements

- **Requirements**:
  - `spec/INDEX.md` - Complete requirements index
  - `REQ-d00069`: Doppler manifest system
  - `REQ-o00015`: Secrets management
  - `REQ-p00001`: Sponsor isolation

### External Resources

- **Doppler Documentation**: https://docs.doppler.com/
- **Doppler CLI**: https://docs.doppler.com/docs/cli
- **GitHub Actions Integration**: https://docs.doppler.com/docs/github-actions
- **gitleaks**: https://github.com/gitleaks/gitleaks
- **Linear API**: https://developers.linear.app/
- **AWS CLI**: https://docs.aws.amazon.com/cli/

### Related Tools

- **Linear Requirement Inserter**: VS Code extension for inserting requirements
  - Setup: `tools/vscode-linear-req-inserter/README.md`
  - Get Linear API token via this guide

- **Workflow Plugin**: Enforces requirement traceability
  - Documentation: `tools/anspar-cc-plugins/plugins/workflow/README.md`
  - Includes secret detection via gitleaks

---

## Contact and Support

**Security questions**: Contact security team
**Doppler access issues**: Contact DevOps lead
**Secret rotation scheduling**: DevOps admin
**Incident reporting**: Security team (immediately)

**Key team roles**:
- **DevOps admin**: Creates/manages Doppler projects and tokens
- **Team lead**: Invites developers, approves access
- **Security team**: Rotates critical secrets, investigates incidents
- **Developers**: Daily Doppler usage, local setup

---

## Document Information

**Version**: 1.0.0
**Last Updated**: 2025-11-11
**Owner**: DevOps / Security Team
**Review Frequency**: Quarterly or after security incidents

**File Location**: `/home/mclew/dev24/diary-worktrees/clean-docs/docs/security-secret-management.md`
