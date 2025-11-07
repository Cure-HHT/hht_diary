# /issue (alias for /ticket)

Alias for `/ticket` command. See `/ticket` for full documentation.

## Usage

```
/issue              # Show current active ticket
/issue new          # Create a new ticket
/issue CUR-XXX      # Switch to ticket CUR-XXX
```

## Implementation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/ticket-command.sh "$@"
```
