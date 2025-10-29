---
description: End an Agent Ops session and archive results
---

# Task: End Agent Ops Session

End the current Agent Ops session, write results summary, and optionally archive.

## Instructions

### 1. Write results.md

Edit: `agent-ops/sessions/YYYYMMDD_HHMMSS/results.md`

Include:
- **Summary**: 2-4 sentences of what was accomplished
- **Completed tasks**: From plan.md
- **Incomplete tasks**: What's left and why
- **Blocked tasks**: What's blocking them
- **Files changed**: Created/modified/deleted
- **Decisions made**: Technical choices with rationale
- **Errors encountered**: What failed and how fixed
- **Requirements addressed**: REQ-* IDs
- **What next session should do**: Immediate next steps

See template: `agent-ops/ai/templates/results.md`

### 2. Update Agent Branch (If You Have One)

If you created an agent branch earlier (e.g., `claude/ai-agent-011ABC`):

```bash
# Switch to agent branch
git checkout claude/ai-agent-011ABC

# Update CONTEXT.md with current state
# Edit: agent-ops/agents/011ABC/CONTEXT.md
# - Update **Status**
# - Update **Last Session**
# - Update **Current State**
# - Update **Current Work**

git add agent-ops/agents/011ABC/CONTEXT.md
git commit -m "[AGENT] 011ABC: Session complete"
git push

# Back to product branch
git checkout [your-product-branch]
```

### 3. Archive Session (If Milestone Complete)

**Only archive if**:
- Major milestone complete
- Feature done
- Want permanent record

**Don't archive if**:
- Work continuing tomorrow
- Mid-feature pause

**To archive**:

```bash
# On agent branch
git checkout claude/ai-agent-011ABC

# Move session to archive with descriptive name
mv ../[product-branch]/agent-ops/sessions/YYYYMMDD_HHMMSS/ \
   agent-ops/archive/YYYYMMDD_HHMMSS_descriptive_name/

git add agent-ops/archive/
git commit -m "[ARCHIVE] Session: descriptive name"
git push

git checkout [your-product-branch]
```

### 4. Or Use the Script

Alternatively, run:

```bash
./agent-ops/scripts/end-session.sh
```

This will prompt you interactively.

## What Happens Next

Next session:
- Read your agent CONTEXT.md for current state
- Read latest results.md to understand what was done
- Start new session with `/agent-start`

## Quick Reference

**Session files**: `agent-ops/sessions/YYYYMMDD_HHMMSS/`
**Agent state**: `agent-ops/agents/{agent-id}/CONTEXT.md` (on agent branch)
**Archive**: `agent-ops/archive/` (on agent branch)

**Full guide**: `agent-ops/docs/workflows/end-session.md`
