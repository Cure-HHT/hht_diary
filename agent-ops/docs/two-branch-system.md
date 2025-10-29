# Two-Branch Architecture

**Problem**: Multiple AI agents working simultaneously need to coordinate without merge conflicts.

**Solution**: Separate branches for product code vs. coordination state.

---

## Architecture Overview

```
main (product code)
├── database/
├── apps/
└── agent-ops/
    ├── docs/        # System documentation
    ├── ai/          # AI templates and guides
    └── scripts/     # Automation tools

claude/feature-X-011ABC (product branch)
├── database/migrations/...    # Your feature work
├── apps/...
└── .github/workflows/...

claude/ai-agent-011ABC (agent branch - coordination only)
└── agent-ops/
    ├── agents/
    │   └── 011ABC/
    │       ├── CONTEXT.md       # What I'm working on
    │       ├── STATUS.md        # Last active time
    │       └── CURRENT_SESSION.md
    └── archive/
        └── 20251028_140000_phase2/  # Completed sessions
            ├── plan.md
            ├── diary.md
            └── results.md
```

---

## Why This Works

### No Merge Conflicts

Each agent owns their namespace:
- Alice writes to: `agent-ops/agents/alice/`
- Bob writes to: `agent-ops/agents/bob/`
- Claude writes to: `agent-ops/agents/011ABC/`

**Impossible to conflict!**

### Async Coordination

Read others' state without checkout:

```bash
# See what Alice is doing RIGHT NOW
git show origin/ai-agent-alice:agent-ops/agents/alice/CONTEXT.md

# Output:
# Working on: Authentication module
# Files: src/auth/jwt_validator.dart
# ETA: Complete today
```

### Clean History

- **Product branches**: Only product code + commits
- **Agent branches**: Only coordination state
- **Main branch**: Only merged product code (no agent state pollution)

---

## Workflow

### 1. Create Agent Branch (First Time)

```bash
# Extract agent ID from your product branch
# Branch: claude/CICD-phase-2-011ABC → Agent ID: 011ABC

# Create agent branch
git checkout -b claude/ai-agent-011ABC
mkdir -p agent-ops/agents/011ABC

# Initialize CONTEXT.md
cat > agent-ops/agents/011ABC/CONTEXT.md <<EOF
# Agent: 011ABC

**Status**: 🟢 Active
**Product Branch**: claude/CICD-phase-2-011ABC
**Linear Ticket**: #CUR-85
**Started**: $(date +"%Y-%m-%d %H:%M:%S")

## Current Work
Starting CI/CD implementation.
EOF

git add agent-ops/
git commit -m "[AGENT] 011ABC: Initialize agent"
git push -u origin claude/ai-agent-011ABC

# Switch back to work
git checkout claude/CICD-phase-2-011ABC
```

### 2. Work on Product Branch

All actual work happens on product branch:

```bash
# You are on: claude/CICD-phase-2-011ABC
./agent-ops/scripts/new-session.sh "implement pr validation"

# Creates: agent-ops/sessions/20251028_140000/ (local, gitignored)
# Do work, maintain diary...
```

### 3. Update Agent State Periodically

Every ~30 min or at major milestones:

```bash
# Switch to agent branch
git checkout claude/ai-agent-011ABC

# Update your CONTEXT.md
# (Edit file to reflect current status)

git add agent-ops/agents/011ABC/
git commit -m "[AGENT] 011ABC: Progress update"
git push origin claude/ai-agent-011ABC

# Back to work
git checkout claude/CICD-phase-2-011ABC
```

### 4. End Session and Archive

```bash
# On product branch
./agent-ops/scripts/end-session.sh

# Archives to: agent-ops/sessions/20251028_140000/ → (ready to commit)

# Switch to agent branch
git checkout claude/ai-agent-011ABC

# Move archive
mv ../claude/CICD-phase-2-011ABC/agent-ops/sessions/20251028_140000_phase2/ \
   agent-ops/archive/20251028_140000_phase2/

git add agent-ops/archive/20251028_140000_phase2/
git commit -m "[ARCHIVE] Session: Phase 2 PR validation complete"

# Update CONTEXT.md with completion
git add agent-ops/agents/011ABC/
git commit -m "[AGENT] 011ABC: Session complete"
git push origin claude/ai-agent-011ABC
```

---

## Agent Discovery

```bash
# See all active agents
./agent-ops/scripts/show-agents.sh

# Output:
# Active Agents:
# - alice (2 hours ago): Working on auth module
# - bob (1 day ago): Fixed bug in reports
# - 011ABC (just now): Implementing CI/CD
```

Script does:
1. `git fetch --all`
2. `git branch -r | grep "ai-agent-"`
3. Read each agent's CONTEXT.md
4. Display summary

---

## Benefits

✅ **No conflicts**: Each agent in separate namespace
✅ **Parallel work**: Multiple agents simultaneously
✅ **Async discovery**: See others' state via git
✅ **Clean main**: Agent coordination doesn't pollute product code
✅ **Persistent history**: Agent branches never deleted
✅ **Linear tracking**: Reference tickets in agent state

---

## Key Rules

### DO:
- Check for other agents before starting (`show-agents.sh`)
- Update agent state periodically
- Archive completed sessions to agent branch
- Reference Linear tickets in CONTEXT.md

### DON'T:
- Commit agent state to product branches
- Merge agent branches to main
- Skip agent discovery (may cause conflicts on same files)
- Forget to push agent branch (others won't see your state)

---

**Version**: 1.0
**Location**: agent-ops/docs/two-branch-system.md
