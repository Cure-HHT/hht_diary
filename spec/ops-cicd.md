# Operations Specification: CI/CD Pipeline for Requirement Traceability

**Audience**: DevOps, Operations, Release Management
**Status**: Active
**Last Updated**: 2025-10-28

## Overview

This document specifies the continuous integration and continuous delivery (CI/CD) pipeline for validating requirement traceability, ensuring FDA 21 CFR Part 11 compliance, and maintaining audit trail integrity throughout the software development lifecycle.

## Table of Contents

- [Requirements](#requirements)
- [CI/CD Pipeline Architecture](#cicd-pipeline-architecture)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Branch Protection Configuration](#branch-protection-configuration)
- [Testing Procedures](#testing-procedures)
- [Troubleshooting](#troubleshooting)
- [Monitoring and Alerts](#monitoring-and-alerts)
- [FDA Compliance](#fda-compliance)

---

## Requirements

### REQ-o00052: CI/CD Pipeline for Requirement Traceability

**Level**: Ops | **Implements**: d00002, p00010 | **Status**: Active

**Description**: The system SHALL provide automated CI/CD validation of requirement traceability on every pull request and commit to protected branches.

**Acceptance Criteria**:

1. ✅ GitHub Actions workflow validates requirement format and IDs
2. ✅ Workflow generates traceability matrix automatically
3. ✅ Pull requests cannot merge without passing validation
4. ✅ Validation results posted as PR comments
5. ✅ Artifacts retained for 90 days for audit purposes
6. ✅ Failed validations trigger notifications
7. ✅ Workflow runs complete within 10 minutes

**Validation Method**: Trigger workflow with intentional errors, verify failure detection

**Implementation Files**:
- `.github/workflows/pr-validation.yml`
- `tools/requirements/validate_requirements.py`
- `tools/requirements/generate_traceability.py`

---

### REQ-o00053: Branch Protection Enforcement

**Level**: Ops | **Implements**: o00052, p00010 | **Status**: Active

**Description**: The system SHALL enforce branch protection rules on `main` and `develop` branches that require passing CI/CD checks before merge.

**Acceptance Criteria**:

1. ✅ Direct commits to `main` blocked
2. ✅ Direct commits to `develop` blocked
3. ✅ Merge requires PR approval
4. ✅ Merge requires passing status checks
5. ✅ Status checks include requirement validation
6. ✅ Administrators can override in emergencies (with audit trail)

**Validation Method**: Attempt direct commit to protected branch, verify rejection

**Implementation**: GitHub repository settings (see [Branch Protection Configuration](#branch-protection-configuration))

---

### REQ-o00054: Audit Trail Generation for CI/CD

**Level**: Ops | **Implements**: o00052, p00010 | **Status**: Active

**Description**: The system SHALL generate and archive traceability matrices as build artifacts for every CI/CD run, maintaining audit trail compliance.

**Acceptance Criteria**:

1. ✅ Traceability matrix generated in HTML format
2. ✅ Traceability matrix generated in Markdown format
3. ✅ Artifacts uploaded to GitHub Actions
4. ✅ Artifacts retained for 90 days minimum
5. ✅ Artifacts include commit SHA and timestamp
6. ✅ Artifacts downloadable by authorized personnel

**Validation Method**: Review GitHub Actions artifacts tab, verify presence and retention

**Implementation Files**: `.github/workflows/pr-validation.yml` (upload-artifact step)

---

## CI/CD Pipeline Architecture

### Pipeline Stages

```
┌─────────────────────────────────────────────────────────────────┐
│                       PR Created/Updated                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: Requirement Validation                                  │
│ - Validate requirement format and IDs                            │
│ - Check for duplicates and orphans                               │
│ - Generate traceability matrix                                   │
│ - Upload artifacts                                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 2: Code Header Validation                                  │
│ - Check implementation files have requirement headers            │
│ - Validate header format                                         │
│ - Warn on missing headers (non-blocking)                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 3: Migration Header Validation                             │
│ - Check migration files have proper headers                      │
│ - Validate migration metadata                                    │
│ - Fail on invalid headers (blocking)                             │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 4: Security Check                                          │
│ - Scan for accidentally committed secrets                        │
│ - Check for .env files in git                                    │
│ - Validate no hardcoded credentials                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 5: FDA Compliance Check                                    │
│ - Verify audit trail requirements present                        │
│ - Check RLS policies exist                                       │
│ - Validate event sourcing implementation                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 6: Validation Summary                                      │
│ - Aggregate results from all stages                              │
│ - Post summary to GitHub PR                                      │
│ - Generate GitHub Step Summary                                   │
│ - Overall pass/fail determination                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
                  ┌──────┴──────┐
                  │             │
                  ▼             ▼
           ┌──────────┐  ┌──────────┐
           │   PASS   │  │   FAIL   │
           │  Merge   │  │  Block   │
           │ Allowed  │  │  Merge   │
           └──────────┘  └──────────┘
```

### Pipeline Characteristics

- **Total Runtime**: < 10 minutes typical, 10 minute timeout
- **Parallelization**: 5 validation jobs run in parallel, 1 summary job waits for all
- **Fail-Fast**: Critical failures (requirements, security, FDA compliance) block merge
- **Warnings**: Code header validation issues are warnings, not blocking
- **Artifacts**: Generated on every run, regardless of pass/fail status
- **Notifications**: Failed runs trigger GitHub notifications to PR author

---

## GitHub Actions Workflows

### pr-validation.yml

**File**: `.github/workflows/pr-validation.yml`
**Purpose**: Validates requirements and traceability on every PR
**Triggers**: Pull requests to `main`, `develop`, `feature/**`, `release/**`

#### Jobs

**1. validate-requirements**
- Validates requirement format using `validate_requirements.py`
- Generates traceability matrices (HTML + Markdown)
- Uploads artifacts
- Comments on PR with results
- **Blocking**: YES

**2. validate-code-headers**
- Checks SQL and Dart files for requirement headers
- Validates header format per `spec/requirements-format.md`
- **Blocking**: NO (warning only)

**3. validate-migrations**
- Checks migration files for proper headers
- Validates per `database/migrations/README.md`
- **Blocking**: YES
- **Conditional**: Only runs if migrations changed

**4. security-check**
- Scans for API keys, passwords, secrets
- Checks for committed .env files
- **Blocking**: YES

**5. fda-compliance-check**
- Verifies audit trail requirements exist
- Checks for RLS policies
- Validates event sourcing implementation
- **Blocking**: YES

**6. summary**
- Aggregates results from all jobs
- Posts to GitHub Step Summary
- Determines overall pass/fail
- **Blocking**: YES

#### Artifact Outputs

| Artifact | Format | Retention | Purpose |
|----------|--------|-----------|---------|
| `traceability_matrix.md` | Markdown | 90 days | Human-readable audit trail |
| `traceability_matrix.html` | HTML | 90 days | Presentation-quality report |

#### Environment Variables

None required. All validation uses tools checked into the repository.

---

## Branch Protection Configuration

### Setup Instructions

**Prerequisite**: Repository administrator access

**Steps**:

1. Navigate to: `https://github.com/{org}/{repo}/settings/branches`

2. Click "Add rule" or edit existing rule for `main`

3. Configure the following settings:

   **Branch name pattern**: `main`

   ✅ **Require a pull request before merging**
   - ✅ Require approvals: 1 minimum
   - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require review from Code Owners (optional)

   ✅ **Require status checks to pass before merging**
   - ✅ Require branches to be up to date before merging
   - ✅ Status checks required:
     - `Validate Requirements Format & Traceability`
     - `Validate Code Implementation Headers` (optional)
     - `Validate Database Migration Headers`
     - `Security - Check for Secrets`
     - `FDA Compliance - Audit Trail Verification`
     - `Validation Summary`

   ✅ **Require conversation resolution before merging**

   ✅ **Require signed commits** (recommended for FDA compliance)

   ✅ **Include administrators** (administrators must follow rules)
   - NOTE: Can be disabled for emergency hotfixes (creates audit trail)

   ✅ **Restrict who can push to matching branches**
   - Add: CI/CD service account (if needed)
   - Add: Release managers

4. Click "Create" or "Save changes"

5. Repeat for `develop` branch

### Verification

Test branch protection is working:

```bash
# Attempt direct commit to main (should fail)
git checkout main
echo "test" >> test.txt
git add test.txt
git commit -m "Test direct commit"
git push origin main  # Should be rejected
```

Expected output:
```
! [remote rejected] main -> main (protected branch hook declined)
```

### Emergency Override Procedure

**When**: Critical production hotfix required, CI/CD blocking

**Authority**: Lead DevOps Engineer or CTO approval required

**Steps**:

1. Document reason for override in Linear ticket
2. Obtain written approval from authorized personnel
3. Navigate to branch protection settings
4. Temporarily disable "Include administrators"
5. Push hotfix directly to main
6. Create post-facto PR documenting changes
7. Re-enable branch protection
8. Document override in `docs/incident-log.md`

**Audit Trail**: All GitHub changes are logged, emergency overrides create audit records

---

## Testing Procedures

### Test 1: Validate Successful PR

**Purpose**: Verify workflow passes with valid requirements

**Steps**:

1. Create feature branch:
   ```bash
   git checkout -b test/validate-cicd-pass
   ```

2. Make trivial change to spec:
   ```bash
   echo "" >> spec/prd-app.md
   git add spec/prd-app.md
   git commit -m "Test: Validate CI/CD passes"
   ```

3. Push and create PR:
   ```bash
   git push -u origin test/validate-cicd-pass
   gh pr create --title "Test: CI/CD Validation Pass" --body "Testing CI/CD workflow with valid changes"
   ```

4. Observe GitHub Actions tab:
   - All jobs should pass (green checkmarks)
   - Traceability matrix artifact should be available
   - PR comment should appear with validation results

5. Clean up:
   ```bash
   gh pr close --delete-branch
   ```

**Expected Result**: All checks pass, PR mergeable

---

### Test 2: Validate Failed PR (Invalid Requirement)

**Purpose**: Verify workflow fails with invalid requirements

**Steps**:

1. Create feature branch:
   ```bash
   git checkout -b test/validate-cicd-fail
   ```

2. Add invalid requirement (use a fake ID that doesn't match your requirements):
   ```bash
   cat >> spec/prd-app.md <<'EOF'

### REQ-pXXXXX: Test Invalid Requirement

**Level**: PRD | **Implements**: REQ-p00000 | **Status**: Active

This is an intentionally invalid requirement for testing CI/CD.
(Use a real requirement ID format when testing, this example uses XXXXX to avoid validation errors in this doc)

EOF
   git add spec/prd-app.md
   git commit -m "Test: Add invalid requirement"
   ```

3. Push and create PR:
   ```bash
   git push -u origin test/validate-cicd-fail
   gh pr create --title "Test: CI/CD Validation Fail" --body "Testing CI/CD workflow with invalid requirement"
   ```

4. Observe GitHub Actions tab:
   - `validate-requirements` job should fail (red X)
   - Error message should indicate "Implements non-existent requirement"
   - PR should be blocked from merging

5. Clean up:
   ```bash
   gh pr close --delete-branch
   ```

**Expected Result**: Validation fails, PR blocked, error message clear

---

### Test 3: Validate Migration Header Check

**Purpose**: Verify migration header validation works

**Steps**:

1. Create feature branch:
   ```bash
   git checkout -b test/validate-migration-fail
   ```

2. Add invalid migration:
   ```bash
   cat > database/migrations/20251028_test_invalid.sql <<'EOF'
-- This migration is missing required headers
CREATE TABLE test_table (id SERIAL PRIMARY KEY);
EOF
   git add database/migrations/20251028_test_invalid.sql
   git commit -m "Test: Add invalid migration"
   ```

3. Push and create PR:
   ```bash
   git push -u origin test/validate-migration-fail
   gh pr create --title "Test: Migration Validation Fail" --body "Testing migration header validation"
   ```

4. Observe GitHub Actions tab:
   - `validate-migrations` job should fail
   - Error message should indicate missing migration headers
   - PR should be blocked from merging

5. Clean up:
   ```bash
   gh pr close --delete-branch
   ```

**Expected Result**: Migration validation fails, PR blocked

---

### Test 4: Validate Security Check

**Purpose**: Verify secret detection works

**Steps**:

1. Create feature branch:
   ```bash
   git checkout -b test/validate-security-fail
   ```

2. Add file with fake secret:
   ```bash
   cat > config_test.txt <<'EOF'
api_key = "sk_test_1234567890abcdefghijklmnop"
password = "MySecretPassword123"
EOF
   git add config_test.txt
   git commit -m "Test: Add file with secrets"
   ```

3. Push and create PR:
   ```bash
   git push -u origin test/validate-security-fail
   gh pr create --title "Test: Security Check Fail" --body "Testing secret detection"
   ```

4. Observe GitHub Actions tab:
   - `security-check` job should fail
   - Error message should indicate secrets detected
   - PR should be blocked from merging

5. Clean up:
   ```bash
   gh pr close --delete-branch
   ```

**Expected Result**: Security check fails, PR blocked

---

## Troubleshooting

### Issue: Workflow Not Triggering

**Symptoms**: Pull request created, but no GitHub Actions checks appear

**Possible Causes**:

1. Workflow file syntax error
2. Workflow file not on base branch
3. Repository Actions disabled

**Diagnosis**:

```bash
# Check workflow syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pr-validation.yml'))"

# Check if workflow exists on main
git fetch origin main
git show origin/main:.github/workflows/pr-validation.yml

# Check GitHub Actions settings
# Navigate to: Settings → Actions → General → Allow all actions
```

**Resolution**:

1. Fix syntax error if found
2. Merge workflow to main branch first
3. Enable GitHub Actions in repository settings

---

### Issue: Validation Failing Incorrectly

**Symptoms**: Validation fails even though requirements appear correct

**Possible Causes**:

1. Requirement format doesn't match spec
2. Hidden characters in requirement ID
3. Implements link to nonexistent requirement
4. Circular requirement dependencies

**Diagnosis**:

```bash
# Run validation locally
python3 tools/requirements/validate_requirements.py

# Check for hidden characters
cat -A spec/prd-app.md | grep REQ-

# Validate specific requirement
grep -A 5 "REQ-p00001" spec/prd-*.md
```

**Resolution**:

1. Review error output for specific requirement ID
2. Check `spec/requirements-format.md` for correct format
3. Ensure "Implements" field references existing requirement
4. Fix requirement format and re-run validation

---

### Issue: Artifacts Not Uploading

**Symptoms**: Workflow completes but no artifacts in GitHub Actions tab

**Possible Causes**:

1. Traceability matrix generation failed
2. File path incorrect in workflow
3. Insufficient permissions

**Diagnosis**:

```bash
# Run generation locally
python3 tools/requirements/generate_traceability.py --format markdown
python3 tools/requirements/generate_traceability.py --format html

# Check files created
ls -lh traceability_matrix.*
```

**Resolution**:

1. Fix any errors in traceability generation
2. Verify file paths in `.github/workflows/pr-validation.yml`
3. Ensure workflow has `contents: read` permission

---

### Issue: Branch Protection Not Enforcing

**Symptoms**: PR merges even though checks failed

**Possible Causes**:

1. Branch protection not configured
2. Status check names don't match
3. Administrator override enabled

**Diagnosis**:

```bash
# Check branch protection via API
gh api repos/{owner}/{repo}/branches/main/protection

# Verify status check names in workflow match branch protection settings
grep "^name:" .github/workflows/pr-validation.yml
```

**Resolution**:

1. Configure branch protection per instructions above
2. Ensure status check names exactly match workflow job names
3. Include administrators in branch protection rules

---

### Issue: Workflow Timeout

**Symptoms**: Workflow runs for 10 minutes and times out

**Possible Causes**:

1. Validation script has infinite loop
2. Network issues downloading artifacts
3. Extremely large repository

**Diagnosis**:

```bash
# Time validation locally
time python3 tools/requirements/validate_requirements.py
time python3 tools/requirements/generate_traceability.py --format markdown

# Check repository size
du -sh .
```

**Resolution**:

1. If local validation takes > 5 minutes, investigate script performance
2. Consider caching Python dependencies in workflow
3. Increase timeout in workflow (max 360 minutes)

---

## Monitoring and Alerts

### GitHub Actions Dashboard

**URL**: `https://github.com/{org}/{repo}/actions`

**Monitoring**:

- Check "Workflow runs" for recent status
- Filter by workflow: "PR Validation"
- Review failure trends

**Alerts**:

- Failed runs automatically notify PR author
- Repository watchers receive notifications
- Configure additional alerts in GitHub settings

### Metrics to Track

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Workflow success rate | > 95% | < 90% |
| Average runtime | < 5 min | > 8 min |
| Artifact generation success | 100% | < 100% |
| False positive rate | < 1% | > 5% |
| Mean time to fix failures | < 1 hour | > 4 hours |

### Weekly Review Checklist

- [ ] Review workflow success rate
- [ ] Check for recurring failure patterns
- [ ] Verify artifacts are being generated
- [ ] Review branch protection effectiveness
- [ ] Update documentation if issues found

---

## FDA Compliance

### 21 CFR Part 11 Mapping

This CI/CD pipeline supports the following 21 CFR Part 11 requirements:

| Regulation | Requirement | CI/CD Implementation |
|------------|-------------|----------------------|
| §11.10(a) | System validation | Automated validation on every PR |
| §11.10(b) | Accurate copies | Traceability matrix artifacts |
| §11.10(e) | Audit trails | GitHub Actions logs + artifacts |
| §11.10(k)(1) | Documentation controls | Requirement validation enforced |
| §11.10(k)(2) | Change control | Branch protection + PR reviews |

### Audit Trail Retention

- **GitHub Actions logs**: 90 days (GitHub default)
- **Traceability matrix artifacts**: 90 days (configurable)
- **Git commit history**: Permanent
- **Branch protection logs**: Permanent

For FDA audits, provide:

1. Traceability matrix artifacts from GitHub Actions
2. Git commit logs showing validation passed
3. Branch protection configuration screenshots
4. This operations specification document

### Validation Documentation

This CI/CD system has been validated per:

- **Installation Qualification (IQ)**: Workflow file syntax validated, jobs defined correctly
- **Operational Qualification (OQ)**: Tests 1-4 above demonstrate proper operation
- **Performance Qualification (PQ)**: Monitoring metrics confirm performance meets requirements

**Validation Date**: 2025-10-28
**Validated By**: DevOps Team
**Next Re-Validation**: 2026-10-28 (annually)

---

## Related Documents

- **Requirements Format**: `spec/requirements-format.md`
- **Pre-commit Hook**: `.githooks/README.md`
- **Validation Tool**: `tools/requirements/validate_requirements.py`
- **Traceability Tool**: `tools/requirements/generate_traceability.py`
- **Migration Headers**: `database/migrations/README.md`
- **FDA Compliance**: `spec/prd-clinical-trials.md`

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-28 | 1.0 | Initial CI/CD specification | DevOps Team |

---

## Approval

**Prepared By**: DevOps Team
**Reviewed By**: _________________
**Approved By**: _________________
**Date**: _________________

---

**Document Classification**: Operations Specification
**Retention**: Permanent (FDA audit requirement)
