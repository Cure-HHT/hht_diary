# ANSPAR Marketplace V2 Architecture - REFINED

## Design Philosophy
**Augment, not orchestrate** - Plugins are tools the orchestrator (Claude agent) invokes at decision points, not a workflow engine. **Always get approval before creating artifacts.**

---

## V2 Plugin Structure

### 1. Policy Enforcement (Gates)
**Block non-compliant actions**

#### `policy-enforcer` (future rename from workflow)
- Git commit requirements enforcement
- Ticket claiming before commits
- REQ-xxx references in commit messages
- Per-worktree state management

#### `scope-guardian` (NEW)
- Validates work against claimed ticket/requirement scope
- Detects out-of-scope changes (new files, modified functions not in REQ)
- **Hook**: `pre-commit` - analyze staged changes vs. requirement scope
- **Output**: Block or warn with scope drift summary

---

### 2. Validation (Checkers)
**Provide feedback, don't block**

#### `requirement-validator` (enhanced)
- **Scope validation**: Does requirement define clear boundaries?
- **Completeness check**: Required sections present (Purpose, Acceptance, Out-of-Scope)?
- **Cascade validation**: PRD → Ops → Dev hierarchy intact
- **Decision point detection**: Flags ambiguities needing ADR (suggests, doesn't create)
- **Implementation status**: Checks `specs/outdated-implementations.json`
  - Reports: implemented, outdated, not-implemented
- **Agent**: `RequirementValidator` - interactive checking
- **Skill**: `GetRequirementDefinition` - returns clean REQ content

**Validation Output:**
```
REQ-d00027: Authentication Module
Status: ⚠️  OUTDATED IMPLEMENTATIONS
- Implemented in: 3 files
- Outdated: 2 files (scope-hash mismatch)
- Not implemented: 1 acceptance criterion
```

#### `spec-compliance` (keep existing)
- Validates spec/ directory structure
- Enforces audience separation (prd/ops/dev)
- Checks file naming conventions

#### `traceability-validator` (enhanced)
- Validates all code has REQ references
- Checks all REQs have implementation
- Detects orphaned requirements or code
- Cross-references with `specs/outdated-implementations.json`

---

### 3. Generation (Creators)
**Generate artifacts with approval**

#### `requirement-generator` (NEW)
- Creates new requirement when scope drift detected
- **Always prompts user** with preview before creating
- Prompts for: type (prd/ops/dev), cascade parent, scope
- Auto-assigns next REQ-{type}NNNNN ID
- Templates based on type

**Approval flow:**
```
[Detected out-of-scope work: billing-fix.ts]

Suggest creating:
  REQ-d00042: Billing calculation fix
  Type: dev
  Parent: REQ-p00012

Preview:
  ---
  req-id: REQ-d00042
  scope-hash: [auto-generated]
  ---
  # Billing Calculation Fix
  [generated content...]

Approve creation? (y/n)
```

#### `adr-generator` (NEW)
- Detects decision points during implementation
- **Always prompts user** before creating ADR
- **Agent**: `ADRAssistant` - conducts decision interview
- Templates follow docs/adr/ADR-NNN-title.md format

**Approval flow:**
```
[Ambiguity detected in REQ-d00027: "flexible authentication"]

This appears to be a decision point.
Options detected:
  1. OAuth2 (industry standard, complex)
  2. JWT (stateless, simpler)
  3. Session-based (traditional, server state)

Create ADR to document decision? (y/n)
```

#### `ticket-generator` (NEW)
- Creates Linear tickets from requirements
- Creates follow-up tickets from current work
- Links tickets to requirements (one-way: ticket → REQ)
- **Agent**: `TicketCreator` - interactive ticket creation

**User Stories Supported:**
```bash
# Story 1: Starting from requirement
/generate-tickets REQ-p00012
→ Analyzes requirement, suggests ticket breakdown
→ Shows preview, gets approval
→ Creates tickets with REQ links

# Story 4: Follow-up ticket needed
/create-followup "Optimize database queries"
→ Prompts: Related to current ticket CUR-262? (y/n)
→ Prompts: Related to requirement REQ-d00027? (y/n)
→ Shows preview, creates ticket
```

#### `requirement-tracker` (NEW)
- Monitors requirement scope-hash changes
- When hash changes:
  1. Scans codebase for `Implements: REQ-xxx` references
  2. Creates Linear ticket with checklist of affected files
  3. Appends to `specs/outdated-implementations.json`
- **Hook**: `spec-file-watcher` or manual trigger

**Outdated Implementations Format:**
```json
{
  "REQ-d00027": {
    "previous-hash": "abc123",
    "current-hash": "def456",
    "changed-at": "2025-10-31T15:30:00Z",
    "affected-files": [
      "src/auth/jwt-handler.ts:15",
      "src/auth/middleware.ts:42",
      "tests/auth.test.ts:120"
    ],
    "verification-ticket": "CUR-301",
    "status": "pending-verification"
  }
}
```

#### `traceability-reporter` (keep, enhance)
- Generates traceability matrices
- Multiple formats: markdown, JSON, HTML
- Visual dependency graphs
- Includes outdated implementation status

---

### 4. Integration (External Systems)

#### `linear-integration` (enhanced)
- Fetch ticket details and requirements
- Create tickets (with approval)
- Update ticket status
- **One-way linking**: Ticket → REQ (never REQ → Ticket)

#### `anspar-github-actions-generator` (NEW)
- Generates GitHub Actions workflows for new repos
- **Templates**:
  - `requirement-validation.yml`: Runs on spec/ changes
  - `traceability-check.yml`: Runs on PR creation
  - `scope-compliance.yml`: Validates commits have REQ refs
  - `outdated-impl-check.yml`: Checks outdated-implementations.json
- **Command**: `/setup-github-actions`
- Enforces CI/CD compliance with ANSPAR workflow

**Generated Workflow Example:**
```yaml
# .github/workflows/requirement-validation.yml
name: Requirement Validation
on:
  pull_request:
    paths: ['spec/**']
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate Requirements
        run: |
          # Run requirement-validator
          # Check for scope-hash changes
          # Trigger outdated-implementation tracking
```

---

### 5. Skills (Data Retrieval)

#### Skill: `GetRequirementDefinition` (NEW)
**Purpose**: Return clean REQ content without extra spec file details

**Location**: `plugins/validation/requirement-validator/skills/GetRequirement/`

**Input:**
```javascript
{
  "req-id": "REQ-d00027",
  "include-metadata": false,  // optional
  "format": "markdown"        // markdown | json | yaml
}
```

**Output:**
```markdown
---
req-id: REQ-d00027
scope-hash: abc123def456
---

# Authentication Module

## Purpose
Implement JWT-based authentication for API endpoints.

## Scope

### In Scope
- JWT token generation and validation
- Middleware for protected routes
- Token refresh mechanism

### Out of Scope
- OAuth integration (see REQ-d00041)
- Social login (defer to Q2)

## Acceptance Criteria
1. Tokens expire after 1 hour
2. Refresh tokens valid for 7 days
3. Invalid tokens return 401

## Success Metrics
- 100% protected endpoints require valid token
- <50ms token validation overhead
```

**Usage by Orchestrator:**
```javascript
// Claude agent retrieves REQ before starting work
const req = await GetRequirementDefinition("REQ-d00027");
// Now has clean requirement context without parsing full spec file
```

---

### 6. Meta Layer

#### `plugin-expert` (keep existing)
- Create and manage marketplace plugins

---

## Workflow Integration Pattern - User Stories

### Story 1: Starting from Requirement
```
User: "Implement REQ-p00012"

1. [GetRequirementDefinition] Fetch REQ-p00012 content
2. [requirement-validator] Check completeness
   ├─ ✓ Complete
   └─ ⚠️  Decision needed: Database choice
3. Ask user: "Create ADR for database selection? (y/n)"
   └─ User: y
4. [adr-generator] Create ADR-020-database-selection.md (with approval)
5. [ticket-generator] Suggest ticket breakdown:
   Preview:
     CUR-301: Set up database schema
     CUR-302: Implement data layer
     CUR-303: Add validation layer
   Approve? (y/n)
   └─ User: y
6. [linear-integration] Create tickets (link to REQ-p00012)
7. [policy-enforcer] Claim CUR-301
```

### Story 2: Requirement Refinement During Work
```
User: "Working on CUR-262, REQ-d00027 needs refinement"

1. [GetRequirementDefinition] Fetch REQ-d00027
2. User edits spec/dev-authentication.md
3. [requirement-change-tracker] Detects scope-hash change
   Old: abc123
   New: def456
4. [requirement-change-tracker] Scans codebase for REQ-d00027
   Found in:
   - src/auth/jwt-handler.ts:15
   - src/auth/middleware.ts:42
5. Ask user: "Create verification ticket for outdated implementations? (y/n)"
   └─ User: y
6. [ticket-generator] Create CUR-303:
   Title: Verify REQ-d00027 implementations after scope change
   Description:
     Requirement REQ-d00027 updated on 2025-10-31
     Verify implementations:
     - [ ] src/auth/jwt-handler.ts:15
     - [ ] src/auth/middleware.ts:42
7. Append to specs/outdated-implementations.json
```

### Story 3: Discovering New Requirement
```
User: "Working on CUR-262, discovered need for rate limiting"

1. [scope-guardian] Detects out-of-scope work (rate-limiter.ts)
2. Suggest: "Create new requirement for rate limiting? (y/n)"
   └─ User: y
3. [requirement-generator] Preview:
   REQ-d00043: API Rate Limiting
   Type: dev
   Parent: REQ-p00012
   [generated content]
   Approve? (y/n)
   └─ User: y
4. [requirement-generator] Create spec/dev-rate-limiting.md
5. [ticket-generator] Suggest: "Create ticket for REQ-d00043? (y/n)"
   └─ User: y
6. [linear-integration] Create CUR-304 (links to REQ-d00043)
```

### Story 4: Follow-up Ticket Needed
```
User: "Need follow-up ticket for performance optimization"

1. User: /create-followup "Optimize auth token caching"
2. [ticket-generator] Ask: "Related to current ticket CUR-262? (y/n)"
   └─ User: y (adds relation in Linear)
3. [ticket-generator] Ask: "Related to requirement? (current: REQ-d00027)"
   Options:
     1. Yes, REQ-d00027
     2. Different requirement
     3. No requirement link
   └─ User: 1
4. [ticket-generator] Preview:
   CUR-305: Optimize auth token caching
   Related: CUR-262
   Requirement: REQ-d00027
   Approve? (y/n)
   └─ User: y
5. [linear-integration] Create CUR-305
```

---

## File Structure Updates

### Requirement File Enhancement
**Only keep scope-hash in frontmatter:**

```yaml
---
req-id: REQ-d00027
scope-hash: abc123def456
---
```

**Direction of links:**
- ❌ Requirements DO NOT link to tickets
- ✅ Tickets link to requirements (in Linear)
- ✅ Code references requirements (`Implements: REQ-xxx`)
- ✅ ADRs link to requirements

### New File: `specs/outdated-implementations.json`
**Tracks implementations needing verification after REQ changes:**

```json
{
  "version": "1.0.0",
  "updated-at": "2025-10-31T15:30:00Z",
  "outdated": {
    "REQ-d00027": {
      "previous-hash": "abc123",
      "current-hash": "def456",
      "changed-at": "2025-10-31T15:30:00Z",
      "changed-by": "user@example.com",
      "affected-files": [
        "src/auth/jwt-handler.ts:15",
        "src/auth/middleware.ts:42",
        "tests/auth.test.ts:120"
      ],
      "verification-ticket": "CUR-301",
      "status": "pending-verification"
    }
  },
  "verified": {
    "REQ-d00025": {
      "verified-at": "2025-10-30T10:00:00Z",
      "verified-by": "CUR-298",
      "affected-files": [
        "src/billing/calculator.ts:88"
      ]
    }
  }
}
```

**Status values:**
- `pending-verification`: Ticket created, not completed
- `verified`: All files checked and updated
- `not-applicable`: Change didn't affect implementations

### Enhanced Requirement Validation Output

```bash
$ requirement-validator --status

Requirements Status Report
==========================

Fully Implemented (5):
✓ REQ-d00025: Billing Calculator
✓ REQ-d00026: User Dashboard
✓ REQ-d00028: Email Notifications
✓ REQ-p00010: Authentication System
✓ REQ-o00005: Database Backup

Outdated Implementations (2):
⚠️  REQ-d00027: Authentication Module
   - 2 files need verification (see CUR-301)
   - Changed: 2025-10-31
⚠️  REQ-d00041: OAuth Integration
   - 5 files need verification (see CUR-310)
   - Changed: 2025-10-30

Not Implemented (3):
○ REQ-d00042: Rate Limiting
○ REQ-d00043: Audit Logging
○ REQ-p00015: Reporting Dashboard

No Code Required (1):
- REQ-o00012: Deployment Runbook (ops spec, no code)
```

---

## V2 Plugin Structure (Final)

```
tools/anspar-marketplace/
├── plugins/
│   ├── policy-enforcement/
│   │   ├── policy-enforcer/
│   │   └── scope-guardian/
│   │
│   ├── validation/
│   │   ├── requirement-validator/
│   │   │   ├── agents/RequirementValidator.md
│   │   │   ├── skills/GetRequirement/SKILL.md
│   │   │   └── scripts/validate-requirements.sh
│   │   ├── spec-compliance/
│   │   └── traceability-validator/
│   │
│   ├── generation/
│   │   ├── requirement-generator/
│   │   ├── adr-generator/
│   │   ├── ticket-generator/
│   │   ├── requirement-tracker/
│   │   └── traceability-reporter/
│   │
│   ├── integration/
│   │   ├── linear-integration/
│   │   └── anspar-github-actions-generator/
│   │
│   └── meta/
│       └── plugin-expert/
│
├── specs/                    # Reference specs for plugin development
└── README.md
```

---

## GitHub Actions Setup

### Command: `/setup-github-actions`
**Generates complete CI/CD for new repository**

**Generated Files:**
```
.github/workflows/
├── requirement-validation.yml      # Validates spec/ changes
├── traceability-check.yml         # Ensures REQ references
├── scope-compliance.yml           # Pre-merge checks
├── outdated-impl-check.yml        # Checks outdated-implementations.json
└── policy-enforcement.yml         # Commit message validation
```

**Key Workflows:**

#### `requirement-validation.yml`
```yaml
name: Requirement Validation
on:
  pull_request:
    paths: ['spec/**']
jobs:
  validate:
    steps:
      - name: Check scope-hash changes
        run: |
          # Detect hash changes
          # Run requirement-tracker
          # Create tickets if needed

      - name: Validate completeness
        run: requirement-validator --strict

      - name: Check outdated implementations
        run: |
          if [ -s specs/outdated-implementations.json ]; then
            echo "⚠️  Outdated implementations exist"
            cat specs/outdated-implementations.json
            exit 1
          fi
```

#### `traceability-check.yml`
```yaml
name: Traceability Check
on: [pull_request]
jobs:
  check:
    steps:
      - name: Validate REQ references
        run: traceability-validator --pr-mode

      - name: Ensure no orphaned code
        run: |
          # All changed files have Implements: comments
          # All referenced REQs exist
```

---

## Implementation Priority

### Phase 1: Core + Tracking (Critical)
1. `policy-enforcer` (future rename from workflow)
2. `requirement-validator` + `GetRequirement` skill
3. `requirement-tracker` (NEW - critical for hash tracking)
4. `specs/outdated-implementations.json` support

### Phase 2: Generation (User Stories)
5. `requirement-generator` (with approval)
6. `ticket-generator` (with approval)
7. `adr-generator` (with approval)

### Phase 3: Automation
8. `anspar-github-actions-generator`
9. Enhanced `traceability-validator`
10. `scope-guardian`

---

## Key Principles

1. **Approval Required**: Never create REQ, ADR, or ticket without user approval
2. **Unidirectional Links**: Ticket → REQ, Code → REQ, ADR → REQ (never reverse)
3. **Hash-Based Change Detection**: scope-hash is source of truth for REQ changes
4. **Outdated Tracking**: `specs/outdated-implementations.json` tracks verification needs
5. **Skills for Clean Data**: `GetRequirement` provides REQ content without noise
6. **GitHub Actions**: Full automation setup for new repositories
7. **User Story Driven**: Supports all 4 user stories with approval gates
