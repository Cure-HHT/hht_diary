# Phase 5: Compliance & Safety - Discussion Points

## Overview
This document outlines decision points and non-standard issues in Phase 5 that require team input before implementation.

## Decision Points Required

### 1. REQ Enforcement Strategy (Issue #113)
**Current State**: PR validation only warns about missing REQ references
**Options**:
1. **Hard block** - Reject all PRs without REQ references immediately
2. **Grace period** - Warn for 2 weeks, then enforce
3. **Grandfathering** - Only enforce on new files/changes

**Considerations**:
- Immediate enforcement will block all existing PRs
- Some emergency fixes may not have pre-assigned REQs
- Bot commits might need exemption

**Recommendation**: Option 2 with emergency bypass mechanism

### 2. 7-Year Retention Implementation (Issue #114)
**Current State**: Placeholder comment "TODO: Upload to S3 Glacier"
**Questions**:
- Should we use S3 Glacier Instant Retrieval or Glacier Flexible Retrieval?
- Do we need cross-region replication for compliance?
- Should retention be exactly 7 years or longer for safety?

**Cost Impact**:
- Glacier IR: ~$0.004/GB/month
- Glacier Flexible: ~$0.0036/GB/month
- Cross-region adds ~$0.02/GB transferred

**Recommendation**: Glacier IR with 7.5-year retention, single region initially

### 3. Database Reset in Development (Issue #16)
**Current State**: `supabase db reset` destroys all data
**Options**:
1. **Remove entirely** - Never reset, use migrations only
2. **Add confirmation** - Require explicit flag/confirmation
3. **Backup first** - Auto-backup before reset
4. **Keep as-is** - Document as destructive

**Considerations**:
- Developers expect clean slate in dev
- Some teams may have test data they want to preserve
- Reset is faster than migration chain for major changes

**Recommendation**: Option 3 - Auto-backup with restore command

### 4. Concurrency Control Method (Issue #12, #101)
**Current State**: No concurrency control for REQ assignment
**Options**:
1. **GitHub API locks** - Use deployment locks
2. **Database sequence** - PostgreSQL sequence
3. **File-based lock** - Lock file in repo
4. **Queue-based** - GitHub Actions concurrency groups

**Trade-offs**:
- API locks are complex but reliable
- Database requires external state
- File locks can conflict with branch protection
- Queue-based is simple but may cause delays

**Recommendation**: Option 4 - Concurrency groups with cancel-in-progress: false

### 5. Bot Detection Bypass Fix (Issue #119)
**Current State**: Any commit with "Bot:" prefix bypasses validation
**Security Risk**: High - allows unauthorized bypasses
**Options**:
1. **Exact match** - Only "github-actions[bot]"
2. **Signed commits** - Require GPG signature
3. **Token validation** - Check GITHUB_TOKEN permissions
4. **Remove bypass** - No special bot handling

**Recommendation**: Option 1 + Option 3 for defense in depth

### 6. Empty Audit Export Handling (Issue #115)
**Current State**: Empty exports only warn, don't fail
**Options**:
1. **Always fail** - Empty export = failure
2. **Context-aware** - Fail in prod, warn in dev
3. **Threshold-based** - Fail if < X records
4. **Time-based** - Only fail if system has been running > 24h

**Recommendation**: Option 2 with Option 4 for production

## Non-Standard Implementation Notes

### Certificate Verification (Issue #116)
The weak certificate verification (`curl -k`) appears 5 times. This is likely for:
- Self-signed certificates in staging
- Internal PKI not in system trust store

**Action**: Needs security team review to determine if intentional

### Placeholder Version in Rollback (Issue #117)
```yaml
echo "From Version: [Previous]"  # Should be actual version
```
**Challenge**: Determining "current" version during rollback
**Solution**: Store version in deployment record, retrieve during rollback

### Invalid JSON Fields (Issue #118, #120)
Two workflows use invalid JSON fields:
- `job.duration` instead of valid GitHub context
- Undefined variables in JSON construction

**Note**: These will cause immediate workflow failures when fixed

## Risk Assessment

### Breaking Changes
These fixes WILL break existing workflows:
1. REQ enforcement - All PRs need requirements
2. Error suppression removal - Hidden failures will surface
3. Database backup enforcement - Adds 30-60s to workflows

### Performance Impact
1. S3 uploads: +30-60s per deployment
2. Backup operations: +15-30s
3. Concurrency queuing: Variable delays
4. Checksum verification: +5-10s

### Cost Impact
1. S3 Glacier storage: ~$50/month after 1 year
2. Additional API calls: ~$10/month
3. Larger artifacts storage: ~$20/month

## Rollback Strategy

If Phase 5 causes issues:
1. **Hour 1**: Revert PR, assess impact
2. **Hour 2-4**: Cherry-pick non-breaking fixes
3. **Day 2**: Re-implement with adjustments
4. **Week 2**: Full implementation with monitoring

## Testing Requirements

### Pre-Production Testing
1. Create test PRs without REQ references
2. Simulate concurrent REQ assignments (10 parallel)
3. Test with empty database exports
4. Verify S3 uploads and retention policies
5. Test rollback with missing versions

### Monitoring After Deployment
1. PR validation failure rate
2. Workflow execution times
3. S3 storage costs
4. Concurrent assignment conflicts
5. Audit trail completeness

## Stakeholder Approval Needed

- [ ] **Security Team**: Certificate verification, bot detection
- [ ] **Compliance Team**: FDA retention, audit trail format
- [ ] **Infrastructure Team**: S3 costs, retention policies
- [ ] **Development Team**: REQ enforcement, breaking changes
- [ ] **Finance**: Ongoing AWS costs

## Implementation Order

Suggested order to minimize disruption:
1. Data integrity fixes (non-breaking)
2. S3 uploads and retention (additive)
3. Concurrency control (transparent)
4. Warning → Error conversions (coordinated)
5. REQ enforcement (with notice period)

## Questions for Team

1. **Emergency bypass**: Should we have a break-glass mechanism for REQ enforcement?
2. **Grandfathering**: Should existing code be exempt from REQ requirements?
3. **Cost threshold**: What's acceptable for S3/Glacier storage costs?
4. **Downtime tolerance**: Can we accept 5-minute workflow queuing?
5. **Migration strategy**: Big bang or gradual rollout?