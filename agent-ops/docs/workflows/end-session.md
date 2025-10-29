# Ending a Session

**Purpose**: Archive work and update agent state.

---

## Quick End

```bash
./agent-ops/scripts/end-session.sh
```

This script will:
1. Prompt for results.md summary
2. Update agent CONTEXT.md
3. Optionally archive session

---

## Manual Process

### 1. Write results.md

Summarize the session:

```markdown
# Session Results

**Duration**: X hours
**Summary**: [2-3 sentences]

## Completed
- [x] Task 1
- [x] Task 2

## Incomplete
- [ ] Task 3 (50% - blocked on X)

## Files Changed
- Created: file1.yml
- Modified: file2.md

## Decisions
- Decision: [brief]
- Rationale: [why]

## Next Session Should
1. [First action]
2. [Second action]
```

See: [results.md template](../../ai/templates/results.md)

### 2. Update Agent Branch

Switch to agent branch and update state:

```bash
# Switch to agent branch
git checkout claude/ai-agent-011ABC

# Update CONTEXT.md
# Example:
# **Status**: 🟢 Active
# **Last Session**: 20251028_140000
# **Current State**: PR validation workflow complete, testing in progress
# **Next**: Monitor test PR, document if passed

git add agent-ops/agents/011ABC/CONTEXT.md
git commit -m "[AGENT] 011ABC: Session complete"
git push
```

### 3. Archive Session (If Milestone Complete)

```bash
# Still on agent branch
mv ../claude/feature-name-011ABC/agent-ops/sessions/20251028_140000/ \
   agent-ops/archive/20251028_140000_pr_validation/

git add agent-ops/archive/20251028_140000_pr_validation/
git commit -m "[ARCHIVE] Session: PR validation workflow complete"
git push
```

Otherwise, leave in `sessions/` (gitignored, local).

### 4. Switch Back to Product Branch

```bash
git checkout claude/feature-name-011ABC
```

---

## When to Archive

**Archive when**:
- Major milestone complete
- Feature complete
- Want permanent record for audit

**Don't archive when**:
- Work continuing tomorrow
- Mid-feature pause
- Just ending day

---

## Special Cases

### Context Limit Reached

**Don't end session!** Instead:

```markdown
## [HH:MM] Context Limit Reached

Current task: [what you're doing]
Status: [in progress]
Next step: [immediate next action]

Next instance should:
1. Resume in THIS session directory
2. Read diary.md
3. Continue from [task]
```

**Don't write results.md** - session not complete.

### User Says "Stop Here"

Normal session end - follow steps above.

### Emergency Stop

If user disappears:
1. Write brief results.md
2. Update agent CONTEXT.md with current state
3. Leave in sessions/ (not archived)

---

**See Also**:
- [Start Session](start-session.md)
- [During Session](during-session.md)
- [Resume Work](resume.md)

---

**Version**: 1.0
**Location**: agent-ops/docs/workflows/end-session.md
