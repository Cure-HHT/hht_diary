# /ticket (alias: /issue)

Manage Linear tickets with workflow integration

## Usage

```
/ticket              # Show current active ticket
/ticket new          # Create a new ticket (launches ticket-creation-agent)
/ticket CUR-XXX      # Switch to ticket CUR-XXX (claims it and sets status to In Progress)
```

## Examples

```
/ticket              # Returns: Active ticket: CUR-320 (core)
/ticket new          # Launches intelligent ticket creation agent
/ticket CUR-322      # Switches to CUR-322, updates Linear status
```

## Implementation

This command integrates with:
- **Workflow plugin**: For ticket claiming and state management
- **Linear API**: For status updates
- **Ticket-creation-agent**: For intelligent ticket creation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/ticket-command.sh "$@"
```
