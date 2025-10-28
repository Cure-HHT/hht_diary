# Docker Environment Maintenance Guide

**Purpose**: Ensure FDA 21 CFR Part 11 compliance through regular review and updates.

**Last Updated**: 2025-10-28

---

## Automated Enforcement

GitHub Actions automatically checks file modification dates monthly:
- **Quarterly Review (90 days)**: Role-specific Dockerfiles, warning baselines
- **Annual Review (365 days)**: Base image

**Workflow**: `.github/workflows/maintenance-check.yml`

### What Happens

1. **Monthly Check**: 1st of each month at 9:00 UTC
2. **Failure Behavior**: Creates GitHub issue if files are stale
3. **Success Behavior**: Generates maintenance report

---

## Quarterly Maintenance (Every 90 Days)

### Files to Review

1. `docker/dev.Dockerfile` - Developer environment
2. `docker/qa.Dockerfile` - QA environment
3. `docker/ops.Dockerfile` - Operations environment
4. `EXPECTED_WARNINGS.md` - Warning baseline

### Review Checklist

```bash
# 1. Check for outdated tool versions
./check-versions.sh  # Helper script (create if needed)

# 2. Review each file
cat docker/dev.Dockerfile | grep "ENV.*_VERSION"

# 3. Check release notes
# - Supabase CLI: https://github.com/supabase/cli/releases
# - kubectl: https://github.com/kubernetes/kubernetes/releases
# - Cosign: https://github.com/sigstore/cosign/releases
# - Syft: https://github.com/anchore/syft/releases
# - Grype: https://github.com/anchore/grype/releases

# 4. Security advisories
# Check each tool's GitHub security tab

# 5. Test if updating
./setup.sh --build-only
docker run --rm clinical-diary-dev:latest flutter doctor -v

# 6. Commit (even if no changes)
git add docker/*.Dockerfile EXPECTED_WARNINGS.md
git commit -m "[MAINTENANCE] Quarterly review - $(date +%Y-%m-%d)"
git push origin main
```

### Version Update Process

**If security patch**: Update immediately
```bash
# Example: Supabase security fix
vim docker/dev.Dockerfile
# Change: ENV SUPABASE_CLI_VERSION=v2.54.10
# To:     ENV SUPABASE_CLI_VERSION=v2.54.11

git commit -m "[SECURITY] Update Supabase CLI to v2.54.11 (CVE-XXXX-XXXX)"
```

**If feature update**: Evaluate during quarterly review
1. Read release notes
2. Check breaking changes
3. Test in dev environment first
4. Update with documented reasoning

---

## Annual Maintenance (Every 365 Days)

### Files to Review

1. `docker/base.Dockerfile` - Foundation image

### Review Checklist

```bash
# 1. Review Ubuntu LTS version
# Currently: Ubuntu 24.04 LTS
# Next LTS: Check ubuntu.com for release schedule

# 2. Review Node.js LTS
# Currently: Node 20.x
# Check: https://nodejs.org/en/about/previous-releases

# 3. Review Python version
# Currently: Python 3.x (system)
# Check: python.org for latest stable

# 4. Review base tooling
# - Git (from PPA)
# - GitHub CLI
# - Doppler

# 5. Full regression test
./setup.sh --build-only
# Test all 5 images
# Run full app build test

# 6. Commit
git add docker/base.Dockerfile
git commit -m "[MAINTENANCE] Annual review - $(date +%Y-%m-%d)"
git push origin main
```

---

## Warning Baseline Review

### When to Review

1. **Quarterly**: Check if suppressions still valid
2. **After tool updates**: New warnings may appear
3. **After Flutter updates**: Doctor output changes

### Process

```bash
# 1. Run warning validation
./validate-warnings.sh dev

# 2. Review report
cat validation-reports/warnings-dev-*.txt

# 3. Check for new warnings
# If new warnings appear:
#   - Investigate root cause
#   - Suppress at source if possible
#   - Document in EXPECTED_WARNINGS.md if can't suppress
#   - Update validate-warnings.sh patterns

# 4. Remove obsolete suppressions
# If expected warnings no longer appear:
#   - Update EXPECTED_WARNINGS.md
#   - Document what changed
#   - Update validate-warnings.sh

# 5. Commit
git add EXPECTED_WARNINGS.md validate-warnings.sh
git commit -m "[MAINTENANCE] Quarterly warning baseline review"
git push origin main
```

---

## Emergency Maintenance

### Security Vulnerabilities

**Trigger**: CVE announcement for pinned tool

**Process**:
1. Assess severity (CVSS score)
2. Check if we're affected (version comparison)
3. Update immediately if critical
4. Test in dev environment
5. Deploy to all images
6. Document in commit message

**Example**:
```bash
git checkout -b hotfix/cve-2025-xxxxx
# Update affected Dockerfile(s)
./setup.sh --build-only
# Test
git commit -m "[SECURITY HOTFIX] CVE-2025-XXXXX: Update <tool> to <version>"
git push origin hotfix/cve-2025-xxxxx
# Create PR, merge immediately after review
```

---

## Maintenance Records

### Audit Trail

All maintenance is recorded in:
1. **Git commits**: Timestamped, author-attributed
2. **GitHub Actions logs**: Automated check results
3. **GitHub Issues**: Overdue maintenance tracking
4. **This file**: Last Updated date

### FDA Compliance Evidence

For audits, provide:
1. GitHub Actions workflow history (`.github/workflows/maintenance-check.yml`)
2. Git log filtered by `[MAINTENANCE]` commits
3. Closed maintenance issues
4. This documentation

**Export audit evidence**:
```bash
# Generate compliance report
git log --all --oneline --grep="\[MAINTENANCE\]" > maintenance-audit-trail.txt
gh issue list --label maintenance --state all --json number,title,createdAt,closedAt > maintenance-issues.json
```

---

## Deferred Maintenance

### If Quarterly Review Missed

**Immediate Actions**:
1. Acknowledge the GitHub issue
2. Schedule review within 7 days
3. Perform full review (not just timestamp update)
4. Document any risks in issue comments
5. Add calendar reminder for next review

**Documentation**:
```bash
# In GitHub issue:
"Quarterly review deferred by X days due to [reason].
Risk assessment: [Low/Medium/High]
Mitigation: [Actions taken]
Scheduled completion: [Date]"
```

---

## Tool-Specific Notes

### Supabase CLI

- **Update Frequency**: Quarterly (unless security patch)
- **Breaking Changes**: Review migration guides
- **Test Command**: `supabase --version && supabase db diff --help`

### Flutter

- **Update Frequency**: Align with stable channel releases
- **Major Updates**: Require full regression testing
- **Test Command**: `flutter doctor -v && flutter build apk --debug`

### Android SDK

- **Update Frequency**: As needed for new platform releases
- **Build Tools**: Update when Flutter requires
- **Test Command**: `sdkmanager --list | grep installed`

---

## Maintenance Schedule Template

Copy to team calendar:

```
# Docker Environment Maintenance Schedule

## 2025
- ✅ Q1 Review: 2025-01-15 (Completed)
- ✅ Q2 Review: 2025-04-15 (Completed)
- ✅ Q3 Review: 2025-07-15 (Completed)
- ⏰ Q4 Review: 2025-10-28 (Today)
- 📅 Annual Review: 2025-10-28 (Completed)

## 2026
- 📅 Q1 Review: 2026-01-15
- 📅 Q2 Review: 2026-04-15
- 📅 Q3 Review: 2026-07-15
- 📅 Q4 Review: 2026-10-15
- 📅 Annual Review: 2026-10-28
```

---

## Questions?

**"Do I really need to update if nothing changed?"**
Yes - the timestamp update proves you reviewed. This is for audit compliance.

**"Can I batch multiple quarterly reviews?"**
No - each review must be done within its 90-day window. Batching defeats the purpose.

**"What if I'm on vacation during review time?"**
Assign a backup reviewer or schedule the review before/after vacation.

**"Can I disable the GitHub Action?"**
Not recommended - it's your automated compliance proof. If you must, document why in an ADR.

---

## See Also

- `.github/workflows/maintenance-check.yml` - Automated enforcement
- `EXPECTED_WARNINGS.md` - Warning baseline documentation
- `validate-warnings.sh` - Warning validation tool
- Project CLAUDE.md - Requirement traceability system
