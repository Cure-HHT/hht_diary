# Requirements Traceability Tools

Tools for validating and tracking requirements across PRD, Operations, and Development specifications.

> **Git Hook Integration**: These tools are automatically run via git hooks through the
> simple-requirements and traceability-matrix plugins in `tools/anspar-cc-plugins/plugins/`.
> See `.githooks/README.md` for hook configuration.

## Prerequisites

See the following guides:
- [Development Prerequisites](../../docs/development-prerequisites.md) - Installing Python, jq, and other required tools
- [Git Hooks Setup](../../docs/git-hooks-setup.md) - Configuring requirement validation hooks

For requirement format details, see [spec/README.md](../../spec/README.md) (single source of truth).

## Overview

This directory contains Python scripts that:
- Validate requirement format and consistency
- Generate traceability matrices showing requirement relationships
- Check for broken links and orphaned requirements
- Provide visibility into implementation coverage

## Tools

### 1. validate_requirements.py

Validates all requirements in the `spec/` directory.

**Usage:**
```bash
python3 tools/requirements/validate_requirements.py
```

**Checks:**
- ✅ Unique requirement IDs
- ✅ Proper format compliance (`[pod]NNNNN`)
- ✅ Valid "Implements" links exist
- ✅ Level prefix matches stated level
- ✅ Consistent status values
- ⚠️ Orphaned requirements (no children)
- ⚠️ Hierarchy consistency (PRD → Ops → Dev)

**Exit codes:**
- `0`: All requirements valid
- `1`: Validation errors found

**Example output:**
```
🔍 Scanning /path/to/spec for requirements...

📋 Found 6 requirements

======================================================================

✅ ALL REQUIREMENTS VALID

📊 SUMMARY:
  Total requirements: 6
  By level: PRD=2, Ops=2, Dev=2
  By status: Active=6, Draft=0, Deprecated=0
======================================================================
```

### 2. generate_traceability.py

Generates traceability matrix showing requirement relationships.

**Usage:**
```bash
# Markdown format (default)
python3 tools/requirements/generate_traceability.py

# HTML format (interactive with collapsible hierarchy)
python3 tools/requirements/generate_traceability.py --format html

# Generate BOTH markdown and HTML (recommended!)
python3 tools/requirements/generate_traceability.py --format both

# CSV format (for spreadsheets)
python3 tools/requirements/generate_traceability.py --format csv

# Custom output path
python3 tools/requirements/generate_traceability.py --format html --output docs/traceability.html
```

**Output formats:**

**Markdown** (`traceability_matrix.md`):
- Documentation-friendly format
- Shows hierarchical tree structure
- Includes summary statistics
- Identifies orphaned requirements

**HTML** (`traceability_matrix.html`) - **ENHANCED with collapsible hierarchy!**:
- Interactive web page with **collapsible requirement tree**
- **Click to expand/collapse** individual requirements
- **Expand All / Collapse All** buttons for convenience
- Color-coded by level (PRD=blue, Ops=orange, Dev=green)
- Status badges (Active/Draft/Deprecated)
- Professional, responsive design
- Generated from markdown source for consistency
- Can be hosted or shared

**CSV** (`traceability_matrix.csv`):
- Import into Excel, Google Sheets
- All requirement fields in table format
- Good for reporting and filtering

## CI/CD Integration

See [CI/CD Setup Guide](../../docs/cicd-setup-guide.md) for comprehensive GitHub Actions integration examples.

### GitHub Actions

Add to `.github/workflows/validate.yml`:

```yaml
name: Validate Requirements

on:
  pull_request:
    paths:
      - 'spec/**'
  push:
    branches:
      - main

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'

      - name: Validate Requirements
        run: python3 tools/requirements/validate_requirements.py

      - name: Generate Traceability Matrix
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: python3 tools/requirements/generate_traceability.py --format both

      - name: Upload Traceability Matrix
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: actions/upload-artifact@v3
        with:
          name: traceability-matrix
          path: |
            traceability_matrix.html
            traceability_matrix.md
```

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Validate requirements before commit

if git diff --cached --name-only | grep -q "^spec/.*\.md$"; then
    echo "Validating requirements..."
    python3 tools/requirements/validate_requirements.py
    if [ $? -ne 0 ]; then
        echo "❌ Requirement validation failed. Commit aborted."
        exit 1
    fi
fi
```

## Usage in Development Workflow

### Adding New Requirements

1. **Create requirement in spec file:**
```markdown
### REQ-p00003: Data Retention Policies

**Level**: PRD | **Implements**: - | **Status**: Draft

The system SHALL retain clinical trial data for minimum 25 years...

**Rationale**: FDA requirement for clinical trial data retention.

**Acceptance Criteria**:
- Data retained for 25+ years
- Archival storage available
- Data retrievable on demand

**Traced by**: -
```

2. **Validate format:**
```bash
python3 tools/requirements/validate_requirements.py
```

3. **Add implementing requirements at lower levels**

4. **Regenerate traceability matrix:**
```bash
python3 tools/requirements/generate_traceability.py --format both
```

This generates both `traceability_matrix.md` (for documentation) and `traceability_matrix.html` (for interactive viewing).

### Referencing Requirements

**In code comments:**
```dart
// REQ-d00001: Load sponsor-specific configuration
final config = SupabaseConfig.fromEnvironment();
```

**In commit messages:**
```
[p00001] Add multi-sponsor database isolation

Implements REQ-p00001 by creating separate Supabase projects.
Also addresses REQ-o00001, REQ-o00002.
```

**In pull requests:**
```markdown
## Requirements
- REQ-p00001: Multi-Sponsor Data Isolation
- REQ-o00001: Separate Supabase Projects

## Changes
...
```

**In GitHub issues:**
```markdown
**Requirements**: p00001, o00001, d00001

Implement database isolation per requirements above.
```

## Requirements Format

See `spec/requirements-format.md` for full format specification.

**Quick reference:**

```markdown
### REQ-{id}: {informal-title}

**Level**: {PRD|Ops|Dev} | **Implements**: {parent-ids} | **Status**: {Active|Draft|Deprecated}

{requirement-body-using-SHALL/MUST-language}

**Rationale**: {why-this-exists}

**Acceptance Criteria**:
- {testable-criterion-1}
- {testable-criterion-2}
```

**Note**: Child requirements are automatically discovered by tools. No manual "Traced by" field needed.

## Troubleshooting

### No requirements found

**Cause**: No files match the requirement pattern.

**Solution**: Ensure requirements follow the format exactly:
- Header: `### REQ-p00001: Title`
- Metadata line immediately after header
- All required fields present

### Duplicate requirement ID

**Cause**: Same ID used twice.

**Solution**: Each requirement must have unique ID. Check both files mentioned in error.

### Invalid ID format

**Cause**: ID doesn't match `[pod]NNNNN` pattern.

**Solution**: Use correct format:
- `p00001` to `p99999` for PRD
- `o00001` to `o99999` for Ops
- `d00001` to `d99999` for Dev

### Missing parent requirement

**Cause**: "Implements" references non-existent requirement.

**Solution**: Ensure parent requirement exists or use `-` for top-level requirements.

### Level mismatch

**Cause**: ID prefix doesn't match stated level.

**Solution**: If ID is `p00001`, level must be `PRD`. If `o00001`, level must be `Ops`. If `d00001`, level must be `Dev`.

## Dependencies

- Python 3.8+
- No external dependencies (uses only Python standard library)

## License

Same as project.
