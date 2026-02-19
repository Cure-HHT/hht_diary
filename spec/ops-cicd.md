# Operations Specification: CI/CD Pipeline for Requirement Traceability

**Version**: 2.0
**Audience**: DevOps, Operations, Release Management
**Status**: Draft
**Last Updated**: 2025-12-28

## Overview

This document specifies the continuous integration and continuous delivery (CI/CD) pipeline for validating requirement traceability, ensuring FDA 21 CFR Part 11 compliance, and maintaining audit trail integrity throughout the software development lifecycle.

> **See**: ops-deployment.md for deployment operations
> **See**: ops-deployment-automation.md for automated deployment procedures
> **See**: ops-infrastructure-as-code.md for Pulumi infrastructure definitions

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

# REQ-o00052: CI/CD Pipeline for Requirement Traceability

**Level**: Ops | **Status**: Draft | **Implements**: p80060

## Rationale

This requirement ensures automated enforcement of requirement traceability throughout the development lifecycle, supporting FDA 21 CFR Part 11 compliance and audit readiness. The CI/CD pipeline acts as a gatekeeper to prevent non-compliant code from entering protected branches, maintaining the integrity of the requirement-to-implementation mapping. Automated validation reduces manual review burden while ensuring consistent enforcement of traceability standards. The retention period aligns with regulatory expectations for maintaining complete audit trails of validation activities.

## Assertions

A. The system SHALL provide automated CI/CD validation of requirement traceability on every pull request to protected branches.

B. The system SHALL provide automated CI/CD validation of requirement traceability on every commit to protected branches.

C. The CI/CD workflow SHALL validate requirement format for all referenced requirement IDs.

D. The CI/CD workflow SHALL validate that all referenced requirement IDs exist.

E. The CI/CD workflow SHALL automatically generate a traceability matrix during validation.

F. The system SHALL NOT allow pull requests to merge without passing requirement traceability validation.

G. The system SHALL post validation results as comments on the associated pull request.

H. The system SHALL retain validation artifacts for a minimum of 2 years.

I. The system SHALL trigger notifications when requirement traceability validation fails.

J. The CI/CD validation workflow SHALL complete execution within 10 minutes.

*End* *CI/CD Pipeline for Requirement Traceability* | **Hash**: 4bfaefe3
---

# REQ-o00053: Branch Protection Enforcement

**Level**: Ops | **Status**: Draft | **Implements**: o00052, p80060

## Rationale

This requirement enforces code quality gates and prevents unauthorized changes to critical branches in the repository. Branch protection is essential for FDA 21 CFR Part 11 compliance as it ensures all code changes undergo peer review and automated validation before integration. The protection rules prevent accidental or intentional bypass of the CI/CD pipeline, which validates requirement traceability, runs security scanners, and enforces coding standards. Emergency override capability with audit trails allows authorized personnel to respond to critical incidents while maintaining compliance with tamper-evident change control requirements.

## Assertions

A. The system SHALL block direct commits to the main branch.

B. The system SHALL block direct commits to the develop branch.

C. The system SHALL require pull request approval before merging to protected branches.

D. The system SHALL require all status checks to pass before allowing merge to protected branches.

E. Status checks SHALL include requirement validation before merge is permitted.

F. The system SHALL allow administrators to override branch protection rules in emergency situations.

G. The system SHALL create an audit trail entry when administrators override branch protection rules.

*End* *Branch Protection Enforcement* | **Hash**: 52dc7376
---

# REQ-o00054: Audit Trail Generation for CI/CD

**Level**: Ops | **Status**: Draft | **Implements**: o00052, p80030

## Rationale

This requirement ensures FDA 21 CFR Part 11 compliance by maintaining comprehensive audit trails of all CI/CD activities through automated traceability matrix generation and archival. Regulatory inspections require proof that software builds can be traced back to specific requirements and code changes. The 90-day retention period aligns with typical audit windows while the dual format (HTML and Markdown) ensures both human readability and programmatic processing. The inclusion of commit SHA and timestamp creates tamper-evident linking between build artifacts and source code versions, supporting ALCOA+ principles (Attributable, Legible, Contemporaneous, Original, Accurate). This requirement implements the higher-level audit trail requirements (REQ-o00052) and electronic record requirements (REQ-p00010) within the specific context of automated build processes.

## Assertions

A. The system SHALL generate a traceability matrix in HTML format for every CI/CD run.

B. The system SHALL generate a traceability matrix in Markdown format for every CI/CD run.

C. The system SHALL upload generated traceability matrices as artifacts to GitHub Actions.

D. The system SHALL retain uploaded artifacts for a minimum of 90 days.

E. Artifact metadata SHALL include the commit SHA associated with the CI/CD run.

F. Artifact metadata SHALL include the timestamp of the CI/CD run.

G. The system SHALL make artifacts downloadable to authorized personnel.

*End* *Audit Trail Generation for CI/CD* | **Hash**: c4d7f202
---

# REQ-o00078: Change-Appropriate CI Validation

**Level**: Ops | **Status**: Draft | **Implements**: p80060

## Rationale

CI pipelines must balance thoroughness with efficiency. Running every check on every change wastes compute and developer time, while running too few checks risks letting defects through. Change-appropriate validation detects which areas of the codebase were modified and selectively runs only relevant validation jobs, with exceptions for security scanning (which must always run) and workflow changes (which require full validation). A consolidated summary ensures clear pass/fail determination before merge.

## Assertions

A. The CI pipeline SHALL detect which areas of the codebase changed (spec, code, database, tooling, workflows) before executing validation jobs.

B. The CI pipeline SHALL only execute validation jobs relevant to the detected changes, to avoid unnecessary computation.

C. The CI pipeline SHALL always execute security scanning regardless of which files changed.

D. The CI pipeline SHALL execute all validation jobs when workflow definition files themselves change.

E. The CI pipeline SHALL complete all validation jobs and produce a consolidated pass/fail summary before merge is permitted.

*End* *Change-Appropriate CI Validation* | **Hash**: ab0977df
---

# REQ-o00079: Commit and PR Traceability Enforcement

**Level**: Ops | **Status**: Draft | **Implements**: p80060

## Rationale

Squash-merge workflows use the PR title as the final commit message on protected branches. Validating traceability references (Linear ticket and requirement IDs) on every push to a PR — not just at PR creation — ensures developers receive early feedback while references are still fixable. Post-merge detective controls catch anything that bypasses branch protection (e.g., admin overrides) by creating compliance tickets for remediation. Bot commit scope validation prevents automated processes from making unauthorized changes.

## Assertions

A. The CI pipeline SHALL validate that pull request titles contain a Linear ticket reference in the format `[CUR-XXX]`.

B. The CI pipeline SHALL validate on every push to a pull request (including the initial push) that the required traceability references are present, providing feedback before merge.

C. The CI pipeline SHALL create a compliance ticket when a commit to a protected branch is found to be missing required references, as a safety net for cases that bypass branch protection.

D. Each automated process that commits directly to protected branches SHALL have a documented and limited scope of files it is authorized to modify, and the CI pipeline SHALL detect and alert when a bot commit modifies files outside its authorized scope.

E. The CI pipeline SHALL block merge when PR title validation fails.

F. The CI pipeline SHALL provide clear error messages indicating which references are missing and the required format.

*End* *Commit and PR Traceability Enforcement* | **Hash**: cc298537
---

# REQ-o00080: Secret and Vulnerability Scanning

**Level**: Ops | **Status**: Draft | **Implements**: p80060, p01018

## Rationale

Accidentally committed secrets (API keys, tokens, passwords) and vulnerable dependencies pose immediate security risks to an FDA-regulated platform handling clinical data. Defense-in-depth scanning at multiple layers — git history for secrets, dependency manifests for known vulnerabilities, and infrastructure-as-code for misconfigurations — reduces the risk of security incidents. Secret detection must block merge because exposed credentials require immediate remediation, while vulnerability scan results feed into the GitHub Security tab for ongoing tracking.

## Assertions

A. The CI pipeline SHALL scan for accidentally committed secrets on every push to a pull request (including the initial push), examining the repository at its current state.

B. The CI pipeline SHALL scan project dependencies for known vulnerabilities.

C. The CI pipeline SHALL scan infrastructure-as-code configurations (Dockerfiles, Terraform, Kubernetes) for misconfigurations.

D. The CI pipeline SHALL upload vulnerability scan results to GitHub Security for tracking and remediation.

E. Secret detection failures SHALL block merge to protected branches.

*End* *Secret and Vulnerability Scanning* | **Hash**: 90e58ccc
---

# REQ-o00081: Code Quality and Static Analysis

**Level**: Ops | **Status**: Draft | **Implements**: p80060

## Rationale

Static analysis and formatting enforcement catch defects early — before code review and testing — reducing the cost of finding and fixing issues. Flutter/Dart analysis detects type errors, null safety violations, and deprecated API usage. Formatting enforcement ensures consistent code style across contributors. SQL migration linting prevents dangerous database operations (table locks, missing indexes, unsafe ALTER TABLE) that could cause production downtime. Blocking merge on analysis failures ensures that only code meeting quality standards reaches protected branches.

## Assertions

A. The CI pipeline SHALL run static analysis (`flutter analyze` / `dart analyze`) on all changed Dart and Flutter code.

B. The CI pipeline SHALL validate code formatting compliance (`dart format`) on changed code.

C. The CI pipeline SHALL lint changed SQL migration files for dangerous patterns (table locks, missing indexes, unsafe ALTER TABLE) using a SQL linter.

D. Static analysis failures SHALL block merge to protected branches.

E. Code formatting violations SHALL block merge to protected branches.

*End* *Code Quality and Static Analysis* | **Hash**: 0b222d9e
---

# REQ-o00082: Automated Test Execution

**Level**: Ops | **Status**: Draft | **Implements**: p80060

## Rationale

Automated testing provides confidence that code changes do not introduce regressions. Unit tests scoped to changed packages provide fast feedback on isolated functionality. Integration tests must run more broadly because they depend on shared infrastructure (database schema, configuration, service contracts) where changes in one component can break another. Coverage measurement and threshold enforcement ensure that test quality keeps pace with codebase growth. Artifact retention of coverage reports supports audit trail requirements for test evidence.

## Assertions

A. The CI pipeline SHALL run unit tests for packages affected by the changes in the pull request.

B. The CI pipeline SHALL run integration tests when any component they depend on has changed, including shared configuration and database schema.

C. The CI pipeline SHALL measure and report test coverage for all executed test suites.

D. The CI pipeline SHALL upload coverage reports as artifacts with a minimum retention of 30 days.

E. The CI pipeline SHALL enforce a minimum test coverage threshold for components that define one.

F. Unit and integration test failures SHALL block merge to protected branches.

*End* *Automated Test Execution* | **Hash**: 63cc8fe6
---

# REQ-o00083: QA Promotion Gate

**Level**: Ops | **Status**: Draft | **Implements**: p80060

## Rationale

The QA promotion gate provides a higher level of assurance than per-component CI by running the full test suite in an environment representative of the deployment target. Unlike per-PR tests that scope to changed packages, the QA gate runs all tests regardless of what changed, detecting cross-component side effects and integration failures that targeted testing might miss. Containerized infrastructure matching production configuration reduces environment-specific test failures. Manual triggering supports on-demand validation for release readiness checks outside the normal PR workflow.

## Assertions

A. The QA promotion gate SHALL execute the full test suite (unit, integration, and coverage) in an environment representative of the QA deployment target.

B. The QA environment SHALL use containerized infrastructure matching production configuration.

C. The QA promotion gate SHALL run all tests regardless of which files changed, to detect cross-component side effects.

D. The QA promotion gate SHALL post a brief summary of test results on the associated pull request, including pass/fail status per component and coverage percentage.

E. The QA promotion gate SHALL support manual triggering via `workflow_dispatch` for on-demand validation outside the pull request lifecycle.

*End* *QA Promotion Gate* | **Hash**: dd06f8de
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
│ Stage 6: Infrastructure Validation (if infra changes)            │
│ - Run `pulumi preview` on changed stacks                         │
│ - Verify no unexpected resource deletions                        │
│ - Validate Pulumi code compiles (tsc --noEmit)                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Stage 7: Validation Summary                                      │
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
- **Parallelization**: 6 validation jobs run in parallel, 1 summary job waits for all
- **Early-Pass Optimization**: Migration validation exits early (1-2s) when no migrations modified
- **Early-Pass Optimization**: Infrastructure validation exits early when no Pulumi changes
- **Fail-Fast**: Critical failures (requirements, security, FDA compliance, infrastructure) block merge
- **Warnings**: Code header validation issues are warnings, not blocking
- **Artifacts**: Generated on every run, regardless of pass/fail status
- **Notifications**: Failed runs trigger GitHub notifications to PR author
- **Clean Results**: All jobs show ✅ PASSED or ❌ FAILED (never ⏭️ SKIPPED)
- **Infrastructure Preview**: Pulumi preview runs on infra changes to validate before merge

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
- **Conditional Validation**: Checks if migrations were modified; if not, passes immediately
- **Always Shows**: ✅ PASSED (either "all valid" or "no migrations to validate")
- **Audit Note**: Job always runs but exits early with success when no migrations modified

**4. security-check**

- Scans for API keys, passwords, secrets
- Checks for committed .env files
- **Blocking**: YES

**5. fda-compliance-check**

- Verifies audit trail requirements exist
- Checks for RLS policies
- Validates event sourcing implementation
- **Blocking**: YES

**6. validate-infrastructure**

- Checks if Pulumi code was modified in the PR
- Validates TypeScript compilation (`tsc --noEmit`)
- Runs `pulumi preview` to verify infrastructure changes
- **Blocking**: YES (if infrastructure changes detected)
- **Conditional Validation**: Checks if `infrastructure/pulumi/` was modified; if not, passes immediately
- **Always Shows**: ✅ PASSED (either "preview successful" or "no infra changes")
- **Audit Note**: Job always runs but exits early with success when no infrastructure modified

**7. summary**

- Aggregates results from all jobs
- Posts to GitHub Step Summary
- Determines overall pass/fail
- **Blocking**: YES

#### Artifact Outputs

| Artifact | Format | Retention | Purpose |
| --- | --- | --- | --- |
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
     - `Validate Infrastructure (Pulumi)`
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

> **Note**: For local requirement validation before creating PRs, use the `elspais` tool:
> ```bash
> pip install elspais
> elspais validate          # Validate requirements
> elspais analyze hierarchy # View requirement tree
> elspais hash verify       # Check content hashes
> ```

### Test 1: Validate Successful PR

**Purpose**: Verify workflow passes with valid requirements

**Steps**:

1. Create feature branch:
   ```bash
   git checkout -b test/validate-cicd-pass
   ```

2. Make trivial change to spec:
   ```bash
   echo "" >> spec/prd-diary-app.md
   git add spec/prd-diary-app.md
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

### Test 2: Validate Migration Header Check

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

### Test 3: Validate Security Check

**Purpose**: Verify secret detection works

**Steps**:

1. Create feature branch:
   ```bash
   git checkout -b test/validate-security-fail
   ```

2. Add file with fake secret:
   ```bash
   cat > config_test.txt <<'EOF'
# Test file with intentional security violations
api_key = "sk_test_YOUR_KEY_HERE"
password = "YOUR_PASSWORD_HERE"
database_url = "postgresql://user:pass@host/db"
EOF
   git add config_test.txt
   git commit -m "Test: Add file with secrets"
   ```

   **Note**: Replace `YOUR_KEY_HERE` and `YOUR_PASSWORD_HERE` with actual-looking values when testing (e.g., `sk_test_1234567890`, `MyPass123`) to trigger detection.

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

### Test 5: Validate Infrastructure Check

**Purpose**: Verify Pulumi infrastructure validation works

**Steps**:

1. Create feature branch:
   ```bash
   git checkout -b test/validate-infra-fail
   ```

2. Add invalid Pulumi code:
   ```bash
   cat > infrastructure/pulumi/components/test-invalid/index.ts <<'EOF'
   // This file has TypeScript errors
   import * as pulumi from "@pulumi/pulumi";

   const badVariable: string = 123; // Type error
   EOF
   git add infrastructure/pulumi/components/test-invalid/index.ts
   git commit -m "Test: Add invalid Pulumi code"
   ```

3. Push and create PR:
   ```bash
   git push -u origin test/validate-infra-fail
   gh pr create --title "Test: Infrastructure Validation Fail" --body "Testing Pulumi validation"
   ```

4. Observe GitHub Actions tab:

   - `validate-infrastructure` job should fail
   - Error message should indicate TypeScript compilation error
   - PR should be blocked from merging

5. Clean up:
   ```bash
   gh pr close --delete-branch
   ```

**Expected Result**: Infrastructure validation fails, PR blocked

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
# Run validation locally using elspais
elspais validate

# Or use legacy script
python3 tools/requirements/validate_requirements.py

# Check for hidden characters
cat -A spec/prd-diary-app.md | grep REQ-

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
# Run generation locally using elspais
elspais trace --format markdown
elspais trace --format html

# Or use legacy script
python3 tools/requirements/generate_traceability.py --format markdown
python3 tools/requirements/generate_traceability.py --format html

# Check files created
ls -lh traceability*
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
# Time validation locally using elspais
time elspais validate
time elspais trace --format markdown

# Or use legacy scripts
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

### Note: Migration Validation Always Passes

**Behavior**: The "Validate Database Migration Headers" job always shows ✅ PASSED

**This is Expected!** ✅

**How It Works**:

The migration validation job uses an **early-pass pattern**:

1. **Job always runs** (never skipped)
2. **First step**: Check if PR modified any files in `database/migrations/`
3. **If no migrations changed**: Exit immediately with success and notice: "No migration files were modified"
4. **If migrations changed**: Proceed with full header validation

**Benefits**:

1. **Clean UI**: All jobs show ✅ PASSED (no ⏭️ SKIPPED to explain)
2. **Auditor Friendly**: Everything passes - clear audit trail
3. **Efficient**: Still saves time by exiting early when nothing to validate
4. **Self-Documenting**: Job logs clearly state "no migrations to validate" when applicable

**Job Output Examples**:

When no migrations changed:
```
ℹ️  No migration files were modified in this PR
✅ Migration validation: PASSED (no migrations to validate)
```

When migrations were changed:
```
✓ Migration files were modified in this PR
✅ All migration files have proper headers
```

**For Auditors**:

The PASSED status always means one of:

- ✅ All migrations have valid headers (when migrations exist)
- ✅ No migrations to validate (when none were modified)

Both outcomes are compliant and indicate no issues detected.

---

### Note: Infrastructure Validation Always Passes

**Behavior**: The "Validate Infrastructure (Pulumi)" job always shows ✅ PASSED

**This is Expected!** ✅

**How It Works**:

The infrastructure validation job uses an **early-pass pattern**:

1. **Job always runs** (never skipped)
2. **First step**: Check if PR modified any files in `infrastructure/pulumi/`
3. **If no infrastructure changed**: Exit immediately with success and notice: "No infrastructure files were modified"
4. **If infrastructure changed**: Proceed with full validation:

   - TypeScript compilation (`tsc --noEmit`)
   - Pulumi preview for affected stacks

**Benefits**:

1. **Clean UI**: All jobs show ✅ PASSED (no ⏭️ SKIPPED to explain)
2. **Auditor Friendly**: Everything passes - clear audit trail
3. **Efficient**: Saves time by exiting early when nothing to validate
4. **Self-Documenting**: Job logs clearly state "no infrastructure to validate" when applicable

**Job Output Examples**:

When no infrastructure changed:
```
ℹ️  No infrastructure files were modified in this PR
✅ Infrastructure validation: PASSED (no changes to validate)
```

When infrastructure was changed:
```
✓ Infrastructure files were modified in this PR
✓ TypeScript compilation: PASSED
✓ Pulumi preview: PASSED (3 resources unchanged)
✅ All infrastructure validation checks passed
```

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
| --- | --- | --- |
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
| --- | --- | --- |
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
- **elspais Tool**: `pip install elspais` (preferred for local validation)
- **Legacy Validation Tool**: `tools/requirements/validate_requirements.py`
- **Legacy Traceability Tool**: `tools/requirements/generate_traceability.py`
- **Migration Headers**: `database/migrations/README.md`
- **FDA Compliance**: `spec/prd-clinical-trials.md`

---

## Change Log

| Date | Version | Changes | Author |
| --- | --- | --- | --- |
| 2025-12-28 | 1.1 | Added elspais tool references; removed redundant Test 2 (invalid requirement test) | Claude Code |
| 2025-10-28 | 1.0 | Initial CI/CD specification | DevOps Team |
| 2025-12-28 | 2.0 | Added Pulumi infrastructure validation stage, cross-references to IaC docs | Claude |

---

## Approval

**Prepared By**: DevOps Team
**Reviewed By**: _________________
**Approved By**: _________________
**Date**: _________________

---

**Document Classification**: Operations Specification
**Retention**: Permanent (FDA audit requirement)
