# Production Tagging and Hotfix Process

Complete guide for tagging production candidates and managing hotfixes.

## IMPLEMENTS REQUIREMENTS
- REQ-d00072: Production candidate tagging
- REQ-o00018: Release management
- REQ-o00019: Hotfix workflow

## Overview

The production tagging workflow enables:
1. **Production Candidates**: Tag specific builds as production-ready
2. **Traceability**: Lock all sponsor commits to specific SHAs
3. **Hotfixes**: Create patches from tagged releases
4. **FDA Compliance**: Complete audit trail for all releases

## Production Candidate Workflow

### 1. Build Integrated App

First, create a build using the integrated build workflow:

```bash
gh workflow run build-integrated.yml -f archive_artifacts=true
```

**Wait for completion**, then note the **run ID** (e.g., `12345678`).

### 2. Verify Build

Check build artifacts and manifest:

```bash
# Download manifest
gh run download 12345678 -n sponsor-build-manifest

# Inspect manifest
cat sponsor-build-manifest.json | jq '.'

# Verify sponsors
cat sponsor-build-manifest.json | jq '.sponsors'
```

### 3. Tag as Production Candidate

```bash
gh workflow run tag-production-candidate.yml \
  -f version=v1.2.3 \
  -f github_run_id=12345678 \
  -f description="First production release with Callisto sponsor"
```

**Inputs:**
- `version`: Semantic version tag (e.g., `v1.2.3`)
- `github_run_id`: Run ID from build-integrated workflow
- `description`: Human-readable release description

### 4. Verify Release

```bash
# Check GitHub release
gh release view v1.2.3

# Download artifacts
gh release download v1.2.3

# Verify manifest
cat sponsor-build-manifest.json | jq '.'
```

## Workflow Steps

### Job 1: validate-build
1. Downloads build manifest from specified run ID
2. Parses core SHA and sponsor SHAs
3. Validates version format (`vX.Y.Z`)
4. Checks version uniqueness (tag doesn't exist)

### Job 2: tag-core-repo
1. Checks out core repository
2. Creates annotated tag with full metadata:
   - Version and description
   - Build run ID
   - Core SHA
   - All sponsor SHAs
   - Timestamp and actor
3. Pushes tag to repository

### Job 3: create-release
1. Downloads build artifacts (APK, AAB, manifest)
2. Generates comprehensive release notes
3. Creates GitHub release with:
   - Tag reference
   - Release notes (markdown)
   - Attached artifacts (APK, AAB, manifest)

### Job 4: notify-summary
1. Generates workflow summary
2. Lists all sponsors and their commit SHAs
3. Shows job status

## Tag Format

### Annotated Tag Message

```
Production Candidate: v1.2.3

First production release with Callisto sponsor

Build Information:
- GitHub Run ID: 12345678
- Core SHA: a1b2c3d4e5f6g7h8...
- Timestamp: 2025-01-10T12:34:56Z
- Tagged by: github-actions[bot]

Sponsors:
  - callisto (CAL) @ a1b2c3d4e5f6g7h8...

Build Manifest:
https://github.com/Cure-HHT/hht_diary/actions/runs/12345678

Artifacts:
- APK: app-release-apk
- AAB: app-release-aab
- Manifest: sponsor-build-manifest
```

## Hotfix Process

### Scenario
Bug found in production candidate `v1.2.3` that requires immediate fix.

### Step 1: Create Hotfix Branch

```bash
# Checkout production tag
git checkout v1.2.3

# Create hotfix branch
git checkout -b hotfix/v1.2.3-patch1
```

### Step 2: Make Fix

```bash
# Fix the bug
vim path/to/buggy/file.dart

# Commit with REQ reference
git add .
git commit -m "[REQ-d00123] Fix critical bug in authentication

Description of fix...

Hotfix for: v1.2.3
Implements: REQ-d00123"
```

### Step 3: Rebuild with Same Sponsors

**CRITICAL**: Hotfix must use SAME sponsor commits as original release.

**Option A: Mono-Repo (Current)**
```bash
# Sponsors are already at correct commits (mono-repo)
# Just rebuild
gh workflow run build-integrated.yml -f archive_artifacts=true
```

**Option B: Multi-Repo (Future)**
```bash
# Extract sponsor SHAs from original build manifest
CALLISTO_SHA=$(jq -r '.sponsors[] | select(.name=="callisto") | .git_sha' sponsor-build-manifest.json)

# Manually check out sponsor repos at those SHAs
cd sponsor/callisto
git checkout $CALLISTO_SHA
cd ../..

# Then rebuild
gh workflow run build-integrated.yml -f archive_artifacts=true
```

### Step 4: Tag Hotfix

```bash
# Get new build run ID (e.g., 12345679)
gh workflow run tag-production-candidate.yml \
  -f version=v1.2.3-patch1 \
  -f github_run_id=12345679 \
  -f description="Hotfix for v1.2.3: Fix critical authentication bug"
```

### Step 5: Merge Back to Main

```bash
# Switch to main
git checkout main

# Merge hotfix
git merge hotfix/v1.2.3-patch1

# Push
git push origin main

# Delete hotfix branch
git branch -d hotfix/v1.2.3-patch1
```

## Hotfix Constraints

### MUST
- ✅ Use SAME sponsor commits as original release
- ✅ Include REQ references in commit messages
- ✅ Tag with `-patch{N}` suffix (e.g., `v1.2.3-patch1`)
- ✅ Merge back to main after hotfix
- ✅ Archive to S3 (same as regular release)

### MUST NOT
- ❌ Update sponsor versions (breaks traceability)
- ❌ Add new features (hotfixes are for bugs only)
- ❌ Skip archival (FDA compliance requirement)

## Version Numbering

### Semantic Versioning

**Format**: `vMAJOR.MINOR.PATCH[-SUFFIX]`

**Examples:**
- `v1.0.0` - Initial production release
- `v1.1.0` - New feature release
- `v1.1.1` - Bug fix release
- `v1.1.1-patch1` - Hotfix for v1.1.1
- `v2.0.0` - Breaking change release

**Rules:**
- MAJOR: Breaking changes
- MINOR: New features (backwards-compatible)
- PATCH: Bug fixes (backwards-compatible)
- SUFFIX: Hotfixes (`-patch1`, `-patch2`, etc.)

## FDA Compliance

### Release Archives

Every tagged release is archived to per-sponsor S3 buckets:

**Location**: `s3://{bucket}/builds/YYYY/MM/DD/hht-diary-{CODE}-{SHA}.tar.gz`

**Contents:**
- `app-release.apk`
- `app-release.aab`
- `sponsor-build-manifest.json`
- `metadata.json`

**Retention**: 7 years (FDA 21 CFR Part 11)

### Audit Trail

**Git Tags:**
- Annotated tags with full metadata
- Core SHA + all sponsor SHAs
- Timestamp and actor
- Build run reference

**Build Manifest:**
- Complete traceability
- All repository commits
- Build timestamp
- Integrated sponsors

**GitHub Releases:**
- Public record of all releases
- Attached artifacts (APK, AAB, manifest)
- Release notes with full details

## Troubleshooting

### "Version tag already exists"

```bash
# List existing tags
git tag -l "v*"

# Delete tag (if really needed)
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3

# Re-tag
gh workflow run tag-production-candidate.yml -f version=v1.2.3 ...
```

### "Build manifest not found"

Check run ID is correct:
```bash
# List recent runs
gh run list --workflow=build-integrated.yml --limit=10

# View specific run
gh run view 12345678

# Check artifacts
gh run view 12345678 --log
```

### "Sponsor SHA mismatch"

For hotfixes, verify sponsor commits:
```bash
# Original release manifest
gh release download v1.2.3 -p sponsor-build-manifest.json -O original-manifest.json

# Compare with current
diff original-manifest.json build/sponsor-build-manifest.json
```

If sponsors differ, check out original SHAs before rebuilding.

### "Release creation failed"

Check GitHub permissions:
```bash
# Verify GITHUB_TOKEN has release permissions
gh auth status

# Retry manually
gh release create v1.2.3 \
  --title "Production Candidate: v1.2.3" \
  --notes "..." \
  app-release.apk \
  app-release.aab \
  sponsor-build-manifest.json
```

## Best Practices

### 1. Test Before Tagging
- Run full QA suite on build
- Verify all sponsors integrated correctly
- Check build manifest accuracy

### 2. Descriptive Release Notes
- Explain what's new/fixed
- List breaking changes
- Include migration guide (if applicable)

### 3. Hotfix Discipline
- Only critical bugs
- No feature additions
- Always merge back to main

### 4. Version Planning
- Plan major/minor releases in advance
- Communicate breaking changes early
- Document version roadmap

### 5. Archive Verification
- Always verify S3 upload succeeded
- Check archive integrity (download + extract)
- Confirm 7-year retention policy applied

## Examples

### Example 1: First Production Release

```bash
# 1. Build
gh workflow run build-integrated.yml -f archive_artifacts=true
# Run ID: 12345678

# 2. Verify
gh run view 12345678
gh run download 12345678 -n sponsor-build-manifest

# 3. Tag
gh workflow run tag-production-candidate.yml \
  -f version=v1.0.0 \
  -f github_run_id=12345678 \
  -f description="Initial production release with Callisto sponsor"

# 4. Verify release
gh release view v1.0.0
```

### Example 2: Feature Release

```bash
# 1. Build new features
gh workflow run build-integrated.yml -f archive_artifacts=true
# Run ID: 12345679

# 2. Tag
gh workflow run tag-production-candidate.yml \
  -f version=v1.1.0 \
  -f github_run_id=12345679 \
  -f description="Added patient questionnaire feature"

# 3. Announce
gh release view v1.1.0 --web
```

### Example 3: Hotfix

```bash
# 1. Create hotfix branch
git checkout v1.1.0
git checkout -b hotfix/v1.1.0-patch1

# 2. Fix bug
vim lib/services/auth.dart
git commit -m "[REQ-d00456] Fix session timeout bug"

# 3. Rebuild (same sponsors)
gh workflow run build-integrated.yml -f archive_artifacts=true
# Run ID: 12345680

# 4. Tag hotfix
gh workflow run tag-production-candidate.yml \
  -f version=v1.1.0-patch1 \
  -f github_run_id=12345680 \
  -f description="Hotfix: Fix session timeout causing crashes"

# 5. Merge back
git checkout main
git merge hotfix/v1.1.0-patch1
git push
```

## See Also

- Build Workflow: `.github/workflows/build-integrated.yml`
- Tagging Workflow: `.github/workflows/tag-production-candidate.yml`
- Build Workflow Docs: `docs/build-integrated-workflow.md`
- Doppler Setup: `docs/doppler-setup.md`
- S3 Archival: `sponsor/callisto/infrastructure/terraform/README.md`
