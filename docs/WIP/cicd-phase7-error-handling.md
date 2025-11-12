# Phase 7: Error Handling

## Overview
This phase improves error handling, logging, and debugging capabilities across all workflows to make failures easier to diagnose and fix.

## Scope
**20 issues** related to error messages, logging, debugging output, and error recovery.

## Priority: MEDIUM-HIGH
These issues:
- Make debugging production issues difficult
- Hide root causes of failures
- Provide misleading or incomplete error messages
- Lack proper error context

## Issues to Fix

### Poor Error Messages (8 issues)
1. **Issue #33** - `build-publish-images.yml:531` - Generic "Installation failed" message
2. **Issue #34** - `database-migration.yml:89` - "No changes detected" misleading
3. **Issue #35** - `pr-validation.yml:187` - Generic warning for missing REQ
4. **Issue #36** - `deploy-production.yml:98` - "Deploy failed" without context
5. **Issue #37** - `archive-audit-trail.yml:68` - Empty export only warns
6. **Issue #38** - `qa-automation.yml:156` - "Tests failed" without details
7. **Issue #39** - `rollback.yml:94` - "No rollback script" without alternatives
8. **Issue #40** - `verify-archive-integrity.yml:79` - Success when no artifacts

### Missing Debug Information (7 issues)
9. **Issue #41** - `build-publish-images.yml:185` - Build summary lacks details
10. **Issue #42** - `deploy-staging.yml:89` - No deployment verification output
11. **Issue #43** - `database-migration.yml:45` - Migration output not captured
12. **Issue #44** - `pr-validation.yml:106` - Git diff output suppressed
13. **Issue #45** - `qa-automation.yml:223` - Test results not summarized
14. **Issue #46** - `archive-deployment-logs.yml:45` - Log truncation not reported
15. **Issue #47** - `codespaces-prebuild.yml:78` - Prebuild status unclear

### Error Recovery Issues (5 issues)
16. **Issue #48** - `deploy-production.yml:144` - No retry on transient failures
17. **Issue #49** - `build-publish-images.yml:365` - Push failures not retried
18. **Issue #50** - `database-migration.yml:78` - No rollback on failure
19. **Issue #51** - `archive-audit-trail.yml:89` - Upload failure no retry
20. **Issue #52** - `verify-archive-integrity.yml:132` - Checksum mismatch no recovery

## Implementation Steps

### Step 1: Enhance Error Messages
```yaml
# build-publish-images.yml - Detailed failure messages
- name: Install dependencies
  id: install
  run: |
    echo "::group::Installing system dependencies"

    PACKAGES="docker buildx qemu-user-static"
    for pkg in $PACKAGES; do
      echo "Installing $pkg..."
      if ! sudo apt-get install -y "$pkg"; then
        echo "::error title=Installation Failed::Failed to install $pkg"
        echo "::error::Package: $pkg"
        echo "::error::Exit code: $?"
        echo "::error::This may be due to:"
        echo "::error::  - Network connectivity issues"
        echo "::error::  - Package repository problems"
        echo "::error::  - Insufficient permissions"
        echo "Debug info:"
        sudo apt-get update 2>&1 | tail -20
        exit 1
      fi
    done

    echo "::endgroup::"
    echo "✅ All dependencies installed successfully"

# database-migration.yml - Clear migration status
- name: Check migration status
  run: |
    echo "::group::Checking for pending migrations"

    DIFF_OUTPUT=$(supabase db diff --local 2>&1) || true
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
      echo "::error title=Migration Check Failed::Could not determine migration status"
      echo "::error::Exit code: $EXIT_CODE"
      echo "::error::Output: $DIFF_OUTPUT"
      exit 1
    fi

    if [ -z "$DIFF_OUTPUT" ]; then
      echo "::notice title=No Migrations::Database is up to date - no migrations needed"
    else
      echo "::warning title=Migrations Pending::Found database differences"
      echo "Changes detected:"
      echo "$DIFF_OUTPUT"
      echo "Run 'supabase db push' to apply these changes"
    fi

    echo "::endgroup::"
```

### Step 2: Add Comprehensive Logging
```yaml
# deploy-staging.yml - Detailed deployment verification
- name: Verify deployment
  run: |
    echo "::group::Deployment Verification"
    echo "Environment: Staging"
    echo "Version: ${{ github.sha }}"
    echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

    # Check health endpoint
    echo "Checking health endpoint..."
    for i in {1..30}; do
      if curl -f https://staging.hht-diary.com/health; then
        echo "✅ Health check passed"
        break
      fi
      echo "Attempt $i/30 failed, waiting..."
      sleep 10
    done

    # Verify database connectivity
    echo "Verifying database connection..."
    if ! psql "$DATABASE_URL" -c "SELECT version();" > /dev/null 2>&1; then
      echo "::error::Database connection failed"
      exit 1
    fi
    echo "✅ Database connected"

    # Check critical services
    echo "Checking services..."
    SERVICES="auth storage realtime"
    for service in $SERVICES; do
      if curl -f "https://staging.hht-diary.com/api/$service/health"; then
        echo "✅ Service $service is healthy"
      else
        echo "::warning::Service $service health check failed"
      fi
    done

    echo "::endgroup::"
    echo "::notice::Deployment verification complete"
```

### Step 3: Add Error Context and Debugging
```yaml
# pr-validation.yml - Enhanced validation output
- name: Validate changes
  run: |
    echo "::group::PR Validation Details"

    # Show what's being validated
    echo "Base branch: ${{ github.event.pull_request.base.ref }}"
    echo "Head branch: ${{ github.event.pull_request.head.ref }}"
    echo "Changed files:"
    git diff --name-only origin/${{ github.event.pull_request.base.ref }}...HEAD

    # Check requirements
    echo ""
    echo "Checking for requirement references..."
    COMMIT_COUNT=$(git rev-list --count origin/${{ github.event.pull_request.base.ref }}...HEAD)
    COMMITS_WITH_REQ=$(git log --format=%B origin/${{ github.event.pull_request.base.ref }}...HEAD | grep -c "REQ-" || true)

    echo "Total commits: $COMMIT_COUNT"
    echo "Commits with REQ: $COMMITS_WITH_REQ"

    if [ "$COMMITS_WITH_REQ" -eq 0 ]; then
      echo "::error title=Missing Requirements::No commits reference requirements"
      echo "::error::Every commit must reference a requirement (REQ-xxxxx)"
      echo "::error::To fix this:"
      echo "::error::  1. Claim a requirement number"
      echo "::error::  2. Amend your commits with 'Implements: REQ-xxxxx'"
      echo "::error::  3. Force push your branch"
      exit 1
    fi

    echo "::endgroup::"
```

### Step 4: Implement Retry Logic
```yaml
# deploy-production.yml - Retry transient failures
- name: Deploy with retry
  uses: nick-fields/retry@v2
  with:
    timeout_minutes: 10
    max_attempts: 3
    retry_on: error
    retry_wait_seconds: 30
    command: |
      echo "Deployment attempt ${{ strategy.job-index }}"

      # Deploy function
      deploy_app() {
        supabase functions deploy --project-ref $PROJECT_ID
      }

      # Try deployment
      if ! deploy_app; then
        echo "::warning::Deployment failed, will retry..."
        return 1
      fi

      echo "✅ Deployment successful"

# build-publish-images.yml - Retry docker push
- name: Push image with retry
  run: |
    MAX_ATTEMPTS=3
    DELAY=10

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
      echo "Push attempt $attempt/$MAX_ATTEMPTS"

      if docker push "${{ env.REGISTRY }}/${{ env.IMAGE_TAG }}"; then
        echo "✅ Image pushed successfully"
        break
      fi

      if [ $attempt -eq $MAX_ATTEMPTS ]; then
        echo "::error::Failed to push after $MAX_ATTEMPTS attempts"
        exit 1
      fi

      echo "::warning::Push failed, retrying in ${DELAY}s..."
      sleep $DELAY
      DELAY=$((DELAY * 2))  # Exponential backoff
    done
```

### Step 5: Add Recovery and Rollback
```yaml
# database-migration.yml - Auto-rollback on failure
- name: Run migration with rollback
  run: |
    echo "::group::Database Migration"

    # Backup current state
    echo "Creating backup..."
    pg_dump "$DATABASE_URL" > backup-$(date +%s).sql

    # Run migration
    echo "Running migration..."
    if ! supabase db push; then
      echo "::error::Migration failed, initiating rollback"

      # Restore backup
      echo "Restoring from backup..."
      psql "$DATABASE_URL" < backup-*.sql

      echo "::error::Migration rolled back due to failure"
      echo "Review the migration and try again"
      exit 1
    fi

    echo "✅ Migration completed successfully"
    echo "::endgroup::"

# verify-archive-integrity.yml - Provide recovery steps
- name: Handle checksum mismatch
  run: |
    if ! sha256sum -c artifact.sha256; then
      echo "::error title=Integrity Check Failed::Checksum verification failed"
      echo "::error::This indicates the artifact may be corrupted"
      echo ""
      echo "Recovery steps:"
      echo "1. Re-download the artifact"
      echo "2. If issue persists, regenerate from source"
      echo "3. Check S3 bucket for backup copies"
      echo ""
      echo "Expected checksum:"
      cat artifact.sha256
      echo ""
      echo "Actual checksum:"
      sha256sum artifact.tar.gz
      exit 1
    fi
```

## Testing Requirements

1. **Error Message Tests**:
   - Trigger each error condition
   - Verify messages are informative
   - Check error annotations appear correctly

2. **Logging Tests**:
   - Review workflow run logs
   - Ensure all steps have clear output
   - Verify debug information is present

3. **Retry Logic Tests**:
   - Simulate transient failures
   - Verify retry attempts work
   - Check exponential backoff timing

4. **Recovery Tests**:
   - Test migration rollback
   - Verify backup restoration
   - Check recovery instructions are clear

## CI Success Criteria

- [ ] All error messages include context and recovery steps
- [ ] Failed workflows show clear root cause
- [ ] Transient failures are automatically retried
- [ ] Debug information is available for all steps
- [ ] Recovery procedures are documented inline

## Known Risks

1. **Increased Verbosity**:
   - Logs will be larger
   - More output to review
   - May need log aggregation

2. **Retry Delays**:
   - Failed deployments take longer to fail
   - May mask persistent issues
   - Could increase costs

## Success Metrics

- 50% reduction in "unclear failure" support tickets
- 75% of transient failures auto-recover
- All production failures have actionable error messages
- 100% of migrations can be rolled back
- Debug time reduced by 40%