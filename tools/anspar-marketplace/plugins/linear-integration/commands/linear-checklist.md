# /linear-checklist

Add requirement-based implementation checklists to Linear tickets.

## Usage
```
/linear-checklist <ticket-id> [options]
```

## Options
- `--from-requirement`: Use requirement from ticket description
- `--include-acceptance`: Add acceptance criteria
- `--include-subsystems`: Add subsystem-specific tasks
- `--dry-run`: Preview without updating

## Examples

Add checklist from ticket's requirement:
```
/linear-checklist CUR-312 --from-requirement
```

Full checklist with all options:
```
/linear-checklist CUR-312 --from-requirement --include-acceptance --include-subsystems
```

## Implementation
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/add-requirement-checklist.js \
  --ticketId="$1" \
  "${@:2}"
```