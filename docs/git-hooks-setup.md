# Git Hooks Setup Guide

## IMPLEMENTS REQUIREMENTS

- REQ-d00018: Git Hook Implementation
- REQ-o00017: Version Control Workflow

This guide consolidates git hook setup information from all installed Claude Code plugins and provides comprehensive instructions for configuring, managing, and troubleshooting project git hooks.

## Overview

Git hooks are scripts that execute automatically at various points in the git workflow. This project uses hooks to enforce:

- **Requirement traceability** - All commits must reference formal requirements (REQ-xxx)
- **Workflow discipline** - Active ticket management via per-worktree state
- **Specification compliance** - Validation of spec/ directory content
- **Security scanning** - Detection of secrets before they enter git history
- **Matrix regeneration** - Automatic updates to traceability matrices

All hooks are managed through **plugin hooks** that delegate to specialized Claude Code plugins:

```
.githooks/pre-commit (orchestrator)
  ├── workflow/hooks/pre-commit (ticket validation, secret scanning)
  ├── simple-requirements/hooks/pre-commit-requirement-validation (format validation)
  ├── spec-compliance/hooks/pre-commit-spec-compliance (audience scope enforcement)
  └── traceability-matrix/hooks/pre-commit-traceability-matrix (matrix regeneration)

.githooks/commit-msg
  └── workflow/hooks/commit-msg (REQ reference validation)

.githooks/post-commit
  └── workflow/hooks/post-commit (history tracking)
```

**Benefits**:
- Single source of truth for validation logic (used by git hooks AND CI/CD)
- Modular plugin architecture (add/remove hooks without touching main orchestrator)
- Consistent error messages and behavior
- Automatic updates when plugins are updated

## Hooks in This Project

### pre-commit

**When it runs**: Before every `git commit` attempt

**What it validates**:

1. **Branch Protection** (built-in)
   - Blocks commits directly to `main` or `master` branches
   - Enforces feature branch workflow (requires pull request)

2. **Workflow Enforcement** (workflow plugin)
   - Validates active ticket is claimed in `.git/WORKFLOW_STATE`
   - Scans staged files for secrets using gitleaks
   - Blocks commits without claimed ticket
   - Blocks commits that expose API keys, passwords, or credentials

3. **Requirement Validation** (simple-requirements plugin)
   - Validates requirement format: `REQ-{type}{number}` (e.g., `REQ-d00027`)
   - Ensures requirement ID uniqueness across all spec/ files
   - Verifies "Implements" parent requirements exist
   - Detects orphaned requirements (no implementations)

4. **Specification Compliance** (spec-compliance plugin)
   - Validates file naming: `{audience}-{topic}.md`
   - Enforces audience scope rules (PRD cannot contain code)
   - Checks requirement metadata presence and format
   - Validates hierarchical requirement cascade

5. **Traceability Matrix Regeneration** (traceability-matrix plugin)
   - Auto-regenerates `traceability_matrix.md` and `traceability_matrix.html`
   - Only runs when spec/ files change
   - Stages updated matrices for commit

**Failure behavior**:
- Blocks commit with detailed error message
- Shows which validation failed and how to fix it
- Returns exit code 1

### commit-msg

**When it runs**: After pre-commit succeeds, before commit is created

**What it validates**:

- Commit message must contain at least one REQ reference
- Valid format: `REQ-{type}{number}` (e.g., `REQ-p00042`, `REQ-d00027, REQ-o00015`)
- Accepts multiple requirements: `Implements: REQ-p00001, REQ-d00015`
- Accepts "Fixes" or "Implements" keywords: `Fixes: REQ-d00089`

**Valid examples**:
```
Implement authentication system

Implements: REQ-p00042
```

```
Add API authentication

Implements: REQ-d00027, REQ-o00015
```

```
Fix audit trail bug

Fixes: REQ-d00089
```

**Failure behavior**:
- Blocks commit with requirement format instructions
- Shows examples of valid REQ references
- Returns exit code 1

### post-commit

**When it runs**: After commit succeeds

**What it does**:

- Records commit in `.git/WORKFLOW_STATE` history
- Appends action with timestamp, ticket ID, commit hash, and requirements
- Never blocks commits (informational only)
- Maintains append-only audit trail

**History entry format**:
```json
{
  "action": "commit",
  "timestamp": "2025-10-30T12:15:00Z",
  "ticketId": "CUR-262",
  "details": {
    "commitHash": "abc123def456",
    "requirements": ["REQ-d00027"]
  }
}
```

## Automatic Installation

### Via git config

The recommended way to enable hooks is through git configuration:

```bash
# From repository root
git config core.hooksPath .githooks
```

**What this does**:
- Sets `core.hooksPath` configuration for your local repository
- Tells Git to use `.githooks/` directory instead of default `.git/hooks/`
- Applies to all future commits in this repository
- Safe to run multiple times (idempotent)

**Verify installation**:
```bash
git config --get core.hooksPath
# Should output: .githooks
```

**Scope**:
- **Local only**: Affects only your clone of the repository
- **Not global**: Other repositories unaffected
- **Persists**: Configuration saved in `.git/config` (repo-local)

### What the installation does

Running `git config core.hooksPath .githooks` tells Git to:

1. Look for hook scripts in `.githooks/` directory
2. Execute them before standard `.git/hooks/` hooks
3. Apply same hook permission/exit code behavior
4. Pass standard git hook arguments

The hooks themselves are already in the repository and ready to use - this just configures Git to find them.

## Manual Installation

If `git config` doesn't work (rare edge cases), you can manually copy hooks:

### Step 1: Make Plugin Hooks Executable

```bash
# Make all plugin hooks executable
chmod +x tools/anspar-cc-plugins/plugins/*/hooks/*
chmod +x tools/anspar-cc-plugins/plugins/*/hooks/pre-commit

# Verify they're executable
ls -la tools/anspar-cc-plugins/plugins/*/hooks/ | grep -E 'pre-commit|commit-msg|post-commit'
```

### Step 2: Copy Orchestrator Hooks to .git/hooks/

```bash
# Create .git/hooks directory if needed (usually exists)
mkdir -p .git/hooks

# Copy hooks
cp .githooks/pre-commit .git/hooks/pre-commit
cp .githooks/commit-msg .git/hooks/commit-msg
cp .githooks/post-commit .git/hooks/post-commit

# Make them executable
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/commit-msg
chmod +x .git/hooks/post-commit

# Verify
ls -la .git/hooks/ | grep -E 'pre-commit|commit-msg|post-commit'
```

### Step 3: Verify Installation

```bash
# Test with a dry-run commit
git add README.md
git commit -m "test" --dry-run
```

**Expected output** (if no changes staged):
```
nothing to commit, working tree clean
```

**With actual changes**:
```
❌ ERROR: No active ticket claimed for this worktree
(This is expected - shows workflow enforcement is active)
```

## Hook Behavior

### When Each Hook Runs

```
user executes: git commit -m "message"
        ↓
    ┌───────────────────────────────┐
    │ pre-commit hook runs          │
    │ • Branch protection check     │
    │ • Plugin hooks executed       │
    │ • Validation performed        │
    └───────────────────────────────┘
        ↓
    [FAIL] → Commit blocked, error shown, exit code 1
        ↓
    [PASS] → Continue
        ↓
    ┌───────────────────────────────┐
    │ commit-msg hook runs          │
    │ • REQ reference validation    │
    └───────────────────────────────┘
        ↓
    [FAIL] → Commit blocked, error shown, exit code 1
        ↓
    [PASS] → Continue
        ↓
    ┌───────────────────────────────┐
    │ Commit created                │
    └───────────────────────────────┘
        ↓
    ┌───────────────────────────────┐
    │ post-commit hook runs         │
    │ • History recorded            │
    │ • Never blocks                │
    └───────────────────────────────┘
```

### What Causes Hooks to Fail

#### pre-commit failures (blocks commit):

1. **Committed to main/master**:
   ```
   ❌ ERROR: Direct commits to 'main' branch are not allowed!
   ```
   Fix: Create feature branch and commit there

2. **No active ticket claimed**:
   ```
   ❌ ERROR: No active ticket claimed for this worktree
   ```
   Fix: Run `./scripts/claim-ticket.sh <TICKET-ID>`

3. **Secrets detected**:
   ```
   ❌ SECRETS DETECTED IN STAGED FILES!
   Gitleaks found potential secrets in your staged changes.
   ```
   Fix: Remove secrets, use environment variables

4. **Invalid requirement format**:
   ```
   ❌ ERROR: Invalid Requirement Format
   REQ-d00042: Missing metadata
   ```
   Fix: Ensure requirements have Level, Implements, Status metadata

5. **Duplicate requirement ID**:
   ```
   ❌ ERROR: Duplicate requirement ID: REQ-p00042
   Found in:
     - spec/prd-app.md:42
     - spec/prd-features.md:15
   ```
   Fix: Rename duplicate with new ID

6. **Code in PRD file**:
   ```
   ❌ spec/prd-app.md contains code examples (forbidden in PRD files)
   ```
   Fix: Move code to dev-* file, reference from PRD

#### commit-msg failures (blocks commit):

1. **No REQ reference**:
   ```
   ❌ ERROR: Commit message must contain at least one requirement reference
   Expected format: REQ-{type}{number}
   ```
   Fix: Add `Implements: REQ-xxxxx` to commit message

2. **Invalid REQ format**:
   ```
   ❌ ERROR: Invalid requirement reference format
   ```
   Fix: Use format `REQ-{p|o|d}{5-digit-number}`

## Bypassing Hooks

When appropriate, you can bypass hooks using the `--no-verify` flag:

```bash
git commit --no-verify -m "Your message"
```

### When Bypass is Acceptable

- **Draft requirements**: Temporarily broken spec/ (fix before pushing)
- **Emergency hotfixes**: Critical production issue (fix compliance immediately after)
- **Experimental branches**: Testing new patterns (fix before PR to main)

### When Bypass is NOT Acceptable

- **Never bypass on main/master**: Feature branch workflow is non-negotiable
- **Never bypass for secrets**: Use environment variables instead
- **Never push without compliance**: CI/CD will re-validate at PR time
- **Never in production-adjacent**: Never bypass on branches destined for production

### Consequences of Bypassing

Bypassing hooks locally doesn't bypass CI/CD validation:

```bash
git commit --no-verify -m "Draft: WIP"
git push
# ↓
# CI/CD pipeline runs same validations
# ↓
# PR validation blocks merge if validations fail
# ↓
# You must fix issues anyway
```

Therefore, fix issues during development rather than deferring to CI.

## Troubleshooting

### Hook Not Running

**Symptom**: Commit succeeds without any hook output

**Cause**: Git hooks path not configured or hooks not executable

**Solution**:
```bash
# Verify hooks path is configured
git config --get core.hooksPath
# Expected output: .githooks

# If empty or wrong, configure:
git config core.hooksPath .githooks

# Verify hooks are executable
ls -la .githooks/
# Each hook should show -rwxr-xr-x (executable)

# If not executable:
chmod +x .githooks/pre-commit
chmod +x .githooks/commit-msg
chmod +x .githooks/post-commit
```

### Hook Failing Unexpectedly

**Symptom**: Hook fails with error you believe is incorrect

**Solution**:

1. **Read the error carefully**:
   ```bash
   # Error messages include specific guidance
   # Example:
   # ❌ ERROR: Invalid Requirement Format
   #    Expected: **Level**: Dev | **Implements**: ... | **Status**: Active
   ```

2. **Run validation manually to see full output**:
   ```bash
   # Requirement validation
   python3 tools/requirements/validate_requirements.py spec/dev-api.md

   # Spec compliance
   ./tools/anspar-cc-plugins/plugins/spec-compliance/scripts/validate-spec-compliance.sh

   # Traceability matrix generation
   python3 tools/requirements/generate_traceability.py --format markdown
   ```

3. **Check if issue is in staged vs unstaged changes**:
   ```bash
   # Hook validates only staged files
   git diff --cached  # What will be committed
   git diff          # What's not staged
   ```

### Permission Denied

**Symptom**: `Permission denied` when running hooks

**Cause**: Hook files not marked executable

**Solution**:
```bash
# Make all hooks executable
chmod +x .githooks/*
chmod +x tools/anspar-cc-plugins/plugins/*/hooks/*

# Verify
ls -la .githooks/ | head
ls -la tools/anspar-cc-plugins/plugins/*/hooks/ | grep -E 'pre-commit|commit-msg|post-commit'
```

### Python Script Not Found

**Symptom**: Hook fails with "script not found" error

**Cause**: Validation scripts in `tools/requirements/` missing or moved

**Solution**:
```bash
# Verify scripts exist
ls -l tools/requirements/validate_requirements.py
ls -l tools/requirements/generate_traceability.py

# If missing, check git status
git status tools/requirements/

# If deleted, restore from git
git checkout HEAD -- tools/requirements/
```

### Validation Passes Locally But Fails in CI

**Symptom**: Commit works locally, PR validation fails

**Causes**:
- Different Python versions (local vs CI container)
- Validation script updated but not committed
- Different environment or dependencies
- Stale validation scripts

**Solution**:
```bash
# Check Python version
python3 --version

# Ensure scripts are committed
git status tools/requirements/
git status tools/anspar-cc-plugins/

# Run validation with explicit Python
python3 tools/requirements/validate_requirements.py

# Commit any updated scripts
git add tools/requirements/ tools/anspar-cc-plugins/
git commit -m "Update validation scripts

Implements: REQ-xxx
"
```

### Workflow State File Issues

**Symptom**: "State file not found" or "State file corrupted"

**Cause**: `.git/WORKFLOW_STATE` missing or invalid JSON

**Solution**:
```bash
# Check state file
cat .git/WORKFLOW_STATE | python3 -m json.tool

# If corrupted, backup and recreate
mv .git/WORKFLOW_STATE .git/WORKFLOW_STATE.bak
./tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh <TICKET-ID>

# Verify new state
cat .git/WORKFLOW_STATE | python3 -m json.tool
```

### No Active Ticket Error

**Symptom**: `ERROR: No active ticket claimed for this worktree`

**Cause**: Attempting commit without claiming ticket first

**Solution**:
```bash
# Claim a ticket
./tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh CUR-262

# Or check if already claimed
./tools/anspar-cc-plugins/plugins/workflow/scripts/get-active-ticket.sh --format=human
```

### Gitleaks Not Installed

**Symptom**: Warning about gitleaks not available during commit

**Cause**: Secret scanning tool not installed

**Solution** (optional - secret scanning is graceful degradation):
```bash
# macOS
brew install gitleaks

# Ubuntu/Debian
sudo apt-get install gitleaks

# Other systems
# See: https://github.com/gitleaks/gitleaks#installation
```

For development, if you're in the pre-configured dev container, gitleaks is already installed.

## Hook Behavior Details

### Branch Protection

The pre-commit hook includes built-in branch protection:

```bash
# This will ALWAYS fail:
git checkout main
git add file.txt
git commit -m "Changes"
# ❌ ERROR: Direct commits to 'main' branch are not allowed!

# This is the correct workflow:
git checkout -b feature/my-feature
git add file.txt
git commit -m "Changes\n\nImplements: REQ-xxx"
git push -u origin feature/my-feature
# Create pull request via GitHub
```

This enforces that **all changes** go through code review (pull requests).

### Per-Worktree State Management

Each worktree has independent workflow state:

```bash
# Worktree 1: Working on CUR-262
cd ~/diary-worktrees/feature-auth
./scripts/claim-ticket.sh CUR-262
git commit -m "Add auth\n\nImplements: REQ-d00027"

# Worktree 2: Working on CUR-263 (different ticket!)
cd ~/diary-worktrees/feature-db
./scripts/claim-ticket.sh CUR-263
git commit -m "Update DB\n\nImplements: REQ-d00089"

# Each worktree's .git/WORKFLOW_STATE is independent
# No conflicts between worktrees
```

Valid scenarios:
- ✅ Different worktrees on different tickets
- ✅ Different worktrees on same ticket (multiple PRs for one feature)
- ✅ Switching tickets within a worktree (release then claim)

Invalid scenarios:
- ❌ Committing without claiming a ticket
- ❌ Commit message without REQ reference

### Spec File Changes Trigger Matrix Regeneration

When you commit changes to spec/ files, traceability matrices are automatically regenerated:

```bash
git add spec/prd-app.md spec/dev-api.md
git commit -m "Update requirements\n\nImplements: REQ-p00042, REQ-d00027"

# Output during commit:
# 📋 Spec Compliance Validation
# ✅ Spec compliance validation passed!
# ✅ Requirement Validation
# ✅ Validation passed!
# ✅ Regenerating traceability matrix...
# ✅ Generated traceability_matrix.md
# ✅ Generated traceability_matrix.html
# ✅ Added matrices to commit
```

The matrices are automatically staged and included in your commit.

## Plugin Hook Orchestration

### How Plugins Are Discovered

The main pre-commit hook auto-discovers and executes all plugin hooks:

```bash
# Discovery process:
# 1. Scan tools/anspar-cc-plugins/plugins/*/hooks/pre-commit
# 2. Find all matching files
# 3. Execute in alphabetical order
# 4. Stop on first failure

# Example discovery:
find tools/anspar-cc-plugins/plugins -type f -path "*/hooks/pre-commit" | sort
# tools/anspar-cc-plugins/plugins/simple-requirements/hooks/pre-commit-requirement-validation
# tools/anspar-cc-plugins/plugins/spec-compliance/hooks/pre-commit-spec-compliance
# tools/anspar-cc-plugins/plugins/traceability-matrix/hooks/pre-commit-traceability-matrix
# tools/anspar-cc-plugins/plugins/workflow/hooks/pre-commit
```

### Adding New Plugin Hooks

To add a new plugin hook:

1. Create hook file in plugin's hooks directory:
   ```bash
   touch tools/anspar-cc-plugins/plugins/myplugin/hooks/pre-commit
   ```

2. Make it executable:
   ```bash
   chmod +x tools/anspar-cc-plugins/plugins/myplugin/hooks/pre-commit
   ```

3. Implement validation logic (should exit 0 on success, 1 on failure)

4. Test with dry-run:
   ```bash
   git commit -m "test" --dry-run
   ```

The orchestrator hook will automatically discover and execute it.

### Removing Plugin Hooks

To disable a plugin hook:

1. **Option 1**: Rename the hook file:
   ```bash
   mv tools/anspar-cc-plugins/plugins/myplugin/hooks/pre-commit \
      tools/anspar-cc-plugins/plugins/myplugin/hooks/pre-commit.disabled
   ```

2. **Option 2**: Remove the plugin entirely:
   ```bash
   rm -rf tools/anspar-cc-plugins/plugins/myplugin
   ```

3. **Option 3**: Edit orchestrator hook to skip plugin:
   ```bash
   # Edit .githooks/pre-commit to add conditional logic
   ```

## References

### Plugin Documentation

- **workflow** - Ticket management and traceability
  - Path: `tools/anspar-cc-plugins/plugins/workflow/README.md`
  - Enforces: Active ticket requirement, REQ references, secret scanning
  - Hooks: `pre-commit`, `commit-msg`, `post-commit`

- **simple-requirements** - Requirement validation
  - Path: `tools/anspar-cc-plugins/plugins/simple-requirements/README.md`
  - Enforces: Requirement format, uniqueness, parent references
  - Hooks: `pre-commit-requirement-validation`

- **spec-compliance** - Specification compliance
  - Path: `tools/anspar-cc-plugins/plugins/spec-compliance/README.md`
  - Enforces: File naming, audience scope, requirement hierarchy
  - Hooks: `pre-commit-spec-compliance`

- **traceability-matrix** - Matrix generation
  - Path: `tools/anspar-cc-plugins/plugins/traceability-matrix/README.md`
  - Generates: `traceability_matrix.md` and `.html`
  - Hooks: `pre-commit-traceability-matrix`

### Other Documentation

- **Project Instructions**: `CLAUDE.md` - Requirement traceability rules
- **Spec Directory**: `spec/README.md` - How to structure requirements
- **Requirement Format**: `spec/requirements-format.md` - Requirement syntax
- **Workflow Plugin**: `tools/anspar-cc-plugins/plugins/workflow/README.md` - Full workflow details
- **Git Hooks Directory**: `.githooks/README.md` - Original hooks overview

## Summary

This project uses a comprehensive git hook system to enforce:

1. **Code review discipline** - All changes through pull requests (no direct commits to main)
2. **Requirement traceability** - All commits reference formal requirements
3. **Workflow management** - Active ticket tracking per worktree
4. **Specification compliance** - Validation of formal requirements documents
5. **Security** - Prevention of secrets entering git history
6. **Traceability** - Automatic generation of requirement matrices

To enable hooks: `git config core.hooksPath .githooks`

Hooks are non-bypassing in CI/CD, so fix issues locally rather than deferring to CI validation.

For detailed information about any hook, see the plugin documentation in `tools/anspar-cc-plugins/plugins/`.
