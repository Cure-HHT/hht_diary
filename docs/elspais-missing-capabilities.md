# Elspais Missing Capabilities Report

**Created**: 2026-01-01
**Updated**: 2026-01-05
**Context**: CUR-514 - Migration from local `tools/requirements/` scripts to elspais CLI
**elspais Version**: 0.9.3

## Overview

During the migration to elspais, several local script capabilities were identified that have no equivalent in elspais. These scripts remain in `tools/requirements/` and should be considered for future elspais enhancement or retained as specialized tools.

---

## 1. Sponsor-Specific Traceability

**Local Script**: `tools/requirements/generate_traceability.py`
**elspais Command**: `elspais trace`

### Gap Description

The local `generate_traceability.py` script supports multi-sponsor projects with:
- `--mode` flag: `core`, `sponsor`, `combined`
- `--sponsor` flag: Specify sponsor name (e.g., `callisto`, `titan`)
- Sponsor directory filtering: Includes `sponsor/{name}/` only for matching sponsor
- Sponsor-specific REQ ID format: `REQ-{SPONSOR}-{p|o|d}NNNNN`

**elspais limitation**: The `elspais trace` command only supports:
- `--format` (markdown, html, csv, both)
- `--output` (output path)

No mode-based or sponsor-based filtering is available.

### Impact

- **build-test.yml**: Still uses local script for sponsor-specific traceability
- CI/CD workflows cannot generate sponsor-isolated traceability matrices with elspais

### Recommendation

Add `--mode` and `--sponsor` options to `elspais trace` command:
```bash
elspais trace --mode sponsor --sponsor callisto
elspais trace --mode combined
```

---

## 2. Hierarchy Analysis with Parent Proposals

**Local Script**: `tools/requirements/analyze_hierarchy.py`
**elspais Command**: `elspais analyze hierarchy`

### Gap Description

The local script provides capabilities not in elspais:

| Feature | analyze_hierarchy.py | elspais analyze | Gap |
| --- | --- | --- | --- |
| Domain classification | Yes (keyword-based) | No | **MISSING** |
| Parent proposal with confidence | Yes (HIGH/MEDIUM/LOW) | No | **MISSING** |
| JSON output format | Yes (`--json`) | No | **MISSING** |
| Edit commands generation | Yes (`--edits`) | No | **MISSING** |
| Hardcoded hierarchy validation | Yes (`HIERARCHY_STRUCTURE`) | No | **MISSING** |
| Markdown report output | Yes (`--report`) | No | **MISSING** |
| PRD orphan focus | Yes | Skips PRD orphans | Different scope |

### Domain Classification Categories

The local script classifies requirements into:
- mobile_app, portal, database, security, compliance, infrastructure, operations, requirements_tooling

### Impact

- Cannot auto-propose parent assignments for orphaned requirements
- No machine-readable output for CI/automation pipelines
- No automated edit command generation for bulk fixes

### Recommendation

Add to elspais:
1. `elspais analyze propose` - Domain classification and parent proposals
2. `--format json` option for all analyze subcommands
3. `--edits` option for edit command JSON generation

Or retain `analyze_hierarchy.py` as a specialized one-time cleanup tool.

---

## 3. Hierarchy Change Application

**Local Script**: `tools/requirements/apply_hierarchy_changes.py`
**elspais Command**: None

### Gap Description

This script applies hierarchy changes to spec files by modifying `**Implements**:` fields. It:
- Reads proposals from `analyze_hierarchy.py` (JSON format)
- Groups changes by file for batch processing
- Updates `Implements` field using regex pattern matching
- Supports `--dry-run` mode
- Handles ADD_IMPLEMENTS, UPDATE_IMPLEMENTS, REMOVE_IMPLEMENTS actions

### Impact

- No automated way to restructure requirement hierarchy
- Manual edits required for each parent-child relationship fix
- No integration with elspais validation workflow

### Recommendation

Either:
1. Add `elspais fix hierarchy` command to apply proposals
2. Add to anspar-cc-plugins as `/simple-requirements:apply-hierarchy`
3. Retain as specialized restructuring tool

---

## 4. Requirement Relocation

**Local Script**: `tools/requirements/move_reqs.py`
**elspais Command**: None

### Gap Description

This script moves requirements between spec files:
- Two-phase extraction then insertion
- Batch processing via JSON input
- Intelligent insertion before `## References` section
- Auto-creates target files with proper headers
- Dry-run mode support

**Input Format**:
```json
[{"reqId": "d00001", "source": "dev-app.md", "target": "roadmap/dev-app.md"}]
```

### Impact

- Cannot relocate requirements using elspais
- Manual cut-paste required for reorganization
- No audit trail for requirement moves

### Recommendation

Either:
1. Add `elspais move` command
2. Add to anspar-cc-plugins as `/simple-requirements:move`
3. Retain as specialized reorganization tool

---

## 5. Test Mapping and Coverage

**Local Script**: `tools/requirements/generate_traceability.py` (removed `--test-mapping`)
**elspais Command**: `elspais validate --json` (proposed extension)

### Gap Description

The local script previously supported loading test mapping data from a JSON file to display test coverage per requirement. This has been removed in favor of having elspais provide test data directly.

### Proposed Feature

Extend `elspais validate --json` output to include test data for each requirement:

**Per-Requirement Fields**:
```json
{
  "REQ-d00004": {
    "title": "...",
    "status": "Active",
    ... existing fields ...

    "test_count": 5,
    "test_passed": 4,
    "test_result_files": [
      "build-reports/flutter_test/TEST-calendar_screen_test.xml",
      "build-reports/flutter_test/TEST-recording_screen_test.xml"
    ]
  }
}
```

**Command Line Options**:
```bash
elspais validate --json              # Includes test data if [testing] configured
elspais validate --json --no-tests   # Skip test scanning
elspais validate --json --tests      # Force test scanning even if disabled
```

**Configuration Section** (for `.elspais.toml`):
```toml
[testing]
enabled = true

# Test file scanning
test_dirs = ["apps/**/test", "packages/**/test", "tools/**/tests"]
patterns = ["*_test.dart", "test_*.py", "*_test.sql"]

# Test result files to parse for pass/fail counts
result_files = [
    "build-reports/**/TEST-*.xml",
    "build-reports/pytest-results.json"
]
```

### Impact

- `generate_traceability.py` already updated to read test fields from elspais output
- Test badges (✅/❌/⚡) will display when elspais provides the data
- No functional test coverage until elspais implements this feature

### Status

**FEATURE REQUEST** - Pending implementation in elspais

---

## Migration Status Summary

| Capability | Local Script | elspais Equivalent | Status |
| --- | --- | --- | --- |
| Requirement validation | validate_requirements.py | `elspais validate` | MIGRATED |
| INDEX.md validation | validate_index.py | `elspais index validate` | MIGRATED |
| INDEX.md regeneration | regenerate-index.py | `elspais index regenerate` | MIGRATED |
| Hash updates | update-REQ-hashes.py | `elspais hash update` | MIGRATED |
| Core traceability | generate_traceability.py | `elspais trace` | MIGRATED |
| Sponsor traceability | generate_traceability.py --mode sponsor | None | **BLOCKED** |
| Hierarchy analysis | analyze_hierarchy.py | Partial (`elspais analyze`) | **PARTIAL** |
| Hierarchy application | apply_hierarchy_changes.py | None | **BLOCKED** |
| Requirement moves | move_reqs.py | None | **BLOCKED** |
| Test mapping | generate_traceability.py --test-mapping | None | **FEATURE REQUEST** |

---

## Action Items

1. **File issue in elspais repo**: Request sponsor-specific traceability support
2. **File issue in elspais repo**: Request JSON output for analyze commands
3. **File issue in elspais repo**: Request test mapping support (test_count, test_passed, test_result_files)
4. **Decision needed**: Should hierarchy tools move to elspais or remain local?
5. **Decision needed**: Should move_reqs.py become a plugin command?

---

## References

- Ticket: CUR-514
- elspais repo: ~/elspais
- Local scripts: tools/requirements/
- Plugin location: tools/anspar-cc-plugins/plugins/simple-requirements/
