# Requirement Traceability Command

You are assisting with requirement management and traceability for the diary clinical trial platform.

## Command Context

The user invoked the `/req` slash command. Parse their request and execute the appropriate action.

## Available Actions

### 1. Display Requirement Details
**Pattern**: `/req REQ-{type}{number}` (e.g., `/req REQ-p00042`)

**Action**:
1. Extract requirement ID from user input
2. Search `spec/INDEX.md` for the requirement
3. Display:
   - Requirement ID
   - File location
   - Title
   - Hash (for verification)
4. Show the full requirement text from the spec file
5. If requirement has associated Linear tickets, show ticket links

**Example**:
```
User: /req REQ-p00042
You: Looking up REQ-p00042...

📌 REQ-p00042
📄 File: prd-authentication.md
📝 Title: Multi-factor authentication via TOTP
🔑 Hash: a3f9c2...

📖 Content:
─────────────────────────────────────
### REQ-p00042: Multi-factor authentication via TOTP

**Priority**: High

**Description**:
Users must be able to enable multi-factor authentication...
─────────────────────────────────────

🎫 Linear Tickets:
- CUR-123: Implement TOTP MFA
```

### 2. Search Requirements
**Pattern**: `/req search <term>`

**Action**:
1. Search all `spec/*.md` files for the term
2. Find matching requirements
3. Display list with file locations and requirement IDs
4. Optionally show ticket associations

**Example**:
```
User: /req search authentication
You: Searching requirements for: authentication

Found 5 matching requirements:
📄 prd-authentication.md - REQ-p00042: Multi-factor authentication
📄 prd-authentication.md - REQ-p00043: Session timeout handling
📄 prd-security.md - REQ-p00089: Authentication audit logging
📄 dev-auth.md - REQ-d00127: JWT token implementation
📄 ops-security.md - REQ-o00034: Authentication service deployment
```

### 3. New Requirement Guide
**Pattern**: `/req new`

**Action**: Display step-by-step guide for creating a new requirement:

```markdown
📝 CREATE NEW REQUIREMENT

To create a new requirement:

1. **Claim a requirement number**:
   Go to GitHub → Actions → "Claim Requirement Number"
   This will assign you the next available REQ number

2. **Create the requirement file**:
   - PRD requirements: spec/prd-{topic}.md
   - Ops requirements: spec/ops-{topic}.md
   - Dev requirements: spec/dev-{topic}.md

3. **Use the standard format**:
   ### REQ-{type}{number}: Title

   **Priority**: {High|Medium|Low}

   **Description**:
   Detailed requirement description...

   **Acceptance Criteria**:
   - Criterion 1
   - Criterion 2

4. **Update the hash**:
   python3 tools/requirements/update-REQ-hashes.py --req-id={number}

5. **Add to INDEX.md**:
   python3 tools/requirements/add-missing-to-index.py

6. **Validate**:
   python3 tools/requirements/validate_requirements.py

See spec/README.md for full documentation.
```

### 4. Validate Requirements
**Pattern**: `/req validate`

**Action**:
1. Run validation script: `python3 tools/requirements/validate_requirements.py`
2. Display validation results
3. If errors found, show specific issues and suggested fixes

**Example**:
```
User: /req validate
You: Running requirement validation...

✓ Requirement format validation passed
✓ INDEX.md validation passed
✓ Hash validation passed

All requirements are valid!
```

### 5. Show Help (Default)
**Pattern**: `/req` (no arguments)

**Action**: Display usage summary and recent requirements:

```markdown
📋 REQUIREMENT MANAGEMENT

Usage:
  /req REQ-xxx          Display requirement details
  /req search <term>    Search for requirements
  /req new              Guide for creating new requirement
  /req validate         Validate all requirements

Recent requirements (last 5):
  REQ-p00156: Advanced filtering UI
  REQ-d00089: Database migration framework
  REQ-o00043: Production monitoring setup
  REQ-p00157: Export functionality
  REQ-d00090: Event sourcing implementation

📁 Total requirements: 87
```

## Traceability Integration

When displaying requirement details, also check traceability:

1. **Read cache**: Check `.requirement-cache.json` for ticket mappings
2. **Show tickets**: If requirement has tickets, list them
3. **Show status**: Indicate ticket status (Todo, In Progress, Done)
4. **Offer actions**: Suggest creating ticket if none exists

**Example**:
```
📌 REQ-p00042: Multi-factor authentication

🎫 Linear Tickets:
- CUR-123: Implement TOTP MFA [In Progress]
- CUR-145: MFA UI components [Done]

💡 Tip: Use `/ticket CUR-123` to view ticket details
```

## File Paths

All file paths are relative to repository root:
- Spec files: `/spec/*.md`
- Index: `/spec/INDEX.md`
- Validation script: `/tools/requirements/validate_requirements.py`
- Cache: `/.requirement-cache.json`

## Error Handling

### Requirement Not Found
```
❌ Requirement not found: REQ-p99999

The requirement may not exist, or INDEX.md may be out of sync.

💡 Try:
- /req search <keyword>
- Run: python3 tools/requirements/validate_index.py
```

### Invalid Format
```
❌ Invalid requirement ID format: REQ-x123

Expected format: REQ-{type}{number}
Where type is p (PRD), o (Ops), or d (Dev)
And number is 5 digits (e.g., REQ-p00042)
```

### Search No Results
```
❌ No requirements found matching: xyz123

💡 Try:
- Broader search terms
- Check spelling
- Search in ticket descriptions: /ticket search xyz123
```

## Integration with Other Plugins

### linear-integration Plugin
- Share cache file (`.requirement-cache.json`)
- Use ticket search: `/ticket search <term>`
- Link to tickets: `/ticket CUR-123`

### workflow Plugin
- When claiming tickets, show associated requirement
- Validate that commits reference correct requirements
- Link workflow state to requirement traceability

### simple-requirements Plugin
- Use same validation scripts
- Share requirement format knowledge
- Coordinate on requirement ID format

## Cache Management

The cache (`.requirement-cache.json`) stores requirement-to-ticket mappings.

**When to refresh**:
- Cache older than 24 hours
- After creating new tickets
- When traceability seems out of sync

**How to refresh**:
```bash
node tools/anspar-cc-plugins/plugins/requirement-traceability/scripts/create-req-tickets.js --refresh-cache --dry-run
```

## Best Practices

1. **Always validate** after modifying requirements
2. **Update INDEX.md** when adding new requirements
3. **Check traceability** before creating duplicate tickets
4. **Use search** to find requirements before creating new ones
5. **Link tickets** bidirectionally (requirement → ticket, ticket → requirement)

## Security Notes

- No sensitive data in cache (only IDs and mappings)
- Validation scripts are read-only
- API tokens via environment variables only
- Never commit tokens or credentials

---

**Execute the appropriate action based on the user's request.**
