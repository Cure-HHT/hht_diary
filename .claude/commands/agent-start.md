---
description: Start an Agent Ops session for multi-session work
---

# Task: Start Agent Ops Session

Start a new Agent Ops session for tracking multi-session work with complete audit trail.

## When to Use

Use Agent Ops when:
- Work spans multiple Claude Code sessions
- Need complete audit trail (FDA compliance)
- Coordinating with other agents/developers
- Want to resume after context limits/reboots

**Don't use for**: Simple, single-session tasks that will complete in one go.

## Instructions

### 1. Check for Other Agents

First, see if anyone else is working on related files:

```bash
./agent-ops/scripts/show-agents.sh
```

If someone is editing the same files → coordinate with them!

### 2. Start Session

```bash
./agent-ops/scripts/new-session.sh "brief description of work"
```

This creates: `agent-ops/sessions/YYYYMMDD_HHMMSS/`

### 3. Fill Out Plan

Edit: `agent-ops/sessions/YYYYMMDD_HHMMSS/plan.md`

Include:
- Session goal (one sentence)
- Tasks (checkboxes)
- Success criteria
- Related requirements (REQ-*)
- Linear tickets (#CUR-XXX)

### 4. Start Diary

Edit: `agent-ops/sessions/YYYYMMDD_HHMMSS/diary.md`

Add initial entry:

```markdown
## [HH:MM] Session Start

**Goal**: [from plan.md]
**Context**: [current state]
**Tasks**: [list from plan.md]
```

### 5. During Work

**CRITICAL**: Append to diary.md after EVERY action:

```markdown
## [HH:MM] [Action Type]

[What happened]

**Files**: [if applicable]
**Result**: [outcome]
```

Action types: User Request, Investigation, Implementation, Error Encountered, Solution Applied, Decision Made, Task Complete, Blocked

**Update plan.md**: Check off tasks as completed.

## Quick Reference

**Diary entry types**: See `agent-ops/docs/workflows/during-session.md`

**End session**: Run `/agent-end` when done

**Full guide**: `agent-ops/ai/AGENT_GUIDE.md`

---

**Notes**:
- Maintain diary.md continuously (not at end!)
- Reference requirements: REQ-pXXXXX, REQ-oXXXXX, REQ-dXXXXX
- Link to Linear tickets: #CUR-XXX
- Keep plan.md updated with checkboxes
