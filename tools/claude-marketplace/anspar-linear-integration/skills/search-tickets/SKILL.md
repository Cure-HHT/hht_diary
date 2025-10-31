# Search Linear Tickets

Search for Linear tickets by requirement ID, keywords, or any query.

## Usage

Search for tickets:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/search-tickets.js --query="search term"
```

## Parameters
- `--query`: Search query (required) - can be requirement ID, keywords, ticket ID
- `--format`: Output format (`json` or `summary`, default: summary)

## Examples

Find tickets for a requirement:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/search-tickets.js --query="REQ-d00027"
```

Search by keywords:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/search-tickets.js --query="marketplace plugin"
```

Get results as JSON:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/search-tickets.js --query="authentication" --format=json
```

## Notes
- Searches across ticket titles, descriptions, and comments
- Automatically extracts and displays requirement references found in tickets