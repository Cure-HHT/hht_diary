# Starting a Session

**Prerequisites**: You've checked for other agents (`show-agents.sh`)

---

## Quick Start

```bash
./agent-ops/scripts/new-session.sh "session description"
```

Creates: `agent-ops/sessions/YYYYMMDD_HHMMSS/`

---

## What to Read First

### 1. Check Other Agents
```bash
./agent-ops/scripts/show-agents.sh
```

If someone is editing same files → coordinate!

### 2. Read Agent State (if agent branch exists)

From your agent branch (e.g., `claude/ai-agent-011ABC`):
- `agent-ops/agents/{agent-id}/CONTEXT.md` - Your last status
- Check latest archive if continuing work

### 3. Create Session Plan

Edit `sessions/YYYYMMDD_HHMMSS/plan.md`:
- Session goal (one sentence)
- Tasks list (checkboxes)
- Success criteria
- Related requirements/tickets

See: [plan.md template](../../ai/templates/plan.md)

### 4. Start Diary

Edit `sessions/YYYYMMDD_HHMMSS/diary.md`:

```markdown
## [HH:MM] Session Start

**Goal**: [From plan.md]

**Context**: [Brief current state]

**Tasks**: [List from plan.md]
```

---

## Manual Process

If not using scripts:

1. Create directory: `mkdir -p agent-ops/sessions/$(date +%Y%m%d_%H%M%S)`
2. Copy templates from `agent-ops/ai/templates/`
3. Fill out plan.md
4. Start diary.md with timestamp

---

**See Also**:
- [During Session](during-session.md)
- [End Session](end-session.md)
- [Core Concepts](../concepts.md)

---

**Version**: 1.0
**Location**: agent-ops/docs/workflows/start-session.md
