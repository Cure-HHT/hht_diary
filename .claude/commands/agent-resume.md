---
description: Resume Agent Ops work
---

# Resume Agent Ops Work

### 1. Check State

```bash
./agent-ops/scripts/resume.sh  # Shows git status, context, latest session
```

### 2. Read Context

```bash
# Your last status (no checkout needed)
git show origin/claude/ai-agent-011ABC:agent-ops/agents/011ABC/CONTEXT.md

# Latest results
cat agent-ops/sessions/LATEST/results.md
# Or: git show origin/claude/ai-agent-011ABC:agent-ops/archive/LATEST/results.md
```

### 3. Resume or New

**Resume existing** (context limit mid-work, session still local):
```bash
cd agent-ops/sessions/YYYYMMDD_HHMMSS/
# Continue diary.md:
## [HH:MM] Session Resumed
Last: [summary]
Continuing: [task]
```

**Start new** (after reboot, new task):
```bash
./agent-ops/scripts/new-session.sh "continue work"
# In plan.md: **Continuing From**: sessions/20251027_160000/
```

## Reference

**Script**: `./agent-ops/scripts/resume.sh`
**Guide**: `agent-ops/docs/workflows/resume.md`
