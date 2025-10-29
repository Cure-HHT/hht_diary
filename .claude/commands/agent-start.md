---
description: Start Agent Ops session
---

# Start Agent Ops Session

## When to Use

Multi-session work requiring audit trail or coordination.
**Skip for**: Single-session tasks.

## Instructions

### 1. Check Agents

```bash
./agent-ops/scripts/show-agents.sh  # Coordinate if editing same files
```

### 2. Start

```bash
./agent-ops/scripts/new-session.sh "description"
```

### 3. Fill `plan.md`

- Goal, tasks, success criteria
- Requirements (REQ-*), tickets (#CUR-XXX)

### 4. Start `diary.md`

```markdown
## [HH:MM] Session Start
**Goal**: [from plan.md]
**Tasks**: [list]
```

### 5. During Work

Append after EVERY action:
```markdown
## [HH:MM] [Action Type]
[What happened]
**Files**: [if applicable]
```

Action types: User Request, Investigation, Implementation, Error, Solution, Decision, Complete, Blocked

**Update** `plan.md` checkboxes as tasks complete.

## Reference

**Details**: `agent-ops/docs/workflows/during-session.md`
**End**: `/agent-end`
**Guide**: `agent-ops/ai/AGENT_GUIDE.md`
