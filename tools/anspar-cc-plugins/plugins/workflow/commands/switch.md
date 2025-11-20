---
name: switch
description: Switch from one ticket to another
arguments: "<NEW-TICKET-ID> <REASON>"
---

# /workflow:switch Command

Switch from current active ticket to a new ticket in one atomic operation.

## Purpose

The `/workflow:switch` command handles context changes by:
- Releasing current ticket with specified reason
- Immediately claiming new ticket
- Recording full context switch in history
- Maintaining clean workflow state

## Usage

```bash
/workflow:switch CUR-263 "Blocked - waiting for review"
/workflow:switch CUR-264 "Focus pivot to higher priority"
/workflow:switch CUR-262 "Resuming previous work"
```

## Arguments

### `NEW-TICKET-ID` *(required)*

Ticket ID to switch to:
- Format: `PROJECT-NUMBER`
- Must be valid Linear ticket ID
- Example: `CUR-263`

### `REASON` *(required)*

Reason for pausing current ticket:
- Recorded in workflow history
- Helps with later `/resume` decisions
- Example: `"Blocked - waiting for dependencies"`

## Behavior

### Atomic Switch Operation

1. **Validates new ticket exists**: Checks Linear for new ticket
2. **Releases current ticket**: Calls `release-ticket.sh` with reason
3. **Claims new ticket**: Calls `claim-ticket.sh` for new ticket
4. **Records switch**: Adds both actions to history
5. **Rollback on failure**: Reverts if claim fails

### History Tracking

Records two history entries:
```json
{
  "action": "release",
  "ticketId": "CUR-262",
  "timestamp": "2025-11-19T14:30:00Z",
  "reason": "Blocked - waiting for review"
}
{
  "action": "claim",
  "ticketId": "CUR-263",
  "timestamp": "2025-11-19T14:30:05Z",
  "reason": "Context switch"
}
```

## Examples

### Switch Due to Blocker

```bash
/workflow:switch CUR-263 "Blocked - waiting for review"

# Output:
# Releasing current ticket: CUR-262
#   Reason: Blocked - waiting for review
#   Timestamp: 2025-11-19 14:30:00
#
# Claiming new ticket: CUR-263
#   Title: Implement database migration
#   Status: Todo
#   Priority: High
#
# Context switch complete!
#
# Workflow state:
#   Previous ticket: CUR-262 (can resume later)
#   Active ticket: CUR-263
```

### Switch to Higher Priority

```bash
/workflow:switch CUR-264 "Focus pivot to higher priority"

# Output:
# Releasing current ticket: CUR-263
#   Reason: Focus pivot to higher priority
#   Timestamp: 2025-11-19 15:00:00
#
# Claiming new ticket: CUR-264
#   Title: Critical security fix
#   Status: Todo
#   Priority: Urgent
#
# Context switch complete!
```

### Resume Previous Work

```bash
/workflow:switch CUR-262 "Resuming previous work"

# Output:
# Releasing current ticket: CUR-264
#   Reason: Resuming previous work
#   Timestamp: 2025-11-19 16:00:00
#
# Claiming new ticket: CUR-262
#   Title: Add authentication module
#   Status: In Progress
#   Priority: Normal
#
# Note: This ticket was previously paused
# Previous release reason: "Blocked - waiting for review"
#
# Context switch complete!
```

## Integration Points

This command integrates with:
- **release-ticket.sh**: For releasing current ticket
- **claim-ticket.sh**: For claiming new ticket
- **WORKFLOW_STATE**: Atomic state updates
- **Linear API**: Validates new ticket exists
- **/resume**: Released tickets appear in resume list

## Exit Codes

- `0` - Success
- `1` - Invalid arguments
- `2` - Failed to release current ticket
- `3` - Failed to claim new ticket (current ticket remains released)

## Error Handling

The command validates:
- Both arguments provided
- Current ticket is claimed
- New ticket exists in Linear
- WORKFLOW_STATE is writable

### Missing Arguments

```
Error: Both ticket ID and reason required

Usage:
  /workflow:switch <NEW-TICKET-ID> <REASON>

Examples:
  /workflow:switch CUR-263 "Blocked"
  /workflow:switch CUR-264 "Higher priority"
```

### No Active Ticket

```
Error: No active ticket to release

Cannot switch without an active ticket.

Options:
1. Claim a ticket: /claim CUR-XXX
2. Resume previous work: /resume
```

### New Ticket Not Found

```
Error: Ticket CUR-999 not found

The new ticket does not exist in Linear.

Suggestions:
1. Verify ticket ID (check Linear workspace)
2. Search for tickets: /linear:search
3. Create new ticket: /linear:create
```

### Claim Failed (Partial Switch)

```
Warning: Switch partially completed

Current ticket CUR-262 was released successfully.
But failed to claim new ticket CUR-999.

Current state:
  Active ticket: None

Options:
1. Claim different ticket: /claim CUR-XXX
2. Resume released ticket: /resume
3. Fix issue and retry switch
```

## Comparison with Alternatives

### /workflow:switch vs Manual Release + Claim

**Using switch** (recommended):
```bash
/workflow:switch CUR-263 "Blocked"
```

**Manual approach**:
```bash
/workflow:release "Blocked"
/claim CUR-263
```

**Advantages of switch**:
- Atomic operation (rollback on failure)
- Single command
- Better history tracking
- Prevents forgotten releases

### /workflow:switch vs /resume

**Use switch** when:
- You know the next ticket ID
- You want to specify release reason
- You're switching to new ticket

**Use resume** when:
- You want to see recent released tickets
- You don't remember the ticket ID
- You want interactive selection

## Best Practices

1. **Use descriptive reasons**: Helps with future `/resume` decisions
2. **Switch atomically**: Prefer `/switch` over manual release + claim
3. **Validate new ticket exists**: Use `/linear:fetch` to verify
4. **Review history**: Check `/workflow:history` for context switches
5. **Resume paused work**: Use `/resume` to return to blocked tickets

## Related Commands

- `/claim` - Claim ticket without releasing current
- `/workflow:release` - Release without claiming new ticket
- `/resume` - Resume previously released ticket
- `/workflow:history` - View all switches and releases

## Implementation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/switch-ticket.sh "$@"
```

## Notes

- Requires both ticket ID and reason arguments
- Switch is atomic (both operations or neither)
- Released ticket appears in `/resume` list
- Works with both regular repos and git worktrees
- History preserves full switch context
- Rollback on claim failure (current ticket remains released)
- Linear API token required for new ticket validation
