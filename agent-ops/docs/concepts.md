# Agent Ops Core Concepts

**Purpose**: Define core concepts once for reference throughout the system.

---

## Two-Branch Architecture

**Product Branches**: Contain actual product code + system docs
- Example: `claude/feature-name-{session-id}`
- Contains: `database/`, `apps/`, `.github/`, etc.
- Contains: `agent-ops/docs/`, `agent-ops/scripts/`, `agent-ops/ai/`
- **Does NOT contain**: Agent state or session archives
- **Lifecycle**: Merged to `main` when feature complete

**Agent Branches**: Contain coordination state only
- Pattern: `*/ai-agent-{agent-id}`
- Example: `claude/ai-agent-011ABC`
- Contains: `agent-ops/agents/{agent-id}/`, `agent-ops/archive/`
- **Does NOT contain**: Product code
- **Lifecycle**: Never merged to `main` (persist for history)

---

## Key Files

### Session Files (Per Work Session, Gitignored)

Located in: `agent-ops/sessions/YYYYMMDD_HHMMSS/`

- **plan.md**: Goals and tasks for this session
- **diary.md**: Chronological log (append-only)
- **results.md**: Summary of outcomes (written at session end)
- **notes.md**: Scratch space

### Agent State Files (On Agent Branch)

Located in: `agent-ops/agents/{agent-id}/`

- **CONTEXT.md**: Current work, status, Linear ticket
- **STATUS.md**: Last active timestamp
- **CURRENT_SESSION.md**: Link to active session

### Archive (On Agent Branch)

Located in: `agent-ops/archive/YYYYMMDD_HHMMSS_name/`

Contains completed session files (plan.md, diary.md, results.md)

---

## Discovery Pattern

Agents discover each other via git branches:

```bash
# Find all agents
git fetch --all
git branch -r | grep "ai-agent-"

# See what Alice is working on (no checkout needed!)
git show origin/ai-agent-alice:agent-ops/agents/alice/CONTEXT.md
```

**Key Benefit**: No file conflicts (each agent owns their namespace)

---

## Coordination Flow

1. **Before work**: Check for other agents (`./agent-ops/scripts/show-agents.sh`)
2. **Start session**: Create local session (`./agent-ops/scripts/new-session.sh`)
3. **During work**: Maintain diary.md with every action
4. **End session**: Archive to agent branch (`./agent-ops/scripts/end-session.sh`)
5. **Push updates**: Push agent branch so others see your state

---

## Naming Conventions

### Agent IDs

Extract from product branch suffix:
- Branch: `claude/feature-xyz-011ABC` → Agent ID: `011ABC`
- Branch: `cursor/auth-20251028` → Agent ID: `20251028`

### Agent Branches

Pattern: `{tool-prefix}/ai-agent-{agent-id}`
- Claude Code: `claude/ai-agent-011ABC`
- Cursor: `cursor/ai-agent-alice`
- Human: `ai-agent-yourname`

### Session Timestamps

Format: `YYYYMMDD_HHMMSS`
- Example: `20251029_143022`
- Why: Unique, sortable, no conflicts

---

## Linear Integration

Agent CONTEXT.md references Linear tickets:

```markdown
**Linear Ticket**: #CUR-123
**Product Branch**: claude/feature-name-011ABC

## Current Work
Implementing REQ-o00052 (CI/CD validation workflow).
See Linear #CUR-123 for requirements.
```

This provides traceability from agent → ticket → requirement.

---

## FDA Compliance

- **Complete audit trail**: diary.md logs every action with timestamps
- **Immutable history**: Archives committed to git
- **Requirement traceability**: Link diary entries to REQ-* IDs
- **Decision log**: Document significant choices
- **Per-agent accountability**: Each agent has separate history

---

**Version**: 1.0
**Location**: agent-ops/docs/concepts.md
