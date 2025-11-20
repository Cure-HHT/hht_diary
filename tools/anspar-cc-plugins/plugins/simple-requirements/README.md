# Anspar Requirement Validation

**Claude Code Plugin for Requirement Validation**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python Version](https://img.shields.io/badge/python-%3E%3D3.8-brightgreen)](https://www.python.org/)

## Overview

The Anspar Simple Requirements plugin provides comprehensive requirement management including validation, change tracking, and implementation verification. It ensures all requirements follow the standard format, maintains proper hierarchical relationships, and helps keep implementations synchronized with requirement changes.

This plugin provides **git hook integration** for validation and **automated change tracking** when requirements are modified.

## Prerequisites

See the following guides for setup requirements:
- [Development Prerequisites](../../../../docs/development-prerequisites.md) - Required tools and installation
- [Git Hooks Setup](../../../../docs/git-hooks-setup.md) - Configuring project git hooks
- [Secret Management](../../../../docs/security-secret-management.md) - API tokens and credentials

For requirement format details, see [spec/README.md](../../../../spec/README.md).

**Key Features**:
- ✅ **Validation**: Format, uniqueness, and link validation before commits
- ✅ **Change Detection**: Automatic detection of modified requirements
- ✅ **Tracking System**: Persistent tracking of outdated implementations
- ✅ **Session Notifications**: Alerts about changed requirements when starting work
- ✅ **Linear Integration**: Optional ticket creation for verification (requires linear-api plugin)
- ✅ **Requirements Agent**: Specialized sub-agent for requirement operations
- ✅ **Get Requirement**: Fetch any requirement by ID with full metadata
- ✅ **Verification Workflow**: Simple commands to mark requirements as verified

## Installation

### As Claude Code Plugin

1. Clone or copy this directory to your Claude Code plugins location
2. The plugin will be automatically discovered by Claude Code
3. Configure git hooks (see below)

### Prerequisites

- **Python**: >=3.8
- **Git**: For hook integration
- **Bash**: >=4.0
- **Validation Script**: `tools/requirements/validate_requirements.py` must exist in parent project

## Setup

### 1. Configure Git Hooks

Enable custom git hooks if not already configured:

```bash
# From repository root
git config core.hooksPath .githooks
```

### 2. Integrate with Pre-Commit Hook

Add the requirement-validation hook to your main pre-commit hook at `.githooks/pre-commit`:

```bash
# Requirement Validation (Plugin)
REQUIREMENT_VALIDATION_HOOK="tools/anspar-cc-plugins/plugins/simple-requirements/hooks/pre-commit-requirement-validation"
if [ -f "$REQUIREMENT_VALIDATION_HOOK" ]; then
    "$REQUIREMENT_VALIDATION_HOOK" || exit 1
fi
```

### 3. Verify Installation

```bash
# Test with a spec file change
git add spec/prd-app.md
git commit -m "test" --dry-run
```

## How It Works

### Reference Architecture

This plugin is a **thin wrapper** that calls the shared validation script:

```
simple-requirements/
└── hooks/
    └── pre-commit-requirement-validation  ← Git hook (this plugin)
 |
                 v
        tools/requirements/
        └── validate_requirements.py       ← Shared script (CI/CD compatible)
```

**Why this architecture?**
- ✅ Single source of truth for validation logic
- ✅ CI/CD and git hooks use the same script
- ✅ Updates to validation automatically apply everywhere
- ✅ No code duplication

### Validation Flow

1. **Git commit triggered** with spec/ changes
2. **Hook detects** spec/*.md files in staging area
3. **Python script runs** to validate all requirements
4. **Results reported** with detailed error messages
5. **Commit blocked** if validation fails

### What Gets Validated

**Format Validation**:
- Requirement ID format: `REQ-{type}{number}` (e.g., `REQ-p00042`)
- Metadata presence: Level, Implements, Status
- Prescriptive language: SHALL/MUST/MAY

**Uniqueness Validation**:
- No duplicate requirement IDs across all spec/ files
- Each requirement ID is unique project-wide

**Link Validation**:
- Parent requirements (in "Implements" field) must exist
- Hierarchical cascade is valid (PRD → Ops → Dev)
- No circular dependencies

## Requirement Change Tracking (Phase 3)

### Overview

The tracking system automatically detects when requirements change and helps ensure implementations stay synchronized. When you modify a requirement in `spec/`, the system:

1. **Detects the change** (compares hash against INDEX.md)
2. **Tracks outdated implementations** (adds to tracking file)
3. **Notifies you** at session start
4. **Optionally creates Linear tickets** for verification

### Quick Start

```bash
# 1. Check for changes:
python3 scripts/detect-changes.py --format summary

# 2. View a specific requirement:
python3 scripts/get-requirement.py REQ-d00027

# 3. After updating implementation, mark as verified:
python3 scripts/mark-verified.py d00027
```

### Tracking Scripts

#### Get Requirement
Fetch and display any requirement by ID:

```bash
# View requirement (markdown):
python3 scripts/get-requirement.py d00027

# JSON output (for automation):
python3 scripts/get-requirement.py d00027 --format json
```

#### Detect Changes
Find requirements that have been modified:

```bash
# Human-readable summary:
python3 scripts/detect-changes.py --format summary

# JSON for automation:
python3 scripts/detect-changes.py --format json
```

#### Update Tracking
Add changed requirements to tracking file:

```bash
# From detect-changes output:
python3 scripts/detect-changes.py --format json > /tmp/changes.json
python3 scripts/update-tracking.py --input /tmp/changes.json

# Single requirement:
python3 scripts/update-tracking.py --req-id d00027 --old-hash abc --new-hash def
```

#### Mark Verified
Remove requirement from tracking after verification:

```bash
# Mark single requirement:
python3 scripts/mark-verified.py d00027

# Dry run (preview):
python3 scripts/mark-verified.py d00027 --dry-run
```

### Hooks

#### Post-Commit Hook
Automatically runs after commits that modify `spec/*.md`:
- Detects changed requirements
- Updates tracking file
- Shows summary of changes
- Optionally creates Linear tickets (if `LINEAR_CREATE_TICKETS=true`)

#### Session-Start Hook
Runs when Claude Code session starts:
- Checks for outdated requirements
- Displays concise notification
- Suggests next actions

### Tracking File

**Location**: `untracked-notes/outdated-implementations.json`

**Format**:
```json
{
  "version": "1.0",
  "last_updated": "2025-11-06T12:34:56+00:00",
  "outdated_requirements": [
    {
      "req_id": "d00027",
      "old_hash": "abc12345",
      "new_hash": "def67890",
      "file": "dev-api.md",
      "title": "API Authentication",
      "linear_ticket": "CUR-123",
      "verified_at": null
    }
  ]
}
```

### Requirements Agent

Claude can use the Requirements sub-agent for requirement operations:

```
User: "What does REQ-d00027 say?"
Claude: [Uses Requirements agent to fetch and explain]

User: "Have any requirements changed?"
Claude: [Uses Requirements agent to detect and report]
```

### Linear Integration (Optional)

Enable automatic ticket creation for changed requirements:

```bash
export LINEAR_CREATE_TICKETS=true
```

When enabled, post-commit hook creates verification tickets with:
- Full requirement context
- Verification checklist
- Commands to run
- Links to source files

### Complete Workflow Example

```bash
# 1. Modify a requirement
vim spec/dev-api.md  # Update REQ-d00027

# 2. Commit the change
git commit -m "Update REQ-d00027: Improve auth flow"
# Post-commit hook runs automatically

# 3. Next session, you see notification:
# 📋 REQUIREMENTS CHANGED
#    • REQ-d00027: API Authentication

# 4. Review the requirement:
python3 scripts/get-requirement.py d00027

# 5. Find implementations:
git grep -n "REQ-d00027"

# 6. Update code to match new requirement
vim src/api/auth.py

# 7. Mark as verified:
python3 scripts/mark-verified.py d00027
# ✅ Marked as verified and removed from tracking
```

For detailed workflow documentation, see [TRACKING-WORKFLOW.md](./TRACKING-WORKFLOW.md).

## Phase 4: Implementation Verification

**Tools for finding and verifying implementations when requirements change:**

- `scan-implementations.py` - Find all code implementing a requirement
- `analyze-compliance.py` - AI-powered analysis of implementation compliance
- `generate-report.py` - Create verification reports (markdown/HTML/JSON)

See [VERIFICATION-GUIDE.md](./VERIFICATION-GUIDE.md) for details.

## Phase 5: CI/CD Integration

See [CI/CD Setup Guide](../../../../docs/cicd-setup-guide.md) for comprehensive GitHub Actions integration examples.

**Automated verification in GitHub Actions:**

Workflow `.github/workflows/requirement-verification.yml` runs on spec/ changes:
- Detects changed requirements automatically
- Scans for implementations
- Generates verification reports
- Posts results as PR comments
- Uploads artifacts for audit

All verification tools are production-ready with comprehensive test coverage.

## Usage

### Automatic Validation (Recommended)

The plugin runs automatically when you commit changes to spec/ files:

```bash
# Normal workflow - validation runs automatically
git add spec/dev-api.md
git commit -m "Add API requirements"

# Output:
# ✅ Found 112 requirements
# ⚠️  9 warnings (orphaned requirements)
# ✅ No errors - validation passed!
```

### Manual Validation

Run the validation script directly:

```bash
# From repository root
python3 tools/requirements/validate_requirements.py

# Or with specific files
python3 tools/requirements/validate_requirements.py spec/dev-api.md
```

### Bypassing Validation (Not Recommended)

If you need to commit despite validation failures:

```bash
git commit --no-verify -m "Draft: WIP requirements"
```

**Only bypass for**:
- Draft requirements (fix before pushing)
- Emergency hotfixes (fix immediately after)

## Common Validation Errors

### Error: Duplicate Requirement ID

**Error**:
```
❌ ERROR: Duplicate requirement ID: REQ-p00042
   Found in:
     - spec/prd-app.md:42
     - spec/prd-features.md:15
```

**Fix**:
1. Choose which requirement to keep
2. Rename the duplicate with a new ID
3. Update any references to the old ID

### Error: Invalid Requirement Format

**Error**:
```
❌ ERROR: REQ-d00042: Missing metadata
   Expected: **Level**: Dev | **Implements**: ... | **Status**: Active
   Found in: spec/dev-api.md:25
```

**Fix**:
```markdown
### REQ-d00042: API Authentication

**Level**: Dev | **Implements**: REQ-p00015 | **Status**: Active

The API SHALL implement OAuth2 authentication...
```

### Error: Parent Requirement Not Found

**Error**:
```
❌ ERROR: REQ-d00042 implements REQ-p00999, but REQ-p00999 not found
```

**Fix**:
1. Create the parent requirement (REQ-p00999)
2. Or update REQ-d00042 to implement correct parent requirement

### Warning: Orphaned Requirement

**Warning**:
```
⚠️  WARNING: REQ-o00015 is not implemented by any Dev requirement
```

**Fix** (optional):
- This is a warning, not an error
- Create Dev requirements that implement this Ops requirement
- Or mark as "waiting for implementation"

## Configuration

### Validation Rules

To modify validation rules, edit:
- **Location**: `tools/requirements/validate_requirements.py`
- **Shared with**: CI/CD pipeline
- **Changes apply to**: Git hooks AND CI/CD

### Hook Behavior

To customize hook behavior, edit:
- **Location**: `hooks/pre-commit-requirement-validation`
- **Customize**: When to trigger, how to handle failures

## INDEX.md Management

### CRITICAL RULES

**⚠️ NEVER add new requirements by directly editing INDEX.md**

When you need a new requirement ID:
- Use the GitHub Actions workflow: **"Claim Requirement Number"**
- This ensures sequential numbering across all branches
- Direct editing can cause conflicts with the main branch

**Why?** The main branch might have assigned higher REQ numbers while you were working on your branch. Direct editing bypasses the centralized numbering system.

### INDEX.md Regeneration

INDEX.md can be **safely regenerated from scratch** at any time:

```bash
# Update all hashes in spec files and INDEX.md
python3 tools/requirements/update-REQ-hashes.py

# Verify consistency
python3 tools/requirements/validate_index.py
```

**Why is this safe?**
- The source of truth is in `spec/*.md` files, not INDEX.md
- INDEX.md is a derived artifact (like a cache or index)
- Regeneration recalculates hashes and rebuilds the index from spec files
- No data loss - all requirement content lives in spec/*.md

### Hash Management

Hashes are calculated automatically:
- **Manual update**: `python3 tools/requirements/update-REQ-hashes.py`
- **Automatic**: Post-commit hooks detect changes and update tracking
- Hash changes trigger implementation verification workflow

## Troubleshooting

### Hook Not Running

**Cause**: Git hooks path not configured or hook not executable

**Solution**:
```bash
# Check git hooks path
git config core.hooksPath

# Should show: .githooks

# If not set:
git config core.hooksPath .githooks

# Make hook executable
chmod +x tools/anspar-cc-plugins/plugins/simple-requirements/hooks/pre-commit-requirement-validation
```

### Python Script Not Found

**Cause**: Validation script missing or wrong path

**Solution**:
```bash
# Verify script exists
ls -l tools/requirements/validate_requirements.py

# If missing, check if it was moved or renamed
find . -name "validate_requirements.py"
```

### Validation Fails in CI But Passes Locally

**Cause**: Different Python versions or script versions

**Solution**:
1. Verify Python version matches CI: `python3 --version`
2. Ensure validation script is committed and up to date
3. Run validation with same flags as CI

## Integration

### With Other Plugins

This plugin works alongside:
- **traceability-matrix**: Generates traceability matrices
- **spec-compliance**: Enforces spec/ directory compliance
- **linear-api**: Creates Linear tickets from requirements

### With CI/CD

This plugin uses the **same validation script** as CI/CD:

**Git Hook** (local):
```bash
python3 tools/requirements/validate_requirements.py
```

**CI Pipeline** (GitHub Actions):
```yaml
- name: Validate Requirements
  run: python3 tools/requirements/validate_requirements.py
```

**Benefits**:
- Same validation logic everywhere
- Catch errors before pushing
- Fast feedback loop

## Dependencies

- **Python**: >=3.8
- **Bash**: >=4.0
- **Git**: For hook integration
- **Validation Script**: `tools/requirements/validate_requirements.py`

## License

MIT License - see [LICENSE](./LICENSE) file for details.

## Contributing

This plugin is part of the Anspar Foundation tooling ecosystem. Contributions welcome!

## Credits

**Developed by**: Anspar Foundation
**Plugin System**: Claude Code by Anthropic

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for version history.

## Related Documentation

- **Requirement Format**: See spec/requirements-format.md in parent project
- **Validation Script**: `tools/requirements/validate_requirements.py`
- **Traceability Matrix**: `tools/anspar-cc-plugins/plugins/traceability-matrix`
- **Claude Code Plugins**: https://docs.claude.com/en/docs/claude-code/plugins-reference

## Support

For issues, questions, or contributions:
- **Repository**: https://github.com/anspar/diary
- **Plugin Path**: `tools/anspar-cc-plugins/plugins/simple-requirements`
