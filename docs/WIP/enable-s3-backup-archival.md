# Enabling S3 Backup Archival

## Overview

Database backup and deployment log archival to S3 is controlled by a feature flag: **`ENABLE_S3_BACKUP_ARCHIVAL`**

**Current State**: DISABLED (feature flag defaults to `false`)
**When Enabled**: Backups and deployment logs automatically upload to S3 with 7-year retention

---

## Feature Flag Behavior

### When DISABLED (default)

**Database Backup Step**:
```
════════════════════════════════════════════════════════
  ℹ️  S3 BACKUP ARCHIVAL NOT YET ENABLED
════════════════════════════════════════════════════════

Database backup archival to S3 is currently disabled.

To enable this feature, complete the following setup:
  1. Apply Terraform configuration (create S3 buckets)
     - hht-diary-backups-{sponsor}-{region}
     - hht-diary-audit-logs-{sponsor}-{region}

  2. Configure Doppler secrets:
     - SPONSOR_BACKUPS_BUCKET
     - SPONSOR_AUDIT_LOGS_BUCKET
     - SPONSOR_AWS_REGION

  3. Verify AWS credentials are configured

  4. Enable the feature flag in Doppler:
     doppler secrets set ENABLE_S3_BACKUP_ARCHIVAL=true \
       --project hht-diary-callisto --config production

See: docs/WIP/phase5-pr1-multi-sponsor-infrastructure-setup.md
════════════════════════════════════════════════════════
```

**Deployment Log Step**:
- Creates JSON log file locally
- Displays log contents
- Shows: `ℹ️  S3 audit log archival not yet enabled - log saved locally only`
- JSON includes: `"s3_archival_enabled": false`

**Result**: Workflow continues successfully, no S3 operations attempted

### When ENABLED

**Database Backup Step**:
- ✅ Shows: `S3 backup archival is ENABLED`
- Creates PostgreSQL dump with `pg_dump`
- Compresses with gzip
- Uploads to `s3://{bucket}/backups/{YYYY}/{MM}/{DD}/backup-prod-{timestamp}.sql.gz`
- Tags for 7-year retention
- Sets outputs: `backup_location`, `backup_size`

**Deployment Log Step**:
- Creates JSON deployment log
- JSON includes: `"s3_archival_enabled": true`
- Uploads to `s3://{bucket}/deployments/{YYYY}/{MM}/{DD}/deployment-prod-{timestamp}.json`
- Tags for 7-year retention

**Result**: Backups and logs archived to S3 for FDA compliance

---

## Setup Instructions

### Prerequisites

Before enabling the feature flag, ensure the following infrastructure is in place:

1. **S3 Buckets Created** (via Terraform):
   ```bash
   # Production buckets
   hht-diary-backups-callisto-eu-west-1
   hht-diary-audit-logs-callisto-eu-west-1

   # Verify
   aws s3 ls | grep hht-diary-backups
   aws s3 ls | grep hht-diary-audit-logs
   ```

2. **Lifecycle Policies Applied**:
   ```bash
   # Check backup bucket lifecycle
   aws s3api get-bucket-lifecycle-configuration \
     --bucket hht-diary-backups-callisto-eu-west-1

   # Should show:
   # - 90 days → DEEP_ARCHIVE
   # - 2555 days → Expiration (7 years)
   ```

3. **Doppler Secrets Configured**:
   ```bash
   # Switch to production config
   doppler setup --project hht-diary-callisto --config production

   # Verify required secrets exist
   doppler secrets get SPONSOR_BACKUPS_BUCKET --plain
   doppler secrets get SPONSOR_AUDIT_LOGS_BUCKET --plain
   doppler secrets get SPONSOR_AWS_REGION --plain
   doppler secrets get DATABASE_URL --plain

   # All should return values (not errors)
   ```

4. **AWS Credentials Valid**:
   ```bash
   # Test AWS access with GitHub secrets
   export AWS_ACCESS_KEY_ID="<from GitHub secrets>"
   export AWS_SECRET_ACCESS_KEY="<from GitHub secrets>"

   aws s3 ls s3://hht-diary-backups-callisto-eu-west-1/

   # Should list bucket contents (or show empty)
   ```

### Enabling the Feature

Once all prerequisites are complete:

```bash
# Production
doppler secrets set ENABLE_S3_BACKUP_ARCHIVAL=true \
  --project hht-diary-callisto --config production

# Verify
doppler secrets get ENABLE_S3_BACKUP_ARCHIVAL --plain
# Should output: true
```

**For other environments** (staging, development):
```bash
# Staging
doppler secrets set ENABLE_S3_BACKUP_ARCHIVAL=true \
  --project hht-diary-callisto --config staging

# Development
doppler secrets set ENABLE_S3_BACKUP_ARCHIVAL=true \
  --project hht-diary-callisto --config dev
```

### Testing the Feature

**Manual Test** (without deploying):

```bash
# Create a test workflow run or use deploy-production.yml
# The workflow will now:
# 1. Show "S3 backup archival is ENABLED"
# 2. Attempt to create backup
# 3. Upload to S3
# 4. Verify upload successful

# Check S3 for uploaded files
aws s3 ls s3://hht-diary-backups-callisto-eu-west-1/backups/ --recursive

# Should show files like:
# backups/2025/01/12/backup-prod-20250112-143000.sql.gz
```

---

## Rollback Procedure

If you need to disable the feature (e.g., S3 issues):

```bash
# Disable feature flag
doppler secrets set ENABLE_S3_BACKUP_ARCHIVAL=false \
  --project hht-diary-callisto --config production

# Or delete the secret entirely (defaults to false)
doppler secrets delete ENABLE_S3_BACKUP_ARCHIVAL \
  --project hht-diary-callisto --config production
```

**Effect**: Next deployment will skip S3 uploads and show INFO message

---

## Multi-Sponsor Considerations

### Current Implementation (Single Sponsor)

The current workflow is designed for a **single sponsor** (callisto):
- Uses single `DOPPLER_TOKEN_PROD` secret
- Backs up single `DATABASE_URL`
- Hardcoded fallback to "callisto" in bucket naming

### Future: Multi-Sponsor Support

When implementing multi-sponsor database backups:

1. **Per-Sponsor Feature Flags**:
   ```bash
   # Each sponsor has own Doppler project
   doppler secrets set ENABLE_S3_BACKUP_ARCHIVAL=true \
     --project hht-diary-callisto --config production

   doppler secrets set ENABLE_S3_BACKUP_ARCHIVAL=true \
     --project hht-diary-titan --config production
   ```

2. **Matrix Strategy** (like build-integrated.yml):
   - Get sponsor list from manifest
   - Iterate over enabled sponsors
   - Each sponsor checks their own feature flag
   - Parallel backup execution

3. **Gradual Rollout**:
   - Enable for callisto first
   - Verify working correctly
   - Enable for additional sponsors one at a time

See: `docs/WIP/phase5-pr1-multi-sponsor-infrastructure-setup.md` for complete multi-sponsor plan

---

## Troubleshooting

### Feature Flag Not Working

**Symptom**: Workflow still shows "NOT YET ENABLED" even after setting flag

**Solutions**:
1. Verify Doppler project and config are correct:
   ```bash
   doppler secrets get ENABLE_S3_BACKUP_ARCHIVAL --plain \
     --project hht-diary-callisto --config production
   ```

2. Check workflow is using correct `DOPPLER_TOKEN`:
   ```bash
   gh secret list | grep DOPPLER_TOKEN_PROD
   ```

3. Verify token has access to correct project:
   ```bash
   # In GitHub Actions log, look for:
   # "Loaded secrets from Doppler"
   ```

### S3 Upload Fails

**Symptom**: Feature enabled, but S3 upload returns error

**Solutions**:
1. Verify bucket exists:
   ```bash
   aws s3 ls s3://hht-diary-backups-callisto-eu-west-1/
   ```

2. Check AWS credentials are valid:
   ```bash
   gh secret list | grep AWS_ACCESS_KEY_ID_CALLISTO
   gh secret list | grep AWS_SECRET_ACCESS_KEY_CALLISTO
   ```

3. Verify IAM permissions (bucket must allow PutObject, PutObjectTagging):
   ```bash
   aws s3api put-object \
     --bucket hht-diary-backups-callisto-eu-west-1 \
     --key test.txt \
     --body /dev/null
   ```

### Backup Size is 0

**Symptom**: Feature disabled, outputs show `backup_size=0`

**Expected**: This is normal when feature is disabled
- Downstream steps use these outputs
- They gracefully handle "not-configured" and "0" values
- No impact on deployment success

---

## References

- **Infrastructure Setup**: `docs/WIP/phase5-pr1-multi-sponsor-infrastructure-setup.md`
- **Multi-Sponsor Plan**: Agent plan output from ultra-thinking session
- **Terraform Module**: `infrastructure/terraform/modules/sponsor-s3/`
- **Workflow**: `.github/workflows/deploy-production.yml`
