---
name: changes
description: Detect requirement changes (hash comparison)
arguments: "[REQ-ID] [--format=json|summary]"
---

# /requirements:changes Command

Detect requirement changes by comparing current hashes with recorded hashes in INDEX.md.

## Purpose

The `/requirements:changes` command maintains compliance by:
- Detecting modified requirements via hash comparison
- Identifying requirements needing reverification
- Tracking requirement evolution over time
- Triggering verification ticket creation
- Supporting FDA audit trail requirements

## Usage

```bash
/requirements:changes                        # Detect all changes
/requirements:changes REQ-d00027             # Check specific requirement
/requirements:changes --format=json          # JSON output
/requirements:changes --format=summary       # Human-readable summary (default)
```

## Arguments

### `REQ-ID` *(optional)*

Specific requirement to check:
- Format: `REQ-{p|o|d}NNNNN`
- If omitted, checks all requirements
- Example: `REQ-d00027`

### `--format=<FORMAT>` *(optional)*

Output format:
- `summary` (default): Human-readable summary
- `json`: Machine-readable JSON
- Example: `--format=json`

## Behavior

### Change Detection Process

1. **Reads INDEX.md**: Gets recorded requirement hashes
2. **Calculates current hashes**: Computes hashes from spec files
3. **Compares hashes**: Identifies mismatches
4. **Reports changes**: Lists modified requirements
5. **Updates tracking**: Optionally updates `outdated-implementations.json`

### Hash Calculation

Uses SHA-256 hash of requirement content:
- Excludes YAML frontmatter
- Includes title, description, acceptance criteria
- Consistent across runs
- Changes only when content changes

### Output Information

For each changed requirement:
- Requirement ID
- Title
- File location
- Old hash (from INDEX.md)
- New hash (current calculated)
- Change detection timestamp

## Examples

### Detect All Changes (Summary)

```bash
/requirements:changes

# Output:
# ════════════════════════════════════════════════════════════
# Requirement Change Detection
# Generated: 2025-11-19 14:30:00 UTC
# ════════════════════════════════════════════════════════════
#
# Scanning all requirements for changes...
#
# Checked: 75 requirements
# Unchanged: 72 requirements ✅
# Changed: 3 requirements ⚠️
#
# ════════════════════════════════════════════════════════════
# Changed Requirements
# ════════════════════════════════════════════════════════════
#
# REQ-d00027: Workflow plugin state management
#   File: spec/dev-workflow.md
#   Old Hash: abc123def456...
#   New Hash: def456abc123...
#   Status: NEEDS VERIFICATION ⚠️
#
#   Implementation files may need updates:
#   - tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh
#   - tools/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh
#
#   Next steps:
#   1. Review requirement changes: diff spec/dev-workflow.md
#   2. Update implementations if needed
#   3. Create verification ticket: /compliance:verify REQ-d00027
#   4. Update hash: elspais hash update
#
# REQ-p00042: Multi-factor authentication via TOTP
#   File: spec/prd-authentication.md
#   Old Hash: 123abc456def...
#   New Hash: 456def123abc...
#   Status: NEEDS VERIFICATION ⚠️
#
#   Implementation files may need updates:
#   - packages/auth/lib/mfa/totp.dart
#   - packages/auth/lib/mfa/backup_codes.dart
#
#   Next steps: [same as above]
#
# REQ-o00015: Database backup automation
#   File: spec/ops-deployment.md
#   Old Hash: aaa111bbb222...
#   New Hash: bbb222aaa111...
#   Status: NEEDS VERIFICATION ⚠️
#
# ════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════
#
# Total changes: 3
# PRD changes: 1
# Ops changes: 1
# Dev changes: 1
#
# ⚠️  Action required: Create verification tickets for changed requirements
#
# Recommended workflow:
#   1. /compliance:verify REQ-d00027 --old-hash=abc123... --new-hash=def456...
#   2. Review and update implementations
#   3. Run tests to verify compliance
#   4. Update hashes: elspais hash update
```

### Check Specific Requirement

```bash
/requirements:changes REQ-d00027

# Output:
# Checking requirement: REQ-d00027
#
# REQ-d00027: Workflow plugin state management
#   File: spec/dev-workflow.md
#   Status: CHANGED ⚠️
#
#   Old Hash: abc123def456...
#   New Hash: def456abc123...
#
#   This requirement was modified and needs reverification.
#
#   Implementation files that may be affected:
#   - tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh
#   - tools/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh
#
#   Next steps:
#   1. Review changes: git diff spec/dev-workflow.md
#   2. Create verification ticket: /compliance:verify REQ-d00027
#   3. Update implementations if needed
#   4. Update hash after verification
```

### No Changes Detected

```bash
/requirements:changes

# Output:
# Scanning all requirements for changes...
#
# ✅ All requirements unchanged!
#
# Checked: 75 requirements
# No hash mismatches detected
#
# All implementations are in sync with requirements.
```

### JSON Output

```bash
/requirements:changes --format=json

# Output:
# {
#   "timestamp": "2025-11-19T14:30:00Z",
#   "total_requirements": 75,
#   "unchanged": 72,
#   "changed": 3,
#   "changes": [
#     {
#       "req_id": "REQ-d00027",
#       "title": "Workflow plugin state management",
#       "file": "spec/dev-workflow.md",
#       "level": "Dev",
#       "old_hash": "abc123def456...",
#       "new_hash": "def456abc123...",
#       "detected_at": "2025-11-19T14:30:00Z",
#       "implementation_files": [
#         "tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh",
#         "tools/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh"
#       ],
#       "verification_ticket": null,
#       "status": "needs_verification"
#     },
#     {
#       "req_id": "REQ-p00042",
#       "title": "Multi-factor authentication via TOTP",
#       "file": "spec/prd-authentication.md",
#       "level": "PRD",
#       "old_hash": "123abc456def...",
#       "new_hash": "456def123abc...",
#       "detected_at": "2025-11-19T14:30:00Z",
#       "implementation_files": [
#         "packages/auth/lib/mfa/totp.dart"
#       ],
#       "verification_ticket": null,
#       "status": "needs_verification"
#     }
#   ]
# }
```

### Single Requirement (Unchanged)

```bash
/requirements:changes REQ-p00001

# Output:
# Checking requirement: REQ-p00001
#
# ✅ REQ-p00001: Multi-sponsor authentication
#   File: spec/prd-authentication.md
#   Status: UNCHANGED
#
#   Hash: a3f9c2d1b8e6... (matches INDEX.md)
#
#   No action required.
```

## Integration Points

This command integrates with:
- **spec/INDEX.md**: Source of recorded hashes
- **Spec files**: Current requirement content
- **untracked-notes/outdated-implementations.json**: Tracking file
- **/compliance:verify**: Creates verification tickets
- **elspais hash update**: Updates hashes after verification

## Exit Codes

- `0` - Success (changes detected or none found)
- `1` - Requirement not found
- `2` - Failed to calculate hash
- `3` - Invalid arguments

## Error Handling

The command validates:
- spec/INDEX.md exists
- Requirement ID is valid (if specified)
- Spec files are readable
- Hash calculation succeeds

### Requirement Not Found

```
Error: Requirement REQ-d99999 not found

The requirement does not exist in spec/INDEX.md.

Check available requirements:
  grep "REQ-" spec/INDEX.md
```

### Missing INDEX.md

```
Error: spec/INDEX.md not found

INDEX.md is required for hash comparison.

Generate INDEX.md:
  elspais index regenerate
```

### Hash Calculation Failed

```
Error: Failed to calculate hash for REQ-d00027

The spec file may be corrupted or missing.

Check file:
  cat spec/dev-workflow.md | grep "REQ-d00027"

Validate spec file:
  /spec:validate spec/dev-workflow.md
```

## Change Detection Workflow

### Standard Workflow

1. **Detect changes**:
   ```bash
   /requirements:changes --format=json > changes.json
   ```

2. **Review changes**:
   ```bash
   cat changes.json | jq '.changes[] | {req_id, file}'
   ```

3. **Create verification tickets**:
   ```bash
   /compliance:verify REQ-d00027 --old-hash=abc... --new-hash=def...
   ```

4. **Update implementations**:
   - Review requirement changes
   - Update code/scripts
   - Run tests

5. **Update hashes**:
   ```bash
   elspais hash update
   ```

### Automated CI/CD Integration

```yaml
# .github/workflows/requirement-compliance.yml
- name: Detect requirement changes
  run: /requirements:changes --format=json > changes.json

- name: Check for changes
  run: |
    if [ $(jq '.changed' changes.json) -gt 0 ]; then
      echo "⚠️ Requirements changed - verification needed"
      exit 1
    fi
```

## Best Practices

1. **Run before updates**: Detect changes before modifying INDEX.md
2. **Create verification tickets**: Track reverification work
3. **Review changes carefully**: Understand requirement evolution
4. **Update implementations**: Keep code in sync with requirements
5. **Update hashes after verification**: Mark requirements as verified
6. **Track changes over time**: Maintain audit trail

## Related Commands

- **/compliance:verify** - Create verification ticket
- **/requirements:report** - Generate compliance reports
- **/spec:validate** - Validate spec files
- **elspais hash update** - Update hashes after verification

## Implementation

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/../simple-requirements/scripts/detect-changes.py "$@"
```

## Notes

- Requires Python 3.7+
- Uses SHA-256 for hash calculation
- Hash excludes YAML frontmatter
- Changes tracked in `untracked-notes/outdated-implementations.json`
- JSON output useful for automation
- Summary format useful for manual review
- Hash mismatches indicate requirement modifications
- Always verify implementations after requirement changes
