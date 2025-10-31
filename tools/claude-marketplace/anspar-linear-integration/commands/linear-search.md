# /linear-search

Search Linear tickets by requirement ID or keyword

## Usage
```
/linear-search <query>
```

## Examples
- `/linear-search REQ-d00027` - Find tickets for a requirement
- `/linear-search "marketplace plugin"` - Search by keywords

## Implementation
```bash
node tools/claude-marketplace/anspar-linear-integration/scripts/search-tickets.js --query="$1"
```