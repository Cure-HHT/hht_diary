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
node tools/claude-marketplace/anspar-linear-integration/scripts/fetch-tickets.js "$@"
```