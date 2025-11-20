---
name: release
description: Release currently claimed ticket
arguments: "[REASON] [--pr-number NUM] [--pr-url URL]"
---

# /workflow:release Command

Release the currently claimed ticket by updating workflow state and optionally linking to GitHub PR.

## Purpose

The `/workflow:release` command completes ticket work by:
- Clearing active ticket from WORKFLOW_STATE
- Recording release reason in history
- Optionally adding Linear comment with PR link
- Enabling context switching or work completion

## Usage

```bash
/workflow:release
/workflow:release "Work complete"
/workflow:release "Switching to different ticket"
/workflow:release "Work complete" --pr-number 42 --pr-url https://github.com/org/repo/pull/42
```

## Arguments

### `REASON` *(optional)*

Reason for releasing ticket:
- Default: "Work complete"
- Recorded in workflow history
- Useful for `/resume` context
- Example: `"Blocked - waiting for review"`

### `--pr-number <NUM>` *(optional)*

GitHub PR number:
- Adds Linear comment with PR link
- Requires `--pr-url` to be provided
- Example: `--pr-number 42`

### `--pr-url <URL>` *(optional)*

GitHub PR URL:
- Used with `--pr-number` to create Linear comment
- Full PR URL from GitHub
- Example: `--pr-url https://github.com/org/repo/pull/42`

## Behavior

### State Management

1. **Reads WORKFLOW_STATE**: Gets current active ticket
2. **Clears active ticket**: Sets `activeTicket = null`
3. **Records history**: Adds release action with timestamp and reason
4. **Writes state**: Updates WORKFLOW_STATE file

### Linear Integration

If PR information provided:
1. Validates ticket exists in Linear
2. Creates comment with PR link
3. Optionally updates ticket status

### Output

Shows release confirmation:
- Released ticket ID
- Release reason
- Workflow state (before and after)
- PR link (if provided)

## Examples

### Basic Release

```bash
/workflow:release

# Output:
# Released ticket: CUR-320
# Reason: Work complete
# Timestamp: 2025-11-19 14:30:00
#
# Workflow state updated:
#   Active ticket: None
```

### Release with Reason

```bash
/workflow:release "Blocked - waiting for code review"

# Output:
# Released ticket: CUR-320
# Reason: Blocked - waiting for code review
# Timestamp: 2025-11-19 14:30:00
#
# Tip: Resume later with /resume
```

### Release with PR Link

```bash
/workflow:release "Work complete" \
  --pr-number 42 \
  --pr-url https://github.com/Cure-HHT/diary/pull/42

# Output:
# Released ticket: CUR-320
# Reason: Work complete
# Timestamp: 2025-11-19 14:30:00
#
# Linear comment added:
#   PR created: https://github.com/Cure-HHT/diary/pull/42
#
# Workflow state updated:
#   Active ticket: None
```

### Release Before Context Switch

```bash
/workflow:release "Switching to higher priority work"

# Output:
# Released ticket: CUR-320
# Reason: Switching to higher priority work
# Timestamp: 2025-11-19 14:30:00
#
# Next steps:
#   - Claim new ticket: /claim CUR-XXX
#   - Or resume later: /resume
```

## Integration Points

This command integrates with:
- **WORKFLOW_STATE**: Clears active ticket
- **Workflow history**: Records release action
- **Linear API**: Adds PR comment (if --pr-number provided)
- **/resume**: Released tickets appear in resume list
- **/workflow:switch**: Alternative for immediate switch to new ticket

## Exit Codes

- `0` - Success
- `1` - No active ticket to release
- `2` - Failed to update state file
- `3` - Failed to add Linear comment

## Error Handling

The command handles:
- No active ticket claimed
- Missing WORKFLOW_STATE file
- Failed Linear API calls
- Invalid PR URL format
- Write permission errors

### No Active Ticket

```
Error: No active ticket to release

No ticket is currently claimed in WORKFLOW_STATE.

Options:
1. Claim a ticket: /claim CUR-XXX
2. Check workflow status: cat .git/WORKFLOW_STATE
```

### Missing WORKFLOW_STATE

```
Error: WORKFLOW_STATE file not found

No workflow state exists for this worktree.

Initialization:
1. Claim a ticket first: /claim CUR-XXX
2. Or create state manually: .git/WORKFLOW_STATE
```

### Linear API Error

```
Warning: Failed to add Linear comment

Ticket released successfully, but Linear comment failed.

Error: Invalid LINEAR_API_TOKEN

The ticket is released in workflow state.
To add PR link manually, use Linear UI.
```

### Invalid PR Arguments

```
Error: --pr-number requires --pr-url

Both arguments must be provided together.

Usage:
  /workflow:release "reason" --pr-number 42 --pr-url https://...
```

## Workflow Patterns

### Pattern 1: Complete Work

```bash
# 1. Complete implementation
# 2. Create PR
gh pr create --title "..." --body "..."

# 3. Release ticket with PR link
/workflow:release "Work complete" --pr-number 42 --pr-url https://...
```

### Pattern 2: Pause for Review

```bash
# 1. Submit for review
git push

# 2. Release while waiting
/workflow:release "Waiting for review"

# 3. Work on different ticket
/claim CUR-XXX

# 4. Resume later
/resume
```

### Pattern 3: Context Switch

```bash
# Quick switch to different ticket
/workflow:switch CUR-YYY "Higher priority work"

# (This internally calls release + claim)
```

## Best Practices

1. **Provide descriptive reasons**: Helps with `/resume` selection
2. **Link PRs when available**: Maintains traceability
3. **Release before switching**: Keeps workflow state clean
4. **Check history**: Review past releases with `/workflow:history`
5. **Use /switch for immediate context changes**: Combines release + claim

## Related Commands

- `/claim` - Claim ticket for work
- `/resume` - Resume previously released ticket
- `/workflow:switch` - Switch to different ticket (release + claim)
- `/workflow:history` - View release history

## Implementation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/release-ticket.sh "$@"
```

## Notes

- Requires git repository with WORKFLOW_STATE
- Release reason stored in history for context
- Works with both regular repos and git worktrees
- Released tickets remain in history for `/resume`
- PR comments are optional but recommended for traceability
- Linear integration requires LINEAR_API_TOKEN
- State updates are immediate (no undo)
