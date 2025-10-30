# Git Hooks for Requirement Traceability

## Overview

This directory contains Git hooks that orchestrate validation plugins from the Claude Code marketplace.

The main pre-commit hook delegates to specialized plugins for modular, maintainable validation:

**Plugins (in `tools/claude-marketplace/`)**:
1. **traceability-matrix** - Auto-regenerates requirement traceability matrices
2. **requirement-validation** - Validates requirement format and links
3. **spec-compliance** - Enforces spec/ directory compliance rules

## Installation

To enable these hooks, run:

```bash
git config core.hooksPath .githooks
```

This tells Git to use hooks from `.githooks/` instead of the default `.git/hooks/`.

## Available Hooks

### pre-commit

**Purpose**: Orchestrates validation by calling marketplace plugins.

**What it does**:
1. **Dockerfile linting** (hadolint) - If Dockerfiles changed
2. **Traceability Matrix Regeneration** (plugin):
   - Automatically regenerates `traceability_matrix.md` and `traceability_matrix.html`
   - Stages updated matrices for commit
   - Only runs when spec/ files change
3. **Requirement Validation** (plugin):
   - Validates requirement format (REQ-{p|o|d}NNNNN)
   - Checks requirement ID uniqueness
   - Verifies "Implements" references exist
   - Detects orphaned requirements
4. **Spec Compliance Validation** (plugin):
   - Validates file naming conventions
   - Enforces audience scope rules (PRD/Ops/Dev)
   - Detects code in PRD files
   - Validates requirement format

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

### Plugin not found warnings

If you see "WARNING: Plugin not found", verify plugins are installed:

```bash
# Check plugins exist
ls -l tools/claude-marketplace/

# Make plugins executable
chmod +x tools/claude-marketplace/*/hooks/*
```

### Validation errors

Plugins call validation scripts from `tools/requirements/`. If validation fails:

1. Read the error message carefully
2. See `spec/requirements-format.md` for format rules
3. Run validation manually to see full output:
   ```bash
   python3 tools/requirements/validate_requirements.py
   ```

### Permission denied

Make sure hooks are executable:
```bash
chmod +x .githooks/pre-commit
chmod +x tools/claude-marketplace/*/hooks/*
```

### Plugin-specific issues

See plugin documentation for detailed troubleshooting:
- `tools/claude-marketplace/spec-compliance/README.md`
- `tools/claude-marketplace/requirement-validation/README.md`
- `tools/claude-marketplace/traceability-matrix/README.md`

## Related Documentation

- **Marketplace Overview**: `tools/claude-marketplace/README.md`
- **Requirement format**: `spec/requirements-format.md`
- **Validation tools**: `tools/requirements/README.md`
- **Project instructions**: `CLAUDE.md`
