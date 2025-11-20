---
name: create
description: Create a Linear ticket interactively
arguments: "--title=<TITLE> [OPTIONS]"
---

# /linear:create Command

Create a Linear ticket with title, description, labels, and priority.

## Purpose

The `/linear:create` command creates new Linear tickets by:
- Accepting title and description (inline or from file)
- Supporting labels, priority, project, and assignee settings
- Validating all inputs before creation
- Returning ticket URL and identifier for tracking

## Usage

```bash
/linear:create --title="Fix login bug"
/linear:create --title="Add MFA support" --description="Implement TOTP multi-factor authentication"
/linear:create --title="Database migration" --description-file=/path/to/description.md --priority=high
/linear:create --title="New feature" --labels="backend,security" --priority=P1
```

## Arguments

### `--title=<TITLE>` *(required)*

The ticket title:
- Must be descriptive and concise
- Format: Plain text string
- Example: `--title="Implement user authentication"`

### `--description=<TEXT>` *(optional)*

Ticket description as inline text:
- Supports markdown formatting
- Can include requirement references
- Example: `--description="Add TOTP MFA following REQ-p00042"`

### `--description-file=<PATH>` *(optional)*

Read description from file:
- Path to markdown file
- Useful for longer descriptions
- Example: `--description-file=./ticket-description.md`

### `--priority=<LEVEL>` *(optional)*

Ticket priority:
- Values: `urgent`, `high`, `normal`, `low` (or `0-4`, `P1-P4`)
- Default: `normal`
- Example: `--priority=high` or `--priority=P1`

### `--labels=<LABELS>` *(optional)*

Comma-separated label names:
- Labels must exist in Linear workspace
- Use `/linear:labels` to see available labels
- Example: `--labels="backend,security,ai:claude"`

### `--project=<PROJECT>` *(optional)*

Project name or ID:
- Assigns ticket to specific project
- Example: `--project="Authentication Sprint"`

### `--assignee=<EMAIL>` *(optional)*

Assignee email or ID:
- Assigns ticket to team member
- Example: `--assignee="developer@company.com"`

## Behavior

### Validation

1. **Checks LINEAR_API_TOKEN**: Ensures token is set in environment
2. **Validates team ID**: Auto-discovers if not configured
3. **Validates labels**: Checks labels exist before creation
4. **Validates priority**: Normalizes priority format

### Creation Flow

1. Parse command-line arguments
2. Validate required fields (title)
3. Load description from file if `--description-file` used
4. Resolve label names to IDs
5. Resolve priority to Linear format
6. Create ticket via GraphQL API
7. Display ticket URL and identifier

### Output

Shows ticket details:
- Ticket identifier (e.g., CUR-123)
- Ticket URL
- Title
- Priority
- Labels
- Project (if assigned)

## Examples

### Basic Ticket

```bash
/linear:create --title="Fix logout redirect"

# Output:
# Created ticket: CUR-345
# Title: Fix logout redirect
# Priority: Normal
# URL: https://linear.app/cure-hht/issue/CUR-345
```

### Ticket with Description

```bash
/linear:create \
  --title="Implement database migration for MFA" \
  --description="Add mfa_tokens table with TOTP secret storage"

# Output:
# Created ticket: CUR-346
# Title: Implement database migration for MFA
# Priority: Normal
# URL: https://linear.app/cure-hht/issue/CUR-346
```

### High-Priority Ticket with Labels

```bash
/linear:create \
  --title="Critical: Password reset broken" \
  --description="Users unable to reset passwords via email" \
  --priority=urgent \
  --labels="security,backend,bug"

# Output:
# Created ticket: CUR-347
# Title: Critical: Password reset broken
# Priority: Urgent
# Labels: security, backend, bug
# URL: https://linear.app/cure-hht/issue/CUR-347
```

### Ticket from Description File

```bash
/linear:create \
  --title="REQ-p00042: Multi-factor authentication" \
  --description-file=spec/prd-authentication.md \
  --labels="security,backend" \
  --priority=P1

# Output:
# Created ticket: CUR-348
# Title: REQ-p00042: Multi-factor authentication
# Priority: High (P1)
# Labels: security, backend
# URL: https://linear.app/cure-hht/issue/CUR-348
```

### Ticket with Project and Assignee

```bash
/linear:create \
  --title="Design MFA settings UI" \
  --project="Authentication Sprint" \
  --assignee="designer@company.com" \
  --labels="frontend,ui"

# Output:
# Created ticket: CUR-349
# Title: Design MFA settings UI
# Project: Authentication Sprint
# Assignee: designer@company.com
# Labels: frontend, ui
# URL: https://linear.app/cure-hht/issue/CUR-349
```

## Integration Points

This command integrates with:
- **Linear API**: For ticket creation
- **linear-api/lib/ticket-creator**: Reusable ticket creation module
- **linear-api/lib/label-manager**: Label resolution
- **Workflow plugin**: Created tickets can be claimed via `/claim`

## Exit Codes

- `0` - Success
- `1` - Invalid arguments or validation error
- `2` - Linear API error (authentication, rate limit)
- `3` - Failed to create ticket

## Error Handling

The command validates:
- LINEAR_API_TOKEN is set
- Title is provided
- Labels exist in workspace
- Priority format is valid
- Description file exists (if specified)
- Team ID is configured or discoverable

### Missing API Token

```
Error: LINEAR_API_TOKEN not set

Set environment variable:
  export LINEAR_API_TOKEN="your-token-here"

Or configure via Doppler:
  doppler run -- claude
```

### Invalid Label

```
Error: Label 'invalid-label' not found

Available labels:
  - backend
  - frontend
  - security
  - ai:claude

Use /linear:labels to see all available labels.
```

### Invalid Priority

```
Error: Invalid priority 'super-urgent'

Valid priorities:
  - urgent (P0)
  - high (P1)
  - normal (P2)
  - low (P3)
  - Or use: 0, 1, 2, 3, 4, P0, P1, P2, P3, P4
```

## Best Practices

1. **Use descriptive titles**: Makes tickets searchable
2. **Include requirement references**: Link to REQ-IDs when applicable
3. **Set appropriate priority**: Don't overuse urgent/high
4. **Use labels consistently**: Follow team conventions
5. **Reference related tickets**: Mention dependencies in description
6. **Add to projects**: Group related work

## Related Commands

- `/linear:fetch` - Fetch ticket details
- `/linear:update` - Update existing ticket
- `/linear:search` - Search tickets
- `/linear:labels` - List available labels
- `/claim` - Claim ticket for work

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/../linear-api/scripts/create-ticket.js "$@"
```

## Notes

- Requires LINEAR_API_TOKEN environment variable
- Team ID auto-discovered from token if not configured
- Labels are case-sensitive
- Created tickets start in default state (usually "Todo")
- URL format: `https://linear.app/{workspace}/issue/{identifier}`
