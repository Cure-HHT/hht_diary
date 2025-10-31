# Create Linear Ticket

Create a new Linear ticket with proper requirement linking and metadata.

## Usage

Create a ticket:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-single-ticket.js \
  --title="Title" \
  --description="Description" \
  --priority=3
```

## Parameters
- `--title`: Ticket title (required)
- `--description`: Ticket description in Markdown (required)
- `--priority`: Priority level (0-4, where 0=none, 1=urgent, 2=high, 3=normal, 4=low)
- `--labels`: Comma-separated labels (e.g., "bug,frontend")
- `--project-id`: Linear project ID to assign ticket to
- `--team-id`: Override default team ID

## Examples

Create a feature ticket:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-single-ticket.js \
  --title="Implement user authentication" \
  --description="Add OAuth2 authentication\n\nImplements: REQ-p00002" \
  --priority=2 \
  --labels="feature,security"
```

Create a bug ticket:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-single-ticket.js \
  --title="Fix login redirect loop" \
  --description="Users stuck in redirect loop after login\n\nSteps to reproduce:\n1. Login\n2. Navigate to /dashboard\n3. Observe redirect loop" \
  --priority=1 \
  --labels="bug,urgent"
```

## Notes
- Returns the created ticket ID and URL
- Automatically links requirements mentioned in description
- Can be claimed with anspar-workflow after creation