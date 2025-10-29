# Project Structure and SOPs

## Directory Organization

### Core Platform (Root)

- **README.md**: Project overview and documentation structure
- **spec/**: Core platform formal requirements (WHAT, WHY, HOW to build/deploy)
  - Use hierarchical naming: `{audience}-{topic}(-{subtopic}).md`
  - Audiences: `prd-` (product), `ops-` (operations), `dev-` (development)
  - **ALWAYS read spec/README.md before modifying spec/ files**
- **docs/**: Implementation documentation (HOW decisions were made)
  - `adr/`: Architecture Decision Records (ADRs)
  - Implementation guides, runbooks, design notes
  - **See docs/README.md and docs/adr/README.md for ADR process**
- **database/**: Shared SQL schema for ALL sponsors (deployed per-sponsor)
  - Schema, triggers, functions, migrations, RLS policies
  - **NOT sponsor-specific** - same schema deployed to each sponsor's Supabase instance
- **packages/**: Core Flutter packages (abstract interfaces)
- **apps/**: Flutter app templates (mobile, portal)
- **tools/**: Automation and development tooling
  - `build_system/`: Build scripts for composing core + sponsor code
  - `linear-cli/`: Linear API integration tools for requirement-ticket traceability
  - `requirements/`: Requirement validation and traceability matrix generation
- **archive/**: Obsolete files - DO NOT use unless explicitly asked
- **evaluation/**: Mock sponsor evaluation materials
- **untracked-notes/**: Scratch files, analysis, planning docs (gitignored)

### Sponsor-Specific Code (`sponsor/`)

⭐ **IMPORTANT**: The `sponsor/` directory contains sponsor-specific implementations and configurations. It mirrors the root structure but contains ONLY sponsor-specific code.

```text
sponsor/
├── lib/                        # Sponsor implementations
│   ├── orion/                  # Sponsor: Orion
│   │   ├── orion_config.dart
│   │   ├── orion_edc_sync.dart
│   │   └── orion_theme.dart
│   └── andromeda/              # Sponsor: Andromeda
│       ├── andromeda_config.dart
│       └── andromeda_theme.dart
│
├── config/                     # Sponsor configurations (GITIGNORED!)
│   ├── orion/
│   │   ├── mobile.yaml
│   │   ├── portal.yaml
│   │   └── supabase.env        # SECRETS - NEVER COMMIT!
│   └── andromeda/
│       └── supabase.env        # SECRETS - NEVER COMMIT!
│
├── assets/                     # Sponsor branding
│   ├── orion/
│   │   ├── logo.png
│   │   └── icon.png
│   └── andromeda/
│       └── logo.png
│
├── edge_functions/             # Sponsor Edge Functions (EDC integrations)
│   ├── orion/
│   │   └── edc_sync/
│   └── andromeda/
│       └── edc_sync/
│
└── spec/                       # Sponsor-specific requirements (from Google Docs)
    ├── orion/
    │   └── (imported later)
    └── andromeda/
        └── (imported later)
```

**Key Principles**:

- ✅ Sponsor code extends core abstractions (SponsorConfig, EdcSync, etc.)
- ✅ Each sponsor isolated in their own subdirectory
- ✅ Build system composes core + sponsor at build time
- ✅ Database schema is shared (deployed per-sponsor, but same schema)
- ❌ NO sponsor-specific secrets committed to git (use `sponsor/*/config/*.env`)
- ❌ NO cross-sponsor code dependencies

**Codenames**: Use astronomical phenomena (e.g., Orion, Andromeda, Carina, Nebula) instead of real company names

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

## ⚠️ REQUIREMENT TRACEABILITY (MANDATORY) ⚠️

**This project uses formal requirement traceability. ALL code and specs MUST be linked to requirements.**

### For Complex Requirement Tasks

**Use the Requirements Sub-Agent**: For finding, creating, or analyzing requirements, delegate to the specialized Requirements sub-agent.

**See**: `agent-ops/ai/subagents/ORCHESTRATOR_GUIDE.md` for how to use sub-agents.

### Quick Rules for Simple Cases

**Code files need headers**:
```sql
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-d00007: Database Schema Implementation
```

**New requirements follow top-down cascade**:
1. PRD level (REQ-p00xxx): Business need
2. Ops level (REQ-o00xxx): How to deploy/operate
3. Dev level (REQ-d00xxx): How to implement
4. Code: Implements the requirements

**Never**:
- ❌ Write code first, then add requirements
- ❌ Skip PRD and start at Ops/Dev
- ❌ Describe existing code (use prescriptive SHALL/MUST)

### Quick Reference

| Need | Action |
|------|--------|
| Complex requirement work | Delegate to Requirements sub-agent (see ORCHESTRATOR_GUIDE.md) |
| Find requirements | Grep `spec/` for `### REQ-{id}:` OR use sub-agent |
| Create requirements | Use Requirements sub-agent for proper cascade |
| Validate requirements | Run `python3 tools/requirements/validate_requirements.py` |
| Format specification | Read `spec/requirements-format.md` |
| Linear ticket integration | See `tools/linear-cli/` section below |

**Violations will cause build failures. Add requirements BEFORE committing code.**

---

## Workflow for New Features

### Standard Development Workflow

1. **Ticket created**: Issue/ticket defines the need
2. **Assess if ADR needed**: Significant architectural decision with trade-offs?
   - ✅ Yes → Draft ADR in `docs/adr/` with "Proposed" status
   - ❌ No → Proceed to requirements
3. **Create requirements**: Delegate to Requirements sub-agent for proper top-down cascade (PRD → Ops → Dev)
4. **Validate requirements**: Run `python3 tools/requirements/validate_requirements.py`
5. **Implement code**: Add requirement references in file headers (use sub-agent to generate headers if needed)
6. **Update ADR** (if applicable): Set status to "Accepted"
7. **Commit**: Include ticket and requirement references in commit message

### Commit Message Format

```text
[TICKET-XXX] Brief description

Detailed explanation of changes.

Implements: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz
ADR: ADR-NNN-title (if applicable)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Quick Reference

### Specialized Sub-Agents

For complex domain-specific tasks, use specialized sub-agents:

| Sub-Agent | Purpose | Documentation |
|-----------|---------|---------------|
| **Requirements** | Find, create, validate requirements; generate code headers; analyze traceability | `agent-ops/ai/subagents/REQUIREMENTS.md` |

**How to use**: See `agent-ops/ai/subagents/ORCHESTRATOR_GUIDE.md` for delegation patterns.

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
| Sub-agent delegation | `agent-ops/ai/subagents/ORCHESTRATOR_GUIDE.md` |

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
<https://linear.app/settings/api>

**Store token securely** - Do NOT commit tokens to git.

Recommended: Use environment variable

```bash
# Add to your ~/.bashrc or ~/.zshrc:
export LINEAR_API_TOKEN="lin_api_YOUR_TOKEN_HERE"

# Then use in commands:
node fetch-tickets.js --token=$LINEAR_API_TOKEN

# Or create a wrapper script that sources the token:
# tools/linear-cli/.env.local (gitignored)
LINEAR_API_TOKEN="lin_api_YOUR_TOKEN_HERE"
```

**Note**: The `.env.local` pattern is already in `.gitignore` to prevent accidental commits.

### Common Workflows

**Create tickets for all new requirements**:

```bash
# 1. Dry-run to preview
./run-dry-run-all.sh

# 2. Create tickets
./create-tickets.sh

# 3. Add sub-system checklists
node add-subsystem-checklists.js --token=$LINEAR_API_TOKEN
```

**Link existing ticket to requirement**:

```bash
# Find ticket ID from Linear, then:
node update-ticket-with-requirement.js --token=$LINEAR_API_TOKEN --ticket-id=<UUID> --req-id=p00015
```

**Analyze ticket coverage**:

```bash
# Fetch all tickets and check REQ references
node fetch-tickets.js --token=$LINEAR_API_TOKEN --format=json | grep -i "REQ-"

# Find duplicates
node check-duplicates.js --token=$LINEAR_API_TOKEN
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

## Feature Diary System

**IMPORTANT**: Record all significant work in feature-based diary entries in `untracked-notes/`.

### When to Create a Diary Entry

Create a diary entry when:
- Working on a feature/bug/task that involves multiple files or steps
- Implementing requirements that will take more than 30 minutes
- Making architectural decisions or significant changes
- Any work that would benefit from a detailed record for future reference

**Do NOT create diary entries for**:
- Trivial fixes (typo corrections, formatting)
- Single-file changes that are self-explanatory

### Diary File Naming

**Format**: `diary-YYYY-MM-DD-feature-name.md`

**Examples**:
- `diary-2025-10-28-cicd-workflow-optimization.md`
- `diary-2025-10-27-carina-portal.md`
- `diary-2025-10-26-requirement-validation-tool.md`

**Key Points**:
- One file per feature (not per day)
- Use kebab-case for feature names
- Descriptive feature names that indicate what was worked on

### Diary Entry Structure

```markdown
# Diary - YYYY-MM-DD - Feature Name

## Project: Brief project description

**Start Time**: HH:MM
**Status**: ✅ Completed / 🚧 In Progress / ⚠️ Blocked
**Branch**: `feature/branch-name`

---

## Overview

Brief description of the goal and what was accomplished.

---

## Work Completed

### Phase 1: Phase Name (HH:MM - HH:MM)

✅ Task 1 completed
✅ Task 2 completed
🚧 Task 3 in progress

**Key Files Created/Modified**:
- `path/to/file1.ext` - Description
- `path/to/file2.ext` - Description

**Technologies/Tools Used**:
- Tool 1
- Tool 2

### Phase 2: Phase Name (HH:MM - HH:MM)

...

---

## Requirements Implemented

- REQ-p00XXX: Requirement description
- REQ-o00YYY: Requirement description
- REQ-d00ZZZ: Requirement description

---

## Issues Encountered and Solutions

### Issue 1: Description

**Problem**: Detailed description
**Solution**: How it was resolved
**Files Changed**: List of files

---

## Commits Made

- `abc1234` - Commit message 1
- `def5678` - Commit message 2

---

## Next Steps / Follow-up

- [ ] Task 1 remaining
- [ ] Task 2 remaining

---

## Lessons Learned

- Lesson 1
- Lesson 2
```

### Key Guidelines

1. **Update as you work**: Add entries incrementally, don't wait until the end
2. **Be specific**: Include file paths, requirement IDs, commit hashes
3. **Record decisions**: Document WHY choices were made, not just WHAT was done
4. **Track time**: Use time ranges to show progression through phases
5. **Link requirements**: Always reference REQ-* IDs for traceability
6. **Note blockers**: If blocked, document the blocker clearly

### Example Workflow

```bash
# Start work on feature
echo "# Diary - $(date +%Y-%m-%d) - CI/CD Optimization" > untracked-notes/diary-$(date +%Y-%m-%d)-cicd-optimization.md

# Add overview and initial phase
# ... work on feature ...

# Update diary with completed tasks
# ... mark tasks as ✅ ...

# At end, ensure requirements and commits are documented
```

---

## User Preferences

- Whenever you stop to ask me a question, play an audible notification using: `paplay ~/freesound/762115__jerryberumen__alarm-misc-message-alert-notification-quick-short-arp.wav`
- When modifying SQL, before implementing migration, ask the user if ANY database has ever been deployed with this system.
- When making notes or todo files that are about your plans or otherwise not part of the project, put them in untracked-notes/ and do not track them in git.

## Agent Ops System

This project uses the agent-ops system for multi-agent coordination.

**For AI Agents**:
- Read `agent-ops/ai/ORCHESTRATOR.md` for orchestrator workflow
- Use `ai-coordination` sub-agent for session management
- Run `./agent-ops/scripts/init-agent.sh` once per session

**Documentation**:
- `agent-ops/README.md` - System overview
- `agent-ops/HUMAN.md` - Human-readable guide
- `agent-ops/ai/AI_COORDINATION.md` - Sub-agent instructions

