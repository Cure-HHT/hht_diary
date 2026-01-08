---
name: verify
description: Create verification ticket for changed requirement
arguments: "<REQ-ID> --old-hash=<HASH> --new-hash=<HASH>"
---

# /compliance:verify Command

Create Linear verification ticket for a requirement that has been modified.

## Purpose

The `/compliance:verify` command ensures FDA compliance by:
- Creating verification tickets for changed requirements
- Tracking requirement modifications
- Linking verification work to requirement changes
- Maintaining audit trail for compliance
- Automating verification ticket generation

## Usage

```bash
/compliance:verify REQ-d00027 --old-hash=abc123 --new-hash=def456
/compliance:verify REQ-p00042 --old-hash=123abc --new-hash=456def --priority=high
/compliance:verify REQ-o00015 --old-hash=aaa111 --new-hash=bbb222 --assignee=developer@company.com
```

## Arguments

### `REQ-ID` *(required)*

Requirement identifier that changed:
- Format: `REQ-{p|o|d}NNNNN`
- Must exist in spec/INDEX.md
- Example: `REQ-d00027`

### `--old-hash=<HASH>` *(required)*

Previous requirement hash:
- Hash value from INDEX.md before change
- Used to track what changed
- Example: `--old-hash=abc123def456...`

### `--new-hash=<HASH>` *(required)*

Current requirement hash:
- Hash value after requirement modification
- Calculated from current spec file
- Example: `--new-hash=def456abc123...`

### `--priority=<LEVEL>` *(optional)*

Ticket priority:
- Values: `urgent`, `high`, `normal`, `low`
- Default: `high` (requirement changes are high priority)
- Example: `--priority=urgent`

### `--assignee=<EMAIL>` *(optional)*

Assignee for verification ticket:
- Email address or Linear user ID
- Auto-assigns to requirement owner if available
- Example: `--assignee=developer@company.com`

## Behavior

### Ticket Creation Process

1. **Validates requirement**: Checks REQ-ID exists in INDEX.md
2. **Extracts requirement details**: Gets title, file, level from INDEX
3. **Generates ticket title**: Format: `Verify REQ-{id}: {title}`
4. **Creates detailed description**: Includes old/new hashes, file location
5. **Creates ticket via Linear API**: Assigns labels and priority
6. **Returns ticket URL**: For tracking

### Ticket Content

**Title**:
```
Verify REQ-d00027: Workflow plugin state management
```

**Description**:
```markdown
## Requirement Verification

This ticket tracks verification of requirement changes to ensure implementation compliance.

**Requirement**: REQ-d00027
**Title**: Workflow plugin state management
**File**: spec/dev-workflow.md
**Level**: Development

## Hash Changes

- **Old Hash**: abc123def456...
- **New Hash**: def456abc123...
- **Change Detected**: 2025-11-19 14:30:00 UTC

## Verification Checklist

- [ ] Review requirement changes
  - [ ] Compare old vs new requirement content
  - [ ] Understand scope of changes
  - [ ] Identify affected implementation files

- [ ] Update Implementation
  - [ ] tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh
  - [ ] tools/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh
  - [ ] (Add other affected files)

- [ ] Update Tests
  - [ ] Review existing tests
  - [ ] Add tests for new requirements
  - [ ] Ensure all tests pass

- [ ] Update Documentation
  - [ ] Update inline code comments
  - [ ] Update README if needed
  - [ ] Update implementation guides

- [ ] Verification
  - [ ] Manual testing completed
  - [ ] Automated tests pass
  - [ ] Code review completed
  - [ ] Requirement fully implemented

- [ ] Update Hash
  - [ ] Run: `elspais hash update`
  - [ ] Verify hash updated in INDEX.md
  - [ ] Commit hash update

## Files to Review

Based on implementation scan, review these files:
- tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh
- tools/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh

## Related Issues

- Original requirement: spec/dev-workflow.md (REQ-d00027)

---

**Created by**: /compliance:verify command
**Requirement Tracking**: This is a compliance verification ticket
```

**Labels**:
- `requirement`
- `verification`
- `compliance`
- Level-specific: `prd`, `ops`, or `dev`

## Examples

### Create Verification Ticket

```bash
/compliance:verify REQ-d00027 --old-hash=abc123def456 --new-hash=def456abc123

# Output:
# Creating verification ticket for REQ-d00027...
#
# Validating requirement...
# ✅ REQ-d00027 found in INDEX.md
#    Title: Workflow plugin state management
#    File: spec/dev-workflow.md
#    Level: Development
#
# Creating Linear ticket...
# ✅ Ticket created: CUR-350
#
# Ticket Details:
#   Title: Verify REQ-d00027: Workflow plugin state management
#   Priority: High
#   Labels: requirement, verification, compliance, dev
#   URL: https://linear.app/cure-hht/issue/CUR-350
#
# Next steps:
#   1. Review requirement changes: git diff spec/dev-workflow.md
#   2. Claim ticket: /claim CUR-350
#   3. Update implementations
#   4. Complete verification checklist
#   5. Update hash: elspais hash update
```

### High-Priority Verification

```bash
/compliance:verify REQ-p00042 \
  --old-hash=123abc456def \
  --new-hash=456def123abc \
  --priority=urgent

# Output:
# Creating verification ticket for REQ-p00042...
#
# ✅ Ticket created: CUR-351
#    Title: Verify REQ-p00042: Multi-factor authentication via TOTP
#    Priority: Urgent
#    URL: https://linear.app/cure-hht/issue/CUR-351
#
# ⚠️  URGENT PRIORITY: Requirement change affects security feature
#
# Next steps:
#   1. Immediate review required
#   2. Claim ticket: /claim CUR-351
#   3. Assess security impact
#   4. Update implementations
```

### Assigned Verification

```bash
/compliance:verify REQ-o00015 \
  --old-hash=aaa111bbb222 \
  --new-hash=bbb222aaa111 \
  --assignee=devops@company.com

# Output:
# Creating verification ticket for REQ-o00015...
#
# ✅ Ticket created: CUR-352
#    Title: Verify REQ-o00015: Database backup automation
#    Priority: High
#    Assignee: devops@company.com
#    Labels: requirement, verification, compliance, ops
#    URL: https://linear.app/cure-hht/issue/CUR-352
```

### From JSON Input

```bash
# Using output from /requirements:changes
cat changes.json | jq -r '.changes[0]' | \
  /compliance:verify --input -

# Reads JSON from stdin:
# {
#   "req_id": "REQ-d00027",
#   "old_hash": "abc123...",
#   "new_hash": "def456...",
#   "title": "Workflow plugin state management",
#   "file": "spec/dev-workflow.md"
# }
```

## Integration Points

This command integrates with:
- **spec/INDEX.md**: Requirement validation
- **/requirements:changes**: Source of change detection
- **Linear API**: Ticket creation
- **linear-api/lib/ticket-creator**: Reusable creation module
- **requirement-traceability plugin**: Adds REQ reference to ticket

## Exit Codes

- `0` - Success (ticket created)
- `1` - Invalid arguments
- `2` - Requirement not found
- `3` - Linear API error

## Error Handling

The command validates:
- REQ-ID exists in INDEX.md
- Both hashes provided
- LINEAR_API_TOKEN is set
- Requirement file exists

### Requirement Not Found

```
Error: Requirement REQ-d99999 not found

The requirement does not exist in spec/INDEX.md.

Check available requirements:
  grep "REQ-" spec/INDEX.md
```

### Missing Hashes

```
Error: Both --old-hash and --new-hash required

Usage:
  /compliance:verify REQ-{id} --old-hash=<hash> --new-hash=<hash>

Get hashes:
  /requirements:changes REQ-{id}
```

### Linear API Error

```
Error: Failed to create verification ticket

Linear API error: Rate limit exceeded

Options:
1. Wait and retry
2. Check LINEAR_API_TOKEN permissions
3. Create ticket manually in Linear UI
```

### Missing API Token

```
Error: LINEAR_API_TOKEN not set

Set environment variable:
  export LINEAR_API_TOKEN="your-token-here"

Or configure via Doppler:
  doppler run -- claude
```

## Verification Workflow

### Standard Workflow

1. **Detect changes**:
   ```bash
   /requirements:changes > changes.txt
   ```

2. **Create verification tickets**:
   ```bash
   /compliance:verify REQ-d00027 --old-hash=abc... --new-hash=def...
   ```

3. **Claim and work**:
   ```bash
   /claim CUR-350
   ```

4. **Review requirement changes**:
   ```bash
   git diff spec/dev-workflow.md
   ```

5. **Update implementations**:
   - Modify code/scripts
   - Update tests
   - Run test suite

6. **Complete verification**:
   - Check all checklist items
   - Code review
   - Merge changes

7. **Update hash**:
   ```bash
   elspais hash update
   ```

8. **Close ticket**:
   ```bash
   /linear:update --ticketId=CUR-350 --status=done
   ```

## Best Practices

1. **Create tickets immediately**: When changes detected
2. **Use appropriate priority**: Security/critical requirements = urgent
3. **Assign to experts**: Requirement owners or domain experts
4. **Complete checklist**: Don't skip verification steps
5. **Update hashes after verification**: Mark as complete
6. **Link related tickets**: Reference original implementation tickets
7. **Document changes**: Add comments explaining modifications

## Related Commands

- **/requirements:changes** - Detect requirement changes
- **/claim** - Claim verification ticket
- **/linear:update** - Update ticket status
- **/requirements:report** - Generate compliance reports

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/../compliance-verification/scripts/create-verification.js "$@"
```

## Notes

- Requires LINEAR_API_TOKEN environment variable
- Verification tickets created with high priority by default
- Checklists generated from requirement content
- Implementation files detected automatically
- Hash updates require manual script execution
- Verification critical for FDA compliance
- Tickets labeled for easy tracking
- Supports JSON input for automation
