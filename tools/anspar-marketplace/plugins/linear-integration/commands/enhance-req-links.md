# /enhance-req-links

Update Linear tickets to add clickable GitHub links for REQ references

## Usage

```bash
/enhance-req-links                       # Interactive prompt
/enhance-req-links CUR-329               # Update specific ticket
/enhance-req-links --all                 # Update all tickets (prompts for confirmation)
/enhance-req-links --all --dry-run       # Preview changes without updating
/enhance-req-links CUR-329 --dry-run     # Preview single ticket
```

## What it does

Scans ticket descriptions for `REQ-xxxxx` references and enhances them with:
- Relative file path (e.g., `spec/prd-portal.md`)
- Clickable GitHub link to exact line number
- Points to main branch (always current)

## Example Transformation

**Before:**
```markdown
**Requirement**: REQ-d00014
```

**After:**
```markdown
**Requirement**: REQ-d00014 - [spec/dev-requirements-management.md](https://github.com/Cure-HHT/hht_diary/blob/main/spec/dev-requirements-management.md#L29)
```

## Features

- **Idempotent**: Safe to run multiple times, skips REQs that already have links
- **Graceful**: Continues if some REQs aren't found in spec/
- **Smart replacement**: Preserves surrounding context, only enhances REQ reference
- **Dry-run mode**: Preview changes before applying
- **Bulk mode**: Update all tickets with one command

## Options

- `--dry-run`: Preview changes without updating tickets
- `--force`: Update even if REQ already has a link (re-generate link)
- `--all`: Process all tickets (prompts for confirmation unless --dry-run)

## Examples

### Update single ticket
```bash
/enhance-req-links CUR-240
```

### Preview bulk update
```bash
/enhance-req-links --all --dry-run
```

### Apply bulk update
```bash
/enhance-req-links --all
```

## Implementation

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/enhance-req-links.js "$@"
```

## Related

- `/ticket-fetch`: View ticket details
- See: CUR-329 for feature background
