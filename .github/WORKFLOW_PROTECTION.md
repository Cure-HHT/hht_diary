# Workflow Protection Configuration

## Overview

Workflow protection provides security controls for GitHub Actions workflows and local git hooks to prevent unauthorized modifications to critical files.

**Current Status**: DISABLED (development mode)

## Feature Flag: `WORKFLOW_PROTECTION_ENABLED`

Workflow protection is controlled by a repository variable that can only be modified by repository admins.

### States

- **`false` or unset** (Default): Development mode
  - Automated workflow alerts DISABLED
  - CODEOWNERS reviews still apply (GitHub enforced)
  - Local git hooks may skip enforcement
  - Safe for active development

- **`true`**: Production mode
  - Automated workflow alerts ENABLED
  - CODEOWNERS reviews enforced
  - Full security posture active
  - Use when approaching production

## What is Protected?

When enabled, workflow protection monitors and alerts on changes to:

1. **GitHub Actions Workflows** (`.github/workflows/**`)
   - Detects use of `BOT_BYPASS_MAIN_PROTECTION` token
   - Posts security alerts on PRs
   - Requires security review checklist

2. **GitHub Scripts** (`.github/scripts/**`)
   - Automation scripts that workflows depend on

3. **CODEOWNERS** (`.github/CODEOWNERS`)
   - Controls who can approve sensitive changes

4. **Security Documentation** (`.github/BOT_SECURITY.md`)
   - Security policies and procedures

## Enabling Workflow Protection

**⚠️ Requires: Repository Admin Access**

### Step 1: Set Repository Variable

1. Go to repository Settings → Secrets and variables → Actions → Variables tab
2. Click "New repository variable"
3. Name: `WORKFLOW_PROTECTION_ENABLED`
4. Value: `true`
5. Click "Add variable"

### Step 2: Verify Protection is Active

1. Make a test change to any `.github/workflows/*.yml` file
2. Create a PR
3. Verify that the "Alert on Workflow Changes" workflow runs
4. If bypass token is used, verify security alert appears on PR

## Disabling Workflow Protection

**⚠️ Requires: Repository Admin Access**

### Option 1: Set to False

1. Go to repository Settings → Secrets and variables → Actions → Variables
2. Find `WORKFLOW_PROTECTION_ENABLED`
3. Click "Update"
4. Change value to `false`
5. Save

### Option 2: Delete Variable

1. Go to repository Settings → Secrets and variables → Actions → Variables
2. Find `WORKFLOW_PROTECTION_ENABLED`
3. Click "Delete"

**Note**: Unset (deleted) variable behaves the same as `false`

## Access Control

### Who Can Toggle Protection?

Only users with **Admin** or **Write** access to the repository can modify repository variables.

Recommended: Limit to repository admins only via GitHub role settings.

### Who Can Modify Protected Files?

Even with protection disabled:
- **CODEOWNERS** rules still apply (GitHub-enforced)
- Changes to `.github/workflows/` require `@Cure-HHT/admins` approval
- Changes to `.github/BOT_SECURITY.md` require `@Cure-HHT/admins` approval

## Security Model

### Defense in Depth

Workflow protection is one layer in a multi-layer security model:

1. **CODEOWNERS** (Always active)
   - GitHub-enforced reviews
   - Cannot be bypassed by variable setting

2. **Workflow Protection** (When enabled)
   - Automated detection and alerting
   - Security review checklists
   - Transparent monitoring

3. **Bot Validation** (Always active)
   - Validates bot commits only modify authorized files
   - Runs after every bot commit
   - Independent of workflow protection flag

### Why a Feature Flag?

During active development:
- Frequent workflow changes are expected
- Security alerts would be noise
- Team is small and trusted

Approaching production:
- Changes should be rare and reviewed
- Security alerts catch mistakes
- Audit trail is important

## Local Git Hooks

Local git hooks MAY check the `WORKFLOW_PROTECTION_ENABLED` variable via GitHub API.

However, local enforcement is optional because:
- Repository secrets are not accessible locally
- Local operations cannot bypass branch protection
- Local hooks are for developer convenience

## Troubleshooting

### Workflow not running when protection enabled

**Check**:
1. Is `WORKFLOW_PROTECTION_ENABLED` set to exactly `true` (lowercase)?
2. Are you modifying files in the monitored paths?
3. Check workflow run history in Actions tab

### How to test protection without enabling it?

Create a test PR and manually run the workflow:
1. Go to Actions → Alert on Workflow Changes
2. Click "Run workflow"
3. Select your PR branch
4. Review output

### I enabled protection but PRs don't show alerts

The alert only appears if:
1. A workflow file was modified in the PR
2. That workflow file contains `BOT_BYPASS_MAIN_PROTECTION`

Regular workflow changes won't trigger alerts.

## Implementation Details

### Workflow Condition

```yaml
jobs:
  alert-workflow-changes:
    if: vars.WORKFLOW_PROTECTION_ENABLED == 'true'
```

This condition:
- Checks repository variables (not secrets)
- Evaluates to false if variable is unset
- Only runs job when explicitly set to `'true'`

### Files Modified

- `.github/workflows/alert-workflow-changes.yml`: Added feature flag condition
- `.github/CODEOWNERS`: Always active (not conditional)
- `.github/BOT_SECURITY.md`: Updated with protection toggle documentation

## References

- [GitHub Repository Variables Documentation](https://docs.github.com/en/actions/learn-github-actions/variables)
- [CODEOWNERS Documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- See `.github/BOT_SECURITY.md` for complete security model

## Changelog

- 2025-11-07: Initial implementation with feature flag (CUR-331)
