# Phase 6: Production Stability

## Overview
This phase addresses issues that could cause production instability, undefined behavior, or silent failures that impact system reliability.

## Scope
**22 issues** affecting production stability, undefined variables, and error propagation.

## Priority: HIGH
These issues:
- Can cause production workflows to fail silently
- Create undefined behavior in critical paths
- Risk deployment failures without proper alerts
- May corrupt state or lose data

## Issues to Fix

### Undefined Variables & State (10 issues)
1. **Issue #9** - `build-publish-images.yml:173` - PLATFORMS undefined, will fail
2. **Issue #10** - `build-publish-images.yml:185` - IMAGE_TAG undefined for report
3. **Issue #11** - `build-publish-images.yml:434` - Webhook uses undefined $IMAGE_TAG
4. **Issue #17** - `deploy-staging.yml:45` - SPONSOR_SUBDOMAINS not exported
5. **Issue #18** - `pr-validation.yml:163` - $api_base undefined
6. **Issue #19** - `rollback.yml:102` - $DATABASE_URL undefined
7. **Issue #20** - `verify-archive-integrity.yml:147` - WORKFLOW_NAME not set
8. **Issue #27** - `build-publish-images.yml:215-223` - VULNERABILITIES not properly passed
9. **Issue #90** - `build-publish-images.yml:397` - image_size undefined
10. **Issue #111** - `archive-audit-trail.yml:102` - AUDIT_EXPORT_FILE undefined

### Silent Failures & Missing Error Handling (7 issues)
11. **Issue #14** - `deploy-production.yml:166` - mkdir without -p will fail if exists
12. **Issue #15** - `deploy-production.yml:168` - cp to non-existent directory
13. **Issue #21** - `rollback.yml:91` - ROLLBACK_SCRIPT lookup may fail
14. **Issue #24** - `database-migration.yml:102-106` - Empty PENDING check doesn't fail
15. **Issue #29** - `build-publish-images.yml:302-305` - JSON generation no validation
16. **Issue #31** - `verify-archive-integrity.yml:116` - find might return nothing
17. **Issue #112** - `deploy-production.yml:165-169` - Path creation race condition

### Critical Path Issues (5 issues)
18. **Issue #25** - `qa-automation.yml:249` - E2E tests exit 0 even on failure
19. **Issue #28** - `build-publish-images.yml:247-250` - Security scan doesn't block
20. **Issue #32** - `pr-validation.yml:22` - Bot validation only in PR title
21. **Issue #102** - `deploy-staging.yml:45-62` - Deploy continues despite errors
22. **Issue #103** - `build-publish-images.yml:171-195` - Build continues with undefined vars

## Implementation Steps

### Step 1: Fix Undefined Variables
```yaml
# build-publish-images.yml - Define all variables at job level
env:
  PLATFORMS: "linux/amd64,linux/arm64"
  IMAGE_TAG: "${{ github.sha }}"
  REGISTRY: "ghcr.io"

# deploy-staging.yml - Export variables properly
- name: Set sponsor subdomains
  run: |
    export SPONSOR_SUBDOMAINS="callisto.staging.hht-diary.com"
    echo "SPONSOR_SUBDOMAINS=$SPONSOR_SUBDOMAINS" >> $GITHUB_ENV

# pr-validation.yml - Define api_base
- name: Validate API endpoints
  run: |
    api_base="${{ secrets.SUPABASE_URL }}"
    if [ -z "$api_base" ]; then
      echo "::error::SUPABASE_URL not configured"
      exit 1
    fi
```

### Step 2: Add Proper Error Handling
```yaml
# deploy-production.yml - Safe directory creation
- name: Prepare deployment directory
  run: |
    DEPLOY_DIR="/opt/hht-diary/deployments/$(date +%Y%m%d-%H%M%S)"
    sudo mkdir -p "$DEPLOY_DIR"

    if [ ! -d "$DEPLOY_DIR" ]; then
      echo "::error::Failed to create deployment directory"
      exit 1
    fi

    echo "DEPLOY_DIR=$DEPLOY_DIR" >> $GITHUB_ENV

# rollback.yml - Safe rollback script lookup
- name: Find rollback script
  run: |
    VERSION="${{ github.event.inputs.target_version }}"
    ROLLBACK_SCRIPT=$(find database/migrations/rollbacks -name "*${VERSION}*.sql" -type f | head -n1)

    if [ -z "$ROLLBACK_SCRIPT" ]; then
      echo "::warning::No rollback script for version $VERSION"
      echo "Manual intervention required"
      echo "rollback_found=false" >> $GITHUB_OUTPUT
    else
      echo "Using rollback script: $ROLLBACK_SCRIPT"
      echo "rollback_script=$ROLLBACK_SCRIPT" >> $GITHUB_OUTPUT
      echo "rollback_found=true" >> $GITHUB_OUTPUT
    fi
```

### Step 3: Fix Silent Failures
```yaml
# qa-automation.yml - Proper test exit codes
- name: Run E2E tests
  id: e2e_tests
  run: |
    set -euo pipefail
    cd tools/testing/e2e

    if ! npm test; then
      echo "::error::E2E tests failed"
      echo "failed=true" >> $GITHUB_OUTPUT
      exit 1
    fi

    echo "failed=false" >> $GITHUB_OUTPUT

# build-publish-images.yml - Validate security scan
- name: Run security scan
  run: |
    trivy image --severity HIGH,CRITICAL \
      --exit-code 1 \
      --format json \
      --output trivy-report.json \
      "${{ env.IMAGE_TAG }}"

    # Parse results
    CRITICAL_COUNT=$(jq '.Results[].Vulnerabilities | map(select(.Severity == "CRITICAL")) | length' trivy-report.json | awk '{sum+=$1} END {print sum}')

    if [ "$CRITICAL_COUNT" -gt 0 ]; then
      echo "::error::Found $CRITICAL_COUNT critical vulnerabilities"
      exit 1
    fi
```

### Step 4: Add State Validation
```yaml
# verify-archive-integrity.yml - Check for artifacts
- name: Find artifacts to verify
  id: find_artifacts
  run: |
    ARTIFACTS=$(find ./artifacts -name "*.tar.gz" 2>/dev/null || true)

    if [ -z "$ARTIFACTS" ]; then
      echo "::warning::No artifacts found to verify"
      echo "found=false" >> $GITHUB_OUTPUT
      exit 0
    fi

    echo "Found artifacts:"
    echo "$ARTIFACTS"
    echo "artifacts<<EOF" >> $GITHUB_OUTPUT
    echo "$ARTIFACTS" >> $GITHUB_OUTPUT
    echo "EOF" >> $GITHUB_OUTPUT
    echo "found=true" >> $GITHUB_OUTPUT

# database-migration.yml - Validate migration state
- name: Check for pending migrations
  run: |
    PENDING=$(supabase db diff --local 2>/dev/null || echo "ERROR")

    if [ "$PENDING" = "ERROR" ]; then
      echo "::error::Failed to check migration status"
      exit 1
    fi

    if [ -n "$PENDING" ]; then
      echo "::error::Pending migrations found:"
      echo "$PENDING"
      exit 1
    fi

    echo "✅ No pending migrations"
```

### Step 5: Add Workflow Guards
```yaml
# Add to all production deployment workflows
- name: Validate deployment prerequisites
  run: |
    # Check all required secrets are present
    required_secrets="SUPABASE_PROJECT_ID DATABASE_URL AWS_ACCESS_KEY_ID"

    for secret in $required_secrets; do
      if [ -z "${!secret:-}" ]; then
        echo "::error::Required secret $secret is not configured"
        exit 1
      fi
    done

    # Check all required tools
    required_tools="supabase aws jq"

    for tool in $required_tools; do
      if ! command -v $tool &> /dev/null; then
        echo "::error::Required tool $tool is not installed"
        exit 1
      fi
    done

    echo "✅ All prerequisites validated"
```

## Testing Requirements

1. **Variable Definition Tests**:
   - Run workflows with GitHub Actions debugger
   - Verify all variables are defined before use
   - Check GITHUB_ENV exports work correctly

2. **Error Propagation Tests**:
   - Simulate failures at each step
   - Verify workflows fail appropriately
   - Check error messages are informative

3. **State Validation Tests**:
   - Test with missing artifacts
   - Test with empty databases
   - Test with invalid configurations

## CI Success Criteria

- [ ] All workflows complete without undefined variable errors
- [ ] Failed tests cause workflow failure (no exit 0 on error)
- [ ] Security scans block deployment when issues found
- [ ] All mkdir operations use -p flag
- [ ] All file operations check target exists

## Known Risks

1. **Breaking Changes**:
   - Workflows that were "passing" with hidden errors will fail
   - Missing secrets will now block deployments
   - Some "successful" deployments were actually incomplete

2. **Performance Impact**:
   - Additional validation adds 10-20 seconds
   - State checks add database queries
   - Guards may reveal configuration issues

## Rollback Plan

If stability issues occur:
1. Identify which validation is causing issues
2. Temporarily add bypass flag for that validation
3. Fix root cause
4. Remove bypass flag

## Success Metrics

- Zero undefined variable errors in production
- 100% test failure detection rate
- All security vulnerabilities blocked before deployment
- No silent failures in critical paths
- Complete audit trail for all deployments