---
description: End Agent Ops session
---

# End Agent Ops Session

### 1. Write `results.md`

Summary, completed/incomplete/blocked tasks, files changed, decisions, errors, requirements (REQ-*), next steps.

See: `agent-ops/ai/templates/results.md`

### 2. Update Agent Branch (Optional)

If you have agent branch (e.g., `claude/ai-agent-011ABC`):

```bash
git checkout claude/ai-agent-011ABC
# Edit agent-ops/agents/011ABC/CONTEXT.md
git add agent-ops/agents/011ABC/CONTEXT.md
git commit -m "[AGENT] 011ABC: Session complete"
git push
git checkout [product-branch]
```

### 3. Archive (Optional)

**Only if milestone complete**:

```bash
git checkout claude/ai-agent-011ABC
mv ../[product-branch]/agent-ops/sessions/YYYYMMDD_HHMMSS/ \
   agent-ops/archive/YYYYMMDD_HHMMSS_name/
git add agent-ops/archive/
git commit -m "[ARCHIVE] Session: name"
git push
git checkout [product-branch]
```

### Or Use Script

```bash
./agent-ops/scripts/end-session.sh  # Interactive
```

## Reference

**Guide**: `agent-ops/docs/workflows/end-session.md`
