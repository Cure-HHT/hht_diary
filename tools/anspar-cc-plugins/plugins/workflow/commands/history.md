---
name: history
description: View workflow action history
arguments: "[--limit=N] [--action=ACTION] [--format=human|json]"
---

# /workflow:history Command

View complete workflow history for this worktree, showing ticket claims, releases, and context switches.

## Purpose

The `/workflow:history` command provides visibility by:
- Displaying all workflow actions (claim, release, commit)
- Filtering by action type or time limit
- Supporting both human-readable and JSON output
- Helping identify patterns and recent work

## Usage

```bash
/workflow:history                          # Show all history
/workflow:history --limit=10               # Show last 10 actions
/workflow:history --action=claim           # Show only claims
/workflow:history --action=release         # Show only releases
/workflow:history --format=json            # Output as JSON
```

## Arguments

### `--limit=<N>` *(optional)*

Show only last N actions:
- Default: All actions
- Useful for recent activity
- Example: `--limit=10`

### `--action=<ACTION>` *(optional)*

Filter by action type:
- Values: `claim`, `release`, `commit`
- Shows only matching actions
- Example: `--action=claim`

### `--format=<FORMAT>` *(optional)*

Output format:
- `human` (default): Human-readable timeline
- `json`: Machine-readable JSON
- Example: `--format=json`

## Behavior

### History Tracking

Reads from WORKFLOW_STATE history array:
```json
{
  "history": [
    {
      "action": "claim",
      "ticketId": "CUR-320",
      "timestamp": "2025-11-19T10:00:00Z",
      "agent": "human"
    },
    {
      "action": "commit",
      "ticketId": "CUR-320",
      "timestamp": "2025-11-19T11:30:00Z",
      "message": "Add authentication module"
    },
    {
      "action": "release",
      "ticketId": "CUR-320",
      "timestamp": "2025-11-19T14:00:00Z",
      "reason": "Work complete"
    }
  ]
}
```

### Display Order

- **Chronological**: Newest actions first
- **Grouped by ticket**: Related actions clustered
- **Color-coded**: Claims (green), releases (yellow), commits (blue)

## Examples

### View All History

```bash
/workflow:history

# Output:
# Workflow History
# ================
#
# 2025-11-19 14:00:00  RELEASE  CUR-320
#   Reason: Work complete
#
# 2025-11-19 11:30:00  COMMIT   CUR-320
#   Message: Add authentication module
#
# 2025-11-19 10:00:00  CLAIM    CUR-320
#   Agent: human
#
# 2025-11-18 16:45:00  RELEASE  CUR-318
#   Reason: End of day
#
# 2025-11-18 14:20:00  CLAIM    CUR-318
#   Agent: claude
```

### Last 10 Actions

```bash
/workflow:history --limit=10

# Output:
# Workflow History (Last 10 Actions)
# ===================================
#
# [Shows most recent 10 actions...]
```

### Filter by Action Type

```bash
/workflow:history --action=claim

# Output:
# Workflow History (Claims Only)
# ===============================
#
# 2025-11-19 10:00:00  CLAIM    CUR-320
#   Agent: human
#
# 2025-11-18 14:20:00  CLAIM    CUR-318
#   Agent: claude
#
# 2025-11-17 09:15:00  CLAIM    CUR-315
#   Agent: human
```

### Releases with Reasons

```bash
/workflow:history --action=release

# Output:
# Workflow History (Releases Only)
# =================================
#
# 2025-11-19 14:00:00  RELEASE  CUR-320
#   Reason: Work complete
#
# 2025-11-18 16:45:00  RELEASE  CUR-318
#   Reason: End of day
#
# 2025-11-17 17:30:00  RELEASE  CUR-315
#   Reason: Blocked - waiting for review
```

### JSON Output

```bash
/workflow:history --limit=5 --format=json

# Output:
# {
#   "history": [
#     {
#       "action": "release",
#       "ticketId": "CUR-320",
#       "timestamp": "2025-11-19T14:00:00Z",
#       "reason": "Work complete"
#     },
#     {
#       "action": "commit",
#       "ticketId": "CUR-320",
#       "timestamp": "2025-11-19T11:30:00Z",
#       "message": "Add authentication module",
#       "sha": "abc123def456"
#     },
#     {
#       "action": "claim",
#       "ticketId": "CUR-320",
#       "timestamp": "2025-11-19T10:00:00Z",
#       "agent": "human"
#     }
#   ],
#   "count": 5
# }
```

## Integration Points

This command integrates with:
- **WORKFLOW_STATE**: Reads history array
- **Git hooks**: Commit actions recorded automatically
- **/resume**: Uses release history
- **Analytics tools**: JSON output for metrics

## Exit Codes

- `0` - Success
- `1` - No history found
- `2` - Invalid arguments
- `3` - Failed to read WORKFLOW_STATE

## Error Handling

The command handles:
- Missing WORKFLOW_STATE file
- Empty history array
- Invalid action type
- Invalid format
- Corrupted JSON

### No History Found

```
No workflow history found

WORKFLOW_STATE exists but contains no history.

This happens when:
1. No tickets have been claimed yet
2. History was manually cleared
3. Fresh worktree

Start working:
  /claim CUR-XXX
```

### No Matching Actions

```
No 'commit' actions found in history

History exists but no commit actions recorded.

This happens when:
1. No commits made with tickets claimed
2. Git hooks not installed
3. History filtered too narrowly

Check all history:
  /workflow:history
```

### Invalid Action Type

```
Error: Invalid action type 'invalid'

Valid action types:
  - claim
  - release
  - commit

Usage:
  /workflow:history --action=claim
```

## Use Cases

### Review Daily Work

```bash
# Morning review of yesterday's work
/workflow:history --limit=20

# Check what was worked on
```

### Track Context Switches

```bash
# See all ticket switches
/workflow:history --action=release

# Review reasons for pausing work
```

### Generate Work Report

```bash
# Export work history to file
/workflow:history --format=json > work-report.json

# Process with jq or other tools
cat work-report.json | jq '.history[] | select(.action == "commit")'
```

### Identify Blocked Work

```bash
# Find tickets released due to blockers
/workflow:history --action=release --format=json \
  | jq '.history[] | select(.reason | contains("Blocked"))'
```

## Analytics Examples

### Count Claims by Agent

```bash
/workflow:history --action=claim --format=json \
  | jq '[.history[] | .agent] | group_by(.) | map({agent: .[0], count: length})'

# Output:
# [
#   {"agent": "human", "count": 15},
#   {"agent": "claude", "count": 8}
# ]
```

### Find Most Worked Tickets

```bash
/workflow:history --format=json \
  | jq '[.history[] | .ticketId] | group_by(.) | map({ticket: .[0], actions: length}) | sort_by(.actions) | reverse'

# Output:
# [
#   {"ticket": "CUR-320", "actions": 12},
#   {"ticket": "CUR-318", "actions": 8},
#   {"ticket": "CUR-315", "actions": 5}
# ]
```

### Average Time Between Claim and Release

```bash
# Requires custom script processing JSON output
/workflow:history --format=json > history.json
python3 analyze_work_duration.py history.json
```

## Best Practices

1. **Review regularly**: Check history at end of day
2. **Use filters**: Focus on specific action types
3. **Export for analysis**: Use JSON format for reporting
4. **Track patterns**: Identify frequent context switches
5. **Document releases**: Provide meaningful release reasons

## Related Commands

- `/claim` - Records claim action in history
- `/workflow:release` - Records release action in history
- `/resume` - Uses release history
- `/workflow:switch` - Records both release and claim

## Implementation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-history.sh "$@"
```

## Notes

- History is per-worktree (not shared across worktrees)
- Commit actions added automatically by git hooks
- History grows unbounded (no automatic cleanup)
- JSON format useful for programmatic analysis
- Timestamps in ISO 8601 format (UTC)
- Color-coding in human format for readability
- Works with both regular repos and git worktrees
