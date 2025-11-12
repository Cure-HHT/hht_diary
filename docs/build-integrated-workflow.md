# Build Integrated Workflow

Comprehensive guide for the multi-sponsor integrated build workflow.

## IMPLEMENTS REQUIREMENTS
- REQ-d00071: Integrated build workflow
- REQ-d00070: Sponsor integration automation
- REQ-o00016: FDA compliance archival

## Overview

The `build-integrated.yml` workflow automates the complete build process for the multi-sponsor mobile application:

1. **Integration**: Loads sponsor manifest from Doppler, integrates enabled sponsors
2. **Verification**: Validates sponsor structure and configuration
3. **Building**: Compiles Flutter mobile app with all integrated sponsors
4. **Archival**: (Optional) Archives build artifacts to per-sponsor S3 buckets

## Workflow Structure

### Jobs

#### 1. integrate-sponsors
Integrates sponsor modules from manifest.

**Inputs:**
- `DOPPLER_TOKEN_CORE` (secret) - Core Doppler project token
- `SPONSOR_REPO_TOKEN` (secret) - GitHub PAT for cloning sponsor repos

**Outputs:**
- `sponsors` - JSON array of sponsor names (for matrix)
- `build_manifest` - Complete build manifest JSON

**Steps:**
1. Checkout code
2. Install dependencies (jq, yq)
3. Install Doppler CLI
4. Run `integrate-sponsors.sh` with Doppler secrets
5. Verify each sponsor structure
6. Upload build manifest and integrated sponsors as artifacts

#### 2. build-mobile-app
Builds the Flutter mobile application.

**Depends on:** `integrate-sponsors`

**Steps:**
1. Checkout code
2. Download integrated sponsors from previous job
3. Setup Flutter (3.24.0, stable)
4. Install dependencies (`flutter pub get`)
5. Run tests (`flutter test`)
6. Build APK (`flutter build apk --release`)
7. Build App Bundle (`flutter build appbundle --release`)
8. Upload APK and AAB as artifacts

#### 3. archive-per-sponsor
Archives build artifacts to environment-specific S3 buckets.

**Depends on:** `integrate-sponsors`, `build-mobile-app`

**Condition:** `inputs.archive_artifacts == 'true'`

**Matrix:** Runs once per sponsor

**Environment-Specific Behavior:**

| Environment | Bucket | Retention | Object Lock | Use Case |
|-------------|--------|-----------|-------------|----------|
| Production | `SPONSOR_ARTIFACTS_BUCKET` | 7 years | ✅ Enabled | FDA-compliant production releases |
| Staging | `SPONSOR_ARTIFACTS_BUCKET_STAGING` | 30 days | ❌ Disabled | Pre-production testing |
| Development | `SPONSOR_ARTIFACTS_BUCKET_DEV` | 7 days | ❌ Disabled | Testing archival workflow |

**Steps:**
1. Display archival configuration (environment, bucket, retention)
2. Checkout code
3. Download build artifacts (manifest, APK, AAB)
4. Get environment-specific AWS credentials and bucket from Doppler
5. Create archive with metadata (includes environment flag)
6. Upload to S3 with environment-specific path:
   - Production: `s3://{bucket}/builds/YYYY/MM/DD/`
   - Staging: `s3://{bucket}/staging/builds/YYYY/MM/DD/`
   - Development: `s3://{bucket}/dev/builds/YYYY/MM/DD/`
7. Verify archive integrity

#### 4. summary
Generates build summary for GitHub Actions UI.

**Depends on:** `integrate-sponsors`, `build-mobile-app`

**Condition:** Always runs (even on failure)

**Output:** Markdown table in GitHub Actions summary showing:
- Timestamp and git SHA
- Integrated sponsors (name, code, repo, tag, SHA, features)
- Build status for each job

## Usage

### Manual Trigger

Navigate to Actions → Build Integrated App → Run workflow

**Options:**
- `environment`: Target environment (development/staging/production)
  - **development** (default): Test buckets, 7-day retention
  - **staging**: Pre-production buckets, 30-day retention
  - **production**: Production buckets, 7-year retention (FDA compliance)
- `archive_artifacts`: Whether to archive to S3 (default: false)

### CLI Trigger

**Development Build (Test Archival):**
```bash
gh workflow run build-integrated.yml \
  -f environment=development \
  -f archive_artifacts=true
```

**Staging Build (Pre-Production Test):**
```bash
gh workflow run build-integrated.yml \
  -f environment=staging \
  -f archive_artifacts=true
```

**Production Build (7-Year FDA Archival):**
```bash
gh workflow run build-integrated.yml \
  -f environment=production \
  -f archive_artifacts=true
```

### Scheduled Builds

Add schedule trigger to workflow:

```yaml
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2 AM UTC
  workflow_dispatch:
    # ... existing inputs
```

## Configuration

### Required Secrets

#### Core Secrets (Repository Level)
- `DOPPLER_TOKEN_CORE` - Core Doppler project token (hht-diary-core)
- `SPONSOR_REPO_TOKEN` - GitHub PAT for cloning sponsor repos (future multi-repo)

#### Per-Sponsor Secrets (Repository Level)
For each sponsor, create secrets with `{SPONSOR_NAME}` suffix (uppercase):

- `DOPPLER_TOKEN_CALLISTO` - Callisto Doppler project token
- `AWS_ACCESS_KEY_ID_CALLISTO` - Callisto AWS access key
- `AWS_SECRET_ACCESS_KEY_CALLISTO` - Callisto AWS secret key

**Example for Titan sponsor:**
- `DOPPLER_TOKEN_TITAN`
- `AWS_ACCESS_KEY_ID_TITAN`
- `AWS_SECRET_ACCESS_KEY_TITAN`

### Doppler Configuration

#### hht-diary-core Project

**Config:** `production`

**Required Secrets:**
- `SPONSOR_MANIFEST` - YAML manifest (see schema)
- `SPONSOR_REPO_TOKEN` - GitHub PAT (for multi-repo mode)

#### hht-diary-{sponsor} Projects

**Config:** `production`

**Required Secrets:**
- `SPONSOR_AWS_REGION` - AWS region (e.g., `eu-west-1`)
- `SPONSOR_ARTIFACTS_BUCKET` - Production S3 bucket (7-year retention)
  - Example: `hht-diary-artifacts-callisto-eu-west-1`

**Optional Secrets (for testing archival):**
- `SPONSOR_ARTIFACTS_BUCKET_STAGING` - Staging S3 bucket (30-day retention)
  - Fallback: `hht-diary-artifacts-{sponsor}-staging`
- `SPONSOR_ARTIFACTS_BUCKET_DEV` - Development S3 bucket (7-day retention)
  - Fallback: `hht-diary-artifacts-{sponsor}-dev`

### S3 Bucket Structure

**Production Bucket** (`SPONSOR_ARTIFACTS_BUCKET`):
```
hht-diary-artifacts-{sponsor}-{region}/
├── builds/                              # Production builds (7-year retention)
│   ├── 2025/
│   │   ├── 01/
│   │   │   ├── 10/
│   │   │   │   └── hht-diary-CAL-a1b2c3d4.tar.gz
│   │   │   ├── 11/
│   │   │   │   └── hht-diary-CAL-e5f6g7h8.tar.gz
│   ├── latest.tar.gz -> 2025/01/11/hht-diary-CAL-e5f6g7h8.tar.gz
```

**Staging Bucket** (`SPONSOR_ARTIFACTS_BUCKET_STAGING`):
```
hht-diary-artifacts-{sponsor}-staging/
├── staging/                             # Staging builds (30-day retention)
│   ├── builds/
│   │   ├── 2025/01/10/
│   │   │   └── hht-diary-CAL-x7y8z9a0.tar.gz
│   ├── latest.tar.gz
```

**Development Bucket** (`SPONSOR_ARTIFACTS_BUCKET_DEV`):
```
hht-diary-artifacts-{sponsor}-dev/
├── dev/                                 # Dev builds (7-day retention)
│   ├── builds/
│   │   ├── 2025/01/10/
│   │   │   └── hht-diary-CAL-b1c2d3e4.tar.gz
│   ├── latest.tar.gz
```

## Archive Format

### Archive Contents

```
hht-diary-{CODE}-{SHA}/
├── app-release.apk
├── app-release.aab
├── sponsor-build-manifest.json
└── metadata.json
```

### metadata.json

```json
{
  "sponsor": "callisto",
  "sponsor_code": "CAL",
  "environment": "production",
  "git_sha": "a1b2c3d4e5f6g7h8...",
  "timestamp": "2025-01-10T12:34:56Z",
  "github_run_id": "12345678",
  "github_run_number": "42",
  "github_actor": "github-actions[bot]",
  "workflow": "build-integrated",
  "is_production": true
}
```

**Fields:**
- `environment`: Build environment (development/staging/production)
- `is_production`: Boolean flag for quick filtering of production archives

### sponsor-build-manifest.json

See `tools/build/README.md` for schema.

## FDA Compliance

### 21 CFR Part 11 Requirements

**Electronic Records (§11.10):**
- ✅ Complete audit trail in build manifest
- ✅ Git SHA for core repo and all sponsor repos
- ✅ Timestamp (ISO 8601, UTC)
- ✅ Actor information (GitHub user)

**Electronic Signatures (§11.50):**
- ✅ GitHub Actions actor as signature equivalent
- ✅ Workflow run ID as unique identifier

**Retention:**
- ✅ Artifacts retained 90 days in GitHub Actions
- ✅ S3 archives retained 7 years (per-sponsor, per-region)
- ✅ Build manifest included in archive

### Archive Integrity

Each archive upload is verified:
1. Download from S3
2. Extract tarball
3. Verify all required files present
4. Fails workflow if verification fails

### Per-Sponsor Isolation

Each sponsor receives:
- Identical build artifacts (APK, AAB)
- Same build manifest
- Sponsor-specific metadata
- Stored in sponsor-owned S3 bucket

This ensures:
- Each sponsor can independently access their archives
- FDA audits can be sponsor-specific
- No cross-sponsor data leakage

## Testing Archival Process

### Why Test Environments Matter

The archival process uploads to S3 with different retention policies:
- **Production**: 7-year immutable retention (Object Lock enabled)
- **Staging**: 30-day mutable retention (for pre-production testing)
- **Development**: 7-day mutable retention (for workflow testing)

Testing with production buckets risks:
- Polluting compliance records with test data
- Wasting storage costs on non-production artifacts
- Creating confusion during FDA audits

### Testing Workflow

#### 1. Development Environment (Recommended for Testing)

Use this for testing changes to the archival workflow itself.

```bash
gh workflow run build-integrated.yml \
  -f environment=development \
  -f archive_artifacts=true
```

**Characteristics:**
- Uses `SPONSOR_ARTIFACTS_BUCKET_DEV` or fallback bucket
- 7-day automatic deletion
- Path: `s3://{bucket}/dev/builds/YYYY/MM/DD/`
- No Object Lock (can be deleted manually if needed)
- Metadata includes `"is_production": false`

**Verify Archive:**
```bash
# List development archives
aws s3 ls s3://hht-diary-artifacts-callisto-dev/dev/builds/ --recursive

# Download latest
aws s3 cp s3://hht-diary-artifacts-callisto-dev/dev/builds/latest.tar.gz ./test-archive.tar.gz

# Extract and inspect
tar -xzf test-archive.tar.gz
cat hht-diary-CAL-*/metadata.json
```

#### 2. Staging Environment (Pre-Production)

Use this for final validation before production releases.

```bash
gh workflow run build-integrated.yml \
  -f environment=staging \
  -f archive_artifacts=true
```

**Characteristics:**
- Uses `SPONSOR_ARTIFACTS_BUCKET_STAGING`
- 30-day retention (suitable for release candidates)
- Path: `s3://{bucket}/staging/builds/YYYY/MM/DD/`
- No Object Lock
- Metadata includes `"environment": "staging"`

**Use Cases:**
- Testing new Doppler configurations
- Validating bucket permissions
- Verifying archive integrity before production
- Release candidate archival

#### 3. Production Environment (Production Only)

**⚠️ Use only for actual production releases!**

```bash
gh workflow run build-integrated.yml \
  -f environment=production \
  -f archive_artifacts=true
```

**Characteristics:**
- Uses `SPONSOR_ARTIFACTS_BUCKET`
- 7-year retention (FDA compliance)
- Path: `s3://{bucket}/builds/YYYY/MM/DD/`
- Object Lock enabled (immutable)
- Metadata includes `"is_production": true`

### Setting Up Test Buckets

#### Option 1: Use Terraform Module (Recommended)

Create test buckets using the sponsor-s3 module:

```hcl
# In sponsor/callisto/infrastructure/terraform/s3-test-buckets.tf

module "test_buckets" {
  source = "../../../../infrastructure/terraform/modules/sponsor-s3"

  sponsor_code = "callisto"
  aws_region   = var.aws_region

  # Development bucket (7-day retention)
  artifacts_retention_days = 7
  artifacts_lifecycle_enabled = true
  enable_object_lock = false  # Allow deletion

  # Override bucket names for dev/staging
  bucket_prefix = "hht-diary-test"
}
```

#### Option 2: Manual Bucket Creation

Create simple S3 buckets for testing:

```bash
# Development bucket
aws s3 mb s3://hht-diary-artifacts-callisto-dev --region eu-west-1

# Add lifecycle policy (7-day expiration)
aws s3api put-bucket-lifecycle-configuration \
  --bucket hht-diary-artifacts-callisto-dev \
  --lifecycle-configuration '{
    "Rules": [{
      "Status": "Enabled",
      "Id": "DeleteAfter7Days",
      "Expiration": {"Days": 7}
    }]
  }'

# Staging bucket (30-day expiration)
aws s3 mb s3://hht-diary-artifacts-callisto-staging --region eu-west-1
aws s3api put-bucket-lifecycle-configuration \
  --bucket hht-diary-artifacts-callisto-staging \
  --lifecycle-configuration '{
    "Rules": [{
      "Status": "Enabled",
      "Id": "DeleteAfter30Days",
      "Expiration": {"Days": 30}
    }]
  }'
```

#### Add to Doppler

Add test bucket names to sponsor Doppler config:

```bash
# Development bucket
doppler secrets set SPONSOR_ARTIFACTS_BUCKET_DEV="hht-diary-artifacts-callisto-dev" \
  --project hht-diary-callisto --config production

# Staging bucket
doppler secrets set SPONSOR_ARTIFACTS_BUCKET_STAGING="hht-diary-artifacts-callisto-staging" \
  --project hht-diary-callisto --config production
```

### Verifying Test Archives

Check that archives are being created correctly:

```bash
# 1. List all archives in dev environment
aws s3 ls s3://hht-diary-artifacts-callisto-dev/dev/builds/ --recursive

# 2. Download and inspect latest
aws s3 cp s3://hht-diary-artifacts-callisto-dev/dev/builds/latest.tar.gz ./

# 3. Extract
tar -xzf latest.tar.gz

# 4. Verify contents
ls -lh hht-diary-CAL-*/
cat hht-diary-CAL-*/metadata.json | jq .

# 5. Check environment flag
cat hht-diary-CAL-*/metadata.json | jq -r '.environment, .is_production'
# Should output:
# development
# false
```

### Cleanup

Development and staging archives auto-delete after 7/30 days respectively. For immediate cleanup:

```bash
# Delete specific archive
aws s3 rm s3://hht-diary-artifacts-callisto-dev/dev/builds/2025/01/10/hht-diary-CAL-x1y2z3.tar.gz

# Delete all dev archives
aws s3 rm s3://hht-diary-artifacts-callisto-dev/dev/ --recursive

# Delete entire dev bucket (if recreating)
aws s3 rb s3://hht-diary-artifacts-callisto-dev --force
```

## Troubleshooting

### "DOPPLER_TOKEN_CORE not set"

Ensure secret is created at repository level:
1. Settings → Secrets and variables → Actions
2. New repository secret
3. Name: `DOPPLER_TOKEN_CORE`
4. Value: Token from `doppler configs tokens create github-actions`

### "Sponsor verification failed"

Check sponsor structure:
```bash
./tools/build/verify-sponsor-structure.sh callisto
```

Fix any errors reported by verification script.

### "Failed to clone sponsor repo"

Multi-repo mode requires `SPONSOR_REPO_TOKEN`:
1. Create GitHub PAT with `repo` scope
2. Add as repository secret: `SPONSOR_REPO_TOKEN`
3. Ensure PAT has access to sponsor repositories

### "S3 upload failed"

Verify AWS credentials and bucket:
1. Check `AWS_ACCESS_KEY_ID_{SPONSOR}` secret
2. Check `AWS_SECRET_ACCESS_KEY_{SPONSOR}` secret
3. Verify bucket exists: `aws s3 ls s3://hht-diary-artifacts-callisto-eu-west-1/`
4. Check IAM permissions (PutObject, GetObject)

### "Archive integrity verification failed"

Check archive contents:
```bash
aws s3 cp s3://bucket/builds/YYYY/MM/DD/archive.tar.gz /tmp/
tar -tzf /tmp/archive.tar.gz
```

Ensure all required files present:
- `app-release.apk`
- `app-release.aab`
- `sponsor-build-manifest.json`
- `metadata.json`

## Performance

**Typical runtime:**
- Integration: 2-3 minutes
- Build: 10-15 minutes
- Archive (per sponsor): 2-3 minutes

**Total (1 sponsor, with archival):** ~17-21 minutes

**Matrix parallelization:** Archive jobs run in parallel (one per sponsor)

## Future Enhancements

- [ ] iOS build support (IPA)
- [ ] Code signing integration
- [ ] Automated store upload (Google Play, App Store)
- [ ] Build caching (Flutter build cache)
- [ ] Incremental integration (skip unchanged sponsors)
- [ ] Multi-platform builds (Android, iOS, Web)
- [ ] Automated version bumping
- [ ] Release notes generation
- [ ] Slack/email notifications

## See Also

- Sponsor Manifest Schema: `.github/config/sponsor-manifest-schema.yml`
- Integration Script: `tools/build/integrate-sponsors.sh`
- Verification Script: `tools/build/verify-sponsor-structure.sh`
- Doppler Setup: `docs/doppler-setup.md`
- Phase 8 Implementation: `cicd-phase8-implementation-plan.md`
