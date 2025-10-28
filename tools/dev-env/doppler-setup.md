# Doppler Secrets Management Setup

**Implements**: REQ-d00031 (Secrets Management via Doppler)

This guide covers setting up Doppler for secure secrets management across development environments.

---

## Why Doppler?

- ✅ Zero-knowledge encryption (secrets never in Git)
- ✅ Audit logs (who accessed what secret, when)
- ✅ Role-based access control
- ✅ Secret rotation without code changes
- ✅ Free tier for small teams
- ✅ Native Docker integration

---

## Prerequisites

1. Doppler account (free): https://doppler.com/
2. Doppler CLI installed (included in Docker containers)
3. Project created in Doppler dashboard

---

## Initial Setup

### Step 1: Create Doppler Account

```bash
# Sign up at https://doppler.com/
# or via CLI:
doppler login
```

### Step 2: Create Projects

Create separate projects for each environment:

```bash
# Create projects via Doppler dashboard or CLI
doppler projects create clinical-diary-dev
doppler projects create clinical-diary-staging
doppler projects create clinical-diary-prod
```

### Step 3: Configure Environments

For each project, set up environments:
- `dev` - Local development
- `ci` - GitHub Actions / CI/CD
- `prod` - Production builds

---

## Secrets to Configure

### GitHub Tokens (per role)

Create GitHub Personal Access Tokens with minimal scopes:

**Developer Token** (`GH_TOKEN_DEV`):
- Scopes: `repo`, `read:org`
- Use: Clone repos, create branches, push commits

**QA Token** (`GH_TOKEN_QA`):
- Scopes: `repo`, `checks:write`, `pull_requests:write`
- Use: Run tests, post check results, comment on PRs

**DevOps Token** (`GH_TOKEN_OPS`):
- Scopes: `workflow`, `repo_deployment`, `packages:write`
- Use: Trigger workflows, deploy, push container images

**Management Token** (`GH_TOKEN_MGMT`):
- Scopes: `read:org`, `read:repo_hook`, `read:packages`
- Use: View-only access to repos and deployments

### Supabase Credentials

**Supabase Service Role Key** (`SUPABASE_SERVICE_TOKEN`):
- Get from: Supabase Dashboard → Settings → API → service_role key
- Use: Database migrations, admin operations

**Supabase Project Reference** (`SUPABASE_PROJECT_REF`):
- Get from: Supabase Dashboard → Settings → General → Reference ID
- Use: Constructing Supabase API URLs

### Anthropic API Key

**Claude API Key** (`ANTHROPIC_API_KEY`):
- Get from: https://console.anthropic.com/
- Use: Claude Code CLI integration

---

## Adding Secrets to Doppler

### Via Dashboard (Recommended for initial setup)

1. Navigate to project: `clinical-diary-dev`
2. Select environment: `dev`
3. Click "Add Secret"
4. Enter key-value pairs:

```
GH_TOKEN_DEV=ghp_xxxxxxxxxxxxxxxxxxxx
GH_TOKEN_QA=ghp_yyyyyyyyyyyyyyyyyyyy
GH_TOKEN_OPS=ghp_zzzzzzzzzzzzzzzzzzzz
GH_TOKEN_MGMT=ghp_aaaaaaaaaaaaaaaaaaa
SUPABASE_SERVICE_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_PROJECT_REF=abcdefghijklmnop
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxx
```

### Via CLI

```bash
# Set secrets for dev environment
doppler secrets set GH_TOKEN_DEV="ghp_xxxx" --project clinical-diary-dev --config dev
doppler secrets set GH_TOKEN_QA="ghp_yyyy" --project clinical-diary-dev --config dev
# ... etc
```

---

## Usage in Containers

### Method 1: Doppler Run (Recommended)

Inject secrets at runtime without persisting to disk:

```bash
# Inside dev container
doppler run -- gh auth login

# Or for entire shell session
doppler run -- bash
# Now all commands have access to secrets
```

### Method 2: Service Tokens (for CI/CD)

Generate service tokens for automated access:

```bash
# Generate token (do this in Doppler dashboard)
# Settings → Service Tokens → Generate

# In GitHub Actions, add as repository secret
# Settings → Secrets → Actions → New repository secret
# Name: DOPPLER_TOKEN_DEV
# Value: dp.st.xxxxxxxxxxxx
```

### Method 3: Docker Compose Integration

Already configured in `docker-compose.yml`:

```yaml
environment:
  - DOPPLER_PROJECT=clinical-diary-dev
```

Then inside container:

```bash
# Login once
doppler login

# Configure project
doppler setup --project clinical-diary-dev --config dev

# Use secrets
doppler run -- ./your-command
```

---

## Container-Specific Configuration

### Dev Container

```bash
# Enter dev container
docker-compose exec dev bash

# One-time setup
doppler login
doppler setup --project clinical-diary-dev --config dev

# Authenticate GitHub
doppler run -- gh auth login

# Authenticate Supabase
doppler run -- supabase link --project-ref $(doppler secrets get SUPABASE_PROJECT_REF --plain)

# Run development commands
doppler run -- flutter run
doppler run -- npm start
```

### QA Container

```bash
# Enter QA container
docker-compose exec qa bash

# Setup
doppler login
doppler setup --project clinical-diary-dev --config dev

# Authenticate for QA tasks
doppler run -- gh auth login

# Run tests with secrets
doppler run -- /usr/local/bin/qa-runner.sh
```

### Ops Container

```bash
# Enter ops container
docker-compose exec ops bash

# Setup
doppler login
doppler setup --project clinical-diary-dev --config dev

# Authenticate for deployment
doppler run -- gh auth login
doppler run -- aws configure  # if using AWS

# Deploy with secrets
doppler run -- terraform apply
doppler run -- supabase db push
```

### Mgmt Container

```bash
# Enter mgmt container
docker-compose exec mgmt bash

# Setup (read-only token)
doppler login
doppler setup --project clinical-diary-dev --config dev

# View-only access
doppler run -- gh pr list
doppler run -- git log --oneline
```

---

## GitHub Actions Integration

In `.github/workflows/*.yml`:

```yaml
- name: Fetch secrets from Doppler
  uses: dopplerhq/cli-action@v3

- name: Run tests with secrets
  run: doppler run -- npm test
  env:
    DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN_DEV }}
```

---

## Secret Rotation

Doppler makes rotation easy:

1. Generate new token (GitHub, Supabase, etc.)
2. Update in Doppler dashboard
3. No code changes needed
4. Next `doppler run` uses new secret
5. Old token can be revoked

**Rotation Schedule**:
- GitHub PATs: Every 90 days
- Supabase keys: Every 180 days
- API keys: Per vendor recommendation

---

## Audit Logs

View who accessed secrets:

1. Doppler Dashboard → Activity
2. Filter by secret name
3. See: user, timestamp, IP address

**Compliance**: Audit logs satisfy FDA 21 CFR Part 11 traceability requirements.

---

## Security Best Practices

✅ **DO**:
- Use `doppler run --` to inject secrets
- Use service tokens for CI/CD
- Rotate secrets regularly
- Review audit logs monthly
- Use minimum-privilege scopes

❌ **DON'T**:
- Export secrets to environment variables
- Commit secrets to Git
- Share personal Doppler login
- Use production secrets in dev
- Echo or log secret values

---

## Troubleshooting

### "doppler: command not found"

```bash
# Rebuild container (Doppler should be in base image)
docker-compose build dev
```

### "You are not logged in"

```bash
doppler login
# Opens browser for authentication
```

### "Project not found"

```bash
# Verify project exists
doppler projects list

# Setup explicitly
doppler setup --project clinical-diary-dev --config dev
```

### "Failed to fetch secrets"

```bash
# Check authentication
doppler me

# Verify network access
curl https://api.doppler.com/

# Check project access
doppler configs --project clinical-diary-dev
```

---

## Alternative: Environment Variables (Fallback)

If Doppler is unavailable, use environment variables temporarily:

```bash
# Create .env file (NEVER COMMIT THIS)
cat > .env <<EOF
GH_TOKEN_DEV=ghp_xxxx
SUPABASE_SERVICE_TOKEN=eyJhbGci...
EOF

# Load in container
docker-compose --env-file .env up
```

**Security Warning**: This method has no audit trail and secrets persist to disk. Use only for local development fallback.

---

## Questions for User

1. Do you already have a Doppler account, or should we set one up?
2. Which GitHub organization owns the repository? (for token scoping)
3. Do you have a Supabase project created yet?
4. Should we use Doppler service tokens for CI/CD, or GitHub Secrets?

---

**See Also**:
- Doppler Documentation: https://docs.doppler.com/
- REQ-d00031: Secrets Management via Doppler
- docs/adr/ADR-006-docker-dev-environments.md
