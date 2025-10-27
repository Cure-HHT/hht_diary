---
description: Systematically implement high-priority Linear tickets with traceability
---

# Task: Implement Priority Tickets

Your task is to select, implement, and track progress on high-priority Linear tickets, maintaining full requirement traceability.

## Context

This project uses formal requirement traceability with Linear tickets. Each ticket:
- Links to a formal requirement (REQ-xxx) in spec/ files
- Has a sub-system checklist showing which systems need updates
- Must maintain traceability (code → requirement → ticket)

## Phase 1: Ticket Selection

1. **Fetch actionable tickets**:
```bash
export LINEAR_API_TOKEN="<token>"
cd tools/linear-cli
node fetch-tickets.js --token=$LINEAR_API_TOKEN --format=json > /tmp/tickets.json
```

2. **Analyze and filter tickets**:
   - Priority: Focus on P0 (Urgent) and P1 (High) first
   - State: Only "Todo" or "In Progress" tickets
   - Implementability: Select tickets you can complete with available context
   - Labels: Prefer `dev`, `infrastructure`, `documentation` over `research`

3. **Selection criteria for 5 tickets**:
   - **Database tickets**: Can write SQL schemas/migrations immediately
   - **Requirements tooling**: Can write Python validation scripts
   - **Dev environment**: Can create config files, setup instructions
   - **Documentation**: Can write ADRs, update specs
   - **Avoid**: Tickets requiring external services not yet configured (Supabase project setup, Google Workspace, etc.)

4. **Ticket diversity**: Select across different areas:
   - 1-2 database/schema tickets
   - 1-2 tooling/automation tickets
   - 1 documentation ticket

## Phase 2: Implementation Workflow (Per Ticket)

For each selected ticket:

### Step 1: Analyze Ticket
- Read ticket description and requirement from spec/
- Understand acceptance criteria
- Identify which sub-systems are relevant
- Assess if fully completable or will need blockers

### Step 2: Create Feature Branch
```bash
git checkout main
git pull
git checkout -b feature/CUR-XXX-descriptive-name
```

### Step 3: Implement
- Write code/config/documentation
- Add requirement headers to all files:
```
# IMPLEMENTS REQUIREMENTS:
#   REQ-xxx: Requirement Title
```
- Follow coding standards from spec/dev-*.md files
- Validate as you go (run tests, validate schemas, etc.)

### Step 4: Update Ticket Progress
Create a script to update ticket description with completed sub-systems:

```javascript
// Update ticket checklist: change [ ] to [x] for completed systems
// Use update-ticket-with-requirement.js as reference
```

Mark completed sub-systems by changing `- [ ] System Name` to `- [x] System Name` in ticket description.

### Step 5: Commit and Document
```bash
git add .
git commit -m "[CUR-XXX] Brief description

Detailed changes.

Implements: REQ-xxx
Status: Complete | Partial - see blockers

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push -u origin feature/CUR-XXX-descriptive-name
```

### Step 6: Handle Blockers (If Needed)

If you cannot complete the ticket:

1. **Document what was accomplished**:
   - Update ticket description with completed work
   - Check off completed sub-systems
   - List what remains

2. **Create blocker tickets**:
   ```bash
   # For each blocker, create a new ticket via Linear API
   # Example blockers:
   # - "Supabase project not yet created" (blocks database schema deployment)
   # - "Google Workspace not configured" (blocks MFA setup)
   # - "Missing design decision" (blocks implementation choice)
   ```

3. **Link blockers**:
   - Use Linear API to link blocker tickets
   - Format: "Blocked by CUR-XXX"

4. **Update original ticket state**:
   - State: "Blocked" if completely blocked
   - State: "In Progress" if partially complete
   - Add comment documenting progress and blockers

## Phase 3: Summary and Handoff

After implementing 5 tickets:

1. **Create summary document** (in untracked-notes/):
   - List of tickets attempted
   - Completion status for each
   - Blockers created and links
   - Files changed/created
   - Any follow-up needed

2. **Update traceability matrix**:
   ```bash
   python3 tools/requirements/validate_requirements.py
   python3 tools/requirements/generate_traceability.py --format both
   ```

3. **Git status**:
   - List all feature branches created
   - Indicate which are ready to merge vs. blocked

## Implementation Priority Guide

### High-Priority Implementable Tickets:

**Tier 1: Can implement immediately**
- Requirement validation tooling (Python scripts)
- Git hooks (Bash scripts)
- ADR templates (Markdown)
- Database schema definitions (SQL - design only, not deployment)
- Documentation structure enforcement (scripts)
- Code-to-requirement linking (documentation + examples)

**Tier 2: Need minimal context**
- Traceability matrix generation enhancements
- Pre-commit hook improvements
- Development environment documentation
- Configuration file templates

**Tier 3: Blocked by infrastructure**
- Supabase schema deployment (need project created)
- MFA configuration (need Google Workspace)
- RLS policy deployment (need Supabase)
- CI/CD pipeline (need GitHub Actions configured)

### Ticket Types and Deliverables:

| Ticket Type | Deliverable | Location |
|-------------|-------------|----------|
| Database schema | SQL files | `database/schema.sql` |
| Migrations | SQL files | `database/migrations/` |
| Validation tooling | Python scripts | `tools/requirements/` |
| Git hooks | Bash scripts | `.githooks/` |
| Documentation | Markdown files | `docs/`, `spec/` |
| ADRs | Markdown files | `docs/adr/` |
| Config templates | YAML/JSON/ENV | `config/`, docs |
| Dev environment | Shell scripts, docs | `tools/setup/`, docs |

## Linear API Helpers

**Update ticket description**:
```bash
node tools/linear-cli/update-ticket-with-requirement.js \
  --token=$LINEAR_API_TOKEN \
  --ticket-id=<UUID> \
  --req-id=<REQ-xxx>
```

**Fetch ticket details**:
```bash
node tools/linear-cli/fetch-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --format=json | jq '.viewer.assignedIssues.nodes[] | select(.identifier=="CUR-XXX")'
```

**Create blocker ticket** (use GraphQL mutation via Linear API):
```graphql
mutation CreateBlocker {
  issueCreate(input: {
    teamId: "<team-id>"
    title: "Blocker: <description>"
    description: "Blocks CUR-XXX\n\n<details>"
    priority: 1
  }) {
    success
    issue { id, identifier }
  }
}
```

## Notes

- **DO NOT** deploy infrastructure without user confirmation
- **DO NOT** commit secrets or API tokens
- **DO** maintain requirement traceability in all code
- **DO** test locally before committing
- **DO** document partial progress clearly
- **DO** create specific, actionable blocker tickets

## Success Criteria

- 5 tickets attempted with clear outcomes
- All code includes requirement headers
- Feature branches created for each ticket
- Blocker tickets created and linked where needed
- Traceability matrix updated and validates
- Summary document created for handoff

---

**Usage**: Run `/implement-tickets` to start the implementation workflow with these instructions.
