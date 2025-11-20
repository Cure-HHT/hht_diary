---
name: labels
description: List all available Linear labels in workspace
arguments: "[--filter=PREFIX] [--format=list|json]"
---

# /linear:labels Command

List all available labels in the Linear workspace for ticket tagging.

## Purpose

The `/linear:labels` command displays labels by:
- Listing all labels available in Linear workspace
- Filtering labels by prefix or pattern
- Showing label names for ticket creation/updates
- Supporting both human-readable and JSON output

## Usage

```bash
/linear:labels                          # List all labels
/linear:labels --filter=ai:             # Filter labels by prefix
/linear:labels --format=json            # Output as JSON
/linear:labels --filter=backend --format=list
```

## Arguments

### `--filter=<PREFIX>` *(optional)*

Filter labels by prefix:
- Matches label names starting with prefix
- Case-insensitive
- Example: `--filter=ai:` matches "ai:claude", "ai:gpt"

### `--format=<FORMAT>` *(optional)*

Output format:
- `list` (default): Human-readable list
- `json`: Machine-readable JSON
- Example: `--format=json`

## Behavior

### Label Discovery

1. Queries Linear GraphQL API for all labels
2. Retrieves label name, color, description
3. Sorts alphabetically by name
4. Applies filter if specified

### Output Formats

**List format** (default):
```
Available labels:

  backend           - Backend/server work
  frontend          - Frontend/UI work
  security          - Security-related
  ai:claude         - AI-assisted by Claude
  ai:gpt            - AI-assisted by GPT
  bug               - Bug fix
  feature           - New feature
  docs              - Documentation
```

**JSON format**:
```json
{
  "labels": [
    {
      "name": "backend",
      "color": "#1E90FF",
      "description": "Backend/server work"
    },
    {
      "name": "frontend",
      "color": "#FF6347",
      "description": "Frontend/UI work"
    }
  ],
  "count": 8
}
```

## Examples

### List All Labels

```bash
/linear:labels

# Output:
# Available labels:
#
#   ai:claude         - AI-assisted by Claude
#   ai:gpt            - AI-assisted by GPT
#   backend           - Backend/server work
#   bug               - Bug fix
#   docs              - Documentation
#   feature           - New feature
#   frontend          - Frontend/UI work
#   security          - Security-related
#
# Total: 8 labels
```

### Filter by Prefix

```bash
/linear:labels --filter=ai:

# Output:
# Available labels (filtered by "ai:"):
#
#   ai:claude         - AI-assisted by Claude
#   ai:gpt            - AI-assisted by GPT
#
# Total: 2 labels
```

### JSON Output

```bash
/linear:labels --format=json

# Output:
# {
#   "labels": [
#     {
#       "name": "backend",
#       "color": "#1E90FF",
#       "description": "Backend/server work"
#     },
#     ...
#   ],
#   "count": 8
# }
```

### Filter and JSON Combined

```bash
/linear:labels --filter=backend --format=json

# Output:
# {
#   "labels": [
#     {
#       "name": "backend",
#       "color": "#1E90FF",
#       "description": "Backend/server work"
#     }
#   ],
#   "count": 1
# }
```

## Integration Points

This command integrates with:
- **Linear API**: GraphQL label queries
- **linear-api/lib/label-manager**: Label management module
- **/linear:create**: Used to find labels for ticket creation
- **/linear:update**: Used to find labels for ticket updates

## Exit Codes

- `0` - Success
- `1` - No labels found (or none matching filter)
- `2` - Linear API error
- `3` - Authentication error

## Error Handling

The command handles:
- Missing LINEAR_API_TOKEN
- Empty label list
- Invalid filter patterns
- API authentication errors
- Network timeouts

### Authentication Error

```
Error: LINEAR_API_TOKEN invalid or missing

Set environment variable:
  export LINEAR_API_TOKEN="your-token-here"

Or configure via Doppler:
  doppler run -- claude
```

### No Labels Found

```
No labels found matching filter "nonexistent"

Available filters:
  - ai:
  - backend
  - frontend
  - security

Use /linear:labels to see all labels.
```

### Empty Workspace

```
Warning: No labels configured in workspace

Labels help organize tickets by category.

Create labels in Linear:
  1. Go to Settings → Labels
  2. Add labels (e.g., backend, frontend, security)
  3. Run /linear:labels to verify
```

## Label Naming Conventions

### Common Label Patterns

**Category labels**:
- `backend` - Backend/API work
- `frontend` - UI/client work
- `database` - Database changes
- `infra` - Infrastructure

**Type labels**:
- `bug` - Bug fix
- `feature` - New feature
- `refactor` - Code refactoring
- `docs` - Documentation

**Priority labels**:
- `urgent` - Urgent work
- `blocker` - Blocking issue

**AI labels** (for Claude Code integration):
- `ai:claude` - Work assisted by Claude
- `ai:gpt` - Work assisted by GPT
- `ai:copilot` - Work assisted by Copilot

**Sponsor labels** (for multi-sponsor projects):
- `sponsor:carina` - Carina-specific
- `sponsor:callisto` - Callisto-specific

## Best Practices

1. **Check labels before creating tickets**: Ensure consistency
2. **Use standard prefixes**: Group related labels (ai:, sponsor:)
3. **Filter for relevant labels**: Narrow list for specific contexts
4. **Use JSON for scripting**: Parse labels programmatically
5. **Document label meanings**: Add descriptions in Linear

## Related Commands

- `/linear:create` - Create ticket with labels
- `/linear:update` - Update ticket labels
- `/linear:search` - Search tickets (labels appear in results)

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/../linear-api/scripts/list-labels.js "$@"
```

## Notes

- Requires LINEAR_API_TOKEN environment variable
- Labels are workspace-wide (shared across teams)
- Label colors displayed in JSON but not in list format
- Filter is case-insensitive
- Labels are sorted alphabetically
- No label limit (shows all workspace labels)
