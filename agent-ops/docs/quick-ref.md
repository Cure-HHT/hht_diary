# Agent Ops Quick Reference

**Purpose**: Command cheat sheet for daily use.

---

## Daily Commands

### Check for Other Agents

```bash
./agent-ops/scripts/show-agents.sh
```

Shows all active agents and what they're working on.

### Start Session

```bash
./agent-ops/scripts/new-session.sh "session description"
```

Creates `agent-ops/sessions/YYYYMMDD_HHMMSS/` with templates.

### End Session

```bash
./agent-ops/scripts/end-session.sh
```

Prompts for results, updates agent state, optionally archives.

### Resume Work

```bash
./agent-ops/scripts/resume.sh
```

Shows current context, last session, next steps.

---

## First-Time Setup

### Create Agent Branch

```bash
# Extract agent ID from your product branch
# Example: claude/feature-xyz-011ABC → Agent ID: 011ABC

git checkout -b claude/ai-agent-011ABC
mkdir -p agent-ops/agents/011ABC

# Create CONTEXT.md
cat > agent-ops/agents/011ABC/CONTEXT.md <<EOF
# Agent: 011ABC
**Status**: 🟢 Active
**Product Branch**: claude/feature-xyz-011ABC
**Linear Ticket**: #CUR-XXX
**Started**: $(date +"%Y-%m-%d %H:%M:%S")

## Current Work
[Description]
EOF

git add agent-ops/
git commit -m "[AGENT] 011ABC: Initialize agent"
git push -u origin claude/ai-agent-011ABC

# Back to work
git checkout claude/feature-xyz-011ABC
```

---

## Agent Discovery

### List All Agents

```bash
git fetch --all
git branch -r | grep "ai-agent-"
```

### See What Agent is Doing

```bash
# Without checkout
git show origin/ai-agent-alice:agent-ops/agents/alice/CONTEXT.md
```

### Update Agent Cache

```bash
./agent-ops/scripts/sync-agents.sh
```

---

## Agent State Updates

### Update Your Status

```bash
git checkout claude/ai-agent-011ABC

# Edit agent-ops/agents/011ABC/CONTEXT.md

git add agent-ops/agents/011ABC/
git commit -m "[AGENT] 011ABC: Progress update"
git push

git checkout claude/feature-xyz-011ABC  # Back to work
```

### Archive Completed Session

```bash
git checkout claude/ai-agent-011ABC

# Move from product branch sessions/ to agent branch archive/
mv ../claude/feature-xyz-011ABC/agent-ops/sessions/20251028_140000/ \
   agent-ops/archive/20251028_140000_pr_validation/

git add agent-ops/archive/20251028_140000_pr_validation/
git commit -m "[ARCHIVE] Session: PR validation complete"
git push

git checkout claude/feature-xyz-011ABC
```

---

## Session Management

### Manual Session Creation

```bash
SESSION_DIR="agent-ops/sessions/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SESSION_DIR"
cp agent-ops/ai/templates/* "$SESSION_DIR/"
```

### Check Session Status

```bash
ls -lt agent-ops/sessions/
```

### Read Latest Results

```bash
# Local session
cat agent-ops/sessions/LATEST/results.md

# Archived (on agent branch)
git show origin/claude/ai-agent-011ABC:agent-ops/archive/LATEST/results.md
```

---

## Git Commands

### Product Branch Workflow

```bash
# Check status
git status

# Commit product code
git add .
git commit -m "[FEAT] Description"
git push -u origin claude/feature-xyz-011ABC
```

### Agent Branch Workflow

```bash
# Switch to agent branch
git checkout claude/ai-agent-011ABC

# Commit agent state
git add agent-ops/agents/011ABC/
git commit -m "[AGENT] 011ABC: Update"
git push

# Back to work
git checkout claude/feature-xyz-011ABC
```

---

## Diary Entry Quick Formats

### User Request
```markdown
## [HH:MM] User Request
> User: "Do X"
Will do Y.
```

### Implementation
```markdown
## [HH:MM] Implementation
Created: path/to/file
- Feature X
- Requirements: REQ-pXXXXX
```

### Error + Fix
```markdown
## [HH:MM] Error Encountered
Error: [description]
Cause: [why]

## [HH:MM] Solution Applied
Fixed: [how]
Result: ✅ Passed
```

### Task Complete
```markdown
## [HH:MM] Task Complete
✅ Task: [name]
Completed: [details]
```

---

## File Locations

| What | Where |
|------|-------|
| AI guide | `agent-ops/ai/AGENT_GUIDE.md` |
| Concepts | `agent-ops/docs/concepts.md` |
| Workflows | `agent-ops/docs/workflows/*.md` |
| Templates | `agent-ops/ai/templates/*.md` |
| Current session | `agent-ops/sessions/LATEST/` |
| Agent state | `agent-ops/agents/{agent-id}/CONTEXT.md` (on agent branch) |

---

## Common Tasks

| Task | Command |
|------|---------|
| Check agents | `./agent-ops/scripts/show-agents.sh` |
| Start work | `./agent-ops/scripts/new-session.sh "description"` |
| End work | `./agent-ops/scripts/end-session.sh` |
| Resume | `./agent-ops/scripts/resume.sh` |
| See agent status | `git show origin/ai-agent-X:agent-ops/agents/X/CONTEXT.md` |

---

## Troubleshooting

### Can't find agent-ops/
**Cause**: Wrong branch
**Fix**: Checkout product branch

### Session directory not found
**Cause**: No active session
**Fix**: Run `./agent-ops/scripts/new-session.sh`

### Merge conflict in agent files
**Cause**: Rare - should not happen if following two-branch system
**Fix**: Each agent owns their namespace. Check you're on correct branch.

---

**See Also**:
- [Core Concepts](concepts.md)
- [AI Agent Guide](../ai/AGENT_GUIDE.md)
- [File Guide](file-guide.md)

---

**Version**: 1.0
**Location**: agent-ops/docs/quick-ref.md
