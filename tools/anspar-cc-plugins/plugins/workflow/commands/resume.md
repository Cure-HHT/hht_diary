---
name: resume
description: Resume work on a previously released ticket
arguments: "[TICKET-ID]"
---

# /resume Command

Resume work on a previously released ticket by showing recent released tickets and allowing interactive selection or direct specification.

## Purpose

The `/resume` command helps developers return to paused work by:
- Displaying recently released tickets from workflow history
- Allowing interactive selection or direct ticket specification
- Re-claiming the selected ticket to resume work
- Maintaining workflow continuity across context switches

## Usage

```bash
/resume              # Interactive selection from recent released tickets
/resume CUR-262      # Resume specific ticket directly
```

## Arguments

### `TICKET-ID` *(optional)*

The ticket identifier to resume directly:
- If provided, attempts to resume the specified ticket
- If omitted, shows interactive menu of recently released tickets
- Validates ticket exists in release history

## Behavior

### Interactive Mode (No Arguments)

1. **Reads workflow history**: Examines `.git/WORKFLOW_STATE` for release actions
2. **Shows recent releases**: Displays last 20 released tickets (most recent first)
3. **Prompts for selection**: User chooses by number or cancels
4. **Claims selected ticket**: Calls `claim-ticket.sh` to resume work

### Direct Mode (Ticket ID Provided)

1. **Validates ticket in history**: Checks if ticket was previously released
2. **Warns if not found**: Asks for confirmation if ticket not in history
3. **Claims ticket**: Proceeds to claim the specified ticket

### State Tracking

- Reads release history from `WORKFLOW_STATE`
- Shows up to 20 most recent unique released tickets
- Displays release timestamp and reason
- Maintains chronological order (newest first)

## Examples

### Interactive Selection

```bash
/resume

# Output:
# 📋 Recently Released Tickets
#
# Select a ticket to resume:
#
#   1  CUR-320
#      Released: 2025-11-06 14:30
#      Reason: Claiming new ticket
#
#   2  CUR-318
#      Released: 2025-11-05 16:45
#      Reason: End of day
#
#   3  CUR-315
#      Released: 2025-11-04 11:20
#      Reason: Context switch
#
# Enter number (1-3) or 'q' to quit: 1
#
# 📋 Resuming ticket: CUR-320
# [proceeds to claim CUR-320]
```

### Direct Resume

```bash
/resume CUR-318
# Directly resumes CUR-318 if found in release history
# Skips interactive selection
```

### New Ticket Warning

```bash
/resume CUR-999
# ⚠️  WARNING: Ticket CUR-999 not found in recent release history
#    This might be a new ticket or one from a different worktree
#
#    Continue claiming this ticket anyway? [y/N]
```

## Integration Points

This command integrates with:
- **claim-ticket.sh**: For re-claiming the selected ticket
- **WORKFLOW_STATE**: For reading release history
- **Workflow plugin**: For complete ticket lifecycle management

## Requirements

- Workflow state file must exist (`.git/WORKFLOW_STATE`)
- At least one release action in history
- `claim-ticket.sh` script must be available

## Exit Codes

- `0` - Success
- `1` - No released tickets found
- `2` - Invalid selection or claim failed

## Display Format

Each released ticket shows:
- **Ticket ID**: The ticket identifier (e.g., CUR-320)
- **Released timestamp**: When the ticket was released (formatted date/time)
- **Release reason**: Why the ticket was released (if recorded)

## Error Handling

The command handles:
- ✅ Missing workflow state file
- ✅ Empty release history
- ✅ Invalid user selection
- ✅ Tickets not in history (with confirmation)
- ✅ Failed claim attempts

## Best Practices

1. **Use after context switches**: Quickly return to previous work
2. **Check recent releases regularly**: Stay aware of paused work
3. **Provide release reasons**: Makes resume decisions easier
4. **Use direct mode for known tickets**: Faster workflow

## Workflow Scenarios

### Scenario 1: Daily Context Switching
```bash
# Morning: Start work on CUR-320
/claim CUR-320

# Mid-day: Urgent issue requires attention
/claim CUR-325  # Automatically releases CUR-320

# Afternoon: Return to original work
/resume         # Select CUR-320 from list
```

### Scenario 2: Multi-Ticket Development
```bash
# Work on multiple features throughout the week
# Each /claim releases the previous ticket
# /resume shows your recent work history
# Easy to jump back to any paused ticket
```

## Related Commands

- `/claim` - Claim a new or specific ticket
- `/ticket` - Ticket management (linear-api plugin)

## Implementation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/resume-ticket.sh "$@"
```

## Notes

- Only shows tickets released in **this worktree**
- Maintains separate history per worktree
- Release history limited to last 20 actions
- Duplicates are filtered (shows only most recent release per ticket)
- Works with both regular repos and git worktrees
