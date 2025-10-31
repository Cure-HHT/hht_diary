# Create Requirement Tickets

Batch create Linear tickets from formal requirements in spec/ directory.

## Usage

Create tickets for all unmapped requirements:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --team-id=$LINEAR_TEAM_ID
```

## Parameters
- `--token`: Linear API token (or use environment)
- `--team-id`: Linear team ID (or use environment)
- `--dry-run`: Preview tickets without creating
- `--level`: Only create for specific level (PRD, Ops, Dev)
- `--project-id`: Assign tickets to a specific project

## Examples

Dry run to see what would be created:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-requirement-tickets.js --dry-run
```

Create only PRD-level tickets:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-requirement-tickets.js --level=PRD
```

Create and assign to project:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-requirement-tickets.js \
  --project-id="abc123" \
  --level=Dev
```

## Process
1. Scans all spec/*.md files for requirements
2. Checks which requirements already have tickets
3. Creates tickets for unmapped requirements
4. Sets priority by level (PRD=P1, Ops=P2, Dev=P3)
5. Adds appropriate labels based on keywords
6. Links requirements in ticket description

## Notes
- Maintains exclusion list to prevent duplicates
- Adds "ai:new" label to auto-created tickets
- Preserves requirement hierarchy in descriptions
- Safe to run multiple times (idempotent)