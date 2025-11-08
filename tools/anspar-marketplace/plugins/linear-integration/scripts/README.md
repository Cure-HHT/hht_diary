# Linear CLI Tool

Command-line tool for fetching and analyzing Linear tickets. Designed to help Claude (and you) understand your ticket backlog and decide what to work on next.

## Features

- ✅ Fetches all assigned Linear tickets
- ✅ Categorizes by status (Backlog, Todo, In Progress, Blocked, etc.)
- ✅ Extracts requirement references (REQ-p00001, etc.) from descriptions and comments
- ✅ Identifies high-priority and overdue items
- ✅ Shows parent/child relationships
- ✅ Provides summary statistics

## Setup

### 1. Get Linear API Token

1. Go to [Linear Settings > API](https://linear.app/settings/api)
2. Create a new Personal API Key
3. Copy the token (starts with `lin_api_`)

### 2. Set Environment Variable (Recommended)

```bash
export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"
```

Or add to your `~/.bashrc` or `~/.zshrc`:
```bash
echo 'export LINEAR_API_TOKEN="YOUR_LINEAR_TOKEN"' >> ~/.bashrc
source ~/.bashrc
```

## Usage

### Basic Usage (Summary Format)

```bash
node fetch-tickets.js
```

### Specify Token Directly

```bash
node fetch-tickets.js --token=YOUR_LINEAR_TOKEN
```

### JSON Output

```bash
node fetch-tickets.js --format=json
```

### Filter by Status

```bash
node fetch-tickets.js --status=active    # Show only active work
node fetch-tickets.js --status=blocked   # Show only blocked items
node fetch-tickets.js --status=backlog   # Show only backlog
```

## Output

The summary format provides:

1. **Statistics**: Total issues, items with requirements, high priority count, overdue count
2. **Status Breakdown**: Count of issues in each state
3. **In Progress**: Current work items
4. **In Review**: Items awaiting review
5. **Blocked**: Items that are blocked
6. **High Priority Todo/Backlog**: Urgent and high-priority items to tackle next
7. **Overdue Items**: Past-due items that need attention

Each issue displays:
- Identifier and title
- Priority level and status
- URL for quick access
- Linked requirements (REQ-p00001, etc.)
- Labels, due dates, parent/child relationships

## Example Output

```
================================================================================
LINEAR TICKETS SUMMARY - John Doe (john@example.com)
================================================================================

STATISTICS:
  Total Issues:          42
  With Requirements:     18
  High Priority:         5
  Overdue:               2
  Parent Issues:         3
  Sub-tasks:             8

STATUS BREAKDOWN:
  Backlog:               15
  Todo:                  8
  In Progress:           4
  In Review:             2
  Blocked:               1
  Done:                  12

--------------------------------------------------------------------------------
IN PROGRESS
--------------------------------------------------------------------------------

  PROJ-123: Implement user authentication
    Priority: P1 (Urgent) | Status: In Progress | Mobile App
    URL: https://linear.app/team/issue/PROJ-123
    Requirements: REQ-p00001, REQ-o00042, REQ-d00019
    Labels: backend, security
    Due: 2025-10-28

  PROJ-124: Fix database migration
    Priority: P2 (High) | Status: In Progress
    URL: https://linear.app/team/issue/PROJ-124
    Requirements: REQ-d00007
```

## Updating Ticket Status

### update-ticket-status.js

Update a ticket's status (Todo, In Progress, Done, Backlog, Canceled) via Linear API.

**Usage:**
```bash
node update-ticket-status.js --token=$LINEAR_API_TOKEN --ticket-id=<CUR-XXX> --status=<status>
```

**Status Options:**
- `todo` - Move to Todo (unstarted)
- `in-progress` - Move to In Progress (started)
- `done` - Move to Done (completed)
- `backlog` - Move to Backlog
- `canceled` - Move to Canceled

**Examples:**
```bash
# Mark ticket as in progress when starting work
node update-ticket-status.js --token=$LINEAR_API_TOKEN --ticket-id=CUR-127 --status=in-progress

# Mark ticket as done when complete
node update-ticket-status.js --token=$LINEAR_API_TOKEN --ticket-id=CUR-127 --status=done

# Move ticket back to backlog if blocked
node update-ticket-status.js --token=$LINEAR_API_TOKEN --ticket-id=CUR-186 --status=backlog
```

**Workflow:**
1. When starting a ticket: `--status=in-progress`
2. When completing: `--status=done`
3. If blocked: `--status=todo` or `--status=backlog` (add comment explaining blocker)

## Integration with Claude

Claude can run these scripts to:

1. **Understand your backlog**: See what tickets are assigned to you
2. **Identify priorities**: Find high-priority and overdue items
3. **Link to requirements**: See which tickets have requirement references
4. **Decide what to work on**: Help prioritize based on status, priority, and due dates
5. **Update ticket status**: Automatically move tickets through workflow states

### Example Claude Workflow

```bash
# Claude fetches tickets to understand your work
node tools/anspar-marketplace/plugins/linear-integration/scripts/fetch-tickets.js

# Claude suggests which ticket to work on based on:
# - Current workload (in-progress count)
# - Priorities and due dates
# - Requirement coverage
# - Dependencies (parent/child relationships)

# When starting work, Claude updates status
node tools/anspar-marketplace/plugins/linear-integration/scripts/update-ticket-status.js --token=$LINEAR_API_TOKEN --ticket-id=CUR-127 --status=in-progress

# After completing implementation, Claude marks it done
node tools/anspar-marketplace/plugins/linear-integration/scripts/update-ticket-status.js --token=$LINEAR_API_TOKEN --ticket-id=CUR-127 --status=done
```

## Requirements

- Node.js (version with fetch API support, v18+)
- Linear account with API access
- Internet connection

## Troubleshooting

### "Linear API token required"
Set the `LINEAR_API_TOKEN` environment variable or use `--token=<token>`

### "Linear API error: 401"
Your API token is invalid or expired. Get a new one from Linear settings.

### "Linear API error: 403"
Your API token doesn't have permission. Ensure you're using a Personal API Key.

### "GraphQL errors"
Check that your Linear account has access to the queried data.

## Development

The script uses the Linear GraphQL API directly (no SDK dependencies) to:
- Keep it lightweight and fast
- Reduce dependencies
- Make it easy for Claude to run

## License

MIT
