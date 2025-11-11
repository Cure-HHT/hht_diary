# Doppler Configuration Setup

This document describes how to set up and manage Doppler projects for the HHT Diary platform.

## IMPLEMENTS REQUIREMENTS
- REQ-d00069: Doppler manifest system
- REQ-o00015: Secrets management

## Overview

The HHT Diary platform uses Doppler for centralized secrets management with a nested project structure:
- **hht-diary-core**: Core application secrets and sponsor manifest
- **hht-diary-{sponsor}**: Per-sponsor secrets (e.g., `hht-diary-callisto`)

## Project Structure

### hht-diary-core

Contains core application secrets and the sponsor inclusion manifest.

**Configs**: `dev`, `staging`, `production`

**Secrets**:

| Secret | Description | Example |
|--------|-------------|---------|
| `SPONSOR_MANIFEST` | YAML manifest of enabled sponsors | See schema below |
| `SPONSOR_REPO_TOKEN` | GitHub PAT for cloning sponsor repos (future multi-repo) | `ghp_xxxxxxxxxxxxx` |
| `APP_STORE_CREDENTIALS` | Apple/Google store credentials | JSON blob |
| `CORE_AWS_ACCESS_KEY_ID` | Core infrastructure AWS access key | `AKIAXXXXXXXXXXXXX` |
| `CORE_AWS_SECRET_ACCESS_KEY` | Core infrastructure AWS secret key | `xxxxxxxxxxxxxxxx` |

### hht-diary-callisto

Contains Callisto sponsor-specific secrets.

**Configs**: `production`, `staging`

**Secrets**:

| Secret | Description | Example |
|--------|-------------|---------|
| `SUPABASE_ACCESS_TOKEN` | Callisto Supabase access token | `sbp_xxxxxxxxxxxxx` |
| `SUPABASE_PROJECT_ID` | Callisto Supabase project ID | `callisto-portal-prod` |
| `SPONSOR_AWS_ACCESS_KEY_ID` | Callisto-specific AWS access key | `AKIAXXXXXXXXXXXXX` |
| `SPONSOR_AWS_SECRET_ACCESS_KEY` | Callisto-specific AWS secret key | `xxxxxxxxxxxxxxxx` |
| `MOBILE_MODULE_SECRETS` | Callisto-specific API keys | JSON blob |

## Sponsor Manifest Schema

The `SPONSOR_MANIFEST` secret in `hht-diary-core` follows the schema defined in `.github/config/sponsor-manifest-schema.yml`.

### Current Mono-Repo Example

```yaml
sponsors:
  - name: callisto
    code: CAL
    enabled: true
    repo: local  # Points to sponsor/callisto/ directory
    tag: main    # Not used in mono-repo mode
    mobile_module: true
    portal: true
    region: eu-west-1
```

### Future Multi-Repo Example

```yaml
sponsors:
  - name: callisto
    code: CAL
    enabled: true
    repo: cure-hht/sponsor-callisto  # Separate repository
    tag: v1.2.3                       # Locked to specific version
    mobile_module: true
    portal: true
    region: eu-west-1

  - name: titan
    code: TIT
    enabled: true
    repo: cure-hht/sponsor-titan
    tag: v2.0.1
    mobile_module: true
    portal: false  # Direct EDC integration, no portal
    region: us-west-2
```

## Setup Instructions

### Prerequisites

- Doppler CLI installed: `brew install dopplerhq/cli/doppler` (macOS) or see https://docs.doppler.com/docs/install-cli
- Doppler account with appropriate permissions
- GitHub account for CI/CD integration

### 1. Install Doppler CLI

```bash
# macOS
brew install dopplerhq/cli/doppler

# Linux
(curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh || wget -t 3 -qO- https://cli.doppler.com/install.sh) | sudo sh

# Verify installation
doppler --version
```

### 2. Login to Doppler

```bash
doppler login
```

This will open a browser window for authentication.

### 3. Create Projects

```bash
# Create core project
doppler projects create hht-diary-core

# Create sponsor project (example: Callisto)
doppler projects create hht-diary-callisto
```

### 4. Create Configs

```bash
# Create configs for core project
doppler configs create dev --project hht-diary-core
doppler configs create staging --project hht-diary-core
doppler configs create production --project hht-diary-core

# Create configs for sponsor project
doppler configs create staging --project hht-diary-callisto
doppler configs create production --project hht-diary-callisto
```

### 5. Set Secrets

#### Core Project Secrets

```bash
# Set sponsor manifest (mono-repo example)
doppler secrets set SPONSOR_MANIFEST --project hht-diary-core --config production <<'EOF'
sponsors:
  - name: callisto
    code: CAL
    enabled: true
    repo: local
    tag: main
    mobile_module: true
    portal: true
    region: eu-west-1
EOF

# Set AWS credentials (example)
doppler secrets set CORE_AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXX" --project hht-diary-core --config production
doppler secrets set CORE_AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxx" --project hht-diary-core --config production
```

#### Sponsor Project Secrets

```bash
# Set Callisto Supabase credentials
doppler secrets set SUPABASE_PROJECT_ID="callisto-portal-prod" --project hht-diary-callisto --config production
doppler secrets set SUPABASE_ACCESS_TOKEN="sbp_xxxxxxxxxxxxx" --project hht-diary-callisto --config production

# Set Callisto AWS credentials
doppler secrets set SPONSOR_AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXX" --project hht-diary-callisto --config production
doppler secrets set SPONSOR_AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxx" --project hht-diary-callisto --config production
```

### 6. Link Repository (CI/CD Integration)

```bash
# In repository root
doppler setup --project hht-diary-core --config production

# Verify setup
doppler run -- env | grep DOPPLER
```

## Usage in CI/CD

### GitHub Actions Integration

Add Doppler token to GitHub Secrets:

1. Generate service token: `doppler configs tokens create github-actions --project hht-diary-core --config production`
2. Add to GitHub Secrets as `DOPPLER_TOKEN_CORE`
3. Repeat for each sponsor project

**Workflow Example**:

```yaml
name: Build Integrated App

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Doppler CLI
        uses: dopplerhq/cli-action@v3

      - name: Load Core Secrets
        run: |
          doppler secrets download --no-file --format env \
            --token ${{ secrets.DOPPLER_TOKEN_CORE }} > core.env

      - name: Load Callisto Secrets
        run: |
          doppler secrets download --no-file --format env \
            --token ${{ secrets.DOPPLER_TOKEN_CALLISTO }} > callisto.env

      - name: Parse Sponsor Manifest
        run: |
          source core.env
          echo "$SPONSOR_MANIFEST" > /tmp/manifest.yml
          # Process manifest...
```

## Local Development

### Run Commands with Doppler

```bash
# Run with production secrets
doppler run --project hht-diary-core --config production -- flutter build apk

# Run with staging secrets
doppler run --project hht-diary-core --config staging -- flutter run

# Run with development secrets
doppler run --project hht-diary-core --config dev -- npm start
```

### Environment-Specific Configs

Create `.doppler.yaml` in repository root:

```yaml
setup:
  project: hht-diary-core
  config: dev
```

Then simply run:

```bash
doppler run -- flutter run
```

## Security Best Practices

1. **Never commit secrets to git**
   - All secrets managed via Doppler
   - No `.env` files in repository
   - `.gitignore` includes `.doppler*` and `*.env`

2. **Use service tokens for CI/CD**
   - Generate scoped tokens for each environment
   - Rotate tokens regularly
   - Never use personal tokens in CI/CD

3. **Principle of least privilege**
   - Grant minimum necessary access
   - Separate staging/production tokens
   - Audit access regularly

4. **Backup secrets**
   - Doppler provides automatic backups
   - Export secrets to secure offline storage for disaster recovery:
     ```bash
     doppler secrets download --project hht-diary-core --config production --format json > backup-$(date +%Y%m%d).json.gpg
     ```

## Troubleshooting

### "Project not found" error

```bash
# List available projects
doppler projects list

# Verify you're logged in
doppler me
```

### "Config not found" error

```bash
# List configs for project
doppler configs list --project hht-diary-core

# Create missing config
doppler configs create <config-name> --project hht-diary-core
```

### Secrets not loading in CI/CD

1. Verify service token is valid: `doppler configs tokens list --project hht-diary-core --config production`
2. Check token has correct permissions
3. Ensure `DOPPLER_TOKEN_*` secrets are set in GitHub repository settings
4. Verify workflow uses correct token variable

## Migration from .env Files

If migrating from `.env` files:

```bash
# Import from .env file
doppler secrets upload --project hht-diary-core --config dev .env

# Verify import
doppler secrets list --project hht-diary-core --config dev
```

## Adding New Sponsors

When adding a new sponsor:

1. Create Doppler project:
   ```bash
   doppler projects create hht-diary-<sponsor-name>
   ```

2. Create configs (staging, production)

3. Set sponsor-specific secrets

4. Update `SPONSOR_MANIFEST` in `hht-diary-core`:
   ```bash
   doppler secrets set SPONSOR_MANIFEST --project hht-diary-core --config production <<'EOF'
   sponsors:
     - name: callisto
       # ... existing config
     - name: <new-sponsor>
       code: XXX
       enabled: true
       repo: cure-hht/sponsor-<name>
       tag: v1.0.0
       mobile_module: true
       portal: true
       region: us-east-1
   EOF
   ```

5. Generate service token for CI/CD

6. Add to GitHub Secrets as `DOPPLER_TOKEN_<SPONSOR>`

## References

- Doppler Documentation: https://docs.doppler.com/
- GitHub Actions Integration: https://docs.doppler.com/docs/github-actions
- Sponsor Manifest Schema: `.github/config/sponsor-manifest-schema.yml`
- Security Best Practices: `spec/ops-security.md`
