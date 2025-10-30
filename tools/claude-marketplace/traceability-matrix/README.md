# Traceability Matrix Plugin for Claude Code

**Version**: 1.0.0
**Type**: Automation Plugin
**Status**: Active

## Overview

The traceability-matrix plugin automatically regenerates traceability matrices whenever spec/ files are modified. This ensures that the traceability documentation always reflects the current state of requirements.

This plugin is a **thin wrapper** that integrates the traceability matrix generator into the git workflow. The actual generation logic is implemented in `tools/requirements/generate_traceability.py`, which can also be run manually or in CI/CD pipelines.

## Features

- ✅ **Automatic regeneration** when spec/ files change
- ✅ **Multiple formats** - Generates both Markdown (.md) and HTML (.html)
- ✅ **Auto-staging** - Updated matrices are automatically staged for commit
- ✅ **Interactive HTML** - Collapsible hierarchy, filtering, search
- ✅ **Comprehensive view** - Shows full requirement tree with relationships
- ✅ **Consistent output** - Same tool used in CI/CD and local development

## Implementation

This plugin references the existing generation script rather than duplicating it:

**Generation Implementation**: `tools/requirements/generate_traceability.py`
**Documentation**: `tools/requirements/README.md`

The hook script simply calls the generation tool from its canonical location, ensuring consistent traceability output across all environments.

## Installation

### Prerequisites

- Python 3.8+
- Git hooks enabled: `git config core.hooksPath .githooks`

### Steps

1. **Verify the plugin is in place**:
   ```bash
   ls tools/claude-marketplace/traceability-matrix/
   ```

2. **Make the hook executable**:
   ```bash
   chmod +x tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix
   ```

3. **Verify main pre-commit hook calls this plugin**:
   ```bash
   grep "traceability-matrix" .githooks/pre-commit
   ```

   Should show:
   ```bash
   tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix
   ```

## Usage

### Automatic (Git Hook)

The plugin runs automatically when you commit changes to spec/ files:

```bash
git add spec/prd-app.md
git commit -m "Add new requirement"

# Output:
# 📊 Regenerating traceability matrices (spec files changed)...
#
# 🔍 Scanning spec/ for requirements...
# 📋 Found 42 requirements
# 📝 Generating MARKDOWN traceability matrix...
# ✅ Traceability matrix written to: traceability_matrix.md
#
# 🔍 Scanning spec/ for requirements...
# 📋 Found 42 requirements
# 📝 Generating HTML traceability matrix...
# ✅ Traceability matrix written to: traceability_matrix.html
#
# ✅ Traceability matrices regenerated
```

The updated matrix files are automatically staged and will be included in your commit.

### Manual Generation

You can generate matrices anytime using the script directly:

```bash
# Generate both formats
python3 tools/requirements/generate_traceability.py --format markdown
python3 tools/requirements/generate_traceability.py --format html

# Or generate both at once
python3 tools/requirements/generate_traceability.py --format both

# CSV format for spreadsheets
python3 tools/requirements/generate_traceability.py --format csv

# Custom output path
python3 tools/requirements/generate_traceability.py --format html --output docs/traceability.html
```

## Generated Output

### Markdown Format (traceability_matrix.md)

- Documentation-friendly text format
- Hierarchical tree structure with indentation
- Status emojis (✅ Active, 🚧 Draft, ⚠️ Deprecated)
- File locations with line numbers
- Orphaned requirement detection

**Example**:
```markdown
# Requirements Traceability Matrix

**Generated**: 2025-10-30 08:45:12
**Total Requirements**: 42

## Summary

- **PRD Requirements**: 15
- **OPS Requirements**: 12
- **DEV Requirements**: 15

## Traceability Tree

- ✅ **REQ-p00001**: Multi-Sponsor Data Isolation
  - Level: PRD | Status: Active
  - File: prd-architecture.md:23
  - ✅ **REQ-o00001**: Separate Supabase Projects
    - Level: OPS | Status: Active
    - File: ops-deployment.md:45
    - ✅ **REQ-d00001**: Sponsor Configuration Loader
      - Level: DEV | Status: Active
      - File: dev-app.md:67
```

### HTML Format (traceability_matrix.html)

- **Interactive web page** with rich features:
  - **Collapsible hierarchy** - Click to expand/collapse requirement trees
  - **Expand All / Collapse All** buttons
  - **Advanced filtering**:
    - Filter by REQ ID
    - Search titles
    - Filter by level (PRD/OPS/DEV)
    - Filter by status (Active/Draft/Deprecated)
    - Filter by topic (extracted from filename)
  - **Color-coded levels**:
    - PRD = Blue
    - OPS = Orange
    - DEV = Green
  - **Status badges** (Active/Draft/Deprecated)
  - **Test coverage indicators** (if test mapping provided)
  - **Professional, responsive design**
  - **Sticky filter header** for easy navigation
  - **Real-time filter statistics**

### CSV Format (traceability_matrix.csv)

- Spreadsheet-compatible format
- All requirement fields in table columns
- Good for reporting and analysis
- Import into Excel or Google Sheets

## How It Works

1. **Detection**: Hook detects when spec/*.md files are staged
2. **Generation**: Calls `tools/requirements/generate_traceability.py` twice (markdown + HTML)
3. **Staging**: Automatically stages the regenerated matrix files
4. **Commit**: Matrix files are included in your commit

This ensures the traceability documentation is always up-to-date with the requirements.

## Configuration

### Formats Generated

By default, the hook generates both Markdown and HTML:

```bash
python3 "$GENERATION_SCRIPT" --format markdown
python3 "$GENERATION_SCRIPT" --format html
```

To modify, edit the hook file:
```bash
tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix
```

### Output Locations

Default output locations (from repository root):
- `traceability_matrix.md`
- `traceability_matrix.html`

To change output locations, modify the hook to use `--output`:
```bash
python3 "$GENERATION_SCRIPT" --format html --output docs/requirements/traceability.html
```

## Troubleshooting

### Hook Not Running

**Problem**: Matrices don't regenerate on commit

**Solutions**:
```bash
# 1. Verify hooks path
git config --get core.hooksPath
# Should output: .githooks

# 2. Verify hook is executable
ls -l tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix
# Should show: -rwxr-xr-x

# 3. Make executable if needed
chmod +x tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix

# 4. Test hook manually
tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix
```

### Generation Script Not Found

**Problem**: Hook reports generation script missing

**Solution**:
```bash
# Verify script exists
ls -l tools/requirements/generate_traceability.py

# If missing, check git status
git status tools/requirements/
```

### Matrices Not Staged

**Problem**: Generated matrices aren't included in commit

**Solution**:
```bash
# Check if matrices are gitignored
git check-ignore traceability_matrix.md traceability_matrix.html

# If they are, remove from .gitignore
# They should be committed to track requirement evolution
```

### Python Version Issues

**Problem**: Script fails with errors

**Solution**:
```bash
# Check Python version (need 3.8+)
python3 --version

# Run script directly to see full error
python3 tools/requirements/generate_traceability.py --format markdown
```

## Disabling the Hook

If you need to temporarily disable automatic regeneration:

```bash
# Option 1: Bypass for single commit
git commit --no-verify -m "Draft requirements"

# Option 2: Temporarily move the hook
mv tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix \
   tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix.disabled

# Re-enable later
mv tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix.disabled \
   tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix
```

## Integration with CI/CD

This plugin and CI/CD can both use the same generation script, though CI/CD might only generate for archival:

**CI/CD Example** (GitHub Actions):
```yaml
- name: Generate Traceability Matrix
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  run: python3 tools/requirements/generate_traceability.py --format both

- name: Upload Matrix Artifacts
  uses: actions/upload-artifact@v3
  with:
    name: traceability-matrix
    path: |
      traceability_matrix.html
      traceability_matrix.md
```

## Benefits

- **Always up-to-date** - Matrices regenerate automatically on requirement changes
- **No manual work** - Developers don't need to remember to regenerate
- **Consistent output** - Same tool used everywhere (local + CI/CD)
- **Rich visualization** - Interactive HTML for requirement exploration
- **Audit trail** - Matrices are version-controlled with requirements
- **Multiple formats** - Markdown for docs, HTML for viewing, CSV for analysis

## Related Documentation

- **Implementation**: `tools/requirements/README.md`
- **Generation Script**: `tools/requirements/generate_traceability.py`
- **Requirement Format**: `spec/requirements-format.md`
- **Git Hooks**: `.githooks/README.md`
- **Project Instructions**: `CLAUDE.md`

## Plugin Metadata

- **Plugin Name**: traceability-matrix
- **Version**: 1.0.0
- **Hook File**: `hooks/pre-commit-traceability-matrix`
- **Implementation**: `tools/requirements/generate_traceability.py` (shared with CI/CD)
- **Dependencies**: Python 3.8+

## Changelog

### v1.0.0 (2025-10-30)

- Initial release
- Extracted from monolithic `.githooks/pre-commit`
- References existing generation script (no duplication)
- Generates both Markdown and HTML formats
- Automatic staging of regenerated matrices
- Full documentation and plugin metadata

## License

Part of the diary project. See project LICENSE for details.
