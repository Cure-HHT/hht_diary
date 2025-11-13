# Phase 5 PR #1: Multi-Sponsor Database Backup Infrastructure Setup

## Overview

This document provides a step-by-step guide to set up the infrastructure required for multi-sponsor database backups before implementing the workflow changes.

## IMPLEMENTS REQUIREMENTS

- REQ-o00008: Backup and Retention Policy
- REQ-o00049: Artifact Retention and Archival
- REQ-o00041: Infrastructure as Code for Cloud Resources
- REQ-p00012: Clinical Data Retention Requirements

**Current State**:
- ❌ S3 backup buckets not created
- ❌ Per-sponsor Doppler secrets not configured
- ❌ Per-sponsor GitHub secrets not configured
- ✅ Build artifact S3 infrastructure exists (pattern to follow)

**Target State**:
- ✅ S3 backup buckets with lifecycle policies (per sponsor, per environment)
- ✅ Doppler secrets configured (DATABASE_URL, bucket names, AWS credentials)
- ✅ GitHub secrets configured (DOPPLER_TOKEN per sponsor)
- ✅ Ready for multi-sponsor backup workflow implementation

---

## Phase 1: Infrastructure Prerequisites

### 1.1 Verify Existing Infrastructure

**Check if artifact buckets exist** (pattern to replicate):

```bash
# List existing S3 buckets
aws s3 ls | grep hht-diary-artifacts

# Expected output (if build-integrated.yml is working):
# hht-diary-artifacts-callisto-eu-west-1
# hht-diary-artifacts-callisto-staging (optional)
# hht-diary-artifacts-callisto-dev (optional)
```

**Check existing Doppler projects**:

```bash
# List Doppler projects
doppler projects list

# Expected projects:
# hht-diary-core (sponsor manifest)
# hht-diary-callisto (per-sponsor configs)
```

**Check existing GitHub secrets**:

```bash
# List secrets
gh secret list

# Expected for callisto:
# DOPPLER_TOKEN_CALLISTO
# AWS_ACCESS_KEY_ID_CALLISTO
# AWS_SECRET_ACCESS_KEY_CALLISTO
```

### 1.2 Decision Point: Terraform vs Manual Setup

**Option A: Terraform (RECOMMENDED)**
- ✅ Infrastructure as Code (version controlled)
- ✅ Consistent across environments
- ✅ Easy to replicate for new sponsors
- ✅ Follows existing pattern (artifact buckets use Terraform)

**Option B: Manual AWS CLI**
- ⚠️ Quick for single sponsor testing
- ❌ Not repeatable
- ❌ Risk of configuration drift

**Recommendation**: Use Terraform, extend existing `sponsor-s3` module.

---

## Phase 2: Terraform Infrastructure Setup

### 2.1 Extend Existing Terraform Module

**File**: `infrastructure/terraform/modules/sponsor-s3/main.tf`

The existing module already creates artifact buckets. We need to add backup buckets.

**Add to module** (after artifact bucket resources):

```hcl
# Backup Bucket (Database Backups)
resource "aws_s3_bucket" "backups" {
  bucket = var.backup_bucket_name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.sponsor_code} Database Backups"
      Purpose     = "FDA-compliant database backup storage"
      Retention   = "7 years"
      Sponsor     = var.sponsor_name
      SponsorCode = var.sponsor_code
    }
  )
}

# Enable Versioning (FDA Requirement)
resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Policy (7-year retention for production)
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  # Production backups: Transition to Deep Archive after 90 days, retain for 7 years
  rule {
    id     = "archive-production-backups"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555  # ~7 years
    }
  }

  # Non-production paths: Shorter retention
  rule {
    id     = "expire-staging-backups"
    status = "Enabled"

    filter {
      prefix = "staging/backups/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "expire-development-backups"
    status = "Enabled"

    filter {
      prefix = "development/backups/"
    }

    expiration {
      days = 7
    }
  }
}

# Audit Logs Bucket (Deployment Logs)
resource "aws_s3_bucket" "audit_logs" {
  bucket = var.audit_logs_bucket_name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.sponsor_code} Audit Logs"
      Purpose     = "FDA-compliant deployment audit logs"
      Retention   = "7 years"
      Sponsor     = var.sponsor_name
      SponsorCode = var.sponsor_code
    }
  )
}

# Copy encryption, versioning, public access block settings
resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Same lifecycle policy as backups
resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "archive-production-logs"
    status = "Enabled"
    filter {
      prefix = "deployments/"
    }
    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
    expiration {
      days = 2555
    }
  }

  rule {
    id     = "expire-staging-logs"
    status = "Enabled"
    filter {
      prefix = "staging/deployments/"
    }
    expiration {
      days = 30
    }
  }

  rule {
    id     = "expire-development-logs"
    status = "Enabled"
    filter {
      prefix = "development/deployments/"
    }
    expiration {
      days = 7
    }
  }
}
```

### 2.2 Update Module Variables

**File**: `infrastructure/terraform/modules/sponsor-s3/variables.tf`

```hcl
variable "backup_bucket_name" {
  description = "Name of the S3 bucket for database backups"
  type        = string
}

variable "audit_logs_bucket_name" {
  description = "Name of the S3 bucket for deployment audit logs"
  type        = string
}
```

### 2.3 Update Module Outputs

**File**: `infrastructure/terraform/modules/sponsor-s3/outputs.tf`

```hcl
output "backup_bucket_name" {
  description = "Name of the database backup bucket"
  value       = aws_s3_bucket.backups.id
}

output "backup_bucket_arn" {
  description = "ARN of the database backup bucket"
  value       = aws_s3_bucket.backups.arn
}

output "audit_logs_bucket_name" {
  description = "Name of the audit logs bucket"
  value       = aws_s3_bucket.audit_logs.id
}

output "audit_logs_bucket_arn" {
  description = "ARN of the audit logs bucket"
  value       = aws_s3_bucket.audit_logs.arn
}
```

### 2.4 Create Sponsor-Specific Configuration

**File**: `infrastructure/terraform/sponsors/callisto/main.tf`

```hcl
module "callisto_s3" {
  source = "../../modules/sponsor-s3"

  sponsor_name = "callisto"
  sponsor_code = "CAL"
  aws_region   = "eu-west-1"

  # Artifact buckets (existing)
  artifacts_bucket_name = "hht-diary-artifacts-callisto-eu-west-1"

  # NEW: Backup buckets
  backup_bucket_name      = "hht-diary-backups-callisto-eu-west-1"
  audit_logs_bucket_name  = "hht-diary-audit-logs-callisto-eu-west-1"

  # Test buckets (optional, for staging/dev)
  create_test_buckets = true
  staging_artifacts_bucket_name = "hht-diary-artifacts-callisto-staging"
  dev_artifacts_bucket_name     = "hht-diary-artifacts-callisto-dev"

  common_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Sponsor     = "callisto"
    Compliance  = "FDA-21-CFR-Part-11"
  }
}

output "backup_bucket" {
  value = module.callisto_s3.backup_bucket_name
}

output "audit_logs_bucket" {
  value = module.callisto_s3.audit_logs_bucket_name
}
```

### 2.5 Apply Terraform Configuration

```bash
cd infrastructure/terraform/sponsors/callisto

# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Review the plan carefully:
# - Should create 2 new S3 buckets (backups, audit-logs)
# - Should create lifecycle policies
# - Should enable versioning and encryption

# Apply if plan looks correct
terraform apply

# Save outputs
terraform output -json > terraform-outputs.json
```

---

## Phase 3: Doppler Secrets Configuration

### 3.1 Production Secrets (hht-diary-callisto/production)

```bash
# Switch to callisto production config
doppler setup --project hht-diary-callisto --config production

# Get bucket names from Terraform output
BACKUP_BUCKET=$(terraform output -raw backup_bucket)
AUDIT_BUCKET=$(terraform output -raw audit_logs_bucket)

# Set S3 bucket secrets
doppler secrets set SPONSOR_BACKUPS_BUCKET="$BACKUP_BUCKET"
doppler secrets set SPONSOR_AUDIT_LOGS_BUCKET="$AUDIT_BUCKET"

# Verify DATABASE_URL exists (should already be configured)
doppler secrets get DATABASE_URL --plain

# If DATABASE_URL doesn't exist, set it:
# doppler secrets set DATABASE_URL="postgresql://user:pass@host:5432/database"

# Verify AWS region
doppler secrets get SPONSOR_AWS_REGION --plain || \
  doppler secrets set SPONSOR_AWS_REGION="eu-west-1"
```

### 3.2 Staging Secrets (hht-diary-callisto/staging)

```bash
doppler setup --project hht-diary-callisto --config staging

# Use same bucket with different paths
doppler secrets set SPONSOR_BACKUPS_BUCKET="hht-diary-backups-callisto-eu-west-1"
doppler secrets set SPONSOR_AUDIT_LOGS_BUCKET="hht-diary-audit-logs-callisto-eu-west-1"
doppler secrets set SPONSOR_AWS_REGION="eu-west-1"

# Set staging DATABASE_URL
# doppler secrets set DATABASE_URL="postgresql://user:pass@staging-host:5432/database"
```

### 3.3 Development Secrets (hht-diary-callisto/dev)

```bash
doppler setup --project hht-diary-callisto --config dev

doppler secrets set SPONSOR_BACKUPS_BUCKET="hht-diary-backups-callisto-eu-west-1"
doppler secrets set SPONSOR_AUDIT_LOGS_BUCKET="hht-diary-audit-logs-callisto-eu-west-1"
doppler secrets set SPONSOR_AWS_REGION="eu-west-1"

# Set development DATABASE_URL
# doppler secrets set DATABASE_URL="postgresql://user:pass@dev-host:5432/database"
```

---

## Phase 4: GitHub Secrets Configuration

### 4.1 Verify Existing Secrets

```bash
# Check if callisto secrets exist
gh secret list | grep CALLISTO

# Expected:
# DOPPLER_TOKEN_CALLISTO
# AWS_ACCESS_KEY_ID_CALLISTO
# AWS_SECRET_ACCESS_KEY_CALLISTO
```

### 4.2 Create Missing Secrets (if needed)

```bash
# Generate Doppler service token for GitHub Actions
doppler configs tokens create github-actions-callisto \
  --project hht-diary-callisto \
  --config production

# Save token and add to GitHub
gh secret set DOPPLER_TOKEN_CALLISTO --body "<token-from-above>"

# Add AWS credentials (if not already present)
gh secret set AWS_ACCESS_KEY_ID_CALLISTO --body "<aws-access-key>"
gh secret set AWS_SECRET_ACCESS_KEY_CALLISTO --body "<aws-secret-key>"
```

### 4.3 Core Doppler Token (for sponsor manifest)

```bash
# This should already exist for build-integrated.yml
gh secret list | grep DOPPLER_TOKEN_CORE

# If missing, create it:
doppler configs tokens create github-actions-core \
  --project hht-diary-core \
  --config production

gh secret set DOPPLER_TOKEN_CORE --body "<token-from-above>"
```

---

## Phase 5: Validation & Testing

### 5.1 Verify S3 Buckets

```bash
# List buckets
aws s3 ls | grep hht-diary-backups

# Expected output:
# hht-diary-backups-callisto-eu-west-1

# Check lifecycle policies
aws s3api get-bucket-lifecycle-configuration \
  --bucket hht-diary-backups-callisto-eu-west-1

# Verify encryption
aws s3api get-bucket-encryption \
  --bucket hht-diary-backups-callisto-eu-west-1

# Verify versioning
aws s3api get-bucket-versioning \
  --bucket hht-diary-backups-callisto-eu-west-1
```

### 5.2 Test Doppler Access

```bash
# Test production config
doppler run --project hht-diary-callisto --config production -- \
  echo "DATABASE_URL length: ${#DATABASE_URL}"

# Should output: DATABASE_URL length: <some number>

# Test secrets
doppler secrets get SPONSOR_BACKUPS_BUCKET --plain \
  --project hht-diary-callisto --config production

# Should output: hht-diary-backups-callisto-eu-west-1
```

### 5.3 Test GitHub Secrets

```bash
# Trigger a simple workflow to test secret access
# Create a test workflow or use workflow_dispatch on an existing one
gh workflow run deploy-production.yml --help

# Should show that the workflow exists and can be triggered
```

### 5.4 Manual Backup Test

```bash
# Manually test the backup process locally
export DOPPLER_TOKEN="<DOPPLER_TOKEN_CALLISTO>"
export AWS_ACCESS_KEY_ID="<AWS_ACCESS_KEY_ID_CALLISTO>"
export AWS_SECRET_ACCESS_KEY="<AWS_SECRET_ACCESS_KEY_CALLISTO>"
export AWS_REGION="eu-west-1"

# Get DATABASE_URL from Doppler
DATABASE_URL=$(doppler secrets get DATABASE_URL --plain \
  --project hht-diary-callisto --config production)

# Create a test backup
pg_dump "$DATABASE_URL" --no-owner --no-acl -f test-backup.sql

# Compress
gzip test-backup.sql

# Upload to S3
aws s3 cp test-backup.sql.gz \
  s3://hht-diary-backups-callisto-eu-west-1/test/test-backup.sql.gz

# Verify upload
aws s3 ls s3://hht-diary-backups-callisto-eu-west-1/test/

# Download and verify
aws s3 cp s3://hht-diary-backups-callisto-eu-west-1/test/test-backup.sql.gz \
  /tmp/verify.sql.gz

sha256sum test-backup.sql.gz /tmp/verify.sql.gz

# Clean up
rm test-backup.sql.gz /tmp/verify.sql.gz
aws s3 rm s3://hht-diary-backups-callisto-eu-west-1/test/test-backup.sql.gz
```

---

## Phase 6: Decision Point - PR Strategy

### Option A: Infrastructure First, Then Workflow (RECOMMENDED)

**PR #1 (Current)**:
- ✅ Single-sponsor backup in deploy-production.yml (DONE - PR #66)
- ✅ Uses Terraform outputs for bucket names
- ⚠️ Hardcoded to callisto

**PR #2 (Infrastructure)**:
- Terraform module updates (backup buckets)
- Doppler secret configuration documentation
- GitHub secrets documentation
- NO workflow changes yet

**PR #3 (Multi-Sponsor Workflow)**:
- New backup-databases-multi-sponsor.yml workflow
- Update deploy-production.yml to use it
- Update deploy-staging.yml
- Update deploy-development.yml

### Option B: All-in-One PR

**PR #1 (Everything)**:
- Terraform infrastructure
- Workflow implementation
- Documentation
- ⚠️ Large PR, harder to review
- ⚠️ Infrastructure must be deployed before workflow works

### Recommendation: Option A

**Rationale**:
1. **Separation of concerns**: Infrastructure vs application logic
2. **Testing**: Can validate infrastructure before workflow changes
3. **Rollback**: Easier to revert if issues occur
4. **Review**: Smaller, focused PRs easier to review

---

## Phase 7: Current PR #66 Status

### What PR #66 Currently Does

✅ **Working**:
- Database backup using pg_dump with DATABASE_URL
- S3 upload with proper tagging
- Deployment log JSON generation and upload
- Compression for storage efficiency

⚠️ **Limitations**:
- Hardcoded to "callisto" sponsor (fallback bucket name)
- Only runs in deploy-production.yml (no multi-sponsor)
- Requires S3 buckets to exist (Terraform not yet applied)
- Requires Doppler secrets to be configured

### What Needs to Happen Before PR #66 Can Work

1. **Apply Terraform**: Create S3 buckets
2. **Configure Doppler**: Set SPONSOR_BACKUPS_BUCKET, SPONSOR_AUDIT_LOGS_BUCKET
3. **Verify Secrets**: Ensure DATABASE_URL, AWS credentials exist
4. **Test Workflow**: Run deploy-production.yml and verify backup succeeds

### Recommendation for PR #66

**Option 1: Merge as-is (single-sponsor)**:
- Documents the pattern
- Works for callisto once infrastructure is set up
- Follow up with multi-sponsor PR later

**Option 2: Hold PR #66, implement infrastructure first**:
- Create infrastructure PR
- Apply Terraform
- Update PR #66 to use actual bucket names (not hardcoded fallback)
- Then merge

**Option 3: Convert PR #66 to multi-sponsor now**:
- Before merging, implement the full multi-sponsor pattern
- Larger PR, but complete solution

---

## Next Steps

### Immediate Actions

1. **Decide on PR strategy** (see Phase 6)
2. **Create Terraform PR** (if Option A)
3. **Apply Terraform configuration** (create S3 buckets)
4. **Configure Doppler secrets**
5. **Test PR #66** with actual infrastructure
6. **Document findings**

### Future Work

- **Phase 5 PR #2**: Error suppression removal
- **Phase 5 PR #3**: Security & concurrency fixes
- **Multi-sponsor backup workflow**: Complete matrix implementation
- **Scheduled backups**: Nightly automated backups via cron

---

## Summary

This document provides a complete guide to setting up the infrastructure required for multi-sponsor database backups. The key insight is that we need to **set up infrastructure first** before the workflow can function.

**Infrastructure Checklist**:
- [ ] Terraform module extended (backup & audit-logs buckets)
- [ ] S3 buckets created with lifecycle policies
- [ ] Doppler secrets configured (per sponsor, per environment)
- [ ] GitHub secrets configured (per sponsor)
- [ ] Manual backup test successful
- [ ] Ready for workflow implementation

Once infrastructure is in place, we can implement the full multi-sponsor backup workflow with confidence that it will work correctly.
