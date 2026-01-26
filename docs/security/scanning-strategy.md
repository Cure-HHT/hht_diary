# Security Scanning Strategy

**IMPLEMENTS REQUIREMENTS**: REQ-p01018 (Security Audit and Compliance)

**Last Updated**: 2025-11-17
**Status**: Active

## Overview

This document describes the comprehensive security scanning strategy for the Diary Platform. Our approach uses multiple specialized tools to provide defense-in-depth security coverage across all code, dependencies, infrastructure, and containers.

## Executive Summary

**Why NOT CodeQL?**
- CodeQL does NOT support Dart/Flutter (our primary application language)
- The "28 CodeQL alerts" in repository history were about workflow files, not codebase scanning
- CodeQL was never actually enabled for codebase security analysis

**Current Strategy**:
- ✅ **Gitleaks**: Secret scanning (pre-commit + CI/CD)
- ✅ **Trivy**: Multi-layer vulnerability scanning (dependencies, IaC, containers)
- ✅ **Flutter Analyze**: Dart/Flutter static analysis
- ✅ **Squawk**: PostgreSQL migration safety linting
- ✅ **Defense-in-Depth**: Multiple tools at multiple stages

## Scanner Matrix

| Tool | Purpose | Languages/Targets | When | Exit on Failure |
| --- | --- | --- | --- | --- |
| **Gitleaks** | Secret detection | All files | Pre-commit + CI/CD | ✅ Yes |
| **Trivy (filesystem)** | Dependency vulnerabilities | npm, pub, pip, etc. | CI/CD | ❌ No (report only) |
| **Trivy (IaC)** | Infrastructure misconfig | Docker, Terraform, K8s | CI/CD | ❌ No (report only) |
| **Trivy (container)** | Container vulnerabilities | Docker images | CI/CD | ❌ No (report only) |
| **Flutter Analyze** | Dart/Flutter static analysis | .dart files | CI/CD | ✅ Yes |
| **Squawk** | PostgreSQL migration safety | .sql files (database/) | CI/CD | ✅ Yes |

## Scanner Details

### 1. Gitleaks (Secret Scanning)

**Purpose**: Prevent accidental commit of secrets (API keys, tokens, passwords)

**Configuration**: `.gitleaks.toml`
- Version: 2.0.0 (last updated 2025-11-08)
- Uses built-in gitleaks rules
- Allowlist: 3 historical commits with revoked secrets

**When It Runs**:
- **Pre-commit Hook**: `.git/hooks/pre-commit` (via workflow plugin)
  - Scans staged files only
  - Fast (< 1 second for typical commit)
  - Blocks commit if secrets detected
- **CI/CD**: `.github/workflows/pr-validation.yml`
  - Full repository scan
  - Runs on all pull requests
  - Prevents merge if secrets detected

**Version**: v8.29.0 (pinned in `.github/versions.env`)

**Exit Behavior**:
- Pre-commit: Blocks commit (exit code 1)
- CI/CD: Fails workflow (exit code 1)

**How to Fix**:
1. Remove the secret from staged files
2. If secret was already committed:
   - Revoke the secret immediately
   - Use BFG Repo Cleaner or `git filter-repo` to remove from history
   - Add to `.gitleaks.toml` allowlist with reason

**Resources**:
- Gitleaks docs: https://github.com/gitleaks/gitleaks
- Secret management guide: `docs/security/secret-management.md`

### 2. Trivy (Multi-Layer Vulnerability Scanner)

**Purpose**: Detect vulnerabilities in dependencies, infrastructure configs, and containers

**Configuration**: `.github/workflows/qa-automation.yml` (security-scan job)

**Scan Layers**:

#### Layer 1: Filesystem Dependencies
- **Scan Type**: `fs` (filesystem)
- **Targets**: npm packages, Pub packages (Flutter/Dart), Python pip, etc.
- **Severity Filter**: CRITICAL, HIGH
- **Output**: SARIF uploaded to GitHub Security → Code scanning

#### Layer 2: Infrastructure as Code (IaC)
- **Scan Type**: `config`
- **Targets**: Dockerfiles, Terraform configs, K8s manifests
- **Checks**: Misconfigurations, security best practices violations
- **Examples**:
  - Running containers as root
  - Missing resource limits
  - Exposed secrets in env vars

#### Layer 3: Container Images
- **Scan Type**: `image`
- **Targets**: Built Docker images (clinical-diary-base:latest)
- **Checks**: OS package vulnerabilities, outdated base images
- **Note**: Only runs if Dockerfiles detected in repository

**Version**: 0.28.0 (pinned in workflows)

**Exit Behavior**:
- All Trivy scans use `exit-code: 0` (report only, don't fail)
- Results uploaded to GitHub Security for review

**How to Review**:
1. Navigate to: Repository → Security → Code scanning → Trivy alerts
2. Filter by severity: CRITICAL, HIGH
3. Review each alert:
   - Dependency vulnerabilities: Update package version
   - IaC issues: Fix Dockerfile/Terraform config
   - Container issues: Update base image or OS packages

**Resources**:
- Trivy docs: https://aquasecurity.github.io/trivy/
- Trivy GitHub Action: https://github.com/aquasecurity/trivy-action

### 3. Flutter Analyze (Dart/Flutter Static Analysis)

**Purpose**: Static analysis for Dart/Flutter codebase (CodeQL alternative)

**Configuration**: `.github/workflows/qa-automation.yml` (flutter-dart-security job)

**What It Checks**:
- Type safety violations
- Unused imports/variables
- Potential null pointer exceptions
- Code style violations (via `analysis_options.yaml`)
- Security-relevant patterns (if configured)

**Scope**:
- Root `pubspec.yaml` project (if exists)
- All packages in `packages/` directory

**Flags**:
- `--no-fatal-infos`: Don't fail on info-level issues
- `--no-fatal-warnings`: Don't fail on warnings (errors only)

**Exit Behavior**:
- Fails workflow if errors detected (exit code 1)
- Continues on warnings/info

**Dependency Security Check**:
- Runs `flutter pub outdated` to identify outdated packages
- Report only (doesn't fail build)
- Review output for security-relevant updates

**How to Fix**:
1. Run locally: `flutter analyze`
2. Fix errors reported
3. Consider fixing warnings for code quality
4. Update dependencies: `flutter pub upgrade`

**Resources**:
- Flutter analyzer: https://dart.dev/tools/dartanalyzer
- Analysis options: https://dart.dev/guides/language/analysis-options

### 4. Squawk (PostgreSQL Migration Linting)

**Purpose**: Prevent dangerous PostgreSQL migration operations that could cause downtime or data loss

**Configuration**: `.github/workflows/qa-automation.yml` (sql-linting job)

**What It Checks**:
- **Table Locks**: Operations that hold locks during migration (blocking production)
- **Missing Indexes**: Foreign keys without indexes (performance degradation)
- **Unsafe ALTER TABLE**: Operations that rewrite entire table
- **NOT NULL Constraints**: Adding NOT NULL without DEFAULT (breaks inserts)
- **Column Renames**: Renaming that breaks existing application code
- **Data Type Changes**: Type conversions that could lose data

**Examples of Issues Detected**:
```sql
-- ❌ BAD: Adds NOT NULL without default (breaks existing apps)
ALTER TABLE users ADD COLUMN email VARCHAR(255) NOT NULL;

-- ✅ GOOD: Provides default or makes nullable initially
ALTER TABLE users ADD COLUMN email VARCHAR(255) DEFAULT '';

-- ❌ BAD: Adds index with CONCURRENTLY missing (locks table)
CREATE INDEX idx_users_email ON users(email);

-- ✅ GOOD: Uses CONCURRENTLY to avoid locks
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
```

**Version**: v0.29.2 (pinned in workflow)

**When It Runs**:
- **CI/CD**: `.github/workflows/qa-automation.yml`
- Only scans changed SQL files in PR (efficient)
- Manual trigger can scan all SQL files

**Exit Behavior**:
- Fails workflow if dangerous patterns detected (exit code 1)
- Provides detailed explanation of each issue

**How to Fix**:
1. Review Squawk error message in PR check
2. Common fixes:
   - Add `CONCURRENTLY` to index creation
   - Add `DEFAULT` to NOT NULL columns
   - Use multi-step migration for type changes
   - Add indexes before adding foreign keys
3. Update migration file
4. Re-run CI/CD

**PostgreSQL-Specific Benefits**:
- Matches Supabase backend (PostgreSQL 15+)
- Understands PostgreSQL locking behavior
- Knows safe migration patterns for production

**Resources**:
- Squawk GitHub: https://github.com/sbdchd/squawk
- PostgreSQL safe migrations: https://www.braintreepayments.com/blog/safe-operations-for-high-volume-postgresql/

## Defense-in-Depth Strategy

Our security scanning uses multiple layers:

```
┌─────────────────────────────────────────────────────────┐
│                    DEVELOPER WORKSTATION                 │
│  • Dev container with gitleaks pre-installed            │
│  • Pre-commit hook: gitleaks scan (staged files)        │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                      PULL REQUEST CI/CD                  │
│  • Gitleaks: Full repository scan                       │
│  • Trivy: Dependencies, IaC, Containers                 │
│  • Flutter Analyze: Dart/Flutter code                   │
│  • Squawk: PostgreSQL migrations (changed files)        │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    GITHUB SECURITY TAB                   │
│  • Centralized alert dashboard                          │
│  • SARIF results from all scanners                      │
│  • Alerting and notifications                           │
└─────────────────────────────────────────────────────────┘
```

**Why Multiple Tools?**
- **Gitleaks**: Specialized in secret patterns (high accuracy)
- **Trivy**: Comprehensive vulnerability database (dependencies + containers + IaC)
- **Flutter Analyze**: Language-specific static analysis (Dart/Flutter expert)
- **Squawk**: PostgreSQL-specific migration safety (prevents production downtime)
- **No single tool catches everything**: Overlap provides redundancy

## FDA 21 CFR Part 11 Compliance

**Requirement**: REQ-p01018 mandates automated security scanning

**How We Comply**:
1. ✅ **Automated Scanning**: All PRs scanned automatically (no manual review possible bypass)
2. ✅ **Audit Trail**: GitHub Actions logs preserved, SARIF results retained 30 days
3. ✅ **Version Control**: All scanner versions pinned (reproducible results)
4. ✅ **Documentation**: This document + inline workflow comments
5. ✅ **Traceability**: Git hooks enforce REQ references in commits

**Evidence for Audits**:
- Workflow run history: Repository → Actions
- Security findings: Repository → Security → Code scanning
- Scanner configurations: `.gitleaks.toml`, `.github/workflows/*.yml`
- Version pinning: `.github/versions.env`, Dockerfiles

## Why CodeQL Is NOT Enabled

**Investigation Date**: 2025-11-17

**Finding**: CodeQL does NOT support Dart/Flutter

**Evidence**:
- CodeQL supported languages: https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/
  - Supported: C/C++, C#, Go, Java, JavaScript/TypeScript, Python, Ruby, Swift
  - **NOT Supported**: Dart, Flutter
- Primary codebase language: **Dart/Flutter** (mobile app)
- Secondary languages: Python (scripts), JavaScript (tooling), SQL (database)

**Historical Context**:
- Repository shows "28 CodeQL alerts fixed" in PR history
- These alerts were about GitHub Actions workflow files (YAML)
- NOT about application codebase security
- Workflow file alerts have since been fixed (PR #76, 2025-11-15)

**Decision**:
- ✅ Use Flutter Analyze for Dart/Flutter static analysis
- ✅ Use Trivy for dependency and infrastructure scanning
- ❌ Do NOT enable CodeQL (provides no value for Dart/Flutter)

**Future Consideration**:
- If significant Python/JavaScript code is added, consider enabling CodeQL
- Monitor CodeQL roadmap for potential Dart/Flutter support

## Common Workflows

### Workflow 1: Secret Accidentally Committed

**Scenario**: Gitleaks blocks your commit

```bash
$ git commit -m "Add feature"
Running pre-commit gitleaks scan...
Error: Secret detected in staged files
  File: config/settings.py
  Line: 42
  Secret: AWS Access Key
```

**Resolution**:
1. Remove secret from file
2. Store secret in Doppler: `doppler secrets set AWS_ACCESS_KEY`
3. Update code to read from environment: `os.environ.get('AWS_ACCESS_KEY')`
4. Retry commit

**If already pushed**:
1. Revoke the secret IMMEDIATELY (AWS console, Linear settings, etc.)
2. Clean history: `git filter-repo --path config/settings.py --invert-paths`
3. Force push: `git push --force-with-lease`
4. Add to `.gitleaks.toml` allowlist with reason

### Workflow 2: Trivy Finds Vulnerable Dependency

**Scenario**: PR check shows Trivy alert in GitHub Security

**Resolution**:
1. Navigate to: Security → Code scanning → Filter by "Trivy"
2. Click alert to see:
   - Vulnerable package name and version
   - CVE details and severity
   - Recommended fix version
3. Update dependency:
   - Flutter: Update `pubspec.yaml`, run `flutter pub upgrade`
   - npm: Update `package.json`, run `npm update`
   - Python: Update `requirements.txt`, run `pip install -r requirements.txt`
4. Commit and push
5. Verify alert is resolved in next scan

### Workflow 3: Flutter Analyze Fails

**Scenario**: CI/CD fails with Flutter analysis errors

**Resolution**:
1. Run locally: `flutter analyze`
2. Review errors (ignore warnings if desired)
3. Common fixes:
   - Missing imports: Add import statement
   - Type errors: Add explicit types or fix type mismatches
   - Unused code: Remove or comment with `// ignore: unused_*`
4. Re-run: `flutter analyze` (should show "No issues found")
5. Commit and push

### Workflow 4: Squawk Detects Unsafe Migration

**Scenario**: PR check fails with Squawk warning about SQL migration

**Example Error**:
```
⚠️ database/migrations/001_add_user_email.sql

warning: prefer-text-field
note: Prefer text fields over varchar/char fields

   1 | ALTER TABLE users ADD COLUMN email VARCHAR(255) NOT NULL;
 |                                     ^^^^^^^^^^^^

help: Use text fields rather than varchar fields

warning: adding-not-null-to-existing-column
note: Adding a NOT NULL field to an existing table requires exclusive locks

   1 | ALTER TABLE users ADD COLUMN email VARCHAR(255) NOT NULL;
 |                                                  ^^^^^^^^

help: Add the column as nullable, then use a multi-step migration
```

**Resolution**:
1. Review Squawk message in PR check summary
2. Fix the migration:
```sql
-- Step 1: Add column as nullable
ALTER TABLE users ADD COLUMN email TEXT;

-- Step 2: Backfill with default (in separate migration if needed)
UPDATE users SET email = '' WHERE email IS NULL;

-- Step 3: Add NOT NULL constraint (in separate migration)
ALTER TABLE users ALTER COLUMN email SET NOT NULL;
```
3. Commit updated migration
4. Re-run CI/CD (Squawk should pass)

## Scanner Maintenance

**Version Updates**:
- Gitleaks: Update `.github/versions.env` → `GITLEAKS_VERSION`
- Trivy: Update `.github/workflows/qa-automation.yml` → `aquasecurity/trivy-action@VERSION`
- Flutter: Update `.github/versions.env` → `FLUTTER_VERSION`
- Squawk: Update `.github/workflows/qa-automation.yml` → `SQUAWK_VERSION`

**Configuration Updates**:
- Gitleaks rules: Edit `.gitleaks.toml`
- Flutter analysis: Edit `analysis_options.yaml` (if exists)
- Trivy settings: Edit workflow YAML files

**Testing Changes**:
1. Update version/configuration
2. Create test branch
3. Open PR to trigger scans
4. Verify results in GitHub Security tab
5. Merge if successful

## Performance Considerations

**Scan Duration** (approximate):
- Gitleaks (pre-commit): < 1 second
- Gitleaks (CI/CD full scan): 5-10 seconds
- Trivy filesystem: 30-60 seconds
- Trivy IaC: 10-20 seconds
- Trivy container: 2-5 minutes (includes image build)
- Flutter Analyze: 10-30 seconds
- Squawk: < 5 seconds (only changed files)

**Total CI/CD Overhead**: ~5-8 minutes per PR (scans run in parallel)

**Optimization**:
- Gitleaks: Scans only changed files in pre-commit (fast feedback)
- Trivy: Uses cache for vulnerability database
- Container scan: Only runs if Dockerfiles changed

## FAQ

**Q: Why don't we use tool X?**
A: We evaluated multiple tools. Our current stack provides comprehensive coverage for our tech stack (Dart/Flutter + Python + PostgreSQL + Docker). Additional tools would add overhead without meaningful security improvements.

**Q: Why Squawk instead of SQLFluff?**
A: Squawk is PostgreSQL-specific and focuses on migration safety (locks, downtime). SQLFluff is more general (syntax, style) but doesn't catch PostgreSQL-specific production issues. Squawk prevents actual outages.

**Q: Can I disable scanners locally?**
A: Pre-commit hooks can be bypassed with `git commit --no-verify`, but CI/CD scans cannot be bypassed. Use `--no-verify` only for draft commits that won't be pushed.

**Q: What if a scanner reports a false positive?**
A:
- Gitleaks: Add to `.gitleaks.toml` allowlist with justification
- Trivy: File issue with Trivy project, suppress in workflow temporarily
- Flutter: Use `// ignore: rule_name` comment with explanation

**Q: How do I know if scans are passing?**
A: Check PR status checks. All scanners must pass (except Trivy which is report-only).

**Q: Where are scan results stored?**
A:
- GitHub Security tab (SARIF results, 90 days retention)
- GitHub Actions artifacts (raw outputs, 30 days retention)
- Workflow logs (full scan output, 90 days retention)

## References

- **Requirement**: REQ-p01018 (Security Audit and Compliance)
- **Workflows**:
  - `.github/workflows/pr-validation.yml` (gitleaks)
  - `.github/workflows/qa-automation.yml` (Trivy, Flutter)
- **Configuration**:
  - `.gitleaks.toml`
  - `.github/versions.env`
- **Compliance**: `spec/prd-security-compliance.md`

## Change Log

| Date | Change | Author |
| --- | --- | --- |
| 2025-11-17 | Initial documentation | Claude (CUR-336) |
| 2025-11-17 | Added Flutter/Dart security job | Claude (CUR-336) |
| 2025-11-17 | Enhanced Trivy with IaC and container scanning | Claude (CUR-336) |
| 2025-11-17 | Added Squawk PostgreSQL migration linting | Claude (CUR-336) |
