# Requirement Traceability Plugin

**Diary-specific requirement-to-ticket traceability for FDA-compliant clinical trial platform**

This plugin maintains bidirectional traceability between formal requirements in `spec/` files and Linear tickets (CUR-*, ENG-*, OPS-*), ensuring compliance with 21 CFR Part 11 requirements for requirement traceability.

## Prerequisites

- [Development Prerequisites](../../../../docs/development-prerequisites.md) - Required tools (jq, Node.js)
- [Linear API Configuration](../linear-api/README.md) - Setting up Linear API access
- [Git Workflow](../../../../docs/git-workflow.md) - Understanding requirement references in commits

## Purpose

In FDA-regulated software development, every feature must be traceable to a formal requirement. This plugin:

1. **Creates Linear tickets** for requirements that don't have tickets yet
2. **Generates implementation checklists** based on requirement acceptance criteria
3. **Maintains cross-references** between related requirements and their tickets
4. **Caches mappings** to avoid redundant API calls and respect rate limits

## Diary Project Context

### Requirement Format

Requirements in the diary project follow this structure in `spec/` files:

```markdown
### REQ-{type}{number}: Brief Title

**Priority**: {High|Medium|Low}

**Description**:
Detailed requirement description explaining what needs to be built.

**Acceptance Criteria**:
- Criterion 1: Specific, testable condition
- Criterion 2: Another measurable condition
- Criterion 3: Final validation point

**Related Requirements**:
- REQ-p00001: Authentication framework
- REQ-d00042: Database schema
```

Where:
- `{type}` is one of: `p` (Product/PRD), `o` (Operations), `d` (Development)
- `{number}` is a zero-padded 5-digit number (e.g., `00001`, `00042`, `00156`)

### Spec Directory Structure

The `spec/` directory is organized by audience:

| File Pattern | Audience | Code Examples? |
| --- | --- | --- |
| `prd-*.md` | Product team, stakeholders | **NO** - Only descriptions |
| `ops-*.md` | Operations, deployment | CLI commands OK |
| `dev-*.md` | Developers, implementation | **YES** - Full code examples |

Each spec file contains multiple related requirements grouped by topic (e.g., `prd-authentication.md`, `dev-event-sourcing.md`).

### Complete Index

`spec/INDEX.md` maintains a complete, hash-verified index of all requirements:

```markdown
| REQ-ID | File | Title | Hash |
| --- | --- | --- | --- |
| REQ-p00001 | prd-authentication.md | Multi-sponsor user authentication | a3f9c2... |
| REQ-p00042 | prd-authentication.md | Multi-factor authentication via TOTP | b7e4d1... |
...
```

## Architecture

### Cache Location

**CRITICAL**: Cache is stored in **project root**, not plugin directory:

```
/.requirement-cache.json
```

**Rationale**:
- Shared across all plugins that need requirement mappings
- Included in project-level `.gitignore` (not plugin-level)
- Accessible from any working directory via `process.cwd()`
- Survives plugin updates and reinstalls

### Cache Structure

```json
{
  "timestamp": 1699472834000,
  "mappings": {
    "p00001": ["CUR-42", "CUR-87"],
    "p00042": ["CUR-123"],
    "d00089": ["ENG-56", "ENG-91"]
  },
  "metadata": {
    "totalIssues": 342,
    "totalMappings": 87,
    "lastRefresh": "2024-11-08T15:23:54.000Z"
  }
}
```

**Cache Lifecycle**:
- **Created**: On first run of any traceability script
- **Refreshed**: Automatically when older than 24 hours
- **Reused**: When fresh (< 24 hours old)
- **Manual refresh**: `--refresh-cache` flag

### Dependency on linear-api

This plugin depends on the `linear-api` plugin for:

| Module | Purpose |
| --- | --- |
| `lib/graphql-client.js` | Linear GraphQL API client |
| `lib/ticket-creator.js` | Ticket creation with templates |
| `lib/label-manager.js` | Label creation and assignment |
| `lib/env-validation.js` | LINEAR_API_TOKEN validation |

**Installation Check**:
Before using this plugin, verify `linear-api` is installed:
```bash
ls tools/anspar-cc-plugins/plugins/linear-api/
```

## Usage

### 1. Create Tickets for Requirements

Create Linear tickets for all requirements that don't have tickets yet:

```bash
# Always dry-run first to preview
node scripts/create-req-tickets.js --dry-run

# Create tickets (interactive confirmation)
node scripts/create-req-tickets.js

# Filter by file
node scripts/create-req-tickets.js --file spec/prd-authentication.md --dry-run

# Filter by priority
node scripts/create-req-tickets.js --priority High --dry-run

# Filter by type (p/o/d)
node scripts/create-req-tickets.js --type p --dry-run

# Force cache refresh
node scripts/create-req-tickets.js --refresh-cache --dry-run
```

**What it does**:
1. Parses all `spec/*.md` files for requirements
2. Checks cache for existing ticket mappings
3. Excludes requirements that already have tickets
4. Creates Linear tickets with:
   - Title: `[REQ-{type}{number}] {requirement title}`
   - Description: Full requirement text
   - Labels: `requirement`, `{type}` (PRD/Ops/Dev), `{priority}`
   - Team assignment based on requirement type

**Output**:
```
📋 REQUIREMENT TICKET CREATION

Reading cache... ✓ Using cached mappings (2h old, 87 requirements)

Parsing spec files...
  ✓ spec/prd-authentication.md (12 requirements)
  ✓ spec/prd-database.md (8 requirements)
  ✓ spec/dev-event-sourcing.md (15 requirements)
  ...

Total requirements: 87
Requirements with tickets: 62
Requirements without tickets: 25

[DRY RUN] Would create 25 tickets:
  1. [REQ-p00156] Advanced filtering UI
  2. [REQ-d00089] Database migration framework
  3. [REQ-o00043] Production monitoring setup
  ...

Run without --dry-run to create tickets.
```

### 2. Add Implementation Checklist

Add a detailed implementation checklist to an existing ticket:

```bash
# Add checklist for REQ-p00042 to ticket CUR-123
node scripts/add-checklist.js CUR-123 p00042

# Dry-run mode
node scripts/add-checklist.js CUR-123 p00042 --dry-run
```

**What it does**:
1. Reads requirement from `spec/` files
2. Generates checklist from acceptance criteria
3. Adds subsystem-specific tasks (database, API, UI, etc.)
4. Updates ticket description with checklist

**Generated Checklist Format**:
```markdown
## Implementation Checklist

### Acceptance Criteria
- [ ] Criterion 1: User can enable TOTP MFA
- [ ] Criterion 2: QR code generation works
- [ ] Criterion 3: Backup codes provided

### Database Changes
- [ ] Create `mfa_tokens` table
- [ ] Add migration script
- [ ] Update RLS policies

### API Changes
- [ ] POST /auth/mfa/enable endpoint
- [ ] POST /auth/mfa/verify endpoint
- [ ] GET /auth/mfa/backup-codes endpoint

### UI Changes
- [ ] MFA settings page
- [ ] QR code display component
- [ ] Backup code download

### Testing
- [ ] Unit tests for TOTP generation
- [ ] Integration tests for MFA flow
- [ ] E2E tests for UI

### Documentation
- [ ] Update API docs
- [ ] Add user guide for MFA setup
- [ ] Update ops deployment guide
```

### 3. Enhance Requirement Cross-References

Scan tickets for requirement references and add links to related tickets:

```bash
# Dry-run first
node scripts/enhance-links.js --dry-run

# Execute updates
node scripts/enhance-links.js

# Process specific ticket
node scripts/enhance-links.js --ticket CUR-123 --dry-run
```

**What it does**:
1. Scans all tickets for requirement references (e.g., "See REQ-p00001")
2. Looks up tickets that implement those requirements
3. Adds clickable links to related tickets
4. Updates ticket descriptions with enhanced cross-references

**Before**:
```markdown
**Description**:
This feature depends on REQ-p00001 (authentication framework)
and extends REQ-d00042 (database schema).
```

**After**:
```markdown
**Description**:
This feature depends on REQ-p00001 (authentication framework) → CUR-42
and extends REQ-d00042 (database schema) → ENG-56, ENG-91.

**Related Tickets**:
- CUR-42: Implement authentication framework (REQ-p00001)
- ENG-56: Database schema v1 (REQ-d00042)
- ENG-91: Database schema v2 (REQ-d00042)
```

## Skills

Skills are executable wrappers for use with Claude Code agents:

| Skill | Script | Purpose |
| --- | --- | --- |
| `create-req-tickets.skill` | `scripts/create-req-tickets.js` | Create tickets for requirements |
| `add-checklist.skill` | `scripts/add-checklist.js` | Add implementation checklist |
| `enhance-links.skill` | `scripts/enhance-links.js` | Enhance cross-references |

**Usage in Agent**:
```bash
./skills/create-req-tickets.skill --dry-run
./skills/add-checklist.skill CUR-123 p00042
./skills/enhance-links.skill --dry-run
```

## Slash Commands

The plugin provides two slash commands for requirement management and traceability:

### `/req` - Requirement Management

Quick access to requirement information:

#### Display Requirement
```
/req REQ-p00042
```
Shows:
- Requirement ID, file, title, hash
- Full requirement text
- Associated Linear tickets
- Ticket status

#### Search Requirements
```
/req search authentication
```
Finds all requirements matching "authentication" and shows:
- File locations
- Requirement IDs
- Associated tickets

#### New Requirement Guide
```
/req new
```
Displays step-by-step guide for creating new requirements.

#### Validate Requirements
```
/req validate
```
Runs `tools/requirements/validate_requirements.py` and shows results.

#### Help
```
/req
```
Shows usage summary and recent requirements.

### `/add-REQ-to-ticket` - Link Requirements to Tickets

Add formal requirement references to Linear tickets:

#### Add REQ to Specific Ticket
```
/add-REQ-to-ticket CUR-123 REQ-p00042
```
Validates requirement and adds reference to ticket description.

#### Add REQ with Implementation Checklist
```
/add-REQ-to-ticket CUR-123 REQ-p00042 --with-checklist
```
Adds requirement reference AND generates implementation checklist from acceptance criteria.

#### Scan for Tickets Missing REQs
```
/add-REQ-to-ticket scan
```
Finds all open tickets without requirement references and suggests matches.

#### Bulk Add REQs
```
/add-REQ-to-ticket --bulk mappings.json
```
Processes multiple ticket-to-requirement mappings from a file.

#### Interactive Mode
```
/add-REQ-to-ticket
```
Guides you through adding REQ references with prompts.

## Installation

### Prerequisites

1. **linear-api plugin installed**:
   ```bash
   ls tools/anspar-cc-plugins/plugins/linear-api/
   ```

2. **LINEAR_API_TOKEN environment variable**:
   ```bash
   export LINEAR_API_TOKEN="lin_api_..."
   # Or use Doppler:
   doppler run -- claude
   ```

3. **Node.js dependencies** (if not already installed):
   ```bash
   cd tools/anspar-cc-plugins/plugins/linear-api
   npm install
   ```

### Enable Plugin

Add to `.claude-plugins.json` (or let Claude Code auto-discover):
```json
{
  "plugins": [
    "tools/anspar-cc-plugins/plugins/linear-api",
    "tools/anspar-cc-plugins/plugins/requirement-traceability"
  ]
}
```

### Verify Installation

```bash
# Test cache creation
node tools/anspar-cc-plugins/plugins/requirement-traceability/scripts/create-req-tickets.js --dry-run

# Expected output: Cache creation and requirement parsing
```

## Examples

### Example 1: Batch Ticket Creation for New Sprint

**Scenario**: Create tickets for all high-priority PRD requirements.

```bash
# 1. Preview high-priority requirements
node scripts/create-req-tickets.js --type p --priority High --dry-run

# 2. Review output (shows ~12 requirements)

# 3. Create tickets
node scripts/create-req-tickets.js --type p --priority High

# 4. Verify in Linear (12 new tickets with "requirement" label)
```

**Result**:
- 12 tickets created in Linear
- Each ticket has requirement label, PRD label, High priority
- Tickets automatically assigned to Product team
- Cache updated with new mappings

### Example 2: Add Checklist to Implementation Ticket

**Scenario**: Developer claimed ticket CUR-123 for REQ-p00042 (MFA implementation).

```bash
# 1. Add implementation checklist
node scripts/add-checklist.js CUR-123 p00042

# 2. Developer sees checklist in Linear ticket:
#    - Acceptance criteria
#    - Database changes
#    - API endpoints
#    - UI components
#    - Tests

# 3. Developer checks off items as they complete them
```

**Benefit**: Structured implementation guide derived directly from requirement.

### Example 3: Cross-Reference Cleanup

**Scenario**: Many tickets reference requirements but don't link to related tickets.

```bash
# 1. Dry-run to preview changes
node scripts/enhance-links.js --dry-run

# Expected output: List of tickets that will be updated

# 2. Execute updates
node scripts/enhance-links.js

# 3. Verify in Linear: Tickets now have "Related Tickets" sections
```

**Result**: Improved navigation between related tickets via requirement links.

### Example 4: Using with Agent

**Scenario**: Ask Claude Code agent to create tickets for authentication requirements.

**User**: "Create tickets for all authentication requirements"

**Agent**:
```
I'll create Linear tickets for all requirements in spec/prd-authentication.md.
Let me start with a dry-run to preview.

[Executes: ./skills/create-req-tickets.skill --file spec/prd-authentication.md --dry-run]

Found 12 authentication requirements:
- REQ-p00001: Multi-sponsor user authentication
- REQ-p00042: Multi-factor authentication via TOTP
- REQ-p00043: Session timeout handling
...

8 requirements already have tickets.
4 requirements need tickets created.

Shall I proceed with creating the 4 tickets?
```

**User**: "Yes, proceed"

**Agent**:
```
[Executes: ./skills/create-req-tickets.skill --file spec/prd-authentication.md]

✓ Created 4 tickets:
- CUR-256: [REQ-p00089] Session refresh mechanism
- CUR-257: [REQ-p00090] Password complexity rules
- CUR-258: [REQ-p00091] Account lockout after failed attempts
- CUR-259: [REQ-p00092] Audit logging for auth events

Cache updated. All authentication requirements now have tickets.
```

## Troubleshooting

### Cache Not Found or Stale

**Symptoms**: Scripts create cache on every run.

**Solution**: Check cache file permissions and location:
```bash
ls -la /.requirement-cache.json
# Should be in project root, not plugin directory
```

**Fix**:
```bash
# Remove old cache (if in wrong location)
rm tools/anspar-cc-plugins/plugins/requirement-traceability/config/requirement-ticket-cache.json

# Run script to create new cache in correct location
node tools/anspar-cc-plugins/plugins/requirement-traceability/scripts/create-req-tickets.js --dry-run
```

### Linear API Token Not Found

**Symptoms**: Error: "LINEAR_API_TOKEN environment variable not set"

**Solution**:
```bash
# Option 1: Use Doppler (recommended)
doppler run -- claude

# Option 2: Export manually (not recommended for security)
export LINEAR_API_TOKEN="lin_api_..."
```

### Requirement Not Found

**Symptoms**: "Requirement REQ-p00042 not found in spec/"

**Possible Causes**:
1. Requirement doesn't exist (typo in ID)
2. INDEX.md out of sync with spec files
3. Requirement format incorrect

**Solution**:
```bash
# Validate requirement format
python3 tools/requirements/validate_requirements.py

# Rebuild INDEX.md
python3 tools/requirements/add-missing-to-index.py

# Check specific file
grep -n "REQ-p00042" spec/*.md
```

### Duplicate Tickets Created

**Symptoms**: Multiple tickets for same requirement.

**Possible Causes**:
1. Cache was stale or corrupted
2. Ticket description doesn't have `**Requirement**: REQ-xxx` format
3. Manual ticket creation bypassed cache

**Solution**:
```bash
# Refresh cache
node scripts/create-req-tickets.js --refresh-cache --dry-run

# Check for duplicates in Linear
# Search: "REQ-p00042" in Linear search bar

# If duplicates exist, manually merge or close duplicates
```

### Rate Limit Exceeded

**Symptoms**: "Linear API rate limit exceeded" error.

**Solution**:
- Scripts include 100ms delays between requests
- Wait 1 hour before retrying
- Use cache (don't force refresh unless necessary)
- Process requirements in smaller batches (--file flag)

## Integration with Other Plugins

### workflow Plugin

The workflow plugin enforces ticket claiming before commits. Integration:

1. **Claim ticket with requirement**:
   ```bash
   /workflow:claim CUR-123
   # Workflow checks if CUR-123 has requirement reference
   # Shows: "This ticket implements REQ-p00042"
   ```

2. **Validate commit message**:
   ```bash
   git commit -m "Implement MFA

   Implements: REQ-p00042"
   # Workflow validates REQ reference matches active ticket
   ```

### linear-api Plugin

Shared modules:
- `lib/graphql-client.js` - GraphQL API client
- `lib/ticket-creator.js` - Ticket creation
- `lib/label-manager.js` - Label management

Shared cache:
- Both plugins read/write `.requirement-cache.json`

Slash commands:
- `/req REQ-p00042` - Show requirement details (includes tickets if present)

### simple-requirements Plugin

Shared validation:
- Both use `tools/requirements/validate_requirements.py`
- Both understand REQ-{type}{number} format
- Both parse `spec/INDEX.md`

Workflow:
1. `simple-requirements` validates requirement format
2. `requirement-traceability` creates tickets from valid requirements
3. `workflow` ensures commits reference both tickets and requirements

## Cache Management

### Cache File Location

**Correct**: `/.requirement-cache.json` (project root)
**Incorrect**: `tools/anspar-cc-plugins/plugins/requirement-traceability/config/requirement-ticket-cache.json`

### Cache Lifecycle

```
First Run:
  ├─ Cache not found
  ├─ Fetch all tickets from Linear
  ├─ Parse descriptions for REQ-* references
  ├─ Build mappings dictionary
  ├─ Write to /.requirement-cache.json
  └─ Return mappings

Subsequent Runs (< 24h):
  ├─ Read cache
  ├─ Check timestamp
  ├─ Timestamp fresh? → Use cached mappings
  └─ Return mappings

Subsequent Runs (> 24h):
  ├─ Read cache
  ├─ Check timestamp
  ├─ Timestamp stale? → Refresh from Linear
  ├─ Update cache
  └─ Return fresh mappings

Manual Refresh:
  ├─ --refresh-cache flag
  ├─ Ignore cache age
  ├─ Fetch from Linear
  ├─ Update cache
  └─ Return fresh mappings
```

### Cache Invalidation

**When to manually refresh**:
1. After creating many tickets manually in Linear
2. After bulk updating ticket descriptions
3. When traceability seems incorrect (missing mappings)
4. After recovering from API errors

**How to refresh**:
```bash
node scripts/create-req-tickets.js --refresh-cache --dry-run
```

## Security Considerations

### API Token Management

**DO**:
- Store token in environment variable: `LINEAR_API_TOKEN`
- Use Doppler for secret management: `doppler run -- claude`
- Never commit tokens to git

**DON'T**:
- Hardcode tokens in scripts
- Commit `.env` files with tokens
- Share tokens via Slack/email

### Cache Safety

The cache contains:
- ✓ Requirement IDs (public)
- ✓ Ticket identifiers (public)
- ✓ Timestamp metadata (public)

The cache does NOT contain:
- ✗ API tokens
- ✗ User data
- ✗ Sensitive requirement content

**Safe to commit?** No, but only because it's generated data (like node_modules).

### GitIgnore

Ensure `.gitignore` includes:
```
.requirement-cache.json
```

## Future Enhancements

Planned features:
- [ ] Detect requirement changes and flag tickets for update
- [ ] Generate traceability matrix in HTML/PDF format
- [ ] Sync requirement acceptance criteria with ticket checklists
- [ ] Validate that closed tickets have implemented requirements verified
- [ ] Integration with GitHub PRs (link commits to tickets and requirements)
- [ ] Requirement change history tracking
- [ ] Automatic ticket updates when requirements change
- [ ] Traceability dashboard (web UI)

## Contributing

This plugin is part of the diary clinical trial platform monorepo.

**Development**:
1. Clone repo: `git clone https://github.com/anspar/diary.git`
2. Install dependencies: `cd tools/anspar-cc-plugins/plugins/linear-api && npm install`
3. Create feature branch: `git checkout -b feature/req-traceability-xyz`
4. Make changes
5. Test: `node scripts/create-req-tickets.js --dry-run`
6. Commit with REQ reference: `git commit -m "... Implements: REQ-d00xxx"`
7. Push and create PR

**Testing**:
```bash
# Dry-run mode for all scripts
node scripts/create-req-tickets.js --dry-run
node scripts/add-checklist.js CUR-123 p00042 --dry-run
node scripts/enhance-links.js --dry-run

# Cache tests
node -e "const cache = require('./lib/requirement-cache.js'); cache.getRequirementMappings(process.env.LINEAR_API_TOKEN).then(console.log)"
```

## License

MIT License - see repository root for details.

## Support

- **Issues**: https://github.com/anspar/diary/issues
- **Documentation**: https://github.com/anspar/diary/tree/main/docs
- **Linear Workspace**: https://linear.app/anspar

## Related Documentation

- [Workflow Plugin](../workflow/README.md) - Git workflow enforcement
- [Linear API Plugin](../linear-api/README.md) - Generic Linear API client
- [Simple Requirements Plugin](../simple-requirements/README.md) - Requirement validation
- [spec/README.md](/spec/README.md) - Requirement format specification
- [CLAUDE.md](/CLAUDE.md) - Project development guidelines
