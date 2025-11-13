# Environment-Aware S3 Archival Migration Guide

**Document Version**: 1.0
**Date**: 2025-11-11
**Audience**: DevOps, Sponsors
**Purpose**: Migration guide for environment-aware S3 archival system

## IMPLEMENTS REQUIREMENTS

- REQ-o00050: Environment Parity and Separation
- REQ-o00049: Artifact Retention and Archival
- REQ-o00041: Infrastructure as Code for Cloud Resources

---

## Overview

This document provides guidance for migrating from the boolean `archive_artifacts` flag to the new environment-aware archival system with three tiers (development, staging, production).

### What Changed

**Before:**
- Single boolean flag: `archive_artifacts` (true/false)
- All archives went to production buckets with 7-year retention
- No way to test archival process safely

**After:**
- Environment-based archival: `development`, `staging`, `production`
- Each environment has its own bucket and retention policy:
  - **Development**: 7-day retention (testing)
  - **Staging**: 30-day retention (pre-production)
  - **Production**: 7-year retention (FDA compliance)
- Safe testing without production bucket pollution

---

## Migration Checklist

### For Existing Sponsors

- [ ] **Review Current Setup**
  - Check if production bucket exists (`SPONSOR_ARTIFACTS_BUCKET` in Doppler)
  - Verify production bucket has Object Lock enabled
  - Confirm lifecycle policies are configured

- [ ] **Decide on Test Buckets**
  - Option A: Create test buckets (recommended for active development)
  - Option B: Use fallback naming (buckets created on-demand)
  - Option C: Skip test buckets (production-only archival)

- [ ] **If Creating Test Buckets:**
  - [ ] Update Terraform configuration (see below)
  - [ ] Run `terraform plan` to review changes
  - [ ] Run `terraform apply` to create buckets
  - [ ] Add test bucket secrets to Doppler
  - [ ] Test archival workflow with `environment=development`

- [ ] **Update CI/CD Workflows**
  - [ ] Replace `archive_artifacts: true` with explicit environment choice
  - [ ] Test development archival first
  - [ ] Test staging archival (if applicable)
  - [ ] Verify production archival still works

- [ ] **Documentation**
  - [ ] Update team runbooks
  - [ ] Document test bucket cleanup procedures
  - [ ] Add environment selection to deployment guides

---

## Terraform Configuration

### Option 1: Enable Test Buckets in Existing Configuration

Update your sponsor's `s3-buckets.tf` file (e.g., `sponsor/callisto/infrastructure/terraform/s3-buckets.tf`):

```hcl
# Add local variables for test bucket names
locals {
  sponsor_name = "callisto"
  sponsor_code = "CAL"
  region_short = replace(var.aws_region, "-", "")

  # Production bucket (existing)
  artifacts_bucket = "hht-diary-artifacts-${local.sponsor_name}-${var.aws_region}"

  # Test buckets (new)
  staging_bucket = "hht-diary-artifacts-${local.sponsor_name}-staging"
  dev_bucket     = "hht-diary-artifacts-${local.sponsor_name}-dev"

  backups_bucket   = "hht-diary-backups-${local.sponsor_name}-${var.aws_region}"
  logs_bucket      = "hht-diary-logs-${local.sponsor_name}-${var.aws_region}"

  common_tags = {
    Sponsor     = local.sponsor_name
    SponsorCode = local.sponsor_code
    Region      = var.aws_region
  }
}

# Update module call
module "s3_buckets" {
  source = "../../../../infrastructure/terraform/modules/sponsor-s3"

  sponsor_name = local.sponsor_name
  sponsor_code = local.sponsor_code
  aws_region   = var.aws_region

  # Production bucket
  artifacts_bucket_name = local.artifacts_bucket

  # Test buckets (new)
  create_test_buckets = true
  staging_bucket_name = local.staging_bucket
  dev_bucket_name     = local.dev_bucket

  backups_bucket_name   = local.backups_bucket
  logs_bucket_name      = local.logs_bucket

  enable_object_lock = var.enable_object_lock
  create_cicd_user   = var.create_cicd_user

  common_tags = local.common_tags
}

# Add outputs for test buckets
output "staging_bucket_name" {
  description = "Staging test bucket name for Doppler SPONSOR_ARTIFACTS_BUCKET_STAGING"
  value       = module.s3_buckets.staging_bucket_id
}

output "dev_bucket_name" {
  description = "Dev test bucket name for Doppler SPONSOR_ARTIFACTS_BUCKET_DEV"
  value       = module.s3_buckets.dev_bucket_id
}
```

### Option 2: Manual Bucket Creation (Without Terraform)

If you prefer to create test buckets manually:

```bash
# Set your sponsor name
SPONSOR="callisto"

# Create staging bucket (30-day retention)
aws s3 mb s3://hht-diary-artifacts-${SPONSOR}-staging

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket hht-diary-artifacts-${SPONSOR}-staging \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket hht-diary-artifacts-${SPONSOR}-staging \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Set lifecycle policy (7d → IA, 30d → Delete)
cat > staging-lifecycle.json <<EOF
{
  "Rules": [
    {
      "Id": "staging-lifecycle",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 7,
          "StorageClass": "STANDARD_IA"
        }
      ],
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket hht-diary-artifacts-${SPONSOR}-staging \
  --lifecycle-configuration file://staging-lifecycle.json

# Create development bucket (7-day retention)
aws s3 mb s3://hht-diary-artifacts-${SPONSOR}-dev

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket hht-diary-artifacts-${SPONSOR}-dev \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket hht-diary-artifacts-${SPONSOR}-dev \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Set lifecycle policy (7d → Delete)
cat > dev-lifecycle.json <<EOF
{
  "Rules": [
    {
      "Id": "dev-lifecycle",
      "Status": "Enabled",
      "Expiration": {
        "Days": 7
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket hht-diary-artifacts-${SPONSOR}-dev \
  --lifecycle-configuration file://dev-lifecycle.json
```

---

## Doppler Secrets Configuration

### Required Secrets (Per Sponsor)

**Production** (required, no change):
```
SPONSOR_ARTIFACTS_BUCKET=hht-diary-artifacts-callisto-us-east-1
```

**Staging** (optional, new):
```
SPONSOR_ARTIFACTS_BUCKET_STAGING=hht-diary-artifacts-callisto-staging
```

**Development** (optional, new):
```
SPONSOR_ARTIFACTS_BUCKET_DEV=hht-diary-artifacts-callisto-dev
```

### Adding Secrets to Doppler

```bash
# Production (if not already set)
doppler secrets set SPONSOR_ARTIFACTS_BUCKET="hht-diary-artifacts-callisto-us-east-1" \
  --project hht-diary \
  --config prd_callisto

# Staging
doppler secrets set SPONSOR_ARTIFACTS_BUCKET_STAGING="hht-diary-artifacts-callisto-staging" \
  --project hht-diary \
  --config prd_callisto

# Development
doppler secrets set SPONSOR_ARTIFACTS_BUCKET_DEV="hht-diary-artifacts-callisto-dev" \
  --project hht-diary \
  --config prd_callisto
```

### Fallback Behavior

If test bucket secrets are not set, the workflow will fall back to:
- Staging: `hht-diary-artifacts-{sponsor}-staging`
- Development: `hht-diary-artifacts-{sponsor}-dev`

These buckets must still exist (either via Terraform or manual creation).

---

## GitHub Workflow Updates

### Before (Old Syntax)

```yaml
on:
  workflow_dispatch:
    inputs:
      archive_artifacts:
        description: 'Archive build artifacts to S3'
        required: false
        default: 'false'
        type: choice
        options:
          - 'true'
          - 'false'
```

### After (New Syntax)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment (production enables S3 archival)'
        required: true
        default: 'development'
        type: choice
        options:
          - 'development'
          - 'staging'
          - 'production'
      archive_artifacts:
        description: 'Archive build artifacts to S3 (uses environment-specific buckets and retention)'
        required: false
        default: 'false'
        type: choice
        options:
          - 'true'
          - 'false'
```

**Note**: The `archive_artifacts` flag is still used to enable/disable archival. The `environment` parameter now controls which bucket and retention policy to use.

---

## Testing the Migration

### Step 1: Test Development Archival

```bash
# Trigger workflow with development environment
gh workflow run build-integrated.yml \
  --field environment=development \
  --field archive_artifacts=true

# Verify archive was created
aws s3 ls s3://hht-diary-artifacts-callisto-dev/dev/builds/

# Check lifecycle policy is working (after 7 days)
aws s3api list-objects-v2 \
  --bucket hht-diary-artifacts-callisto-dev \
  --query 'Contents[*].[Key,LastModified]' \
  --output table
```

### Step 2: Test Staging Archival

```bash
# Trigger workflow with staging environment
gh workflow run build-integrated.yml \
  --field environment=staging \
  --field archive_artifacts=true

# Verify archive was created
aws s3 ls s3://hht-diary-artifacts-callisto-staging/staging/builds/

# Check tags
aws s3api get-object-tagging \
  --bucket hht-diary-artifacts-callisto-staging \
  --key staging/builds/2025/11/11/hht-diary-CAL-abcd1234.tar.gz
```

### Step 3: Verify Production Still Works

```bash
# Trigger workflow with production environment
gh workflow run build-integrated.yml \
  --field environment=production \
  --field archive_artifacts=true

# Verify archive was created in production bucket
aws s3 ls s3://hht-diary-artifacts-callisto-us-east-1/builds/

# Verify Object Lock status
aws s3api get-object-lock-configuration \
  --bucket hht-diary-artifacts-callisto-us-east-1
```

---

## Production Approval Gate (Recommended)

To prevent accidental production archival, configure GitHub Environment protection:

### Setup Steps

1. Go to repository **Settings** → **Environments**
2. Create environment named `production`
3. Configure protection rules:
   - ✅ Required reviewers (add DevOps team)
   - ✅ Wait timer: 5 minutes
   - ⚠️ Deployment branches: Only `main` and `release/*`

4. Update workflow to use environment:

```yaml
archive-per-sponsor:
  name: Archive for ${{ matrix.sponsor }} (${{ inputs.environment }})
  needs: [integrate-sponsors, build-mobile-app]
  if: inputs.archive_artifacts == 'true'
  runs-on: ubuntu-latest

  # Add environment protection
  environment:
    name: ${{ inputs.environment == 'production' && 'production' || null }}

  strategy:
    matrix:
      sponsor: ${{ fromJson(needs.integrate-sponsors.outputs.sponsors) }}
```

**Benefits:**
- Production archival requires manual approval
- Prevents accidental 7-year archives during development
- Maintains audit trail of who approved production archives

---

## Rollback Plan

If issues arise, you can roll back by:

1. **Revert to old workflow version**:
   ```bash
   git checkout main -- .github/workflows/build-integrated.yml
   git commit -m "Rollback: Revert to boolean archive_artifacts flag"
   ```

2. **Keep test buckets** (they're harmless and auto-delete)

3. **Remove test bucket secrets from Doppler** (optional):
   ```bash
   doppler secrets delete SPONSOR_ARTIFACTS_BUCKET_STAGING --config prd_callisto
   doppler secrets delete SPONSOR_ARTIFACTS_BUCKET_DEV --config prd_callisto
   ```

4. **Destroy test buckets via Terraform** (optional):
   ```bash
   # Update s3-buckets.tf
   # Set: create_test_buckets = false
   terraform apply
   ```

---

## FAQ

### Q: Do I need test buckets?

**A**: No, they're optional. If you only do production releases, you can skip test buckets and always use `environment=production`. However, test buckets are recommended for:
- Testing workflow changes
- Validating archival process
- Training new team members
- Pre-production validation

### Q: What happens if I don't create test buckets?

**A**: The workflow will use fallback bucket names (`hht-diary-artifacts-{sponsor}-staging` and `-dev`). If these buckets don't exist, the archival job will fail. Either create buckets manually or set `create_test_buckets = true` in Terraform.

### Q: Can I delete old development archives manually?

**A**: Yes! Development and staging archives have no Object Lock and can be deleted anytime:
```bash
aws s3 rm s3://hht-diary-artifacts-callisto-dev/dev/builds/2025/11/01/ --recursive
```

### Q: Will this affect existing production archives?

**A**: No. Existing production archives are unchanged. The new system only affects new archives created after this change.

### Q: How do I verify lifecycle policies are working?

**A**: Check bucket lifecycle configuration:
```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket hht-diary-artifacts-callisto-staging
```

Or monitor bucket contents over time to see objects transitioning/expiring.

---

## Support

For issues or questions:
- **DevOps Team**: #devops-support
- **Documentation**: See `docs/build-integrated-workflow.md`
- **Terraform Docs**: See `infrastructure/terraform/modules/sponsor-s3/README.md`

---

## Change History

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-11 | 1.0 | Initial migration guide for environment-aware archival system |
