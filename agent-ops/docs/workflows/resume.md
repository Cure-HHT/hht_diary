# Resuming Work

**Use Case**: Starting work after reboot, context limit, or new day.

---

## Quick Resume

```bash
./agent-ops/scripts/resume.sh
```

Shows:
- Git status
- Agent CONTEXT.md (your last state)
- Latest session info
- Prompt to start new session

---

## Manual Resume

### 1. Check Agent State

Read your agent branch without checkout:

```bash
# See your last status
git show origin/claude/ai-agent-011ABC:agent-ops/agents/011ABC/CONTEXT.md
```

Or checkout agent branch:

```bash
git checkout claude/ai-agent-011ABC
cat agent-ops/agents/011ABC/CONTEXT.md
git checkout claude/feature-name-011ABC  # Back to work
```

### 2. Check Latest Session

Look in `sessions/` or `archive/`:

```bash
# Local sessions (if not rebooted)
ls -lt agent-ops/sessions/

# Archived sessions (on agent branch)
git show origin/claude/ai-agent-011ABC:agent-ops/archive/
```

Read `results.md` from latest session to understand:
- What was completed
- What's incomplete
- What to do next

### 3. Decide: Resume or New Session

**Resume existing session** if:
- Context limit hit mid-work
- Same task continuing
- Session directory still exists locally

**Start new session** if:
- Starting new task
- After reboot (sessions/ cleared)
- New day

---

## Resume Existing Session

If session directory exists:

```bash
cd agent-ops/sessions/20251028_140000/

# Read diary.md to see what was done
# Continue appending to diary.md
```

Example diary entry:

```markdown
## [09:00] Session Resumed

Last action: [summarize last diary entry]
Continuing with: [next action from plan.md]
```

---

## Start New Session

See: [Start Session](start-session.md)

Reference previous session:

```markdown
# Session Plan

**Continuing From**: sessions/20251027_160000/ or archive/20251027_feature_x/

[Rest of plan]
```

---

## After System Reboot

Sessions are local (gitignored), so lost after reboot.

To recover:
1. Check agent branch for archived sessions
2. Read latest `results.md` for context
3. Read agent `CONTEXT.md` for current state
4. Start new session continuing the work

**Pro tip**: Archive important sessions before rebooting!

---

**See Also**:
- [Start Session](start-session.md)
- [Core Concepts](../concepts.md)

---

**Version**: 1.0
**Location**: agent-ops/docs/workflows/resume.md
