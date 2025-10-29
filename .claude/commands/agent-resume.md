---
description: Resume Agent Ops work from previous session
---

# Task: Resume Agent Ops Work

Resume Agent Ops work after reboot, context limit, or new day.

## Instructions

### 1. Check Current State

```bash
./agent-ops/scripts/resume.sh
```

This shows:
- Git status
- Agent CONTEXT.md (your last state)
- Latest session info
- Prompt to start new session

### 2. Read Context

**If you have agent branch** (e.g., `claude/ai-agent-011ABC`):

```bash
# See your last status (no checkout needed!)
git show origin/claude/ai-agent-011ABC:agent-ops/agents/011ABC/CONTEXT.md
```

**Read**:
- Current work
- Last session
- Current state
- Next steps

### 3. Read Latest Results

**If session still exists locally**:
```bash
cat agent-ops/sessions/LATEST/results.md
```

**If archived on agent branch**:
```bash
git show origin/claude/ai-agent-011ABC:agent-ops/archive/LATEST/results.md
```

Look for:
- What was completed
- What's incomplete
- What to do next

### 4. Decide: Resume or New Session

**Resume existing session** if:
- Context limit hit mid-work
- Same task continuing
- Session directory still exists locally

```bash
cd agent-ops/sessions/YYYYMMDD_HHMMSS/

# Continue appending to diary.md
```

Add entry:
```markdown
## [HH:MM] Session Resumed

Last action: [summarize last entry]
Continuing with: [next task]
```

**Start new session** if:
- Starting new task
- After reboot (sessions/ cleared)
- New day

```bash
./agent-ops/scripts/new-session.sh "continue previous work"
```

In plan.md, reference previous session:
```markdown
**Continuing From**: sessions/20251027_160000/ or archive/20251027_name/
```

### 5. Continue Work

Follow normal Agent Ops workflow:
- Maintain diary.md after every action
- Update plan.md checkboxes
- Reference requirements and tickets

## Quick Reference

**Resume script**: `./agent-ops/scripts/resume.sh`
**Start new session**: `/agent-start`
**End session**: `/agent-end`

**Full guide**: `agent-ops/docs/workflows/resume.md`
