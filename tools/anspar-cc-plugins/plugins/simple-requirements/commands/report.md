---
name: report
description: Generate requirement compliance/coverage reports
arguments: "[--type=summary|coverage|status] [--format=markdown|html|json]"
---

# /requirements:report Command

Generate comprehensive requirement compliance and coverage reports for FDA traceability.

## Purpose

The `/requirements:report` command provides visibility by:
- Generating requirement coverage reports
- Showing implementation status
- Identifying compliance gaps
- Supporting multiple output formats
- Enabling audit trail documentation

## Usage

```bash
/requirements:report                           # Generate summary report
/requirements:report --type=coverage           # Coverage analysis
/requirements:report --type=status             # Implementation status
/requirements:report --format=html             # HTML output
/requirements:report --type=summary --format=json  # JSON summary
```

## Arguments

### `--type=<TYPE>` *(optional)*

Report type:
- `summary` (default): High-level overview
- `coverage`: Detailed coverage analysis
- `status`: Implementation status by requirement
- Example: `--type=coverage`

### `--format=<FORMAT>` *(optional)*

Output format:
- `markdown` (default): Markdown formatted
- `html`: HTML with styling
- `json`: Machine-readable JSON
- Example: `--format=html`

### `--req-ids=<IDS>` *(optional)*

Filter by specific requirement IDs:
- Comma-separated list
- Example: `--req-ids=d00027,d00028,p00042`

### `--from-tracking` *(optional)*

Generate report from outdated requirements tracking file:
- Reads `untracked-notes/outdated-implementations.json`
- Focuses on requirements needing verification
- Example: `--from-tracking`

## Behavior

### Report Types

**Summary Report**:
- Total requirements count (by level: PRD/Ops/Dev)
- Implementation status distribution
- Coverage percentage
- Top compliance issues
- Recent changes

**Coverage Report**:
- Requirement-to-ticket mappings
- Tickets per requirement
- Implementation file references
- Test coverage status
- Documentation completeness

**Status Report**:
- Requirement by requirement status
- Implementation files
- Test files
- Verification tickets
- Hash status (current/outdated)

### Data Sources

- `spec/INDEX.md` - Requirement definitions
- `.requirement-cache.json` - Ticket mappings
- `untracked-notes/outdated-implementations.json` - Outdated requirements
- Implementation files - Direct file scans
- Test files - Test coverage analysis

## Examples

### Summary Report (Default)

```bash
/requirements:report

# Output:
# ════════════════════════════════════════════════════════════
# Requirement Compliance Summary Report
# Generated: 2025-11-19 14:30:00 UTC
# ════════════════════════════════════════════════════════════
#
# ## Overview
#
# Total Requirements: 75
# - PRD (Product):     28
# - Ops (Operations):  15
# - Dev (Development): 32
#
# ## Implementation Status
#
# ✅ Implemented:           52 (69%)
# 🔄 In Progress:           15 (20%)
# 📋 Not Started:            5 (7%)
# ⚠️  Needs Verification:    3 (4%)
#
# ## Coverage Analysis
#
# Requirements with Tickets:     68 (91%)
# Requirements with Tests:       45 (60%)
# Requirements Documented:       75 (100%)
#
# ## Top Issues
#
# 1. 3 requirements need reverification (hash changed)
# 2. 5 requirements have no associated tickets
# 3. 30 requirements lack test coverage
#
# ## Recent Changes (Last 7 Days)
#
# - REQ-d00027: Hash updated (workflow plugin changes)
# - REQ-p00042: Implementation completed
# - REQ-o00015: Verification ticket created
```

### Coverage Report

```bash
/requirements:report --type=coverage

# Output:
# ════════════════════════════════════════════════════════════
# Requirement Coverage Report
# ════════════════════════════════════════════════════════════
#
# ## PRD Requirements (28 total)
#
# REQ-p00001: Multi-sponsor authentication
#   Tickets: CUR-123, CUR-145
#   Implementation: packages/auth/lib/multi_sponsor.dart
#   Tests: packages/auth/test/multi_sponsor_test.dart ✅
#   Documentation: spec/prd-authentication.md ✅
#   Status: Implemented ✅
#
# REQ-p00042: Multi-factor authentication via TOTP
#   Tickets: CUR-240, CUR-241, CUR-242
#   Implementation: packages/auth/lib/mfa/totp.dart
#   Tests: packages/auth/test/mfa/totp_test.dart ✅
#   Documentation: spec/prd-authentication.md ✅
#   Status: In Progress 🔄
#
# ...
#
# ## Ops Requirements (15 total)
#
# REQ-o00015: Database backup automation
#   Tickets: None ❌
#   Implementation: tools/ops/backup.sh
#   Tests: None ❌
#   Documentation: spec/ops-deployment.md ✅
#   Status: Needs Ticket 📋
#
# ...
#
# ## Dev Requirements (32 total)
#
# REQ-d00027: Workflow plugin state management
#   Tickets: CUR-262
#   Implementation: tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh
#   Tests: None ⚠️
#   Documentation: spec/dev-workflow.md ✅
#   Status: Needs Verification ⚠️
#
# ...
#
# ## Summary
#
# Total Coverage: 68/75 (91%)
# Test Coverage: 45/75 (60%)
# Documentation: 75/75 (100%)
```

### Status Report

```bash
/requirements:report --type=status --format=json

# Output:
# {
#   "timestamp": "2025-11-19T14:30:00Z",
#   "total_requirements": 75,
#   "requirements": [
#     {
#       "id": "REQ-p00001",
#       "level": "PRD",
#       "title": "Multi-sponsor authentication",
#       "file": "spec/prd-authentication.md",
#       "hash": "a3f9c2d1b8e6...",
#       "hash_status": "current",
#       "tickets": ["CUR-123", "CUR-145"],
#       "implementation_files": [
#         "packages/auth/lib/multi_sponsor.dart"
#       ],
#       "test_files": [
#         "packages/auth/test/multi_sponsor_test.dart"
#       ],
#       "status": "implemented",
#       "coverage": {
#         "has_tickets": true,
#         "has_implementation": true,
#         "has_tests": true,
#         "has_documentation": true
#       }
#     },
#     ...
#   ],
#   "summary": {
#     "by_status": {
#       "implemented": 52,
#       "in_progress": 15,
#       "not_started": 5,
#       "needs_verification": 3
#     },
#     "by_level": {
#       "PRD": 28,
#       "Ops": 15,
#       "Dev": 32
#     },
#     "coverage": {
#       "tickets": 91,
#       "tests": 60,
#       "documentation": 100
#     }
#   }
# }
```

### HTML Report

```bash
/requirements:report --type=coverage --format=html > report.html

# Generates styled HTML report with:
# - Color-coded status badges
# - Sortable/filterable tables
# - Interactive coverage charts
# - Exportable to PDF
```

### Report from Tracking File

```bash
/requirements:report --from-tracking

# Output:
# ════════════════════════════════════════════════════════════
# Outdated Requirements Report
# ════════════════════════════════════════════════════════════
#
# Source: untracked-notes/outdated-implementations.json
# Generated: 2025-11-19 14:30:00 UTC
#
# ## Requirements Needing Verification (3)
#
# REQ-d00027: Workflow plugin state management
#   Old Hash: abc123...
#   New Hash: def456...
#   Changed: 2025-11-18
#   Verification Ticket: CUR-350 ✅
#   Status: Pending verification
#
# REQ-d00028: Event sourcing implementation
#   Old Hash: 123abc...
#   New Hash: 456def...
#   Changed: 2025-11-17
#   Verification Ticket: None ❌
#   Status: Needs ticket
#
# ...
```

## Integration Points

This command integrates with:
- **spec/INDEX.md**: Requirement definitions
- **.requirement-cache.json**: Ticket mappings
- **Implementation files**: Direct scanning
- **Test files**: Coverage analysis
- **outdated-implementations.json**: Change tracking

## Exit Codes

- `0` - Success
- `1` - No requirements found
- `2` - Invalid arguments
- `3` - Failed to generate report

## Error Handling

The command validates:
- spec/INDEX.md exists
- Requirement format is valid
- Output format is supported
- Tracking file exists (when using --from-tracking)

### No Requirements Found

```
Error: No requirements found in spec/INDEX.md

The INDEX file exists but contains no requirements.

Possible causes:
1. INDEX.md not properly formatted
2. No REQ-* entries in table
3. Corrupted file

Check: cat spec/INDEX.md | grep "REQ-"
```

### Invalid Report Type

```
Error: Invalid report type 'invalid'

Valid types:
  - summary: High-level overview
  - coverage: Detailed coverage analysis
  - status: Implementation status

Usage:
  /requirements:report --type=summary
```

### Missing Tracking File

```
Error: Tracking file not found

Expected: untracked-notes/outdated-implementations.json

The --from-tracking flag requires this file.

Create tracking file:
  /requirements:changes > untracked-notes/outdated-implementations.json
```

## Report Output Samples

### Summary Report (Markdown)

```markdown
# Requirement Compliance Summary

**Generated**: 2025-11-19 14:30:00 UTC

## Overview
- Total Requirements: 75
- Implemented: 52 (69%)
- In Progress: 15 (20%)

## Coverage
- With Tickets: 68 (91%)
- With Tests: 45 (60%)
```

### HTML Report Features

- Responsive design
- Color-coded status badges
- Interactive charts (coverage pie chart)
- Sortable/filterable tables
- Exportable to PDF
- Printable format

## Best Practices

1. **Generate regularly**: Weekly or before audits
2. **Use HTML for presentations**: Stakeholder reports
3. **Use JSON for automation**: CI/CD integration
4. **Track trends**: Compare reports over time
5. **Address gaps**: Focus on missing coverage areas
6. **Archive reports**: Keep for audit trail

## Related Commands

- **/requirements:changes** - Detect requirement changes
- **/req:scan** - Find tickets missing requirements
- **/spec:validate** - Validate spec files
- **/req:create-tickets** - Create tickets for requirements

## Implementation

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/../simple-requirements/scripts/generate-report.py "$@"
```

## Notes

- Requires Python 3.7+
- spec/INDEX.md is source of truth
- Coverage percentages rounded to nearest integer
- HTML reports use Bootstrap CSS
- JSON output useful for dashboards
- Reports can be version-controlled for audit trail
- Tracking file updated by /requirements:changes command
