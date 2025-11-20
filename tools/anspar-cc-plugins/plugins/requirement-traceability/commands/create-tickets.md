---
name: create-tickets
description: Bulk create Linear tickets for requirements
arguments: "[REQ-IDS...] [--dry-run] [--level=PRD|Ops|Dev]"
---

# /req:create-tickets Command

Bulk create Linear tickets for requirements that don't have associated tickets.

## Purpose

The `/req:create-tickets` command automates ticket creation by:
- Finding requirements without Linear tickets
- Creating tickets with requirement references
- Linking requirements to tickets bidirectionally
- Updating requirement-ticket cache
- Supporting dry-run mode for preview

## Usage

```bash
/req:create-tickets                        # Create tickets for all unmapped requirements
/req:create-tickets --dry-run              # Preview what would be created
/req:create-tickets --level=PRD            # Create tickets only for PRD requirements
/req:create-tickets REQ-p00042 REQ-p00043  # Create tickets for specific requirements
/req:create-tickets --refresh-cache        # Refresh cache from Linear
```

## Arguments

### `REQ-IDS` *(optional, multiple allowed)*

Specific requirement IDs to create tickets for:
- Format: `REQ-{p|o|d}NNNNN`
- Multiple IDs can be provided
- If omitted, processes all unmapped requirements
- Example: `REQ-p00042 REQ-d00027`

### `--dry-run` *(optional)*

Preview mode without creating tickets:
- Shows what would be created
- Validates requirements exist
- No Linear API calls made
- Example: `--dry-run`

### `--level=<LEVEL>` *(optional)*

Filter by requirement level:
- Values: `PRD`, `Ops`, `Dev`
- Creates tickets only for specified level
- Example: `--level=PRD`

### `--refresh-cache` *(optional)*

Force refresh of requirement-ticket cache:
- Fetches latest ticket-to-requirement mappings from Linear
- Updates `.requirement-cache.json`
- Useful after manual ticket creation
- Example: `--refresh-cache`

### `--project-id=<ID>` *(optional)*

Assign tickets to specific Linear project:
- Project ID or name
- Groups related requirements
- Example: `--project-id=AUTH-SPRINT`

## Behavior

### Discovery Process

1. **Reads spec/INDEX.md**: Gets all requirement IDs
2. **Reads cache**: Checks `.requirement-cache.json` for existing mappings
3. **Identifies gaps**: Finds requirements without tickets
4. **Fetches requirement details**: Extracts title, description from spec files
5. **Creates tickets**: Bulk creates via Linear API
6. **Updates cache**: Records new mappings

### Ticket Creation

For each unmapped requirement:
1. **Title**: Generated from requirement title
   - Format: `REQ-{id}: {title}`
   - Example: `REQ-p00042: Multi-factor authentication via TOTP`

2. **Description**: Includes requirement reference
   ```markdown
   **Requirement**: REQ-p00042

   [Requirement description from spec file...]

   **File**: spec/prd-authentication.md
   **Hash**: a3f9c2d1b8e6...
   ```

3. **Labels**: Auto-assigned based on requirement type
   - PRD requirements → `product`, `requirement`
   - Ops requirements → `operations`, `requirement`
   - Dev requirements → `development`, `requirement`

4. **Priority**: Default to `normal` (can be overridden)

### Cache Management

Updates `.requirement-cache.json`:
```json
{
  "timestamp": 1732032000000,
  "mappings": {
    "p00042": ["CUR-348", "CUR-349"],
    "d00027": ["CUR-350"]
  },
  "reverse": {
    "CUR-348": ["REQ-p00042"],
    "CUR-349": ["REQ-p00042"],
    "CUR-350": ["REQ-d00027"]
  }
}
```

## Examples

### Dry-Run Preview

```bash
/req:create-tickets --dry-run

# Output:
# Scanning spec/INDEX.md for requirements...
# Found 42 requirements total
#
# Checking cache for existing mappings...
# Found 25 requirements with tickets
#
# Would create tickets for 17 requirements:
#
# PRD Requirements (8):
#   REQ-p00042: Multi-factor authentication via TOTP
#   REQ-p00043: Session management and timeout
#   REQ-p00044: Role-based access control
#   ...
#
# Ops Requirements (5):
#   REQ-o00015: Database backup automation
#   REQ-o00016: SSL certificate renewal
#   ...
#
# Dev Requirements (4):
#   REQ-d00027: Workflow plugin state management
#   REQ-d00028: Event sourcing implementation
#   ...
#
# Run without --dry-run to create tickets.
```

### Create All Unmapped Tickets

```bash
/req:create-tickets

# Output:
# Scanning requirements...
# Found 17 unmapped requirements
#
# Creating tickets...
#
# ✅ CUR-348: REQ-p00042: Multi-factor authentication via TOTP
#    https://linear.app/cure-hht/issue/CUR-348
#
# ✅ CUR-349: REQ-p00043: Session management and timeout
#    https://linear.app/cure-hht/issue/CUR-349
#
# ✅ CUR-350: REQ-d00027: Workflow plugin state management
#    https://linear.app/cure-hht/issue/CUR-350
#
# ...
#
# Created 17 tickets successfully!
# Cache updated: .requirement-cache.json
```

### Create Tickets for Specific Requirements

```bash
/req:create-tickets REQ-p00042 REQ-p00043

# Output:
# Creating tickets for 2 requirements...
#
# ✅ CUR-348: REQ-p00042: Multi-factor authentication via TOTP
#    https://linear.app/cure-hht/issue/CUR-348
#
# ✅ CUR-349: REQ-p00043: Session management and timeout
#    https://linear.app/cure-hht/issue/CUR-349
#
# Created 2 tickets successfully!
# Cache updated
```

### Filter by Level

```bash
/req:create-tickets --level=PRD

# Output:
# Creating tickets for PRD requirements only...
#
# ✅ CUR-348: REQ-p00042: Multi-factor authentication via TOTP
# ✅ CUR-349: REQ-p00043: Session management and timeout
# ✅ CUR-350: REQ-p00044: Role-based access control
#
# Created 3 PRD tickets successfully!
```

### Refresh Cache

```bash
/req:create-tickets --refresh-cache --dry-run

# Output:
# Refreshing cache from Linear...
#
# Fetching all tickets with REQ references...
# Found 25 tickets with requirement references
#
# Updated cache:
#   25 requirements mapped to tickets
#   3 tickets reference multiple requirements
#
# Cache refreshed: .requirement-cache.json
#
# Scanning for unmapped requirements...
# [Shows unmapped requirements...]
```

## Integration Points

This command integrates with:
- **spec/INDEX.md**: Source of requirement IDs
- **.requirement-cache.json**: Bidirectional mapping storage
- **Linear API**: Ticket creation
- **linear-api/lib/ticket-creator**: Reusable creation module
- **/req:scan**: Finds tickets missing requirements

## Exit Codes

- `0` - Success (tickets created or dry-run completed)
- `1` - No unmapped requirements found
- `2` - Linear API error
- `3` - Invalid requirement IDs provided

## Error Handling

The command validates:
- LINEAR_API_TOKEN is set
- spec/INDEX.md exists
- Requirement IDs are valid
- Team ID is configured
- Cache file is writable

### No Unmapped Requirements

```
All requirements have associated tickets!

Total requirements: 42
Mapped to tickets: 42
Unmapped: 0

Use --refresh-cache to update mappings from Linear.
```

### Requirement Not Found

```
Error: Requirement REQ-p99999 not found

The requirement does not exist in spec/INDEX.md.

Available requirements:
  REQ-p00001 - REQ-p00050 (PRD)
  REQ-o00001 - REQ-o00025 (Ops)
  REQ-d00001 - REQ-d00035 (Dev)

Check requirement ID and try again.
```

### Linear API Error

```
Error: Failed to create ticket for REQ-p00042

Linear API error: Rate limit exceeded (60 requests/minute)

Options:
1. Wait 60 seconds and retry
2. Use --dry-run to preview first
3. Create tickets in smaller batches
```

### Missing API Token

```
Error: LINEAR_API_TOKEN not set

Set environment variable:
  export LINEAR_API_TOKEN="your-token-here"

Or configure via Doppler:
  doppler run -- claude
```

## Best Practices

1. **Use dry-run first**: Preview before bulk creation
2. **Filter by level**: Create tickets incrementally
3. **Refresh cache regularly**: Keep mappings current
4. **Review created tickets**: Verify in Linear UI
5. **Update ticket details**: Add assignees, projects manually
6. **Link related requirements**: Use requirement references

## Related Commands

- **/req:scan** - Find tickets missing requirement references
- **/add-REQ-to-ticket** - Add requirement to existing ticket
- **/linear:create** - Create single ticket manually
- **/requirements:report** - Generate requirement reports

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/../requirement-traceability/scripts/create-req-tickets.js "$@"
```

## Notes

- Requires LINEAR_API_TOKEN environment variable
- Team ID auto-discovered if not configured
- Cache updated automatically after creation
- Supports up to 100 tickets per run (Linear API limit)
- Rate limiting: 60 requests per minute
- Tickets created in "Todo" state by default
- Requirement hash included in ticket description
- Works with both regular and sponsor-specific requirements
