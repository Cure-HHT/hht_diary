# Doppler Project Setup (One-Time)

**Audience**: DevOps / Project Administrator
**Frequency**: Once per project (once for this project, once for any future clones)
**Prerequisites**: Doppler account with admin permissions

## IMPLEMENTS REQUIREMENTS
- REQ-d00069: Doppler manifest system
- REQ-o00015: Secrets management

## Overview

This document describes the **one-time setup** of Doppler projects and configurations for the Diary Platform. These steps create the foundational Doppler infrastructure that all developers and sponsors will use.

**After completing this setup**:
- Developers can use [doppler-setup-new-dev.md](./doppler-setup-new-dev.md) to configure their local environments
- New sponsors can be added using [doppler-setup-new-sponsor.md](./doppler-setup-new-sponsor.md)

## Architecture Overview

The Diary Platform uses a nested Doppler project structure:

- **hht-diary-core**: Core application secrets and sponsor manifest
  - Configs: `dev`, `staging`, `production`
- **hht-diary-{sponsor}**: Per-sponsor secrets (e.g., `hht-diary-callisto`)
  - Configs: `staging`, `production`

This structure supports the multi-sponsor architecture described in `spec/prd-architecture-multi-sponsor.md`.

## Initial Setup Steps

### 1. Install Doppler CLI

Choose the method appropriate for your operating system:

**macOS**:
```bash
brew install gnupg
brew install dopplerhq/cli/doppler
```

**Linux (Debian/Ubuntu 22.04+)**:
```bash
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | sudo tee /etc/apt/sources.list.d/doppler-cli.list
sudo apt-get update && sudo apt-get install doppler
```

**Universal (any Linux/BSD/macOS)**:
```bash
(curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh || wget -t 3 -qO- https://cli.doppler.com/install.sh) | sudo sh
```

**Verify installation**:
```bash
doppler --version
```

### 2. Authenticate with Doppler

```bash
doppler login
```

This opens a browser window for authentication.

### 3. Create Core Project

```bash
doppler projects create hht-diary-core
```

### 4. Create Core Project Configurations

```bash
doppler configs create dev --project hht-diary-core
doppler configs create staging --project hht-diary-core
doppler configs create production --project hht-diary-core
```

### 5. Set Core Project Secrets

Set the initial secrets for each configuration. Start with production:

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

# Set core AWS credentials (replace with actual values)
doppler secrets set CORE_AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXX" --project hht-diary-core --config production
doppler secrets set CORE_AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxx" --project hht-diary-core --config production

# Set app store credentials (replace with actual JSON blob)
doppler secrets set APP_STORE_CREDENTIALS='{"apple": {...}, "google": {...}}' --project hht-diary-core --config production
```

Repeat similar steps for `staging` and `dev` configurations with environment-appropriate values.

### 6. Create Initial Sponsor Project (Callisto)

```bash
# Create Callisto sponsor project
doppler projects create hht-diary-callisto

# Create Callisto configurations
doppler configs create staging --project hht-diary-callisto
doppler configs create production --project hht-diary-callisto
```

### 7. Set Callisto Sponsor Secrets

```bash
# Production secrets
doppler secrets set SUPABASE_PROJECT_ID="callisto-portal-prod" --project hht-diary-callisto --config production
doppler secrets set SUPABASE_ACCESS_TOKEN="sbp_xxxxxxxxxxxxx" --project hht-diary-callisto --config production
doppler secrets set SPONSOR_AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXX" --project hht-diary-callisto --config production
doppler secrets set SPONSOR_AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxx" --project hht-diary-callisto --config production

# Staging secrets (repeat with staging values)
doppler secrets set SUPABASE_PROJECT_ID="callisto-portal-staging" --project hht-diary-callisto --config staging
# ... etc
```

## GitHub Actions Integration

### 1. Generate Service Tokens

Create service tokens for CI/CD:

```bash
# Core project token
doppler configs tokens create github-actions --project hht-diary-core --config production

# Callisto sponsor token
doppler configs tokens create github-actions --project hht-diary-callisto --config production
```

**Save these tokens securely** - you'll need them in the next step.

### 2. Add Tokens to GitHub Repository

1. Navigate to your GitHub repository
2. Go to Settings → Secrets and variables → Actions
3. Add the following repository secrets:
   - `DOPPLER_TOKEN_CORE`: Token from core project
   - `DOPPLER_TOKEN_CALLISTO`: Token from Callisto project

### 3. Verify GitHub Actions Integration

The workflow in `.github/workflows/build-integrated-app.yml` should now be able to access Doppler secrets.

Example workflow snippet:
```yaml
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
```

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
    code: TTN
    enabled: true
    repo: cure-hht/sponsor-titan
    tag: v2.0.1
    mobile_module: true
    portal: false  # Direct EDC integration, no portal
    region: us-west-2
```

## Email Service Configuration (Email OTP & Activation Codes)

**IMPLEMENTS REQUIREMENTS:**
- REQ-p00002: Multi-Factor Authentication for Staff
- REQ-o00006: MFA Configuration for Staff Accounts
- REQ-p00010: FDA 21 CFR Part 11 Compliance

The platform uses Gmail API with a service account for sending:
- Email OTP codes (6-digit, 10-minute expiration)
- Activation codes for new portal users
- System notifications

### Gmail Service Account Setup (One-Time)

1. **Deploy Terraform admin-project** (creates Gmail service account):
   ```bash
   cd infrastructure/terraform/admin-project
   doppler run -- terraform apply
   ```

2. **Get service account key**:
   ```bash
   terraform output -raw gmail_service_account_key_base64
   ```

3. **Configure domain-wide delegation** in Google Workspace Admin Console:
   - Go to: Security → API Controls → Domain-wide Delegation
   - Add Client ID from `terraform output gmail_client_id`
   - Grant scope: `https://www.googleapis.com/auth/gmail.send`

### Doppler Secrets for Email Service

The email service uses **Workload Identity Federation (WIF)** - Cloud Run or local users impersonate the Gmail SA via IAM. No secret keys required.

Add these to **hht-diary-core** (all environments):

```bash
# Gmail SA email to impersonate
doppler secrets set EMAIL_SVC_ACCT="org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com" \
  --project hht-diary-core --config production

# Sender email (must exist in Google Workspace)
doppler secrets set EMAIL_SENDER="support@anspar.org" \
  --project hht-diary-core --config production

# Enable/disable email sending (set to "false" to disable)
doppler secrets set EMAIL_ENABLED="true" \
  --project hht-diary-core --config production
```

**Note:** `EMAIL_SENDER_NAME` is hardcoded as "Clinical Trial Portal" in the email service.

### Local Development Setup

**1. Authenticate with your Google account:**
```bash
gcloud auth application-default login
```

**2. Grant WIF impersonation permission (one-time, run by admin):**
```bash
gcloud iam service-accounts add-iam-policy-binding \
  org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com \
  --member="user:YOUR_EMAIL@anspar.org" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project=cure-hht-admin
```

**3. Run the server:**
```bash
cd apps/sponsor-portal/portal_server
doppler run -- dart run bin/server.dart
```

### Feature Flag Secrets

Control conditional 2FA behavior per environment:

```bash
# TOTP only for Developer Admins (others use email OTP)
doppler secrets set FEATURE_TOTP_ADMIN_ONLY="true" \
  --project hht-diary-core --config production

# Enable email OTP for non-admin users
doppler secrets set FEATURE_EMAIL_OTP_ENABLED="true" \
  --project hht-diary-core --config production

# Auto-email activation codes when generated
doppler secrets set FEATURE_EMAIL_ACTIVATION="true" \
  --project hht-diary-core --config production
```

### Environment-Specific Notes

| Environment | EMAIL_ENABLED | Notes |
| --- | --- | --- |
| dev | false | Use mock email service, no real emails sent |
| staging | true | Real emails to test addresses only |
| production | true | Real emails to all recipients |

### Verifying Email Configuration

After setting secrets, verify the service is configured:

```bash
# Check WIF is configured
doppler secrets get EMAIL_SVC_ACCT --project hht-diary-core --config production

# Test locally (uses WIF via your gcloud ADC)
cd apps/sponsor-portal/portal_server
doppler run -- dart run bin/server.dart
# Then call GET /api/v1/portal/config/features to verify
```

## Security Checklist

Before completing project setup, verify:

- [ ] All production secrets use strong, unique values (not placeholder examples)
- [ ] Service tokens have minimal required permissions
- [ ] GitHub Actions secrets are stored securely (not in code)
- [ ] `.gitignore` includes `.doppler*` and `*.env`
- [ ] Backup of initial secrets stored in secure offline location:
  ```bash
  doppler secrets download --project hht-diary-core --config production --format json > backup-$(date +%Y%m%d).json
  # Encrypt and store securely
  gpg --encrypt backup-$(date +%Y%m%d).json
  ```

## Troubleshooting

### "Insufficient permissions" errors

Ensure your Doppler account has **Owner** or **Admin** role for creating projects.

### "Project already exists" error

The project may have been created previously. List projects:
```bash
doppler projects list
```

### Service token generation fails

Verify you have permission to create tokens:
```bash
doppler me
```

## Next Steps

After completing project setup:

1. **For developers**: Share link to [doppler-setup-new-dev.md](./doppler-setup-new-dev.md)
2. **For new sponsors**: Follow [doppler-setup-new-sponsor.md](./doppler-setup-new-sponsor.md)
3. **Documentation**: Update project documentation with Doppler project names and structure

## References

- Doppler Documentation: https://docs.doppler.com/
- GitHub Actions Integration: https://docs.doppler.com/docs/github-actions
- Sponsor Manifest Schema: `.github/config/sponsor-manifest-schema.yml`
- Security Best Practices: `spec/ops-security.md`
- Multi-Sponsor Architecture: `spec/prd-architecture-multi-sponsor.md`
