# /ticket-fetch

Fetch and display Linear ticket details by ID or current active ticket

## Usage
```
/ticket-fetch                # Fetch current active ticket from workflow state
/ticket-fetch CUR-240        # Fetch specific ticket by ID
/ticket-fetch CUR-240 CUR-241 CUR-242  # Fetch multiple tickets
```

## Options
- No arguments: Fetches the current active ticket from workflow state
- One or more ticket IDs: Fetches the specified ticket(s)

## Examples
- `/ticket-fetch` - Display current active ticket details
- `/ticket-fetch CUR-240` - Display details for ticket CUR-240
- `/ticket-fetch CUR-240 CUR-241` - Display details for multiple tickets

## Implementation
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/ticket-fetch.js "$@"
```
