# Agent Ops - AI Assistant Quick Guide

**Purpose**: Concise workflow for AI agents. Details in `agent-ops/docs/`.

---

## Before Starting Work

### 1. Check for Other Agents

```bash
./agent-ops/scripts/show-agents.sh
```

If someone is editing same files → coordinate!

### 2. Create Agent Branch (First Time Only)

Extract agent ID from your product branch suffix.

Example: `claude/feature-xyz-011ABC` → Agent ID: `011ABC`

```bash
git checkout -b claude/ai-agent-011ABC
mkdir -p agent-ops/agents/011ABC

cat > agent-ops/agents/011ABC/CONTEXT.md <<EOF
# Agent: 011ABC
**Status**: 🟢 Active
**Product Branch**: claude/feature-xyz-011ABC
**Linear Ticket**: #CUR-XXX
**Started**: $(date +"%Y-%m-%d %H:%M:%S")

## Current Work
[Brief description]
EOF

git add agent-ops/
git commit -m "[AGENT] 011ABC: Initialize agent"
git push -u origin claude/ai-agent-011ABC

git checkout claude/feature-xyz-011ABC  # Back to work
```

**Details**: [Two-Branch System](../docs/two-branch-system.md)

---

## Session Workflow

### Start Session

```bash
./agent-ops/scripts/new-session.sh "session description"
```

Or manually:
1. Create `agent-ops/sessions/YYYYMMDD_HHMMSS/`
2. Fill `plan.md` with goals and tasks
3. Start `diary.md` with initial entry

**Details**: [Start Session](../docs/workflows/start-session.md)

### During Session

**Append to diary.md after EVERY action**:

```markdown
## [HH:MM] [Action Type]

[What happened]

**Files**: [files affected]
**Result**: [outcome]
```

**Action types**: User Request, Investigation, Implementation, Error Encountered, Solution Applied, Decision Made, Task Complete, Blocked

**Update plan.md**: Check off tasks as you complete them.

**Details**: [During Session](../docs/workflows/during-session.md)

### End Session

```bash
./agent-ops/scripts/end-session.sh
```

Or manually:
1. Write `results.md` summary
2. Update agent `CONTEXT.md` on agent branch
3. Archive session if milestone complete

**Details**: [End Session](../docs/workflows/end-session.md)

---

## Diary Entry Examples

**User Request**:
```markdown
## [14:30] User Request
> User: "Create PR validation workflow"
Will create .github/workflows/pr-validation.yml with 6 jobs.
```

**Implementation**:
```markdown
## [14:40] Implementation
Created: .github/workflows/pr-validation.yml
- 6 jobs: requirements, headers, migrations, security, fda, summary
Requirements: REQ-o00052
```

**Error + Solution**:
```markdown
## [15:00] Error Encountered
Error: YAML syntax invalid
Location: pr-validation.yml:240

## [15:05] Solution Applied
Fixed: Added missing `runs-on: ubuntu-latest`
Result: ✅ Validated
```

**Task Complete**:
```markdown
## [15:30] Task Complete
✅ Create PR validation workflow
Completed: workflow file, syntax validation, testing
Updating plan.md.
```

---

## Requirement References

When implementing requirements, note in diary:

```markdown
## [14:40] Implementation

Implementing REQ-p00052: CI/CD Pipeline

Requirements addressed:
- REQ-p00052 (PRD)
- REQ-o00052 (Ops)
- REQ-d00052 (Dev)
```

---

## Update Agent State (Periodically)

Every ~30 min or at major milestones:

```bash
git checkout claude/ai-agent-011ABC
# Edit agent-ops/agents/011ABC/CONTEXT.md
git add agent-ops/agents/011ABC/
git commit -m "[AGENT] 011ABC: Progress update"
git push
git checkout claude/feature-xyz-011ABC  # Back to work
```

---

## Special Cases

### Context Limit Reached

**Don't end session!** Instead, append to diary:

```markdown
## [HH:MM] Context Limit Reached
Current task: [what you're doing]
Next step: [immediate action]

Next instance: Resume in THIS session directory.
```

**Don't** write results.md or update agent state.

### Resume After Reboot

```bash
./agent-ops/scripts/resume.sh
```

Shows current state and starts new session.

**Details**: [Resume Work](../docs/workflows/resume.md)

---

## Checklist

### Session Start
- [ ] Check for other agents
- [ ] Create or resume session
- [ ] Fill plan.md
- [ ] Start diary.md

### During Session
- [ ] Append to diary.md after every action
- [ ] Update plan.md checkboxes
- [ ] Reference requirements when implementing

### Session End
- [ ] Write results.md
- [ ] Update agent CONTEXT.md
- [ ] Archive if milestone complete

---

## Quick Reference

**Concepts**: [Core Concepts](../docs/concepts.md)
**Two-Branch System**: [Architecture](../docs/two-branch-system.md)
**Workflows**:
- [Start Session](../docs/workflows/start-session.md)
- [During Session](../docs/workflows/during-session.md)
- [End Session](../docs/workflows/end-session.md)
- [Resume Work](../docs/workflows/resume.md)

**Templates**: [agent-ops/ai/templates/](templates/)

---

**Version**: 1.0
**Location**: agent-ops/ai/AGENT_GUIDE.md
