# During a Session

**Golden Rule**: Append to `diary.md` after EVERY significant action.

---

## Diary Entry Types

Use these headers in diary.md:

### `[HH:MM] User Request`
User asked you to do something.

```markdown
## [14:30] User Request

> User: "Create PR validation workflow"

Understood. Will create .github/workflows/pr-validation.yml with 6 jobs.
```

### `[HH:MM] Investigation`
You searched/analyzed to understand something.

```markdown
## [14:35] Investigation

Searched for existing workflows.
- Found: .github/workflows/ (empty)
- Requirements: REQ-o00052

Decision: Use 6 separate jobs for clarity.
```

### `[HH:MM] Implementation`
You created/modified files.

```markdown
## [14:40] Implementation

Created: .github/workflows/pr-validation.yml
- 6 jobs: requirements, headers, migrations, security, fda, summary
- Trigger: pull_request, push to main

Requirements: REQ-o00052
```

### `[HH:MM] Error Encountered`
Something failed.

```markdown
## [15:00] Error Encountered

Error: GitHub Actions failing - "API keys found"
Cause: Security check flagging doc examples
File: tools/dev-env/doppler-setup.md:42
```

### `[HH:MM] Solution Applied`
You fixed an error.

```markdown
## [15:05] Solution Applied

Updated security check to exclude .md files.
Modified: .github/workflows/pr-validation.yml:85-92
Result: ✅ Passed
```

### `[HH:MM] Decision Made`
You made a technical choice.

```markdown
## [15:15] Decision Made

**Decision**: Use early-pass pattern for migration validation
**Rationale**: Cleaner for auditors than SKIPPED status
**Alternative**: Conditional job (shows as skipped)
**Impact**: Affects workflow readability

Will document in CONTEXT.md if significant.
```

### `[HH:MM] Task Complete`
You finished a task from plan.md.

```markdown
## [15:30] Task Complete

✅ Task: Create PR validation workflow

Completed:
- Created workflow file (250 lines)
- Validated syntax
- Tested with mock PR

Updating plan.md to mark complete.
```

### `[HH:MM] Blocked`
You hit a blocker.

```markdown
## [16:00] Blocked

Cannot configure branch protection: requires admin access.
Must be done via GitHub UI by user.

Adding to blockers in plan.md.
```

---

## Update plan.md

Check off tasks as you complete them:

```markdown
## Tasks
- [x] Task 1 (completed 15:30)
- [x] Task 2 (completed 16:00)
- [ ] Task 3
```

---

## Use notes.md for Scratch

Temporary info that doesn't fit in diary:
- Debug output
- Copy-paste buffers
- Analysis scratchpad

---

## Requirement References

When implementing requirements, note in diary:

```markdown
## [14:40] Implementation

Implementing REQ-p00052: CI/CD Pipeline

Created: .github/workflows/pr-validation.yml
Requirements addressed:
- REQ-p00052 (PRD)
- REQ-o00052 (Ops)
- REQ-d00052 (Dev)
```

---

## Update Agent State (Optional, Periodically)

Every ~30 min or at major milestones, update your agent branch:

```bash
# Switch to agent branch
git checkout claude/ai-agent-011ABC

# Edit agent-ops/agents/011ABC/CONTEXT.md
# Update with current progress

git add agent-ops/agents/011ABC/
git commit -m "[AGENT] 011ABC: Progress update"
git push

# Back to work
git checkout claude/feature-name-011ABC
```

---

**See Also**:
- [Start Session](start-session.md)
- [End Session](end-session.md)
- [Core Concepts](../concepts.md)

---

**Version**: 1.0
**Location**: agent-ops/docs/workflows/during-session.md
