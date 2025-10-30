# Requirement Validation Plugin for Claude Code

**Version**: 1.0.0
**Type**: Validation Plugin
**Status**: Active

## Overview

The requirement-validation plugin provides git hook integration for automated requirement validation. It ensures all requirements in `spec/` files follow proper format and maintain valid relationships before allowing commits.

This plugin is a **thin wrapper** that integrates the requirement validation tool into the git workflow. The actual validation logic is implemented in `tools/requirements/validate_requirements.py`, which is also used by CI/CD pipelines.

## Features

- ✅ **Automatic validation** on every commit affecting spec/ files
- ✅ **Format compliance** - Checks requirement ID format (REQ-{p|o|d}NNNNN)
- ✅ **Uniqueness** - Ensures no duplicate requirement IDs
- ✅ **Link validation** - Verifies all "Implements" references exist
- ✅ **Level consistency** - Checks ID prefix matches stated level
- ✅ **Orphan detection** - Warns about requirements with no children or code references
- ✅ **Blocks commits** on validation failures

## Implementation

This plugin references the existing validation script rather than duplicating it:

**Validation Implementation**: `tools/requirements/validate_requirements.py`
**Documentation**: `tools/requirements/README.md`

The hook script simply calls the validation tool from its canonical location, ensuring CI/CD and git hooks use the same validation logic.

## Installation

### Prerequisites

- Python 3.8+
- Git hooks enabled: `git config core.hooksPath .githooks`

### Steps

1. **Verify the plugin is in place**:
   ```bash
   ls tools/claude-marketplace/requirement-validation/
   ```

2. **Make the hook executable**:
   ```bash
   chmod +x tools/claude-marketplace/requirement-validation/hooks/pre-commit-requirement-validation
   ```

3. **Verify main pre-commit hook calls this plugin**:
   ```bash
   grep "requirement-validation" .githooks/pre-commit
   ```

   Should show:
   ```bash
   tools/claude-marketplace/requirement-validation/hooks/pre-commit-requirement-validation
   ```

## Usage

### Automatic (Git Hook)

The plugin runs automatically when you commit:

```bash
git add spec/prd-app.md
git commit -m "Add new requirement"

# Output:
# 🔍 Running requirement traceability validation...
#
# 📋 Found 42 requirements
# ✅ Requirement validation passed!
```

### Manual Validation

You can run the validation script directly anytime:

```bash
# Validate all requirements
python3 tools/requirements/validate_requirements.py

# Output includes:
# - Requirements found
# - Validation errors (if any)
# - Warnings about orphaned requirements
# - Summary statistics
```

## What It Validates

### 1. Requirement ID Format

**Rule**: Must match `REQ-{p|o|d}NNNNN: Title`

**Valid**:
- ✅ `### REQ-p00042: User Authentication`
- ✅ `### REQ-o00001: Database Deployment`
- ✅ `### REQ-d00156: API Implementation`

**Invalid**:
- ❌ `### REQ-42: User Login` (missing level prefix)
- ❌ `### REQ-p42: Login` (number too short)
- ❌ `### REQ-product-001: Feature` (wrong format)

### 2. Level Consistency

**Rule**: ID prefix must match stated level

**Valid**:
```markdown
### REQ-p00042: User Authentication
**Level**: PRD | ...
```

**Invalid**:
```markdown
### REQ-p00042: User Authentication
**Level**: Dev | ...   ❌ ID says PRD but level says Dev!
```

### 3. Unique IDs

**Rule**: Each requirement ID must be unique across all spec/ files

**Error Example**:
```
❌ Duplicate requirement ID: p00042
   Found in: prd-app.md and prd-security.md
```

### 4. Valid References

**Rule**: All "Implements" references must point to existing requirements

**Valid**:
```markdown
### REQ-d00156: API Implementation
**Level**: Dev | **Implements**: p00042 | **Status**: Active
```
(REQ-p00042 exists)

**Invalid**:
```markdown
### REQ-d00156: API Implementation
**Level**: Dev | **Implements**: p99999 | **Status**: Active
```
(REQ-p99999 doesn't exist)

### 5. Orphaned Requirements (Warning)

**Rule**: PRD and Ops requirements should have children or code references

**Warning Example**:
```
⚠️  REQ-p00042: No child requirements implement this
   and not found in implementation files
```

## Validation Output Examples

### Success

```
🔍 Scanning spec/ for requirements...

📋 Found 42 requirements

======================================================================

✅ ALL REQUIREMENTS VALID

📊 SUMMARY:
  Total requirements: 42
  By level: PRD=15, Ops=12, Dev=15
  By status: Active=40, Draft=2, Deprecated=0
======================================================================
```

### Failure

```
🔍 Scanning spec/ for requirements...

📋 Found 42 requirements

======================================================================

❌ 2 ERROR(S) FOUND:

  • prd-app.md:67 - Invalid ID format: REQ-p42 (expected: [pod]NNNNN)
  • ops-deployment.md:23 - REQ-o00005: References non-existent requirement 'p99999'

⚠️  1 WARNING(S):

  • prd-security.md:45 - REQ-p00012: No child requirements implement this

❌ Validation failed with 2 error(s)

======================================================================
```

## Troubleshooting

### Hook Not Running

**Problem**: Validation doesn't run on commit

**Solutions**:
```bash
# 1. Verify hooks path
git config --get core.hooksPath
# Should output: .githooks

# 2. Set hooks path if needed
git config core.hooksPath .githooks

# 3. Verify hook is executable
ls -l tools/claude-marketplace/requirement-validation/hooks/pre-commit-requirement-validation
# Should show: -rwxr-xr-x

# 4. Make executable if needed
chmod +x tools/claude-marketplace/requirement-validation/hooks/pre-commit-requirement-validation
```

### Validation Script Not Found

**Problem**: Hook reports validation script missing

**Solution**:
```bash
# Verify script exists
ls -l tools/requirements/validate_requirements.py

# If missing, check git status
git status tools/requirements/
```

### Python Version Issues

**Problem**: Script fails with Python syntax errors

**Solution**:
```bash
# Check Python version (need 3.8+)
python3 --version

# Try running script directly
python3 tools/requirements/validate_requirements.py
```

### Bypassing Validation

**When to bypass** (NOT RECOMMENDED unless):
- Draft requirements (fix before pushing)
- Emergency hotfix (fix immediately after)
- Temporary broken state (fix in next commit)

**How to bypass**:
```bash
git commit --no-verify -m "Draft: WIP requirements"
```

## Integration with CI/CD

This plugin and CI/CD both use the same validation script (`tools/requirements/validate_requirements.py`), ensuring consistent validation across local development and continuous integration.

**CI/CD Example** (GitHub Actions):
```yaml
- name: Validate Requirements
  run: python3 tools/requirements/validate_requirements.py
```

## Related Documentation

- **Implementation**: `tools/requirements/README.md`
- **Requirement Format**: `spec/requirements-format.md`
- **Validation Script**: `tools/requirements/validate_requirements.py`
- **Git Hooks**: `.githooks/README.md`
- **Project Instructions**: `CLAUDE.md`

## Plugin Metadata

- **Plugin Name**: requirement-validation
- **Version**: 1.0.0
- **Hook File**: `hooks/pre-commit-requirement-validation`
- **Implementation**: `tools/requirements/validate_requirements.py` (shared with CI/CD)
- **Dependencies**: Python 3.8+

## Changelog

### v1.0.0 (2025-10-30)

- Initial release
- Extracted from monolithic `.githooks/pre-commit`
- References existing validation script (no duplication)
- Full documentation and plugin metadata

## License

Part of the diary project. See project LICENSE for details.
