# Doppler Setup for New Sponsors

**Audience**: DevOps / Project Administrator
**Frequency**: Once per new sponsor onboarding
**Prerequisites**:
- Doppler CLI installed (see [doppler-setup-project.md](./doppler-setup-project.md))
- Admin access to Doppler organization
- New sponsor's configuration details

## IMPLEMENTS REQUIREMENTS
- REQ-d00069: Doppler manifest system
- REQ-o00015: Secrets management
- REQ-p00001: Sponsor isolation

## Overview

This document describes how to add a new pharmaceutical sponsor to the HHT Diary platform. Each sponsor receives:
- Isolated Doppler project for sponsor-specific secrets
- Entry in the core sponsor manifest
- GitHub Actions integration for CI/CD
- Separate staging and production environments

**Before starting**, gather the following information for the new sponsor:

| Information | Example | Notes |
| --- | --- | --- |
| Sponsor name (lowercase) | `titan` | Used in project names, URLs |
| Sponsor code (3 letters) | `TTN` | Used in identifiers |
| AWS region | `us-west-2` | Geographic deployment region |
| Supabase project ID (staging) | `titan-portal-staging` | From Supabase dashboard |
| Supabase project ID (production) | `titan-portal-prod` | From Supabase dashboard |
| Supabase access token | `sbp_xxxxxxxxxxxxx` | From Supabase settings |
| AWS credentials | Access key + secret | For sponsor-specific infrastructure |
| Has portal? | `true` / `false` | Web portal or direct EDC integration |
| Has mobile module? | `true` | Usually `true` for all sponsors |

## Step-by-Step Setup

### 1. Create Sponsor Doppler Project

Replace `<sponsor>` with the sponsor's name (lowercase):

```bash
doppler projects create hht-diary-<sponsor>
```

**Example**:
```bash
doppler projects create hht-diary-titan
```

### 2. Create Sponsor Configurations

```bash
doppler configs create staging --project hht-diary-<sponsor>
doppler configs create production --project hht-diary-<sponsor>
```

### 3. Set Staging Environment Secrets

```bash
# Supabase credentials
doppler secrets set SUPABASE_PROJECT_ID="<sponsor>-portal-staging" \
  --project hht-diary-<sponsor> --config staging

doppler secrets set SUPABASE_ACCESS_TOKEN="sbp_xxxxxxxxxxxxx" \
  --project hht-diary-<sponsor> --config staging

# AWS credentials
doppler secrets set SPONSOR_AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXX" \
  --project hht-diary-<sponsor> --config staging

doppler secrets set SPONSOR_AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxx" \
  --project hht-diary-<sponsor> --config staging

# Optional: Sponsor-specific API keys or module secrets
doppler secrets set MOBILE_MODULE_SECRETS='{"api_key": "xxx"}' \
  --project hht-diary-<sponsor> --config staging
```

### 4. Set Production Environment Secrets

Repeat step 3 with production values:

```bash
doppler secrets set SUPABASE_PROJECT_ID="<sponsor>-portal-prod" \
  --project hht-diary-<sponsor> --config production

doppler secrets set SUPABASE_ACCESS_TOKEN="sbp_production_token" \
  --project hht-diary-<sponsor> --config production

# ... repeat for all production secrets
```

### 5. Update Core Sponsor Manifest

The sponsor manifest in `hht-diary-core` controls which sponsors are active and their configuration.

First, retrieve the current manifest:

```bash
doppler secrets get SPONSOR_MANIFEST --project hht-diary-core --config production --plain
```

Then update it to include the new sponsor:

```bash
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

  - name: <sponsor>
    code: <CODE>
    enabled: true
    repo: local  # or: cure-hht/sponsor-<name> for multi-repo
    tag: main    # or: v1.0.0 for multi-repo
    mobile_module: true
    portal: true  # or false if direct EDC integration
    region: <aws-region>
EOF
```

**Example for Titan sponsor**:
```yaml
  - name: titan
    code: TTN
    enabled: true
    repo: local
    tag: main
    mobile_module: true
    portal: true
    region: us-west-2
```

**Repeat for staging and dev configurations** with appropriate enabled flags.

### 6. Generate Service Tokens for CI/CD

Create tokens for GitHub Actions:

```bash
# Staging token
doppler configs tokens create github-actions \
  --project hht-diary-<sponsor> --config staging

# Production token
doppler configs tokens create github-actions \
  --project hht-diary-<sponsor> --config production
```

**Save these tokens securely** - you'll need them in the next step.

### 7. Add Tokens to GitHub Repository Secrets

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Add new repository secrets:
   - `DOPPLER_TOKEN_<sponsor>` (e.g., `DOPPLER_TOKEN_titan`)
   - `AWS_ACCESS_KEY_ID_<sponsor>` (e.g., `AWS_ACCESS_KEY_ID_titan`)
   - `AWS_SECRET_ACCESS_KEY_<sponsor>` (e.g., `AWS_SECRET_ACCESS_KEY_titan`)

**Naming convention**: Use **lowercase** sponsor name for the GitHub secret suffix to match the workflow configuration in Step 8.

**Values**:
- `DOPPLER_TOKEN_<sponsor>`: Production token from step 6
- `AWS_ACCESS_KEY_ID_<sponsor>`: From step 4 (production AWS credentials)
- `AWS_SECRET_ACCESS_KEY_<sponsor>`: From step 4 (production AWS credentials)

### 8. Update CI/CD Workflows (REQUIRED)

**IMPORTANT**: You must update GitHub Actions workflows to include the new sponsor.

#### Update build-integrated.yml

Edit `.github/workflows/build-integrated.yml` and add the new sponsor to the matrix includes section (around line 156-165):

```yaml
strategy:
  matrix:
    include:
      - sponsor: callisto
        doppler_secret: DOPPLER_TOKEN_callisto
        aws_key_secret: AWS_ACCESS_KEY_ID_callisto
        aws_secret_secret: AWS_SECRET_ACCESS_KEY_callisto

      # Add new sponsor here:
      - sponsor: titan  # Replace with your sponsor name (lowercase)
        doppler_secret: DOPPLER_TOKEN_titan
        aws_key_secret: AWS_ACCESS_KEY_ID_titan
        aws_secret_secret: AWS_SECRET_ACCESS_KEY_titan
```

**Naming conventions:**
- `sponsor`: Lowercase sponsor name (must match directory name in `sponsor/`)
- `doppler_secret`: `DOPPLER_TOKEN_<sponsor>` (lowercase)
- `aws_key_secret`: `AWS_ACCESS_KEY_ID_<sponsor>` (lowercase)
- `aws_secret_secret`: `AWS_SECRET_ACCESS_KEY_<sponsor>` (lowercase)

**Important**: The GitHub secret names you created in Step 7 must match these references exactly.

#### GitHub Secrets Naming

Ensure you've created these GitHub secrets (Step 7):
- `DOPPLER_TOKEN_titan` (or your sponsor name in lowercase)
- `AWS_ACCESS_KEY_ID_titan`
- `AWS_SECRET_ACCESS_KEY_titan`

**Security Note**: This explicit configuration is required for compliance with CodeQL security scanning and maintains sponsor isolation during CI/CD builds.

### 9. Verify Setup

Run these checks to ensure everything is configured correctly:

```bash
# Verify sponsor project exists
doppler projects list | grep hht-diary-<sponsor>

# Verify configs exist
doppler configs list --project hht-diary-<sponsor>

# Verify secrets are set (staging)
doppler secrets list --project hht-diary-<sponsor> --config staging

# Verify secrets are set (production)
doppler secrets list --project hht-diary-<sponsor> --config production

# Verify manifest includes new sponsor
doppler secrets get SPONSOR_MANIFEST --project hht-diary-core --config production --plain | grep <sponsor>
```

### 10. Create Sponsor Directory (Mono-Repo)

If using mono-repo structure, create the sponsor's directory in the repository:

```bash
mkdir -p sponsor/<sponsor>
touch sponsor/<sponsor>/README.md
```

Add basic configuration files as needed per your architecture.

## Security Verification

Before completing sponsor onboarding, verify:

- [ ] All production secrets use strong, unique values
- [ ] Staging and production secrets are different
- [ ] Service tokens have minimal required permissions
- [ ] GitHub Actions secrets are added correctly
- [ ] GitHub Actions workflow matrix updated in `build-integrated.yml` (Step 8)
- [ ] Secret naming conventions match between GitHub and workflow configuration
- [ ] Sponsor manifest updated in all environments (dev, staging, production)
- [ ] No secrets committed to git repository
- [ ] Sponsor isolation verified (no cross-sponsor data access possible)

## Testing Integration

Test the new sponsor setup:

1. **Local test**: Run application with new sponsor configuration
   ```bash
   doppler run --project hht-diary-<sponsor> --config staging -- flutter run
   ```

2. **CI/CD test**: Trigger a GitHub Actions workflow that uses the new sponsor secrets

3. **Database test**: Verify Supabase connection works with provided credentials

4. **Portal test** (if applicable): Access sponsor portal at unique URL

## Multi-Repo Setup (Future)

For multi-repo sponsor isolation:

1. Create separate repository: `cure-hht/sponsor-<name>`
2. Update sponsor manifest with repository path:
   ```yaml
   repo: cure-hht/sponsor-<name>
   tag: v1.0.0
   ```
3. Ensure `SPONSOR_REPO_TOKEN` is set in `hht-diary-core` for cloning access
4. **Update `.gitignore`**: Remove sponsor from whitelist (delete `!sponsor/{name}/` line)
   - This prevents accidentally committing locally cloned sponsor repos to core

## Troubleshooting

### "Project already exists" error

The sponsor may have been partially set up. List projects:
```bash
doppler projects list
```

If the project exists, skip to step 2 (create configs) or step 3 (set secrets).

### Manifest update not reflecting

Ensure you updated the manifest in the correct environment:
```bash
doppler secrets get SPONSOR_MANIFEST --project hht-diary-core --config production --plain
```

### Token authentication fails in GitHub Actions

Verify:
1. Secret name matches exactly (case-sensitive)
2. Token is from the correct Doppler project and config
3. Token has not expired (list tokens: `doppler configs tokens list`)

### Sponsor isolation concerns

Verify sponsor isolation per `spec/prd-architecture-multi-sponsor.md`:
- Separate Supabase project per sponsor
- Separate Doppler project per sponsor
- Sponsor manifest correctly isolates configurations
- No shared credentials across sponsors

## Offboarding a Sponsor

To disable a sponsor without deleting data:

1. Set `enabled: false` in sponsor manifest:
   ```yaml
   - name: <sponsor>
     enabled: false  # Disable sponsor
     # ... rest of config
   ```

2. Revoke GitHub Actions service tokens:
   ```bash
   doppler configs tokens revoke <token-slug> --project hht-diary-<sponsor> --config production
   ```

3. Archive Doppler project (don't delete - needed for audit trail):
   ```bash
   # Contact Doppler support to archive project
   ```

## References

- Project Setup: [doppler-setup-project.md](./doppler-setup-project.md)
- Developer Setup: [doppler-setup-new-dev.md](./doppler-setup-new-dev.md)
- Sponsor Manifest Schema: `.github/config/sponsor-manifest-schema.yml`
- Multi-Sponsor Architecture: `spec/prd-architecture-multi-sponsor.md`
- Security Best Practices: `spec/ops-security.md`
- Doppler Documentation: https://docs.doppler.com/
