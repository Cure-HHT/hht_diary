---
description: Add requirement references to Linear tickets
---

# Task: Add REQ References to Linear Tickets

You are assisting with adding formal requirement references to Linear tickets to maintain FDA-compliant traceability.

## Command Context

The user invoked the `/add-REQ-to-ticket` slash command. Parse their request and execute the appropriate action.

## Available Actions

### 1. Add REQ to Specific Ticket
**Pattern**: `/add-REQ-to-ticket CUR-XXX REQ-pNNNNN`

**Action**:
1. Validate the requirement exists:
   - Check `spec/INDEX.md` for the REQ-ID
   - Extract requirement metadata (title, file, hash)
2. Fetch the ticket from Linear to verify it exists
3. Add requirement reference to ticket description using:
   ```bash
   node tools/anspar-cc-plugins/plugins/linear-api/scripts/update-ticket.js \
     --ticketId=CUR-XXX \
     --add-requirement=REQ-pNNNNN
   ```
4. Confirm update and display ticket URL
5. Update cache (`.requirement-cache.json`)

**Example**:
```
User: /add-REQ-to-ticket CUR-123 REQ-p00042
You: Adding REQ-p00042 to ticket CUR-123...

✓ Requirement validated: REQ-p00042
  Title: Multi-factor authentication via TOTP
  File: prd-authentication.md

✓ Ticket fetched: CUR-123
  Title: Implement TOTP MFA

✓ Updated ticket description with requirement reference

🎫 Ticket URL: https://linear.app/cure-hht/issue/CUR-123
💾 Cache updated
```

### 2. Find Tickets Missing REQ References
**Pattern**: `/add-REQ-to-ticket --scan` or `/add-REQ-to-ticket scan`

**Action**:
1. Fetch all open tickets from Linear (status: Todo, In Progress)
2. Parse ticket descriptions for requirement references
3. Identify tickets without any REQ reference
4. Display list with suggestions

**Example**:
```
User: /add-REQ-to-ticket scan
You: Scanning Linear tickets for missing requirement references...

Found 15 tickets without REQ references:

📋 High Priority (5):
  • CUR-145: Implement user authentication
    💡 Suggested: REQ-p00001 (Multi-sponsor authentication)

  • CUR-156: Database schema for patients
    💡 Suggested: REQ-d00007 (Database schema implementation)

📋 Medium Priority (7):
  • CUR-167: Add MFA support
  • CUR-178: Create admin dashboard
  ...

📋 Low Priority (3):
  • CUR-189: Update documentation
  ...

Next steps:
1. Review suggestions above
2. Use /add-REQ-to-ticket CUR-XXX REQ-pNNNNN to add references
3. Or use /add-REQ-to-ticket --bulk to process multiple at once
```

### 3. Bulk Add REQs to Multiple Tickets
**Pattern**: `/add-REQ-to-ticket --bulk`

**Action**:
1. Read a mapping file (JSON or CSV) with ticket-to-requirement mappings
2. Validate all requirements exist
3. Show preview of changes (dry-run mode)
4. Prompt for confirmation
5. Execute updates in batch with rate limiting
6. Report results

**Mapping File Format** (JSON):
```json
{
  "mappings": [
    {
      "ticketId": "CUR-123",
      "reqId": "REQ-p00042",
      "note": "MFA implementation"
    },
    {
      "ticketId": "CUR-145",
      "reqId": "REQ-d00007",
      "note": "Database schema"
    }
  ]
}
```

**Example**:
```
User: /add-REQ-to-ticket --bulk mappings.json
You: Loading bulk mapping file: mappings.json

Found 12 ticket-to-requirement mappings:

Preview of changes:
  ✓ CUR-123 → REQ-p00042 (Multi-factor authentication)
  ✓ CUR-145 → REQ-d00007 (Database schema implementation)
  ✓ CUR-156 → REQ-p00025 (Patient enrollment workflow)
  ...

⚠️  2 warnings:
  • CUR-189: REQ-p99999 not found in INDEX.md
  • CUR-201: Already has REQ-p00001 reference

Proceed with updating 10 tickets? (y/n)
```

### 4. Add REQ with Full Implementation Checklist
**Pattern**: `/add-REQ-to-ticket CUR-XXX REQ-pNNNNN --with-checklist`

**Action**:
1. Validate requirement and ticket
2. Add requirement reference
3. Generate and add implementation checklist from requirement acceptance criteria
4. Update ticket description with both reference and checklist

Uses the existing `add-checklist.js` script:
```bash
# Extract short REQ ID (e.g., "p00042" from "REQ-p00042")
node tools/anspar-cc-plugins/plugins/requirement-traceability/scripts/add-checklist.js \
  CUR-XXX p00042
```

**Example**:
```
User: /add-REQ-to-ticket CUR-123 REQ-p00042 --with-checklist
You: Adding REQ-p00042 with implementation checklist to CUR-123...

✓ Requirement reference added
✓ Implementation checklist generated:

## Implementation Checklist

### Acceptance Criteria
- [ ] User can enable TOTP MFA
- [ ] QR code generation works
- [ ] Backup codes provided

### Database Changes
- [ ] Create mfa_tokens table
- [ ] Add migration script

### API Changes
- [ ] POST /auth/mfa/enable endpoint
- [ ] POST /auth/mfa/verify endpoint

### UI Changes
- [ ] MFA settings page
- [ ] QR code display component

### Testing
- [ ] Unit tests for TOTP generation
- [ ] Integration tests for MFA flow

🎫 Ticket updated: https://linear.app/cure-hht/issue/CUR-123
```

### 5. Interactive Mode
**Pattern**: `/add-REQ-to-ticket` (no arguments)

**Action**: Guide user through interactive selection:

```
User: /add-REQ-to-ticket
You: 📋 ADD REQUIREMENT TO TICKET

Choose an action:
1. Add REQ to specific ticket
2. Scan for tickets missing REQs
3. Bulk add from mapping file
4. Add REQ with implementation checklist
5. Help / Documentation

Enter number (1-5):
```

## Implementation Details

### Step 1: Validate Requirement

Before adding any REQ reference, validate it exists:

```bash
# Check spec/INDEX.md
grep "REQ-p00042" spec/INDEX.md

# Or use Python script
python3 -c "
import re
with open('spec/INDEX.md') as f:
    if 'REQ-p00042' in f.read():
        print('✓ Requirement exists')
    else:
        print('✗ Requirement not found')
        exit(1)
"
```

### Step 2: Extract REQ Metadata

Read from INDEX.md to get requirement details:

```bash
# Parse INDEX.md line for REQ-p00042
grep "| REQ-p00042" spec/INDEX.md | awk -F'|' '{print $2,$3,$4,$5}'
```

Expected output:
```
REQ-p00042 | prd-authentication.md | Multi-factor authentication via TOTP | a3f9c2...
```

### Step 3: Fetch Ticket from Linear

Use linear-api plugin:

```bash
node tools/anspar-cc-plugins/plugins/linear-api/scripts/fetch-tickets.js CUR-123
```

### Step 4: Update Ticket Description

Use update-ticket script with --add-requirement flag:

```bash
node tools/anspar-cc-plugins/plugins/linear-api/scripts/update-ticket.js \
  --ticketId=CUR-123 \
  --add-requirement=REQ-p00042
```

This prepends to the description:
```markdown
**Requirement**: REQ-p00042

[existing description...]
```

### Step 5: Update Cache

After successful update, refresh the cache:

```bash
# Option 1: Let the create-req-tickets script refresh cache
node tools/anspar-cc-plugins/plugins/requirement-traceability/scripts/create-req-tickets.js \
  --refresh-cache \
  --dry-run

# Option 2: Manually update cache JSON (for single ticket)
# Read cache, add mapping, write back
```

## Smart Suggestions

When scanning tickets without REQs, use heuristics to suggest requirements:

### Matching Strategy:
1. **Title matching**: Search requirement titles for keywords in ticket title
2. **Label matching**: Map Linear labels to requirement types
   - `backend` → Dev requirements
   - `database` → Database requirements
   - `security` → Security requirements
3. **Project matching**: Use project name to narrow scope
4. **Recent context**: Look at recently linked REQs in same project

### Example Matching Logic:

```javascript
function suggestRequirement(ticket) {
  const keywords = ticket.title.toLowerCase();

  // Database schema tickets
  if (keywords.includes('schema') || keywords.includes('database')) {
    return 'REQ-d00007'; // Database schema implementation
  }

  // Authentication tickets
  if (keywords.includes('auth') || keywords.includes('login')) {
    return 'REQ-p00001'; // Multi-sponsor authentication
  }

  // MFA tickets
  if (keywords.includes('mfa') || keywords.includes('multi-factor')) {
    return 'REQ-p00042'; // Multi-factor authentication
  }

  // Default: null (manual review needed)
  return null;
}
```

## Error Handling

### Requirement Not Found
```
❌ Error: Requirement REQ-p99999 not found

The requirement does not exist in spec/INDEX.md.

💡 Suggestions:
1. Check requirement ID format (REQ-{p|o|d}NNNNN)
2. Search for similar requirements: /req search <keyword>
3. Create new requirement: /req new
```

### Ticket Not Found
```
❌ Error: Ticket CUR-999 not found

The ticket does not exist in Linear or you don't have access.

💡 Suggestions:
1. Verify ticket ID (check Linear workspace)
2. Ensure LINEAR_API_TOKEN has correct permissions
3. Search for tickets: /ticket search <keyword>
```

### Ticket Already Has REQ
```
⚠️  Warning: Ticket CUR-123 already has requirement reference

Current requirement: REQ-p00001
Attempting to add: REQ-p00042

Actions:
1. Replace existing requirement (overwrite)
2. Add as related requirement (append)
3. Cancel

Enter number (1-3):
```

### API Rate Limit
```
⚠️  Rate limit approaching (90/100 requests)

Pausing for 10 seconds before continuing...

For bulk operations, consider:
- Smaller batches (max 20 tickets per run)
- Use --delay flag to increase pause between requests
- Run during off-peak hours
```

## Cache Management

The cache (`.requirement-cache.json`) stores bidirectional mappings:

```json
{
  "timestamp": 1699472834000,
  "mappings": {
    "p00042": ["CUR-123", "CUR-145"],
    "d00007": ["CUR-156"]
  },
  "reverse": {
    "CUR-123": ["REQ-p00042"],
    "CUR-145": ["REQ-p00042"],
    "CUR-156": ["REQ-d00007"]
  }
}
```

**Update Strategy**:
1. Read current cache
2. Add new mapping to both `mappings` and `reverse`
3. Update timestamp
4. Write back to file

## Integration with Other Commands

### Chain with /req
```
User: /req REQ-p00042
You: [Shows requirement details]

Related tickets:
  • CUR-123: Implement TOTP MFA [In Progress]
  • CUR-145: MFA UI components [Done]

💡 To add this REQ to a new ticket:
   /add-REQ-to-ticket CUR-XXX REQ-p00042
```

### Chain with /workflow
```
User: /workflow:claim CUR-123
You: [Claims ticket]

⚠️  This ticket has no requirement reference.

💡 Add a requirement:
   /add-REQ-to-ticket CUR-123 REQ-pNNNNN
```

## File Paths

All paths relative to repository root:
- Spec files: `spec/*.md`
- Index: `spec/INDEX.md`
- Cache: `.requirement-cache.json`
- Update script: `tools/anspar-cc-plugins/plugins/linear-api/scripts/update-ticket.js`
- Checklist script: `tools/anspar-cc-plugins/plugins/requirement-traceability/scripts/add-checklist.js`

## Best Practices

1. **Always validate** requirement exists before adding
2. **Use --with-checklist** for tickets in active development
3. **Scan regularly** to find tickets missing REQs
4. **Bulk operations** are faster but use dry-run first
5. **Update cache** after batch operations
6. **Add REQs early** in ticket lifecycle (ideally during creation)

## Security Notes

- LINEAR_API_TOKEN via environment variable only
- Cache contains no sensitive data (only IDs)
- Never commit API tokens
- Validate all inputs before API calls

## Example Workflows

### Workflow 1: New Ticket Creation
```
1. Create ticket in Linear (manual or via API)
2. /add-REQ-to-ticket CUR-XXX REQ-pNNNNN --with-checklist
3. /workflow:claim CUR-XXX
4. Implement with requirement traceability
```

### Workflow 2: Clean Up Existing Tickets
```
1. /add-REQ-to-ticket scan
2. Review suggested mappings
3. Create mapping file (mappings.json)
4. /add-REQ-to-ticket --bulk mappings.json
5. Verify in Linear
```

### Workflow 3: New Sprint Planning
```
1. Create tickets for high-priority requirements
2. /add-REQ-to-ticket --bulk sprint-N-mappings.json --with-checklist
3. Assign to team members
4. Each developer uses /workflow:claim to start work
```

---

**Execute the appropriate action based on the user's request.**
