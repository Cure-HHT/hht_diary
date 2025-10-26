# Git Hooks for Requirement Traceability

## Overview

This directory contains Git hooks that enforce requirement traceability in the project.

## Installation

To enable these hooks, run:

```bash
git config core.hooksPath .githooks
```

This tells Git to use hooks from `.githooks/` instead of the default `.git/hooks/`.

## Available Hooks

### pre-commit

**Purpose**: Maintains requirement traceability and validates requirements before allowing commits.

**What it does**:
1. **Regenerates traceability matrices** (if spec/ files changed):
   - Automatically regenerates `traceability_matrix.md`
   - Automatically regenerates `traceability_matrix.html`
   - Stages updated matrices for commit
2. **Validates requirements**:
   - All requirements in `spec/` are properly formatted
   - All requirement IDs are unique
   - All "Implements" references point to existing requirements
   - No orphaned or broken requirement links

**When it runs**: Automatically before every `git commit`

**How to bypass** (NOT RECOMMENDED):
```bash
git commit --no-verify
```

Only bypass if you're:
- Working on draft requirements
- Making emergency hotfixes (fix requirements immediately after)
- Temporarily broken state (fix before pushing)

## Troubleshooting

### Hook not running

Make sure you've configured the hooks path:
```bash
git config --get core.hooksPath
# Should output: .githooks
```

If not set:
```bash
git config core.hooksPath .githooks
```

### Validation errors

The hook runs `tools/requirements/validate_requirements.py`. If it fails:

1. Read the error message carefully
2. See `spec/requirements-format.md` for format rules
3. Run validation manually to see full output:
   ```bash
   python3 tools/requirements/validate_requirements.py
   ```

### Permission denied

Make sure the hook is executable:
```bash
chmod +x .githooks/pre-commit
```

## Related Documentation

- **Requirement format**: `spec/requirements-format.md`
- **Validation tool**: `tools/requirements/README.md`
- **Project instructions**: `CLAUDE.md`
- **CI/CD setup**: `TODO_CI_CD_SETUP.md`
