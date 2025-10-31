# /linear-fetch

Fetch Linear tickets assigned to you

## Usage
```
/linear-fetch [--status=<status>] [--format=<format>]
```

## Options
- `--status`: Filter by status (all, backlog, active, blocked, done)
- `--format`: Output format (json or summary)

## Implementation
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js "$@"
```