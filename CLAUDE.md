# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-sponsor Clinical Trial Diary Platform with strict FDA 21 CFR Part 11 compliance requirements. The system uses event sourcing, comprehensive audit trails, and requirement traceability for all code changes.

**Key Characteristics**:
- Multi-sponsor deployment model (shared core + sponsor-specific customization)
- Strict requirement traceability (every change must link to REQ-{p|o|d}NNNNN)
- FDA compliance (21 CFR Part 11, ALCOA+ principles)
- Plugin-based workflow enforcement via Claude Code marketplace plugins

## Critical Rules

### 1. Requirement Traceability (MANDATORY)
- **ALL commits** must include `Implements: REQ-xxx` or `Fixes: REQ-xxx` in commit messages
- Git hooks enforce this - commits without REQ references will be blocked
- Requirement format: `REQ-{type}{number}` where type is `p` (PRD), `o` (Ops), or `d` (Dev), and number is 5 digits (e.g., `REQ-d00027`)
- Implementation files must include requirement headers:
  ```sql
  -- IMPLEMENTS REQUIREMENTS:
  --   REQ-d00027: Workflow plugin state management
  --   REQ-p00042: Event sourcing audit trail
  ```

### 2. Workflow Enforcement
- **Before making any commits**, you MUST claim a ticket using the workflow plugin:
  ```bash
  tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh CUR-XXX
  ```
- The workflow plugin enforces ticket claiming via git hooks
- Use `/workflow:claim CUR-XXX` slash command for quick ticket claiming
- Release tickets when done: `./scripts/release-ticket.sh "Work complete"`

### 3. Documentation Hierarchy
- **spec/**: Formal requirements defining WHAT to build, organized by audience
  - `prd-*.md`: Product requirements (NO CODE EXAMPLES)
  - `ops-*.md`: Deployment/operations (CLI commands OK)
  - `dev-*.md`: Implementation guides (code examples OK)
- **docs/**: Architecture Decision Records (ADRs) explaining WHY decisions were made
- Always read `spec/README.md` before modifying spec/ files
- See `spec/INDEX.md` for complete requirements index

### 4. Sponsor Isolation
- Each sponsor has isolated code in `sponsor/{name}/`
- NEVER cross-reference sponsors or share sponsor-specific code
- Core functionality goes in `packages/`, `apps/`, `database/`
- Sponsor context tracked in workflow: `claim-ticket.sh CUR-XXX human carina`

### 5. Branch Protection
- ALWAYS create a new branch before editing/creating/deleting files if on `main`
- Never commit directly to `main`
- Follow branch naming: `feature/`, `fix/`, `release/`

## Project Structure

```
.
├── spec/                      # Formal requirements (prd-*, ops-*, dev-*)
│   ├── INDEX.md              # Complete requirements index
│   └── README.md             # Naming conventions & scope definitions
├── docs/                      # ADRs and implementation guides
│   └── adr/                  # Architecture Decision Records
├── database/                  # PostgreSQL schema (Supabase)
│   ├── schema.sql            # Core table definitions
│   ├── triggers.sql          # Event store & audit triggers
│   ├── rls_policies.sql      # Row-level security
│   └── migrations/           # Database migrations
├── packages/                  # Core Flutter abstractions (shared)
├── apps/                      # Flutter app templates
├── sponsor/                   # Sponsor-specific implementations
│   └── {sponsor-name}/       # Isolated per sponsor
├── tools/                     # Development & automation tools
│   ├── requirements/         # Validation & traceability scripts
│   ├── dev-env/              # Docker dev containers (role-based)
│   └── anspar-marketplace/   # Claude Code plugins
│       └── plugins/
│           ├── workflow/                   # Git workflow enforcement
│           ├── linear-api/                 # Generic Linear API client
│           ├── requirement-traceability/   # REQ-to-ticket mapping
│           ├── simple-requirements/        # Requirement validation
│           └── spec-compliance/            # spec/ directory compliance
├── .githooks/                 # Git hooks for enforcement
└── .devcontainer/             # Dev container config (recommended)
```

## Common Development Commands

### Requirements Management

```bash
# Validate requirement format and IDs
python3 tools/requirements/validate_requirements.py

# Validate INDEX.md accuracy
python3 tools/requirements/validate_index.py

# Generate traceability matrix (Markdown)
python3 tools/requirements/generate_traceability.py --format markdown

# Generate traceability matrix (HTML)
python3 tools/requirements/generate_traceability.py --format html

# Claim a new requirement number (use GitHub Actions UI)
# Go to Actions → "Claim Requirement Number" workflow
```

### Workflow & Ticket Management

```bash
# Claim a ticket (core functionality)
tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh CUR-XXX

# Claim a ticket (sponsor-specific)
tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh CUR-XXX human carina

# Release ticket when done
tools/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh "Work complete"

# Switch to different ticket
tools/anspar-cc-plugins/plugins/workflow/scripts/switch-ticket.sh CUR-YYY "Reason"

# Resume a previously paused ticket
tools/anspar-cc-plugins/plugins/workflow/scripts/resume-ticket.sh

# View workflow history
tools/anspar-cc-plugins/plugins/workflow/scripts/list-history.sh
```

### Linear API & Requirement Traceability

```bash
# Fetch tickets
bash tools/anspar-cc-plugins/plugins/linear-api/skills/fetch-tickets.skill CUR-240

# Create tickets from requirements (dry run)
node tools/anspar-cc-plugins/plugins/requirement-traceability/scripts/create-req-tickets.js --dry-run

# Use slash commands
/req REQ-p00042      # Show requirement details and associated tickets
/req search auth     # Search requirements by keyword
```

### Git Hooks

```bash
# Enable git hooks (if not already configured)
git config core.hooksPath .githooks

# Hooks will automatically:
# - Block commits without active ticket (pre-commit)
# - Block commits without REQ reference (commit-msg)
# - Record commits in workflow history (post-commit)
```

### Development Environment

```bash
# Recommended: Use dev container (ensures consistent environment)
# 1. Install Docker & VS Code "Dev Containers" extension
# 2. Cmd/Ctrl+Shift+P → "Reopen in Container"

# Or manual setup:
cd tools/dev-env
./setup.sh

# Available roles: dev, qa, ops, mgmt
```

## Architecture Patterns

### Event Sourcing & Audit Trail
- All data changes captured in `event_log` table
- Triggers automatically create audit events
- Immutable audit trail for FDA compliance
- See `spec/prd-database.md` and `database/triggers.sql`

### Multi-Sponsor Deployment
- Shared core platform deployed per-sponsor
- Each sponsor gets isolated Supabase project
- Build system composes core + sponsor-specific code
- See `spec/prd-architecture.md`

### Row-Level Security (RLS)
- PostgreSQL RLS policies enforce data isolation
- Roles: patient, investigator, sponsor_user, admin
- Multi-sponsor access control via sponsor_id
- See `database/rls_policies.sql` and `spec/prd-security.md`

### Plugin Architecture
- Claude Code plugins in `tools/anspar-cc-plugins/plugins/`
- Each plugin has single responsibility
- Plugins communicate via orchestrator pattern
- See individual plugin READMEs for details

## Workflow Guidelines

### Standard Development Flow

1. **Claim a ticket** (required before commits):
   ```bash
   tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh CUR-XXX
   ```

2. **Check if requirements exist** or create new ones:
   - Search `spec/INDEX.md` for relevant requirements
   - If new requirement needed, use GitHub Actions to claim REQ#
   - Follow cascade: PRD → Ops → Dev

3. **Implement changes** with requirement headers:
   ```sql
   -- IMPLEMENTS REQUIREMENTS:
   --   REQ-d00027: Feature description
   ```

4. **Validate before committing**:
   ```bash
   python3 tools/requirements/validate_requirements.py
   python3 tools/requirements/validate_index.py
   ```

5. **Commit with proper format**:
   ```bash
   git commit -m "[CUR-XXX] Brief description

   Detailed explanation of changes.

   Implements: REQ-d00027, REQ-p00042"
   ```

6. **Release ticket** when done:
   ```bash
   tools/anspar-cc-plugins/plugins/workflow/scripts/release-ticket.sh "Work complete"
   ```

### Commit Message Format

```
[TICKET-ID] Brief summary (50 chars max)

Detailed description of what changed and why.
Can be multiple paragraphs explaining context.

Implements: REQ-d00027, REQ-p00042
Fixes: REQ-d00089

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### When to Create ADRs

Create an Architecture Decision Record (ADR) in `docs/adr/` when:
- Making significant architectural decisions
- Choosing between competing approaches (document trade-offs)
- Establishing new patterns or conventions
- Security or compliance-related design choices

Format: `ADR-{number}-{kebab-case-title}.md`

## Key Files & Locations

| Purpose | Location |
|---------|----------|
| Requirements index | `spec/INDEX.md` |
| Requirements validation | `tools/requirements/validate_requirements.py` |
| Traceability matrix | `tools/requirements/generate_traceability.py` |
| Workflow scripts | `tools/anspar-cc-plugins/plugins/workflow/scripts/` |
| Git hooks | `.githooks/` |
| Database schema | `database/schema.sql` |
| Event store triggers | `database/triggers.sql` |
| RLS policies | `database/rls_policies.sql` |
| Dev container config | `.devcontainer/devcontainer.json` |
| CI/CD workflows | `.github/workflows/pr-validation.yml` |

## Plugin Reference

### workflow Plugin
- Enforces ticket claiming before commits
- Validates REQ references in commit messages
- Tracks per-worktree state in `.git/WORKFLOW_STATE`
- Supports paused/resumed tickets
- Location: `tools/anspar-cc-plugins/plugins/workflow/`

### linear-api Plugin
- Generic Linear API client
- Fetch/create/update Linear tickets
- Reusable across projects
- Location: `tools/anspar-cc-plugins/plugins/linear-api/`

### requirement-traceability Plugin
- Requirement-to-ticket traceability
- Creates tickets for requirements
- Maintains bidirectional mappings
- Slash command: `/req`
- Location: `tools/anspar-cc-plugins/plugins/requirement-traceability/`

### simple-requirements Plugin
- Requirement format validation
- Change detection and tracking
- REQ reference parsing
- Location: `tools/anspar-cc-plugins/plugins/simple-requirements/`

### spec-compliance Plugin
- Enforces spec/ directory guidelines
- Validates audience scope rules (prd/ops/dev)
- Prevents code examples in PRD files
- Location: `tools/anspar-cc-plugins/plugins/spec-compliance/`

## Testing & Validation

```bash
# Run all PR validation checks locally
python3 tools/requirements/validate_requirements.py
python3 tools/requirements/validate_index.py
python3 tools/requirements/generate_traceability.py --format markdown

# Database tests (when database exists)
# Run from Supabase SQL editor or psql
\i database/tests/test_audit_trail.sql
\i database/tests/test_compliance_functions.sql

# CI/CD validation happens automatically on PRs
# See .github/workflows/pr-validation.yml
```

## Security Considerations

- **NEVER commit secrets** (API keys, tokens, passwords)
- Use environment variables for all secrets
- Do not use .env files for secrets
- Linear API token is stored in `LINEAR_API_TOKEN` environment variable
- All secrets managed via Doppler (run with `doppler run -- claude`)
- Supabase credentials managed via Doppler (see `spec/ops-security.md`)
- All audit events are tamper-evident (cryptographic hashing)

## Database Deployment

**Target Platform**: Supabase (PostgreSQL 15+)

```bash
# Master initialization script (runs all in order)
\i database/init.sql

# Or run individually:
\i database/schema.sql
\i database/triggers.sql
\i database/roles.sql
\i database/rls_policies.sql
\i database/indexes.sql
\i database/seed_data.sql
```

See `spec/ops-database-setup.md` for complete deployment guide.

## Troubleshooting

### Error: No active ticket claimed
**Solution**: Claim a ticket before committing:
```bash
tools/anspar-cc-plugins/plugins/workflow/scripts/claim-ticket.sh CUR-XXX
```

### Error: Commit message must contain REQ reference
**Solution**: Add requirement reference to commit message:
```bash
git commit -m "Your message

Implements: REQ-d00027"
```

### Error: Requirement validation failed
**Solution**: Check requirement format in spec files matches:
```markdown
### REQ-d00027: Title Here
```

### Error: INDEX.md validation failed
**Solution**: Update INDEX.md after adding/modifying requirements:
```bash
python3 tools/requirements/validate_index.py
# Follow error messages to fix discrepancies
```

## Important Notes

- The workflow plugin provides proactive task-switching detection via UserPromptSubmit hooks
- Dev container usage is recommended but not enforced (warning shown at session start)
- Multiple worktrees can work on the same ticket (valid for multiple PRs)
- Cache management is automatic for Linear integration (24hr refresh)
- All requirement IDs claimed via GitHub Actions to prevent conflicts
- PR validation runs automatically and blocks merge on validation failures

## External Resources

- Supabase Docs: https://supabase.com/docs
- PostgreSQL Docs: https://www.postgresql.org/docs/
- FDA 21 CFR Part 11: https://www.fda.gov/regulatory-information
- Linear API: https://developers.linear.app/
- Flutter Docs: https://docs.flutter.dev/

## Agent Orchestration Pattern
<!-- ORCHESTRATION_V1 -->

When working with plugins that provide specialized agents:

- **ALWAYS check for available sub-agents** before implementing complex tasks
  - Use `/agents` command to see available specialized agents
  - Check plugin documentation for agent capabilities

- **Delegate to sub-agents** when their expertise matches the task
  - Sub-agents have deep domain knowledge and specialized tools
  - They follow architectural patterns and best practices
  - They provide faster, more accurate results than general implementation

- **Act as orchestrator, not implementer** when agents are available
  - Your role: Understand requirements, select appropriate agent, validate results
  - Agent's role: Execute specialized tasks using domain-specific knowledge
  - Avoid reimplementing functionality that agents provide

- **Trust agent expertise** but validate results
  - Agents are designed to handle specific domains correctly
  - Review their outputs for correctness and completeness
  - Escalate to user when agent results are unclear or incorrect

**Example**: When working with plugins, prefer `/plugin-expert` over manually creating plugin files.

