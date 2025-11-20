---
name: fetch
description: Fetch Linear ticket details by ID or current active ticket
arguments: "[TICKET-ID...]"
---

# /linear:fetch Command

Fetch Linear ticket details by identifier or retrieve the current active ticket from workflow state.

## Purpose

The `/linear:fetch` command retrieves ticket information by:
- Fetching specific ticket(s) by ID
- Auto-detecting current active ticket from workflow state
- Displaying ticket metadata, description, labels, and status
- Showing requirement references if present

## Usage

```bash
/linear:fetch                    # Fetch current active ticket
/linear:fetch CUR-240            # Fetch specific ticket
/linear:fetch CUR-240 CUR-241    # Fetch multiple tickets
```

## Arguments

### `TICKET-ID` *(optional, multiple allowed)*

Ticket identifier(s) to fetch:
- Format: `PROJECT-NUMBER` (e.g., CUR-240)
- If omitted, fetches current active ticket from WORKFLOW_STATE
- Multiple IDs can be provided for batch fetching
- Example: `CUR-240`, `CUR-241 CUR-242`

## Behavior

### Auto-Detection of Active Ticket

When no ticket ID provided:
1. Searches for `.git/WORKFLOW_STATE` file
2. Parses JSON to find `activeTicket.id`
3. Fetches details for active ticket
4. Falls back to error if no active ticket found

### Ticket Details Displayed

For each ticket:
- **Identifier**: Ticket ID (e.g., CUR-240)
- **Title**: Ticket title
- **Status**: Current state (Todo, In Progress, Done, etc.)
- **Priority**: Priority level
- **Labels**: Associated labels
- **Description**: Full description (markdown formatted)
- **Assignee**: Assigned team member
- **Project**: Project assignment
- **URL**: Direct link to ticket
- **Requirement References**: REQ-IDs if present in description

### Output Format

```
Ticket: CUR-240
Title: Implement multi-factor authentication
Status: In Progress
Priority: High
Labels: security, backend
Assignee: developer@company.com
Project: Authentication Sprint

Description:
Implement TOTP-based multi-factor authentication.

Requirement: REQ-p00042

- Add mfa_tokens table
- Generate QR codes
- Verify TOTP codes

URL: https://linear.app/cure-hht/issue/CUR-240
```

## Examples

### Fetch Current Active Ticket

```bash
/linear:fetch

# Output:
# Fetching current active ticket from workflow state...
#
# Ticket: CUR-320
# Title: Add session management
# Status: In Progress
# Priority: Normal
# ...
```

### Fetch Specific Ticket

```bash
/linear:fetch CUR-262

# Output:
# Ticket: CUR-262
# Title: Database migration for user roles
# Status: Done
# Priority: High
# ...
```

### Fetch Multiple Tickets

```bash
/linear:fetch CUR-240 CUR-241 CUR-242

# Output:
# ===== Ticket: CUR-240 =====
# Title: Implement MFA
# Status: In Progress
# ...
#
# ===== Ticket: CUR-241 =====
# Title: Add backup codes
# Status: Todo
# ...
#
# ===== Ticket: CUR-242 =====
# Title: MFA UI components
# Status: In Progress
# ...
```

## Integration Points

This command integrates with:
- **WORKFLOW_STATE**: Auto-detects active ticket
- **Linear API**: Fetches ticket data
- **linear-api/lib/ticket-fetcher**: Reusable fetching module
- **Requirement traceability**: Extracts REQ references from description

## Exit Codes

- `0` - Success
- `1` - No active ticket found (when no ID provided)
- `2` - Ticket not found or API error
- `3` - Invalid ticket ID format

## Error Handling

The command handles:
- Missing workflow state file
- No active ticket in workflow
- Invalid ticket ID format
- Ticket not found in Linear
- API authentication errors
- Network timeouts

### No Active Ticket

```
Error: No active ticket found

WORKFLOW_STATE exists but no ticket is currently claimed.

Options:
1. Claim a ticket: /claim CUR-XXX
2. Resume previous work: /resume
3. Fetch specific ticket: /linear:fetch CUR-XXX
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

### No WORKFLOW_STATE

```
Warning: WORKFLOW_STATE not found

Fetching active ticket requires claimed ticket.

Options:
1. Claim a ticket first: /claim CUR-XXX
2. Provide ticket ID explicitly: /linear:fetch CUR-XXX
```

### Authentication Error

```
Error: LINEAR_API_TOKEN invalid or missing

Set environment variable:
  export LINEAR_API_TOKEN="your-token-here"

Or configure via Doppler:
  doppler run -- claude
```

## Best Practices

1. **Use without arguments in workflow**: Quickly check current ticket
2. **Verify ticket before claiming**: Fetch details before `/claim`
3. **Check requirement references**: Ensure REQ traceability
4. **Review before switching**: Fetch to confirm ticket details
5. **Batch fetch related tickets**: Use multiple IDs for context

## Related Commands

- `/claim` - Claim a ticket for work
- `/resume` - Resume previously released ticket
- `/linear:search` - Search for tickets
- `/linear:update` - Update ticket details
- `/linear:create` - Create new ticket

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/../linear-api/scripts/fetch-tickets.js "$@"
```

## Notes

- Requires LINEAR_API_TOKEN environment variable
- Auto-detection uses `.git/WORKFLOW_STATE` file
- Multiple tickets fetched sequentially
- Description supports markdown rendering
- Extracts REQ-IDs using pattern matching
- URLs are clickable in most terminals
- Works with both regular repos and git worktrees
