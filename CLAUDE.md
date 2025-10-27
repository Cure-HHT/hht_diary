# Project Structure and SOPs

## Directory Organization

- **README.md**: Project overview and documentation structure
- **spec/**: Formal requirements (WHAT, WHY, HOW to build/deploy)
  - Use hierarchical naming: `{audience}-{topic}(-{subtopic}).md`
  - Audiences: `prd-` (product), `ops-` (operations), `dev-` (development)
  - **ALWAYS read spec/README.md before modifying spec/ files**
- **docs/**: Implementation documentation (HOW decisions were made)
  - `adr/`: Architecture Decision Records (ADRs)
  - Implementation guides, runbooks, design notes
  - **See docs/README.md and docs/adr/README.md for ADR process**
- **database/**: SQL schema, triggers, functions, migrations, tests
- **tools/**: Automation and development tooling
  - `linear-cli/`: Linear API integration tools for requirement-ticket traceability
  - `requirements/`: Requirement validation and traceability matrix generation
- **archive/**: Obsolete files - DO NOT use unless explicitly asked
- **evaluation/**: Mock sponsor evaluation materials
- **untracked-notes/**: Scratch files, analysis, planning docs (gitignored)

## Key SOPs

### 1. Documentation Placement (spec/ vs docs/)

**Use spec/** for:
- ✅ Formal requirements defining system capabilities
- ✅ Deployment/operation procedures (ops- files)
- ✅ Implementation specifications (dev- files)
- ✅ Compliance and regulatory requirements

**Use docs/** for:
- ✅ Architecture Decision Records (ADRs)
- ✅ Explaining WHY technical choices were made
- ✅ Implementation tutorials and guides
- ✅ Investigation reports

**See**: `docs/README.md` for complete guidelines

### 2. Architecture Decision Records (ADRs)

**When to create an ADR**:
- Significant architectural decisions with trade-offs
- Technology choices affecting multiple components
- Security model decisions
- Compliance approaches

**Workflow**:
1. Ticket created (e.g., #123 "Add feature X")
2. Draft ADR with "Proposed" status, reference ticket
3. Team review and discussion
4. Update to "Accepted" and implement
5. Commit ADR with code, reference ticket in commit message

**See**: `docs/adr/README.md` for complete ADR process and template

### 3. File Naming Conventions

**spec/ files**: `{audience}-{topic}(-{subtopic}).md`
- Examples: `prd-app.md`, `ops-deployment.md`, `dev-security-RBAC.md`

**ADR files**: `ADR-{number}-{descriptive-title}.md`
- Examples: `ADR-001-event-sourcing-pattern.md`

**Audience Scope**:
- `prd-`: No code examples, only WHAT/WHY
- `ops-`: CLI commands, configs, deployment procedures
- `dev-`: Code examples, API docs, implementation patterns

---

# ⚠️ REQUIREMENT TRACEABILITY (MANDATORY) ⚠️

**This project uses formal requirement traceability. ALL code and specs MUST be linked to requirements.**

## CRITICAL: When Creating/Modifying Code Files

**BEFORE** editing ANY implementation file (.sql, .dart, .ts, .py, .js, etc.):

1. ✅ **Identify requirements**: Which requirements does this code implement?
2. ✅ **Add header comments**: Include requirement references at top of file
3. ✅ **Use correct format**: `IMPLEMENTS REQUIREMENTS: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz`

**Example (SQL)**:
```sql
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-d00007: Database Schema Implementation
```

**Example (Dart/TypeScript)**:
```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation
```

## CRITICAL: When Creating/Modifying Requirements

**ALL new requirements MUST follow TOP-DOWN cascade** (never bottom-up from code):

1. **START at PRD level**: What business need exists? (REQ-p00xxx)
2. **Add Ops requirement**: How to deploy/operate? (REQ-o00xxx)
3. **Add Dev requirement**: How to build/implement? (REQ-d00xxx)
4. **THEN modify code**: Link code to requirements

**NEVER**:
- ❌ Write code first, then add requirements
- ❌ Skip PRD and start at Ops/Dev
- ❌ Add requirements that describe existing code (use prescriptive SHALL/MUST)

**See**: `spec/requirements-format.md` for complete methodology

## Where to Find Requirements

- **All requirements**: Scan `spec/` directory for `### REQ-{id}:` blocks
- **Validation tool**: `python3 tools/requirements/validate_requirements.py`
- **Traceability matrix**: See `traceability_matrix.md`
- **Format specification**: See `spec/requirements-format.md`

## Enforcement

- **Pre-commit hook**: Validates requirement format and links (`.githooks/pre-commit`)
  - **Setup required**: `git config core.hooksPath .githooks` (one-time per developer)
  - **See**: `.githooks/README.md` for installation and troubleshooting
- **CI/CD check**: GitHub Actions validates on pull requests (see `TODO_CI_CD_SETUP.md`)
- **Manual validation**: Run `python3 tools/requirements/validate_requirements.py`

**Violations will cause build failures. Add requirements BEFORE committing code.**

---

## Workflow for New Features

### Standard Development Workflow

1. **Ticket created**: Issue/ticket defines the need
2. **Assess if ADR needed**: Significant architectural decision with trade-offs?
   - ✅ Yes → Draft ADR in `docs/adr/` with "Proposed" status
   - ❌ No → Proceed to requirements
3. **Create requirements** (top-down cascade):
   - Start with PRD: `REQ-p00xxx` in appropriate `spec/prd-*.md`
   - Add Ops: `REQ-o00xxx` in `spec/ops-*.md` (implements PRD)
   - Add Dev: `REQ-d00xxx` in `spec/dev-*.md` (implements Ops)
4. **Validate requirements**: Run `python3 tools/requirements/validate_requirements.py`
5. **Create feature branch**: `git checkout -b feature/descriptive-name`
6. **Implement code**: Add requirement references in file headers
7. **Update ADR** (if applicable): Set status to "Accepted"
8. **Commit**: Include ticket and requirement references in commit message
9. **Merge to main**: Pre-commit hook validates automatically

### Commit Message Format

```
[TICKET-XXX] Brief description

Detailed explanation of changes.

Implements: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz
ADR: ADR-NNN-title (if applicable)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Quick Reference

### Finding Documentation

| Need | Location |
|------|----------|
| What the system does | `spec/prd-*.md` |
| How to deploy/operate | `spec/ops-*.md` |
| How to implement | `spec/dev-*.md` |
| Why we made decisions | `docs/adr/` |
| Requirement format | `spec/requirements-format.md` |
| Traceability matrix | `traceability_matrix.md` |
| spec/ vs docs/ rules | `docs/README.md` |
| Linear integration tools | `tools/linear-cli/` (see Linear Integration Tools below) |
| Requirement validation | `tools/requirements/` |

### Key Commands

```bash
# Validate requirements
python3 tools/requirements/validate_requirements.py

# Generate traceability matrix
python3 tools/requirements/generate_traceability.py --format markdown

# Enable git hooks (one-time setup)
git config core.hooksPath .githooks

# Create feature branch
git checkout -b feature/descriptive-name
```

---

## Linear Integration Tools

**Location**: `tools/linear-cli/`
**Implements**: REQ-d00027 (Development Environment and Tooling Setup)

The Linear CLI tools automate requirement-ticket traceability, ensuring all tickets are linked to formal requirements and properly organized.

### Available Tools

#### 1. Ticket Management

**`fetch-tickets.js`** - Fetch all assigned tickets
```bash
node fetch-tickets.js --token=<LINEAR_API_TOKEN> --format=json
```
- Fetches all tickets assigned to you
- Outputs JSON or human-readable format
- Extracts REQ-* references from ticket descriptions

**`fetch-tickets-by-label.js`** - Fetch tickets by label
```bash
node fetch-tickets-by-label.js --token=<TOKEN> --label="ai:new"
```
- Fetches ALL tickets with a specific label (not just assigned)
- Used to query tickets created by automation
- Returns full ticket data including descriptions

#### 2. Requirement-Ticket Linking

**`create-requirement-tickets.js`** - Batch create tickets from requirements
```bash
node create-requirement-tickets.js --token=<TOKEN> --team-id=<TEAM_ID> [options]

Options:
  --dry-run           Preview without creating tickets
  --level=<PRD|Ops|Dev>  Only create tickets for specific level
  --project-id=<ID>   Assign tickets to a project
```
- Parses all requirements from `spec/` directory
- Creates Linear tickets for requirements without existing tickets
- Automatically assigns labels based on keywords
- Sets priority by level: PRD=P1, Ops=P2, Dev=P3
- Adds "ai:new" label to all created tickets

**`update-ticket-with-requirement.js`** - Link existing ticket to requirement
```bash
node update-ticket-with-requirement.js --token=<TOKEN> --ticket-id=<ID> --req-id=<REQ-xxx>
```
- Updates existing ticket description to reference requirement
- Prepends `**Requirement**: REQ-<id>` to description
- Preserves existing ticket content

**`add-subsystem-checklists.js`** - Add sub-system checklists to tickets
```bash
node add-subsystem-checklists.js --token=<TOKEN> [--dry-run]
```
- Analyzes ticket requirements and identifies relevant sub-systems
- Adds checklist to ticket description showing which systems need updates:
  - Supabase (Database & Auth)
  - Google Workspace
  - GitHub, Doppler, Netlify, Linear
  - Development Environment, CI/CD Pipeline
  - Mobile App (Flutter), Web Portal
  - Compliance & Documentation, Backup & Recovery
- Security/access control requirements auto-apply to all cloud services
- Supports dry-run mode for testing

#### 3. Analysis and Debugging

**`check-duplicates.js`** - Find duplicate requirement-ticket mappings
```bash
node check-duplicates.js --token=<TOKEN>
```
- Analyzes all tickets for duplicate requirement references
- Helps identify tickets that may need consolidation

**`check-duplicates-advanced.js`** - Advanced duplicate analysis
```bash
node check-duplicates-advanced.js --token=<TOKEN>
```
- Deep analysis of ticket-requirement relationships
- Identifies similar titles and potential duplicates

**`list-infrastructure-tickets.js`** - List infrastructure tickets
```bash
node list-infrastructure-tickets.js --token=<TOKEN>
```
- Fetches all tickets with "infrastructure" label
- Useful for gap analysis

**`list-security-compliance-infrastructure-tickets.js`** - List security/compliance tickets
```bash
node list-security-compliance-infrastructure-tickets.js --token=<TOKEN>
```
- Fetches tickets with security, compliance, or infrastructure labels
- Used for compliance audits

#### 4. Workflow Automation

**`create-tickets.sh`** - Create all requirement tickets in batches
```bash
./create-tickets.sh
```
- Wrapper script that creates tickets in order: PRD → Ops → Dev
- Automatically loads nvm for Node.js
- Pauses between batches for review

**`run-dry-run.sh`** / **`run-dry-run-all.sh`** - Test ticket creation
```bash
./run-dry-run.sh <PRD|Ops|Dev>
./run-dry-run-all.sh
```
- Preview ticket creation without making API calls
- Shows what would be created and which tickets would be skipped
- Validates configuration before actual creation

### Linear API Token

All tools require a Linear API token. Get yours at:
https://linear.app/settings/api

**Store token securely** - Do NOT commit tokens to git. Use environment variables or pass via command line.

### Common Workflows

**Create tickets for all new requirements**:
```bash
# 1. Dry-run to preview
./run-dry-run-all.sh

# 2. Create tickets
./create-tickets.sh

# 3. Add sub-system checklists
node add-subsystem-checklists.js --token=<TOKEN>
```

**Link existing ticket to requirement**:
```bash
# Find ticket ID from Linear, then:
node update-ticket-with-requirement.js --token=<TOKEN> --ticket-id=<UUID> --req-id=p00015
```

**Analyze ticket coverage**:
```bash
# Fetch all tickets and check REQ references
node fetch-tickets.js --token=<TOKEN> --format=json | grep -i "REQ-"

# Find duplicates
node check-duplicates.js --token=<TOKEN>
```

### Integration with Requirements System

The Linear CLI tools integrate with the requirement validation system:

1. **Requirement → Ticket**: `create-requirement-tickets.js` reads from `spec/` and creates tickets
2. **Ticket → Requirement**: All tickets include `**Requirement**: REQ-xxx` in description
3. **Validation**: Tools check that requirements aren't duplicated across tickets
4. **Traceability**: Tickets link back to formal requirements for audit trail
5. **Sub-systems**: Checklists show which systems need configuration for each requirement

### Notes

- **Exclusion List**: `create-requirement-tickets.js` maintains a list of requirements that already have tickets (lines 295-308)
- **Rate Limiting**: Tools include 100ms delays between API calls to respect Linear rate limits
- **Error Handling**: All tools include comprehensive error messages with file/line references
- **Dry-Run Mode**: Most tools support `--dry-run` for testing before making changes

**See**: `tools/linear-cli/README.md` for detailed tool documentation

---

## User Preferences

- Whenever you stop to ask me a question, play an audible notification using: `paplay ~/freesound/762115__jerryberumen__alarm-misc-message-alert-notification-quick-short-arp.wav`
- When modifying SQL, before implementing migration, ask the user if ANY database has ever been deployed with this system.
- when making notes or todo files that are about your plans or otherwise not part of the project, put them in untracked-notes/ and do not track them in git.