# Phase 5: Critical Compliance & Safety

## Overview
This phase addresses critical FDA 21 CFR Part 11 compliance violations and audit trail integrity issues that could block regulatory approval or cause data loss.

## Scope
**24 critical issues** affecting compliance, audit trails, and data integrity.

## Priority: CRITICAL
These issues:
- Violate FDA 21 CFR Part 11 requirements
- Allow untraced code into production
- Risk data corruption or loss
- Create incomplete audit trails

## Issues to Fix

### FDA Compliance Violations (5 issues)
1. **Issue #113** - `pr-validation.yml:187-197` - Allows PRs with untraced code (FDA violation)
2. **Issue #114** - `deploy-production.yml:134-137` - 7-year retention unimplemented
3. **Issue #115** - `archive-audit-trail.yml:68-70` - Empty audit exports only warn
4. **Issue #117** - `rollback.yml:126` - Audit trail has placeholder instead of version
5. **Issue #118** - `archive-deployment-logs.yml:89` - job.duration invalid field

### Critical Error Suppression (7 issues)
6. **Issue #1** - `pr-validation.yml:106-116` - `|| true` masks git/grep failures
7. **Issue #2** - `archive-deployment-logs.yml:24-27` - `continue-on-error: true` hides download failures
8. **Issue #4** - `archive-audit-trail.yml:48-49` - Database export no error handling
9. **Issue #5** - `archive-artifacts.yml:84` - Integrity check doesn't verify return value
10. **Issue #6** - `archive-deployment-logs.yml:94-96` - Silent log truncation
11. **Issue #26** - `qa-automation.yml:338-340` - Pipeline error from subshell won't propagate
12. **Issue #30** - `verify-archive-integrity.yml:79` - Exits successfully when no artifacts found

### Data Integrity & Backup (7 issues)
13. **Issue #3** - `archive-artifacts.yml:78-81` - Circular checksum verification
14. **Issue #97** - `verify-archive-integrity.yml:60` - Checksum filename mismatch
15. **Issue #104** - `deploy-production.yml:119-133` - Database backup never uploaded
16. **Issue #105** - `deploy-staging.yml:70-76` - Backup created but never used
17. **Issue #12** - `claim-requirement-number.yml` - Race condition for REQ# assignment
18. **Issue #16** - `deploy-development.yml:71` - `supabase db reset` DESTROYS data
19. **Issue #19** - `rollback.yml:102` - Undefined $DATABASE_URL

### Authentication & Security (5 issues)
20. **Issue #116** - `build-publish-images.yml:532,540,548,556,564` - Weak certificate verification
21. **Issue #119** - `validate-bot-commits.yml:31-41` - Bot detection bypass via "Bot:" prefix
22. **Issue #120** - `maintenance-check.yml:272` - Invalid JSON with undefined variables
23. **Issue #22** - `pr-validation.yml:187` - Non-enforced requirement traceability
24. **Issue #101** - `claim-requirement-number.yml` - No concurrency control

## Implementation Steps

### Step 1: Fix FDA Compliance Violations
```yaml
# pr-validation.yml - Make requirement traceability mandatory
- name: Check requirement traceability
  run: |
    # Change from warning to error
    if ! grep -q "REQ-[pod][0-9]{5}" commit_message.txt; then
      echo "::error::All commits must reference a requirement (REQ-xxxxx)"
      exit 1  # Changed from exit 0
    fi

# deploy-production.yml - Implement 7-year retention
- name: Archive for FDA compliance
  run: |
    aws s3 cp deployment.tar.gz \
      s3://hht-diary-retention-${SPONSOR}-eu-west-1/ \
      --storage-class GLACIER_IR \
      --metadata "retention-years=7,fda-compliant=true"

    # Set lifecycle policy for 7-year retention
    aws s3api put-bucket-lifecycle-configuration \
      --bucket hht-diary-retention-${SPONSOR}-eu-west-1 \
      --lifecycle-configuration file://fda-retention-policy.json
```

### Step 2: Remove Error Suppression
```yaml
# Remove all || true, || echo patterns
# Remove all continue-on-error: true
# Add proper error checking:
- name: Database export
  run: |
    set -euo pipefail  # Exit on any error
    pg_dump $DATABASE_URL > export.sql
    if [ ! -s export.sql ]; then
      echo "::error::Database export failed - empty file"
      exit 1
    fi
```

### Step 3: Fix Data Integrity
```yaml
# Fix circular checksum verification
- name: Verify integrity
  run: |
    # Download checksum from S3 first
    aws s3 cp s3://bucket/artifact.sha256 expected.sha256

    # Generate local checksum
    sha256sum artifact.tar.gz > actual.sha256

    # Compare
    if ! diff expected.sha256 actual.sha256; then
      echo "::error::Checksum mismatch!"
      exit 1
    fi

# Fix database backup upload
- name: Upload database backup
  run: |
    BACKUP_NAME="db-backup-$(date +%Y%m%d-%H%M%S).sql.gz"
    gzip -c database.sql > $BACKUP_NAME

    aws s3 cp $BACKUP_NAME \
      s3://hht-diary-backups-${SPONSOR}-eu-west-1/ \
      --storage-class STANDARD_IA

    echo "backup_location=s3://hht-diary-backups-${SPONSOR}-eu-west-1/$BACKUP_NAME" >> $GITHUB_OUTPUT
```

### Step 4: Add Concurrency Control
```yaml
# claim-requirement-number.yml
concurrency:
  group: requirement-number-assignment
  cancel-in-progress: false  # Never cancel, queue instead

- name: Acquire lock
  uses: actions/github-script@v6
  with:
    script: |
      // Use GitHub API to ensure atomic operation
      const lock = await github.rest.actions.createWorkflowDispatch({
        owner: context.repo.owner,
        repo: context.repo.repo,
        workflow_id: 'requirement-lock.yml',
        ref: 'main'
      });
```

## Testing Requirements

1. **Compliance Tests**:
   - Submit PR without REQ reference → Must fail
   - Verify 7-year retention policy is applied
   - Check audit trail completeness

2. **Error Handling Tests**:
   - Simulate database export failure → Must fail workflow
   - Test with empty artifacts → Must fail
   - Verify all error suppression removed

3. **Data Integrity Tests**:
   - Upload artifact with wrong checksum → Must detect
   - Verify backup is uploaded and downloadable
   - Test concurrent REQ# requests → Must serialize

## CI Success Criteria

- [ ] All PR validation checks pass
- [ ] No `|| true` or `continue-on-error` in critical paths
- [ ] Database backups successfully upload to S3
- [ ] Audit trail captures all required fields
- [ ] Concurrent REQ# assignments don't conflict

## Known Risks

1. **Breaking Changes**:
   - PRs without REQ references will be blocked
   - Workflows will fail instead of warning

2. **Performance Impact**:
   - S3 uploads add 30-60 seconds per workflow
   - Concurrency control may queue workflows

3. **Cost Impact**:
   - S3 Glacier storage for 7-year retention
   - Additional S3 API calls for verification

## Rollback Plan

If issues occur:
1. Revert to warning instead of error for REQ validation
2. Temporarily disable S3 uploads
3. Remove concurrency control
4. Document blockers for next attempt

## Success Metrics

- Zero FDA compliance violations
- 100% audit trail capture
- Zero data loss from error suppression
- All backups verified and restorable