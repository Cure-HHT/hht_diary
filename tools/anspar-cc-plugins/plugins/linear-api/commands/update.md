---
name: update
description: Update ticket status, description, or add requirements
arguments: "--ticketId=<ID> [OPTIONS]"
---

# /linear:update Command

Update Linear ticket status, description, checklist, or requirement references.

## Purpose

The `/linear:update` command modifies tickets by:
- Changing ticket status (todo, in-progress, done, backlog, canceled)
- Updating description text
- Adding checklists
- Adding requirement references (REQ-IDs)
- Supporting batch updates

## Usage

```bash
/linear:update --ticketId=CUR-240 --status=in-progress
/linear:update --ticketId=CUR-240 --description="Updated description"
/linear:update --ticketId=CUR-240 --add-requirement=REQ-p00042
/linear:update --ticketId=CUR-240 --status=done --description="Completed MFA implementation"
```

## Arguments

### `--ticketId=<ID>` *(required)*

Ticket identifier to update:
- Format: `PROJECT-NUMBER`
- Example: `--ticketId=CUR-240`

### `--status=<STATUS>` *(optional)*

Change ticket status:
- Values: `todo`, `in-progress`, `done`, `backlog`, `canceled`
- Maps to Linear workflow states
- Example: `--status=in-progress`

### `--description=<TEXT>` *(optional)*

Replace entire description:
- Supports markdown formatting
- Overwrites existing description
- Example: `--description="New description text"`

### `--checklist=<JSON>` *(optional)*

Add checklist to description:
- JSON array or markdown checklist
- Appends to existing description
- Example: `--checklist='[{"text":"Task 1","done":false}]'`

### `--add-requirement=<REQ-ID>` *(optional)*

Add requirement reference:
- Format: `REQ-{p|o|d}NNNNN`
- Prepends to description
- Example: `--add-requirement=REQ-p00042`

## Behavior

### Status Updates

Maps friendly names to Linear states:
- `todo` → "Todo"
- `in-progress` → "In Progress"
- `done` → "Done"
- `backlog` → "Backlog"
- `canceled` → "Canceled"

### Description Updates

- **Full replacement**: `--description` replaces entire description
- **Requirement prepend**: `--add-requirement` prepends to existing
- **Checklist append**: `--checklist` appends to existing

### Requirement References

When adding requirement:
1. Validates REQ-ID exists in `spec/INDEX.md`
2. Prepends reference to description:
   ```markdown
   **Requirement**: REQ-p00042

   [existing description...]
   ```
3. Updates requirement-ticket cache

## Examples

### Update Status to In Progress

```bash
/linear:update --ticketId=CUR-240 --status=in-progress

# Output:
# Updated CUR-240
# Status: In Progress
# URL: https://linear.app/cure-hht/issue/CUR-240
```

### Mark Ticket as Done

```bash
/linear:update --ticketId=CUR-240 --status=done

# Output:
# Updated CUR-240
# Status: Done
# URL: https://linear.app/cure-hht/issue/CUR-240
```

### Update Description

```bash
/linear:update \
  --ticketId=CUR-240 \
  --description="Implemented TOTP MFA with QR code generation and backup codes."

# Output:
# Updated CUR-240
# Description updated (45 characters)
# URL: https://linear.app/cure-hht/issue/CUR-240
```

### Add Requirement Reference

```bash
/linear:update --ticketId=CUR-240 --add-requirement=REQ-p00042

# Output:
# Validating requirement REQ-p00042...
# Requirement found: Multi-factor authentication via TOTP
# Updated CUR-240 with requirement reference
# URL: https://linear.app/cure-hht/issue/CUR-240
```

### Add Checklist

```bash
/linear:update \
  --ticketId=CUR-240 \
  --checklist='- [ ] Add mfa_tokens table
- [ ] Generate QR codes
- [ ] Verify TOTP codes
- [ ] Add backup codes'

# Output:
# Updated CUR-240 with checklist (4 items)
# URL: https://linear.app/cure-hht/issue/CUR-240
```

### Combined Update

```bash
/linear:update \
  --ticketId=CUR-240 \
  --status=in-progress \
  --description="Implementing MFA according to REQ-p00042"

# Output:
# Updated CUR-240
# Status: In Progress
# Description updated
# URL: https://linear.app/cure-hht/issue/CUR-240
```

## Integration Points

This command integrates with:
- **Linear API**: GraphQL mutations
- **Requirement traceability**: REQ-ID validation via `spec/INDEX.md`
- **linear-api/lib/graphql-client**: Reusable mutation module
- **requirement-traceability plugin**: Cache updates

## Exit Codes

- `0` - Success
- `1` - Invalid arguments or validation error
- `2` - Linear API error
- `3` - Requirement not found (when using --add-requirement)

## Error Handling

The command validates:
- Ticket ID is provided
- Status value is valid
- Requirement exists (if adding reference)
- API token is set
- Ticket exists in Linear

### Missing Ticket ID

```
Error: Ticket ID required

Usage:
  /linear:update --ticketId=CUR-XXX [options]
```

### Invalid Status

```
Error: Invalid status 'invalid'

Valid statuses:
  - todo
  - in-progress
  - done
  - backlog
  - canceled
```

### Requirement Not Found

```
Error: Requirement REQ-p99999 not found

The requirement does not exist in spec/INDEX.md.

Suggestions:
1. Check requirement ID format (REQ-{p|o|d}NNNNN)
2. Search for requirements: grep REQ- spec/INDEX.md
3. Create new requirement first
```

### Ticket Not Found

```
Error: Ticket CUR-999 not found

The ticket does not exist or you don't have access.

Suggestions:
1. Verify ticket ID (check Linear workspace)
2. Search for tickets: /linear:search
3. Check LINEAR_API_TOKEN permissions
```

## Best Practices

1. **Update status regularly**: Keep ticket state current
2. **Add requirements early**: Link REQ-IDs during implementation
3. **Use descriptive updates**: Make changes traceable
4. **Verify before updating**: Fetch ticket first
5. **Use checklists for tasks**: Break down implementation

## Related Commands

- `/linear:fetch` - Fetch ticket before updating
- `/linear:create` - Create new ticket
- `/add-REQ-to-ticket` - Alternative for adding requirements
- `/claim` - Claim ticket for work
- `/workflow:release` - Release ticket when done

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/../linear-api/scripts/update-ticket.js "$@"
```

## Notes

- Requires LINEAR_API_TOKEN environment variable
- Status changes trigger Linear workflow transitions
- Description updates replace entire content (except with --add-requirement)
- Requirement references are prepended to maintain visibility
- Checklist format supports markdown syntax
- Updates are immediate (no undo)
- Cache updates happen automatically for requirement references
