---
name: search
description: Search Linear tickets by query string
arguments: "--query=<SEARCH-TERM> [--format=summary|json]"
---

# /linear:search Command

Search Linear tickets using keyword queries or requirement IDs.

## Purpose

The `/linear:search` command finds tickets by:
- Searching titles and descriptions for keywords
- Finding tickets by requirement ID (REQ-XXXXX)
- Filtering by status, priority, or labels
- Supporting both summary and JSON output formats

## Usage

```bash
/linear:search --query="authentication"
/linear:search --query="REQ-p00042"
/linear:search --query="security backend" --format=json
```

## Arguments

### `--query=<SEARCH-TERM>` *(required)*

Search query string:
- Keywords: Searches title and description
- REQ-ID: Finds tickets referencing requirement
- Multiple terms: Combines with AND logic
- Example: `--query="login bug"` or `--query="REQ-p00042"`

### `--format=<FORMAT>` *(optional)*

Output format:
- `summary` (default): Human-readable summary
- `json`: Machine-readable JSON
- Example: `--format=json`

## Behavior

### Search Scope

Searches across:
- Ticket titles
- Ticket descriptions
- Requirement references (REQ-IDs)
- Comments (if available)

### Search Logic

- **Case-insensitive**: "Security" matches "security"
- **Partial matches**: "auth" matches "authentication"
- **Multi-word**: Multiple terms are AND'ed together
- **REQ-ID specific**: Extracts exact requirement references

### Result Sorting

Results sorted by:
1. Priority (urgent → high → normal → low)
2. Status (In Progress → Todo → Backlog)
3. Updated date (most recent first)

## Examples

### Search by Keyword

```bash
/linear:search --query="authentication"

# Output:
# Found 5 tickets matching "authentication":
#
# CUR-240 [In Progress] High
#   Implement multi-factor authentication
#   Labels: security, backend
#
# CUR-156 [Todo] Normal
#   Update authentication documentation
#   Labels: docs
#
# CUR-89 [Done] High
#   Fix authentication redirect bug
#   Labels: backend, bug
# ...
```

### Search by Requirement ID

```bash
/linear:search --query="REQ-p00042"

# Output:
# Found 3 tickets implementing REQ-p00042:
#
# CUR-240 [In Progress] High
#   Implement multi-factor authentication
#   Requirement: REQ-p00042
#   Labels: security, backend
#
# CUR-241 [Todo] Normal
#   Add MFA backup codes
#   Requirement: REQ-p00042
#   Labels: security
#
# CUR-242 [Done] Normal
#   MFA settings UI
#   Requirement: REQ-p00042
#   Labels: frontend, ui
```

### Search Multiple Keywords

```bash
/linear:search --query="database migration"

# Output:
# Found 2 tickets matching "database migration":
#
# CUR-262 [Done] High
#   Database migration for user roles
#   Labels: backend, database
#
# CUR-345 [In Progress] Normal
#   Migration script for MFA tokens
#   Labels: backend, database, security
```

### JSON Output

```bash
/linear:search --query="security" --format=json

# Output:
# {
#   "query": "security",
#   "count": 5,
#   "tickets": [
#     {
#       "id": "CUR-240",
#       "title": "Implement multi-factor authentication",
#       "status": "In Progress",
#       "priority": "High",
#       "labels": ["security", "backend"],
#       "url": "https://linear.app/cure-hht/issue/CUR-240"
#     },
#     ...
#   ]
# }
```

## Integration Points

This command integrates with:
- **Linear API**: GraphQL search queries
- **Requirement traceability**: REQ-ID extraction
- **linear-api/lib/graphql-client**: Reusable query module

## Exit Codes

- `0` - Success (results found)
- `1` - No results found
- `2` - Invalid query or API error
- `3` - Authentication error

## Error Handling

The command validates:
- Query parameter is provided
- LINEAR_API_TOKEN is set
- Format is valid (summary or json)
- API responses are valid

### Missing Query

```
Error: Query required

Usage:
  /linear:search --query="search term"

Examples:
  /linear:search --query="authentication"
  /linear:search --query="REQ-p00042"
```

### No Results Found

```
No tickets found matching "nonexistent-term"

Suggestions:
1. Check spelling
2. Try broader keywords
3. Use requirement ID: --query="REQ-XXXXX"
4. Search all tickets: /linear:search --query="" --format=json
```

### Authentication Error

```
Error: LINEAR_API_TOKEN invalid or missing

Set environment variable:
  export LINEAR_API_TOKEN="your-token-here"

Or configure via Doppler:
  doppler run -- claude
```

## Advanced Search Patterns

### Search for Tickets with Labels

```bash
/linear:search --query="backend security"
# Finds tickets with both terms in title/description
```

### Search by Ticket State

Linear search doesn't directly filter by state, but results show state:
```bash
/linear:search --query="bug" --format=summary
# Review results manually or use jq to filter JSON
```

### Find All Tickets for Requirement

```bash
/linear:search --query="REQ-d00027" --format=json | jq '.tickets[] | .id'
# Lists all ticket IDs implementing REQ-d00027
```

## Best Practices

1. **Use specific keywords**: Narrow search scope
2. **Search by REQ-ID**: Find all tickets for requirement
3. **Use JSON for scripting**: Parse results programmatically
4. **Check priority/status**: Focus on active work
5. **Verify requirement references**: Ensure traceability

## Related Commands

- `/linear:fetch` - Fetch specific ticket details
- `/linear:create` - Create new ticket
- `/req:scan` - Find tickets missing REQ references
- `/claim` - Claim ticket from search results

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/../linear-api/scripts/search-tickets.js "$@"
```

## Notes

- Requires LINEAR_API_TOKEN environment variable
- Search limited to team's tickets
- Results capped at 100 tickets (Linear API limit)
- REQ-ID search uses regex pattern matching
- JSON format useful for automation
- Summary format optimized for readability
