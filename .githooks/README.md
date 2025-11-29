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

### pre-push

**Purpose**: Runs validation scripts before push with PR-aware blocking.

**What it does**:
1. **PR Detection**: Uses `gh` CLI to check if the current branch has an open PR
2. **Requirement Validation**:
   - Runs `validate_requirements.py` (requirement format, links, hashes)
   - Runs `validate_index.py` (INDEX.md accuracy and completeness)
3. **Markdown Linting**: Runs `markdownlint` on changed `.md` files
4. **Secret Detection**: Runs `gitleaks` to detect accidentally committed secrets
5. **Plugin Hooks**: Auto-discovers and runs pre-push hooks from installed plugins

**Blocking Behavior**:
- **Branch WITH open PR**: Validation failures **BLOCK** the push
- **Branch WITHOUT PR**: Validation failures show **warnings only** (push allowed)

**Rationale**: PR branches must pass validation because they represent code ready for review. Regular feature branches can push with warnings to allow work-in-progress commits.

**When it runs**: Automatically before every `git push`

**How to bypass** (NOT RECOMMENDED for PR branches):
```bash
git push --no-verify
```

**Requirements**:
- `gh` CLI for PR detection: https://cli.github.com/
- `jq` for JSON parsing (used with gh CLI)
- Python 3.8+ for validation scripts
- `markdownlint` for markdown linting: `npm install -g markdownlint-cli`
- `gitleaks` for secret detection: https://github.com/gitleaks/gitleaks#installing

---

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

### Pre-push blocking unexpectedly

If pre-push is blocking your push and you don't think there's a PR:

1. Check PR status manually:
   ```bash
   gh pr view --json state,url
   ```

2. If gh CLI can't authenticate:
   ```bash
   gh auth login
   ```

3. If you need to push work-in-progress to a PR branch:
   ```bash
   git push --no-verify  # Use with caution!
   ```

### Permission denied

Make sure hooks are executable:
```bash
chmod +x .githooks/pre-commit
chmod +x .githooks/pre-push
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
