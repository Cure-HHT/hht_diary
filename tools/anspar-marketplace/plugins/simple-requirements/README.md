# Anspar Requirement Validation

**Claude Code Plugin for Requirement Validation**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python Version](https://img.shields.io/badge/python-%3E%3D3.8-brightgreen)](https://www.python.org/)

## Overview

The Anspar Requirement Validation plugin validates requirement format, uniqueness, and links before commits. It ensures all requirements follow the standard format and maintain proper hierarchical relationships.

This plugin provides the **git hook integration** for the validation script located at `tools/requirements/validate_requirements.py` (shared with CI/CD).

**Key Features**:
- ✅ Git pre-commit hook integration
- ✅ Requirement format validation
- ✅ Uniqueness checking (no duplicate IDs)
- ✅ Link validation (parent requirements exist)
- ✅ Automatic validation on spec/ changes

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
REQUIREMENT_VALIDATION_HOOK="tools/anspar-marketplace/plugins/simple-requirements/hooks/pre-commit-requirement-validation"
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
chmod +x tools/anspar-marketplace/plugins/simple-requirements/hooks/pre-commit-requirement-validation
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
- **linear-integration**: Creates Linear tickets from requirements

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
- **Traceability Matrix**: `tools/anspar-marketplace/plugins/traceability-matrix`
- **Claude Code Plugins**: https://docs.claude.com/en/docs/claude-code/plugins-reference

## Support

For issues, questions, or contributions:
- **Repository**: https://github.com/anspar/diary
- **Plugin Path**: `tools/anspar-marketplace/plugins/simple-requirements`
