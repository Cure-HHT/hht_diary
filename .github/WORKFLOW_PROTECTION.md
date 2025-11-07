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

### Step 2: Activate CODEOWNERS

```bash
# Create a branch
git checkout -b activate-workflow-protection

# Rename CODEOWNERS file to activate it
git mv .github/CODEOWNERS-PRE-PRODUCTION .github/CODEOWNERS

# Commit and push
git add .github/
git commit -m "[OPS] Activate workflow protection CODEOWNERS"
git push origin activate-workflow-protection

# Create PR and merge
gh pr create --title "Activate workflow protection" --body "Enables CODEOWNERS enforcement"
```

**Note**: CODEOWNERS only takes effect once the file is named exactly `CODEOWNERS` and merged to the default branch.

### Step 3: Verify Protection is Active

1. Make a test change to any `.github/workflows/*.yml` file
2. Create a PR
3. Verify that:
   - PR requires `@Cure-HHT/admins` approval (CODEOWNERS)
   - "Alert on Workflow Changes" workflow runs (if bypass token used)
4. If bypass token is used, verify security alert appears on PR

## Disabling Workflow Protection

**⚠️ Requires: Repository Admin Access**

### Step 1: Disable Automated Alerts

**Option A**: Set variable to false
1. Go to repository Settings → Secrets and variables → Actions → Variables
2. Find `WORKFLOW_PROTECTION_ENABLED`
3. Click "Update"
4. Change value to `false`
5. Save

**Option B**: Delete variable (same effect as false)
1. Go to repository Settings → Secrets and variables → Actions → Variables
2. Find `WORKFLOW_PROTECTION_ENABLED`
3. Click "Delete"

### Step 2: Deactivate CODEOWNERS (Optional)

To also remove review requirements:

```bash
# Create a branch
git checkout -b deactivate-workflow-protection

# Rename CODEOWNERS file to deactivate it
git mv .github/CODEOWNERS .github/CODEOWNERS-PRE-PRODUCTION

# Commit and push
git add .github/
git commit -m "[OPS] Deactivate workflow protection CODEOWNERS"
git push origin deactivate-workflow-protection

# Create PR and merge
gh pr create --title "Deactivate workflow protection" --body "Disables CODEOWNERS enforcement"
```

**Note**: CODEOWNERS stops being enforced once renamed away from the exact filename `CODEOWNERS`

## Access Control

### Who Can Toggle Protection?

Only users with **Admin** or **Write** access to the repository can modify repository variables.

Recommended: Limit to repository admins only via GitHub role settings.

### Who Can Modify Protected Files?

**Current State**: CODEOWNERS inactive (renamed to CODEOWNERS-PRE-PRODUCTION)
- No review requirements currently enforced
- Anyone with write access can modify `.github/workflows/`
- Anyone with write access can modify security files

**When Activated**: CODEOWNERS rules apply
- Changes to `.github/workflows/` require `@Cure-HHT/admins` approval
- Changes to `.github/BOT_SECURITY.md` require `@Cure-HHT/admins` approval

## Security Model

### Defense in Depth

Workflow protection is one layer in a multi-layer security model:

1. **CODEOWNERS** (When activated by renaming file)
   - GitHub-enforced reviews when file named exactly "CODEOWNERS"
   - Currently inactive (file named CODEOWNERS-PRE-PRODUCTION)

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
- `.github/CODEOWNERS-PRE-PRODUCTION`: Inactive (requires rename to activate)
- `.github/BOT_SECURITY.md`: Updated with protection toggle documentation
- `.github/WORKFLOW_PROTECTION.md`: Complete documentation on activation

## References

- [GitHub Repository Variables Documentation](https://docs.github.com/en/actions/learn-github-actions/variables)
- [CODEOWNERS Documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- See `.github/BOT_SECURITY.md` for complete security model

## Changelog

- 2025-11-07: Initial implementation with feature flag (CUR-331)
