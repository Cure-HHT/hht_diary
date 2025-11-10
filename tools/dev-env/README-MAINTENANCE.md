# Development Environment Maintenance

## Maintenance Schedule

### Quarterly Review (Every 90 Days)
**Files**: `docker/dev.Dockerfile`, `docker/qa.Dockerfile`, `docker/ops.Dockerfile`

**Process**:
```bash
# 1. Check for outdated tool versions
# Review release notes for:
# - Supabase CLI: https://github.com/supabase/cli/releases
# - kubectl: https://github.com/kubernetes/kubernetes/releases
# - Cosign: https://github.com/sigstore/cosign/releases
# - Syft: https://github.com/anchore/syft/releases
# - Grype: https://github.com/anchore/grype/releases

# 2. Check security advisories
# Visit GitHub security tab for each tool

# 3. Test if updating
./setup.sh --rebuild
docker run --rm clinical-diary-dev:latest flutter doctor -v

# 4. Commit (even if no changes - proves review was done)
git add docker/*.Dockerfile
git commit -m "[MAINTENANCE] Quarterly review - $(date +%Y-%m-%d)"
git push origin main
```

### Annual Review (Every 365 Days)
**Files**: `docker/base.Dockerfile`

**Process**:
```bash
# 1. Review base OS (Ubuntu LTS)
# Currently: Ubuntu 24.04 LTS
# Check: ubuntu.com for new LTS releases

# 2. Review Node.js LTS
# Currently: Node 20.x
# Check: https://nodejs.org/en/about/previous-releases

# 3. Review Python version
# Currently: Python 3.x (system)

# 4. Full regression test
./setup.sh --rebuild
./validate-environment.sh --full

# 5. Commit
git add docker/base.Dockerfile
git commit -m "[MAINTENANCE] Annual review - $(date +%Y-%m-%d)"
git push origin main
```

## Version Update Process

### Security Patches (Immediate)
```bash
# Example: Supabase security fix
vim docker/ops.Dockerfile
# Change: ENV SUPABASE_CLI_VERSION=v2.54.10
# To:     ENV SUPABASE_CLI_VERSION=v2.54.11

git commit -m "[SECURITY] Update Supabase CLI to v2.54.11 (CVE-XXXX-XXXX)"
git push origin main
```

### Feature Updates (During Quarterly Review)
1. Read release notes
2. Check breaking changes
3. Test in dev environment
4. Update if stable and beneficial

## Known Warnings (Expected)

These warnings appear during builds and are documented as acceptable:

### Flutter Doctor
1. **Chrome not found** - Mobile-first app, web builds not in scope
2. **Linux toolchain missing** - Desktop builds not in scope
3. **Android Studio not installed** - CLI tools sufficient, IDE not needed

### Android SDK
4. **Package in inconsistent location** - SDK internal behavior, builds work fine

### npm
5. **New major version available** - Intentionally pinned for reproducibility

If you see **different warnings**, investigate before suppressing.

## Emergency Maintenance

### Security Vulnerability (CVE)
```bash
# 1. Assess severity (CVSS score)
# 2. Check if affected (version comparison)
# 3. Create hotfix branch
git checkout -b hotfix/cve-2025-xxxxx

# 4. Update affected Dockerfile(s)
vim docker/ops.Dockerfile  # or relevant file

# 5. Test
./setup.sh --rebuild
docker compose up -d ops
docker compose exec ops <tool> --version

# 6. Commit and merge immediately
git commit -m "[SECURITY HOTFIX] CVE-2025-XXXXX: Update <tool> to <version>"
git push origin hotfix/cve-2025-xxxxx
# Create PR, merge after review
```

## Tool-Specific Notes

### Supabase CLI
- **Update Frequency**: Quarterly (unless security patch)
- **Test Command**: `supabase --version && supabase db diff --help`

### Flutter
- **Update Frequency**: Align with stable channel releases
- **Test Command**: `flutter doctor -v && flutter build apk --debug`
- **Note**: Major updates require full regression testing

### Android SDK
- **Update Frequency**: As needed for new platform releases
- **Test Command**: `sdkmanager --list | grep installed`

## Audit Trail

All maintenance is recorded in:
1. Git commits (timestamped, author-attributed)
2. GitHub Actions logs (`.github/workflows/maintenance-check.yml`)
3. GitHub Issues (overdue maintenance tracking)

For FDA compliance audits:
```bash
# Generate maintenance history
git log --all --oneline --grep="\[MAINTENANCE\]" > maintenance-audit-trail.txt
gh issue list --label maintenance --state all --json number,title,createdAt,closedAt > maintenance-issues.json
```

## Deferred Maintenance

If quarterly review is missed:
1. Acknowledge GitHub issue (if created by automation)
2. Schedule review within 7 days
3. Perform full review (not just timestamp update)
4. Document risk assessment in issue comments

## Calendar Template

Copy to your calendar:

```
2025 Maintenance Schedule
─────────────────────────
Q1 Review: January 15
Q2 Review: April 15
Q3 Review: July 15
Q4 Review: October 15
Annual Review: October 15

2026 Maintenance Schedule
─────────────────────────
Q1 Review: January 15
Q2 Review: April 15
Q3 Review: July 15
Q4 Review: October 15
Annual Review: October 15
```

## Validation After Updates

After any Dockerfile changes:
```bash
# Rebuild
./setup.sh --rebuild

# Run full validation
./validate-environment.sh --full

# Test role-specific functionality
docker compose exec dev flutter doctor -v
docker compose exec qa npx playwright --version
docker compose exec ops terraform --version
docker compose exec mgmt git --version

# Build test Flutter app
docker compose exec dev bash -c "cd /workspace/repos && flutter create test_app && cd test_app && flutter build apk --debug"
```

## FAQ

**Q: Do I really need to commit if nothing changed?**
A: Yes - the timestamp update proves you reviewed. This is for audit compliance.

**Q: Can I batch multiple quarterly reviews?**
A: No - each review must be done within its 90-day window.

**Q: Can I disable the GitHub Action?**
A: Not recommended - it's automated compliance proof. Document reason in ADR if you must.

## See Also

- `.github/workflows/maintenance-check.yml` - Automated enforcement
- `../../docs/adr/ADR-006-docker-dev-environments.md` - Architecture decisions
- `../../spec/dev-environment.md` - Requirements
