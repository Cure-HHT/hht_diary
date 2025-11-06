# List Available Labels

Fetch all available labels from your Linear workspace to see what can be applied to tickets.

## Usage

List all labels:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/list-labels.js
```

Filter labels by prefix:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/list-labels.js --filter="ai:"
```

## Parameters
- `--filter`: Optional prefix to filter labels (e.g., "ai:", "status:", "type:")
- `--format`: Output format: "list" (default) or "json"

## Examples

### Get all labels
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/list-labels.js
```

Output:
```
Available Linear labels:
  ai:new - Tickets created by AI
  ai:reviewed - AI-reviewed tickets
  bug - Bug reports
  enhancement - Feature improvements
  documentation - Documentation tasks
  technical-debt - Code refactoring needs
```

### Get AI-related labels
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/list-labels.js --filter="ai:"
```

### Get labels as JSON
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/list-labels.js --format=json
```

## Notes
- Labels are team-specific
- Shows label name and description
- Useful before creating tickets to ensure correct label names
- Helps discover workflow labels (e.g., status labels)