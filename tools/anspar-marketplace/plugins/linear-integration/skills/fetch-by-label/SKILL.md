# Fetch Tickets by Label

Retrieve all Linear tickets with a specific label, regardless of assignment.

## Usage

Fetch tickets with a label:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets-by-label.js --label="bug"
```

## Parameters
- `--label`: Label to filter by (required)
- `--format`: Output format (`json` or `human`, default: human)
- `--token`: Linear API token (or use environment)

## Examples

Get all bug tickets:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets-by-label.js --label="bug"
```

Get auto-created tickets as JSON:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets-by-label.js \
  --label="ai:new" \
  --format=json
```

Find infrastructure tickets:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets-by-label.js --label="infrastructure"
```

## Output

Human format shows:
- Ticket identifier and title
- Status and priority
- Project assignment
- Requirement references

JSON format returns full ticket data for processing.

## Notes
- Returns ALL tickets with label (not just assigned to you)
- Useful for finding tickets created by automation
- Can identify gaps in requirement coverage
- Helps track specific categories of work