# Requirements Traceability Tools

Tools for validating and tracking requirements across PRD, Operations, and Development specifications.

> **Primary Tool**: The `elspais` CLI is the primary tool for requirement validation and traceability.
> Local scripts in this directory provide supplementary features (domain analysis, test mapping).
> See `.githooks/README.md` for hook configuration.

## Prerequisites

- **elspais CLI**: Install with `pip install elspais` (version pinned in `.github/versions.env`)
- **Python 3.11+**: Required for supplementary scripts

See also:
- [Development Prerequisites](../../docs/development-prerequisites.md)
- [Git Hooks Setup](../../docs/git-hooks-setup.md)

For requirement format details, see [spec/README.md](../../spec/README.md).

## elspais CLI (Primary)

The `elspais` CLI handles core requirement operations. Configuration is in `.elspais.toml`.

### Validation

```bash
# Validate all requirements
elspais validate

# Output as JSON (for programmatic use)
elspais validate --json
```

**Checks:**
- Unique requirement IDs
- Proper format compliance (`REQ-[pod]NNNNN`)
- Valid "Implements" links exist
- Level prefix matches stated level
- Consistent status values
- Hash verification

### Traceability Matrix

```bash
# Generate both markdown and HTML
elspais trace --format both

# Generate specific format
elspais trace --format html --output docs/traceability.html
```

**Output formats:**
- **Markdown**: Documentation-friendly hierarchical tree
- **HTML**: Interactive collapsible tree with color-coding
- **CSV**: Import into spreadsheets

### INDEX.md Management

```bash
# Validate INDEX.md accuracy
elspais index validate

# Regenerate INDEX.md from scratch
elspais index regenerate
```

### Hash Management

```bash
# Verify requirement hashes
elspais hash verify

# Update stale hashes
elspais hash update
```

### Editing Requirements

```bash
# Change implements field
elspais edit --req-id REQ-d00027 --implements "d00014,p00020"

# Change status
elspais edit --req-id REQ-d00027 --status Deprecated

# Move to different file
elspais edit --req-id REQ-d00027 --move-to dev-new-file.md

# Batch edit from JSON
elspais edit --from-json changes.json

# Preview without applying
elspais edit --from-json changes.json --dry-run
```

### Hierarchy Analysis

```bash
# Show requirement hierarchy tree
elspais analyze hierarchy

# Find orphaned requirements
elspais analyze orphans

# Implementation coverage report
elspais analyze coverage
```

## Local Scripts (Supplementary)

These scripts provide features beyond elspais core functionality.

### generate_traceability.py

Extended traceability with test coverage integration and HTML edit mode.

```bash
# Basic usage (same as elspais trace)
python3 tools/requirements/generate_traceability.py --format both

# With test mapping data
python3 tools/requirements/generate_traceability.py --test-mapping build-reports/test_mapping.json

# Embed full content for offline viewing
python3 tools/requirements/generate_traceability.py --format html --embed-content

# Enable edit mode UI
python3 tools/requirements/generate_traceability.py --format html --edit-mode

# Generate planning CSV
python3 tools/requirements/generate_traceability.py --export-planning

# Coverage statistics
python3 tools/requirements/generate_traceability.py --coverage-report
```

### analyze_hierarchy.py

Domain classification and parent proposal for orphaned PRD requirements.

```bash
# Generate analysis report
python3 tools/requirements/analyze_hierarchy.py --report

# Output proposals as JSON
python3 tools/requirements/analyze_hierarchy.py --json

# Output for elspais edit --from-json
python3 tools/requirements/analyze_hierarchy.py --elspais

# Apply changes via elspais
python3 tools/requirements/analyze_hierarchy.py --apply

# Preview without applying
python3 tools/requirements/analyze_hierarchy.py --dry-run
```

## CI/CD Integration

See [CI/CD Setup Guide](../../docs/cicd-setup-guide.md).

### GitHub Actions

```yaml
name: Validate Requirements

on:
  pull_request:
    paths:
      - 'spec/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install elspais
        run: pip install elspais==${{ env.ELSPAIS_VERSION }}

      - name: Validate Requirements
        run: elspais validate

      - name: Generate Traceability Matrix
        run: elspais trace --format both
```

### Git Hooks

Pre-push hook runs:
```bash
elspais validate
elspais index validate
```

See `.githooks/README.md` for setup: `git config core.hooksPath .githooks`

## Usage in Development Workflow

### Adding New Requirements

1. Create requirement in spec file following format in `spec/requirements-format.md`
2. Run `elspais validate` to check format
3. Run `elspais index regenerate` to update INDEX.md
4. Run `elspais hash update` if hash is missing

### Referencing Requirements in Code

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00001: Sponsor Configuration Loading
final config = SupabaseConfig.fromEnvironment();
```

### Commit Messages

```
[CUR-123] Add multi-sponsor database isolation

Implements: REQ-p00001, REQ-o00001, REQ-d00001
```

## Troubleshooting

### elspais not found

Install: `pip install elspais`

### Validation errors

Run `elspais validate` and follow error messages with file:line references.

### Stale hashes

Run `elspais hash update` to recalculate requirement hashes.

### INDEX.md out of sync

Run `elspais index regenerate` to rebuild from scratch.

## Dependencies

- **elspais**: Primary CLI tool (version in `.github/versions.env`)
- **Python 3.11+**: For supplementary scripts (standard library only)

## License

Same as project.
