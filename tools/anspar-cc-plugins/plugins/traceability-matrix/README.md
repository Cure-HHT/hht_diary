# Anspar Traceability Matrix

**Claude Code Plugin for Automatic Traceability Matrix Generation**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python Version](https://img.shields.io/badge/python-%3E%3D3.8-brightgreen)](https://www.python.org/)

## Overview

The Anspar Traceability Matrix plugin auto-regenerates requirement traceability matrices whenever spec/ files change. It ensures traceability matrices are always up-to-date with the latest requirements.

This plugin provides the **git hook integration** for the matrix generation script located at `tools/requirements/generate_traceability.py` (shared with CI/CD).

**Key Features**:
- ✅ Automatic matrix regeneration on spec/ changes
- ✅ Git pre-commit hook integration
- ✅ Markdown and HTML output formats
- ✅ Requirement hierarchy visualization
- ✅ Implementation tracking (requirements → code)

## Installation

### As Claude Code Plugin

1. Clone or copy this directory to your Claude Code plugins location
2. The plugin will be automatically discovered by Claude Code
3. Configure git hooks (see below)

### Prerequisites

- **Python**: >=3.8
- **Git**: For hook integration
- **Bash**: >=4.0
- **Generation Script**: `tools/requirements/generate_traceability.py` must exist in parent project

See the following guides for setup requirements:
- [Development Prerequisites](../../../../docs/development-prerequisites.md) - Required tools (jq, yq)
- [Git Hooks Setup](../../../../docs/git-hooks-setup.md) - Configuring hooks for automatic matrix generation
- [CI/CD Setup Guide](../../../../docs/cicd-setup-guide.md) - GitHub Actions integration

## Setup

### 1. Configure Git Hooks

Enable custom git hooks if not already configured:

```bash
# From repository root
git config core.hooksPath .githooks
```

### 2. Integrate with Pre-Commit Hook

Add the traceability-matrix hook to your main pre-commit hook at `.githooks/pre-commit`:

```bash
# Traceability Matrix Regeneration (Plugin)
TRACEABILITY_HOOK="tools/anspar-cc-plugins/plugins/traceability-matrix/hooks/pre-commit-traceability-matrix"
if [ -f "$TRACEABILITY_HOOK" ]; then
    "$TRACEABILITY_HOOK" || exit 1
fi
```

### 3. Verify Installation

```bash
# Test with a spec file change
git add spec/prd-app.md
git commit -m "test" --dry-run

# Check that matrix was regenerated
ls -l traceability_matrix.md traceability_matrix.html
```

## How It Works

### Reference Architecture

This plugin is a **thin wrapper** that calls the shared generation script:

```
traceability-matrix/
└── hooks/
    └── pre-commit-traceability-matrix  ← Git hook (this plugin)
                 |
                 v
        tools/requirements/
        └── generate_traceability.py    ← Shared script (CI/CD compatible)
                 |
                 v
        traceability_matrix.md          ← Generated output (gitignored)
        traceability_matrix.html
```

**Why this architecture?**
- ✅ Single source of truth for generation logic
- ✅ CI/CD and git hooks use the same script
- ✅ Updates automatically apply everywhere
- ✅ No code duplication

### Generation Flow

1. **Git commit triggered** with spec/ changes
2. **Hook detects** spec/*.md files in staging area
3. **Python script runs** to generate traceability matrices
4. **Matrices updated** (markdown and HTML formats)
5. **Matrices added to commit** automatically

### What Gets Generated

**Markdown Matrix** (`traceability_matrix.md`):
- Requirement hierarchy (PRD → Ops → Dev)
- Parent-child relationships
- Implementation status
- File locations

**HTML Matrix** (`traceability_matrix.html`):
- Interactive web view
- Collapsible sections
- Styled for readability
- Printable format

## Usage

### Automatic Generation (Recommended)

The plugin runs automatically when you commit changes to spec/ files:

```bash
# Normal workflow - matrix regenerates automatically
git add spec/dev-api.md
git commit -m "Add API requirements"

# Output:
# ✅ Regenerating traceability matrix...
# ✅ Generated traceability_matrix.md
# ✅ Generated traceability_matrix.html
# ✅ Added matrices to commit
```

### Manual Generation

Run the generation script directly:

```bash
# From repository root
python3 tools/requirements/generate_traceability.py --format markdown
python3 tools/requirements/generate_traceability.py --format html

# Or generate both
python3 tools/requirements/generate_traceability.py --format markdown --format html
```

### Viewing Matrices

**Markdown**:
```bash
# View in terminal
cat traceability_matrix.md

# Or open in editor
code traceability_matrix.md
```

**HTML**:
```bash
# Open in browser
xdg-open traceability_matrix.html   # Linux
open traceability_matrix.html       # macOS
start traceability_matrix.html      # Windows
```

## Matrix Contents

### Requirement Hierarchy

The matrix shows all requirements organized by level:

```markdown
## PRD Requirements
### REQ-p00042: User Authentication
**Implements**: -
**Status**: Active
**File**: spec/prd-app.md:42

#### Implemented By:
- REQ-o00015: Authentication Deployment (spec/ops-deployment.md:73)
- REQ-d00089: OAuth2 Implementation (spec/dev-security-RBAC.md:25)
```

### Implementation Tracking

Shows which requirements are implemented by code:

```markdown
### REQ-d00089: OAuth2 Implementation
**Implements**: REQ-o00015
**Status**: Active
**File**: spec/dev-security-RBAC.md:25

#### Implemented In Code:
- packages/security/lib/oauth2.dart:15
- database/auth/auth_schema.sql:42
```

### Coverage Analysis

Summary statistics:

```markdown
## Coverage Summary
- Total Requirements: 112
- PRD Requirements: 42
- Ops Requirements: 35
- Dev Requirements: 35
- Orphaned Requirements: 9 (no implementations)
- Implemented in Code: 78 (70%)
```

## Configuration

### Generation Options

To modify generation options, edit:
- **Location**: `tools/requirements/generate_traceability.py`
- **Shared with**: CI/CD pipeline
- **Options**: Output format, filters, styling

### Hook Behavior

To customize hook behavior, edit:
- **Location**: `hooks/pre-commit-traceability-matrix`
- **Customize**: When to trigger, what formats to generate

### Output Location

By default, matrices are generated at repository root:
- `traceability_matrix.md`
- `traceability_matrix.html`

These files are **gitignored** and regenerated on every commit.

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
chmod +x tools/anspar-cc-plugins/plugins/traceability-matrix/hooks/pre-commit-traceability-matrix
```

### Python Script Not Found

**Cause**: Generation script missing or wrong path

**Solution**:
```bash
# Verify script exists
ls -l tools/requirements/generate_traceability.py

# If missing, check if it was moved or renamed
find . -name "generate_traceability.py"
```

### Matrices Not Updated

**Cause**: Script ran but matrices look old

**Solution**:
```bash
# Delete old matrices
rm traceability_matrix.md traceability_matrix.html

# Regenerate manually
python3 tools/requirements/generate_traceability.py --format markdown --format html

# Verify they're current
ls -l traceability_matrix.*
```

### HTML Matrix Not Displaying Correctly

**Cause**: HTML may need specific browser or styling

**Solution**:
1. Open in modern browser (Chrome, Firefox, Edge)
2. Check browser console for errors
3. Regenerate with updated script

## Integration

### With Other Plugins

This plugin works alongside:
- **simple-requirements**: Validates requirements before matrix generation
- **spec-compliance**: Enforces spec/ directory compliance
- **linear-api**: Creates Linear tickets from requirements

### With CI/CD

This plugin uses the **same generation script** as CI/CD:

**Git Hook** (local):
```bash
python3 tools/requirements/generate_traceability.py --format markdown
```

**CI Pipeline** (GitHub Actions):
```yaml
- name: Generate Traceability Matrix
  run: python3 tools/requirements/generate_traceability.py --format html

- name: Publish Matrix
  uses: actions/upload-artifact@v3
  with:
    name: traceability-matrix
    path: traceability_matrix.html
```

**Benefits**:
- Same generation logic everywhere
- Matrices always up to date locally
- CI can publish matrices for review

## Advanced Usage

### Custom Output Paths

```bash
python3 tools/requirements/generate_traceability.py \
  --format markdown \
  --output docs/traceability.md
```

### Filtering Requirements

```bash
# Only PRD requirements
python3 tools/requirements/generate_traceability.py --level PRD

# Only Active requirements
python3 tools/requirements/generate_traceability.py --status Active
```

### Scripting

```bash
# Generate and commit matrices in one step
python3 tools/requirements/generate_traceability.py --format markdown --format html
git add traceability_matrix.*
git commit -m "Update traceability matrices"
```

## Dependencies

- **Python**: >=3.8
- **Bash**: >=4.0
- **Git**: For hook integration
- **Generation Script**: `tools/requirements/generate_traceability.py`

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
- **Generation Script**: `tools/requirements/generate_traceability.py`
- **Requirement Validation**: `tools/anspar-cc-plugins/plugins/simple-requirements`
- **Claude Code Plugins**: https://docs.claude.com/en/docs/claude-code/plugins-reference

## Support

For issues, questions, or contributions:
- **Repository**: https://github.com/anspar/diary
- **Plugin Path**: `tools/anspar-cc-plugins/plugins/traceability-matrix`
