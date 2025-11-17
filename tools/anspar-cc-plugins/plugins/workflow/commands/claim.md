---
name: claim
description: Claim a ticket for this worktree and begin work
arguments: "<TICKET-ID> [AGENT-TYPE] [SPONSOR]"
---

# /claim Command

Claim a ticket for this worktree by creating/updating the workflow state file (WORKFLOW_STATE) with the active ticket information.

## Purpose

The `/claim` command initiates work on a specific ticket by:
- Creating or updating the workflow state tracking file
- Recording ticket ownership and context (human/claude, sponsor if applicable)
- Optionally fetching requirements from Linear
- Setting up traceability for requirement linking

## Usage

```bash
/claim CUR-262                    # Claim ticket for core functionality work
/claim CUR-262 claude             # Claim ticket as Claude agent
/claim CUR-262 human carina       # Claim ticket for Carina sponsor-specific work
/claim CUR-262 claude callisto    # Claim ticket for Callisto sponsor work as Claude
```

## Arguments

### `TICKET-ID` *(required)*

The ticket identifier to claim (e.g., CUR-262, PROJ-123)
- Format: PROJECT-NUMBER
- Must match pattern: `[A-Z]+-[0-9]+`

### `AGENT-TYPE` *(optional)*

Who is claiming the ticket:
- `human` (default) - Human developer
- `claude` - Claude AI agent

### `SPONSOR` *(optional)*

Sponsor context for sponsor-specific work:
- Omit for core functionality work
- Provide sponsor name for sponsor-specific implementations
- Must match an existing sponsor directory in `sponsor/`

## Behavior

### State Management

1. **Checks existing state**: If a ticket is already claimed, prompts to release it first
2. **Creates/updates WORKFLOW_STATE**: Records ticket claim in `.git/WORKFLOW_STATE`
3. **Tracks history**: Adds claim action to workflow history
4. **Validates sponsor**: Ensures sponsor directory exists if specified

### Linear Integration

If Linear integration is available (`LINEAR_API_TOKEN` set):
- Attempts to fetch ticket requirements
- Optionally updates Linear ticket status to "In Progress"

### Output

- Shows worktree path, branch, and claimed ticket details
- Displays current workflow state as JSON
- Provides tips for next steps (requirement linking)

## Examples

### Core Functionality Work

```bash
/claim CUR-320
# Claims CUR-320 for core platform development
# No sponsor context
```

### Sponsor-Specific Work

```bash
/claim CUR-321 human orion
# Claims CUR-321 for Orion sponsor-specific features
# Context isolated to sponsor/orion/
```

### Claude Agent Work

```bash
/claim CUR-322 claude
# Claims CUR-322 with Claude as the active agent
# Useful for AI-driven development workflows
```

## Integration Points

This command integrates with:
- **Workflow plugin hooks**: State validation in PreToolUse hooks
- **Linear integration plugin**: For ticket fetching and status updates
- **Requirement tracking**: Prepares for REQ reference linking

## State File Location

```
.git/WORKFLOW_STATE
```

This file tracks:
- Active ticket ID
- Claimed timestamp
- Agent type (human/claude)
- Sponsor context (if applicable)
- Requirement references
- Action history

## Exit Codes

- `0` - Success
- `1` - Invalid arguments or validation error
- `2` - Failed to fetch requirements
- `3` - Failed to update state file

## Error Handling

The command validates:
- ✅ Ticket ID format
- ✅ Agent type (human or claude)
- ✅ Sponsor directory exists (if specified)
- ✅ State file is writable

## Best Practices

1. **Always claim before starting work**: Ensures workflow tracking
2. **Use correct agent type**: Helps distinguish human vs AI contributions
3. **Specify sponsor for sponsor work**: Maintains isolation
4. **Check for existing claims**: Prevents accidental ticket conflicts

## Related Commands

- `/resume` - Resume work on a previously released ticket
- `/ticket` - Alias for ticket management (linear-api plugin)

## Implementation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/claim-ticket.sh "$@"
```

## Notes

- Requires git repository
- Works with both regular repos and git worktrees
- State is per-worktree (supports parallel work)
- Sponsor validation uses dynamic directory discovery
