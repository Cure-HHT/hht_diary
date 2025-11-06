# Fetch Linear Tickets

Retrieve tickets assigned to you from Linear.

## Usage

Fetch all your assigned tickets:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js
```

With options:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js --format=json --status=active
```

## Parameters
- `--format`: Output format (`json` or `summary`, default: summary)
- `--status`: Filter by status (`all`, `backlog`, `active`, `blocked`, `done`)
- `--token`: Linear API token (or use environment/config)

## Examples

Get active tickets as JSON:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js --status=active --format=json
```

Get all tickets with summary view:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js --status=all
```