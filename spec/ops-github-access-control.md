# GitHub Repository Access Control

**Version**: 1.0
**Audience**: Operations (DevOps, Security, Platform Engineers)
**Last Updated**: 2025-10-27
**Status**: Future (Post-UAT)

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor repository structure
> **See**: ops-deployment.md for deployment procedures
> **See**: dev-security.md for code repository access patterns

---

## Executive Summary

This document defines GitHub repository access control and permissions to be implemented **after UAT** (User Acceptance Testing) when moving toward production deployment. During pre-MVP and MVP phases, lightweight access control is sufficient to maintain development velocity.

**Current Stage**: Pre-skeleton, Pre-MVP
**Recommended Approach**: Open development with minimal restrictions
**Future Stage**: Post-UAT, Pre-production
**Required**: Full access control as documented below

---

## Development Phase Access Control

### Phase 1: Pre-MVP (Current)

**Access Model**: Open development

```
Repository Access:
- All developers: Write access
- No branch protection
- No CODEOWNERS
- Fast iteration priority

Rationale: Small team, rapid iteration, trust-based collaboration
```

**Minimal Security**:
- ✅ Private sponsor repos (no public access to sponsor secrets)
- ✅ .gitignore prevents credential commits
- ✅ Pre-commit hooks validate requirements
- ❌ No branch protection (too restrictive for rapid development)
- ❌ No mandatory code reviews (slows down iteration)

---

### Phase 2: Post-UAT (Future)

**Access Model**: Structured permissions

**When to Implement**: After UAT completes, before first sponsor production deployment

**What Changes**:
- Branch protection on `main`
- Required code reviews
- CODEOWNERS for sensitive files
- Team-based access control
- Audit logging enabled

---

## Post-UAT Repository Structure

### Core Repository (`clinical-diary`)

**Purpose**: Public open-source core platform
**Visibility**: Public
**Access Control**: Team-based

```
Teams and Permissions:

clinical-diary-core-team:
  Role: Write
  Members: Core platform developers
  Scope: All files except sensitive areas

security-team:
  Role: Admin (required reviewers)
  Members: Security engineers, lead developers
  Scope:
    - /database/
    - /.github/workflows/
    - /spec/ops-security*.md
    - /spec/dev-security*.md

compliance-team:
  Role: Write (required reviewers)
  Members: Regulatory compliance, QA
  Scope:
    - /spec/prd-clinical-trials.md
    - /spec/ops-operations.md
    - /database/migrations/

product-team:
  Role: Write
  Members: Product managers, technical writers
  Scope: /spec/prd-*.md

auditors:
  Role: Read
  Members: External auditors, compliance reviewers
  Scope: All files (read-only)

external-contributors:
  Role: Read (fork and PR)
  Members: Community contributors
  Scope: Public repo only
```

---

### Sponsor Repositories (`clinical-diary-{sponsor}`)

**Purpose**: Private sponsor-specific configuration and secrets
**Visibility**: Private
**Access Control**: Sponsor-specific teams

```
clinical-diary-pfizer:
  pfizer-dev-team:
    Role: Write
    Members: Pfizer developers, designated consultants

  pfizer-admins:
    Role: Admin
    Members: Pfizer IT, project leads

  clinical-diary-core-team:
    Role: Read (for integration support)
    Members: Core platform developers

clinical-diary-novartis:
  novartis-dev-team:
    Role: Write

  novartis-admins:
    Role: Admin

  clinical-diary-core-team:
    Role: Read
```

**Principle**: No cross-sponsor access. Pfizer team cannot access Novartis repo.

---

## Branch Protection Rules

### Core Repository (`main` branch)

**Implement After UAT**

```yaml
Branch Protection Settings:

Require pull request reviews:
  ✅ Enabled
  Required approvals: 2
  Dismiss stale reviews: Yes
  Require review from CODEOWNERS: Yes

Require status checks to pass:
  ✅ Enabled
  Required checks:
    - test-requirements-tools
    - validate-documentation
    - validate-sql-syntax
    - test-linear-cli-tools
  Require branches to be up to date: Yes

Require linear history:
  ✅ Enabled (no merge commits, rebase or squash only)

Include administrators:
  ✅ Enabled (enforce for everyone, no exceptions)

Restrict who can push:
  ✅ Enabled
  Allowed: security-team, clinical-diary-core-team

Allow force pushes:
  ❌ Disabled (except for release-manager role in emergencies)

Allow deletions:
  ❌ Disabled
```

### Sponsor Repositories (`main` branch)

```yaml
Branch Protection Settings:

Require pull request reviews:
  ✅ Enabled
  Required approvals: 1
  Require review from CODEOWNERS: Yes

Require status checks to pass:
  ✅ Enabled
  Required checks:
    - validate-sponsor-repo (from core build system)

Include administrators:
  ✅ Enabled

Restrict who can push:
  ✅ Enabled
  Allowed: {sponsor}-admins only
```

---

## CODEOWNERS Configuration

**File**: `.github/CODEOWNERS` (implement post-UAT)

### Core Repository

```
# Default owner for everything (unless overridden below)
* @clinical-diary-core-team

# Database and migrations (requires security review)
/database/ @security-team @compliance-team
/database/migrations/ @security-team @compliance-team

# CI/CD workflows (requires security + DevOps review)
/.github/workflows/ @security-team @devops-team

# Security specifications (requires security review)
/spec/ops-security*.md @security-team
/spec/dev-security*.md @security-team
/spec/prd-security*.md @security-team @compliance-team

# Compliance and regulatory docs (requires compliance review)
/spec/prd-clinical-trials.md @compliance-team
/spec/ops-operations.md @compliance-team

# Product requirements (requires product team review)
/spec/prd-*.md @product-team

# Critical operations docs
/spec/ops-deployment.md @devops-team @security-team
/spec/ops-database-migration.md @devops-team @security-team

# Build system (requires security review - can modify workflows)
/tools/build_system/ @security-team @devops-team
```

### Sponsor Repository

```
# Default owner
* @{sponsor}-dev-team

# Sponsor configuration (requires admin approval)
/config/ @{sponsor}-admins
/lib/sponsor_config.dart @{sponsor}-admins

# Assets and branding (product approval)
/assets/ @{sponsor}-dev-team @{sponsor}-product-team
```

---

## Audit Logging

**Enable Post-UAT**

### GitHub Audit Log Settings

```
Organization Settings → Audit log:
  ✅ Enable audit log streaming
  Destination: CloudWatch, Splunk, or S3
  Events to log:
    - All repository access
    - Team membership changes
    - Branch protection changes
    - Workflow modifications
    - Secret access
    - Deploy key usage
```

### Required Audit Events

**Repository Events**:
- Repository created/deleted
- Repository visibility changed
- Branch protection modified
- Collaborator added/removed

**Code Events**:
- Push to main/release branches
- Pull request created/merged
- Workflow file modified
- Secret added/modified/accessed

**Access Events**:
- Team membership changed
- Permission level changed
- Deploy key added/revoked
- OAuth app authorized

**Retention**: 2 years minimum (FDA 21 CFR Part 11 compliance)

---

## Secret Management

### Repository Secrets (Post-UAT)

**Core Repository**:
- No secrets stored (public repo)
- CI/CD uses ephemeral tokens only

**Sponsor Repositories**:
```
Required Secrets (GitHub Secrets):
  SUPABASE_URL              - Sponsor's Supabase project URL
  SUPABASE_ANON_KEY         - Supabase anonymous key
  SUPABASE_SERVICE_KEY      - Service role key (CI/CD only)
  NETLIFY_AUTH_TOKEN        - Netlify deployment token
  NETLIFY_SITE_ID           - Portal site identifier
  APPLE_CERTIFICATE         - iOS code signing
  APPLE_PROVISIONING        - iOS provisioning profile
  ANDROID_KEYSTORE          - Android signing keystore
  ANDROID_KEY_ALIAS         - Keystore alias
  ANDROID_KEY_PASSWORD      - Keystore password

Secret Access Restrictions:
  ✅ Limit to specific workflows only
  ✅ Limit to specific branches (main, release/*)
  ✅ Never log secret values
  ✅ Rotate secrets quarterly
  ✅ Audit secret access monthly
```

---

## Deploy Keys vs Personal Access Tokens

### Recommendation: Deploy Keys (Post-UAT)

```
Deploy Keys (Preferred):
  ✅ Scoped to single repository
  ✅ Read-only or read-write per key
  ✅ No user account dependency
  ✅ Easy to rotate
  ✅ Audit trail per key

Personal Access Tokens (Avoid):
  ❌ Access to all user's repos
  ❌ Tied to user account
  ❌ User leaves = token revoked = broken deploys
  ❌ Harder to audit
```

**When to Use PAT**: Only for multi-repo operations (rare)

---

## External Contributor Policy

### Post-UAT (Core Repo Only)

```
Fork and Pull Request Workflow:

1. External contributor forks repo
2. Contributor makes changes in fork
3. Contributor opens PR to clinical-diary/main
4. CI/CD runs (limited secrets access)
5. Core team reviews
6. Core team merges (if approved)

Security Restrictions:
  ❌ PRs from forks cannot access secrets
  ❌ PRs from forks cannot modify workflows
  ✅ PRs from forks run linters/tests only
  ✅ Core team can manually trigger full CI/CD after review
```

**Contributor License Agreement (CLA)**: Required before first merge

---

## Implementation Checklist (Post-UAT)

### Phase 1: Enable Basic Protection
```
□ Create GitHub Teams (core-team, security-team, compliance-team)
□ Enable branch protection on main
□ Require 2 PR approvals
□ Enable status checks
□ Create CODEOWNERS file
□ Test: Attempt to push to main (should fail)
□ Test: Create PR, verify 2 approvals required
```

### Phase 2: Audit and Secrets
```
□ Enable audit log streaming
□ Migrate secrets to GitHub Secrets
□ Rotate all secrets (fresh start)
□ Generate deploy keys (replace PATs)
□ Configure secret access restrictions
□ Document secret rotation procedure
```

### Phase 3: Sponsor Repos
```
□ Create sponsor-specific teams
□ Configure sponsor repo branch protection
□ Add sponsor CODEOWNERS
□ Test: Verify cross-sponsor isolation
□ Test: Verify core team read access
```

### Phase 4: Validation
```
□ Audit log test (push, PR, workflow change)
□ Secret access test (verify restrictions work)
□ CODEOWNERS test (modify database/, verify security review)
□ Branch protection test (attempt force push, should fail)
□ External contributor test (fork, PR, verify limited CI)
□ Document all team members and access levels
```

---

## Security Incident Response

### Compromised Credentials (Post-UAT)

**If GitHub PAT or Deploy Key Compromised**:

```
1. IMMEDIATE (within 1 hour):
   - Revoke compromised credential in GitHub
   - Check audit log for unauthorized access
   - Generate new credential
   - Update CI/CD with new credential

2. INVESTIGATION (within 24 hours):
   - Review all commits since last known-good date
   - Check workflow runs for suspicious activity
   - Verify no secrets exposed in logs
   - Document timeline and impact

3. REMEDIATION (within 48 hours):
   - Rotate all related secrets
   - Update security procedures
   - Notify affected sponsors (if applicable)
   - File incident report (FDA 21 CFR Part 11)
```

**If Sponsor Secret Compromised**:

```
1. IMMEDIATE:
   - Revoke secret in GitHub + Supabase/Netlify
   - Invalidate all active user sessions
   - Generate new secret
   - Redeploy applications

2. INVESTIGATION:
   - Review Supabase audit logs
   - Check for unauthorized database access
   - Verify data integrity

3. NOTIFICATION:
   - Notify sponsor within 24 hours
   - Provide incident timeline
   - Document remediation steps
```

---

## GitHub Actions Workflow Scope

### Pre-UAT (Current)

```
Workflow Permissions: Minimal
  - No workflow scope in OAuth tokens
  - Workflows pushed via SSH or GitHub UI
  - Manual approval for workflow changes
```

### Post-UAT

```
Workflow Permissions: Controlled
  - CI/CD service account with workflow scope
  - CODEOWNERS required for workflow files
  - Security team approval mandatory
  - Workflow changes logged and audited
```

**Rationale**: Workflows can access secrets and execute code. Treat as critical security boundary.

---

## Migration Plan (When Ready)

### Step 1: Notify Team
- Email all developers 1 week before implementation
- Document new procedures in team wiki
- Schedule training session

### Step 2: Enable Gradually
- Week 1: Create teams, no enforcement
- Week 2: Enable branch protection (warnings only)
- Week 3: Enable CODEOWNERS (warnings only)
- Week 4: Full enforcement

### Step 3: Monitor
- Check audit logs daily for first week
- Identify friction points
- Adjust policies as needed
- Document common issues/solutions

---

## References

- **Architecture**: prd-architecture-multi-sponsor.md
- **Deployment**: ops-deployment.md
- **Security**: dev-security.md, ops-security.md
- **GitHub Docs**: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-security-and-analysis-settings-for-your-repository

---

## Quick Reference

### Current Stage (Pre-MVP)
```
✅ Private sponsor repos
✅ Pre-commit requirement validation
✅ Trust-based development
❌ No branch protection
❌ No CODEOWNERS
❌ No mandatory reviews
```

### Post-UAT Stage
```
✅ Branch protection on main
✅ Required PR reviews (2 approvals)
✅ CODEOWNERS enforcement
✅ Team-based access control
✅ Audit logging enabled
✅ Secret access restrictions
✅ Deploy keys (no PATs)
```

**Timeline**: Implement post-UAT, before first production deployment
