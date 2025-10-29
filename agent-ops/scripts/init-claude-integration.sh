#!/usr/bin/env bash
#
# Initialize Agent Ops integration with Claude Code
#
# This script sets up:
# - Agent definitions in .claude/agents.json
# - Slash commands in .claude/commands/
# - Instructions in .claude/instructions.md
#
# Safe to re-run (idempotent)
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine script location and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"

echo -e "${BLUE}=== Agent Ops Claude Code Integration ===${NC}"
echo "Project root: $PROJECT_ROOT"
echo

# Create .claude directory if it doesn't exist
if [ ! -d "$CLAUDE_DIR" ]; then
    echo -e "${YELLOW}Creating .claude directory...${NC}"
    mkdir -p "$CLAUDE_DIR"
fi

if [ ! -d "$COMMANDS_DIR" ]; then
    echo -e "${YELLOW}Creating .claude/commands directory...${NC}"
    mkdir -p "$COMMANDS_DIR"
fi

# =============================================================================
# 1. Update .claude/instructions.md
# =============================================================================

echo -e "${BLUE}Updating .claude/instructions.md...${NC}"

INSTRUCTIONS_FILE="$CLAUDE_DIR/instructions.md"
AGENT_OPS_MARKER="## Agent Ops"

if grep -q "$AGENT_OPS_MARKER" "$INSTRUCTIONS_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ Agent Ops instructions already present${NC}"
else
    echo -e "${YELLOW}Adding Agent Ops instructions...${NC}"

    cat >> "$INSTRUCTIONS_FILE" << 'EOF'

## Agent Ops

This project uses Agent Ops for multi-agent coordination.

**Before starting work**:
1. Check for other agents: `./agent-ops/scripts/show-agents.sh`
2. Read: `agent-ops/ai/AGENT_GUIDE.md` (concise workflow)

**If working on multi-session task**:
1. Start session: `./agent-ops/scripts/new-session.sh "description"`
2. Maintain: `agent-ops/sessions/YYYYMMDD_HHMMSS/diary.md` (append after every action)
3. End session: `./agent-ops/scripts/end-session.sh`

**Quick reference**: `agent-ops/docs/quick-ref.md`

**Use slash commands**: `/agent-start`, `/agent-end`, `/agent-resume`
EOF

    echo -e "${GREEN}✓ Added Agent Ops instructions${NC}"
fi

# =============================================================================
# 2. Create slash commands
# =============================================================================

echo -e "${BLUE}Creating Agent Ops slash commands...${NC}"

# /agent-start command
AGENT_START_FILE="$COMMANDS_DIR/agent-start.md"
if [ -f "$AGENT_START_FILE" ]; then
    echo -e "${GREEN}✓ /agent-start already exists${NC}"
else
    echo -e "${YELLOW}Creating /agent-start...${NC}"
    cat > "$AGENT_START_FILE" << 'EOF'
---
description: Start an Agent Ops session for multi-session work
---

# Task: Start Agent Ops Session

Start a new Agent Ops session for tracking multi-session work with complete audit trail.

## When to Use

Use Agent Ops when:
- Work spans multiple Claude Code sessions
- Need complete audit trail (FDA compliance)
- Coordinating with other agents/developers
- Want to resume after context limits/reboots

**Don't use for**: Simple, single-session tasks that will complete in one go.

## Instructions

### 1. Check for Other Agents

First, see if anyone else is working on related files:

```bash
./agent-ops/scripts/show-agents.sh
```

If someone is editing the same files → coordinate with them!

### 2. Start Session

```bash
./agent-ops/scripts/new-session.sh "brief description of work"
```

This creates: `agent-ops/sessions/YYYYMMDD_HHMMSS/`

### 3. Fill Out Plan

Edit: `agent-ops/sessions/YYYYMMDD_HHMMSS/plan.md`

Include:
- Session goal (one sentence)
- Tasks (checkboxes)
- Success criteria
- Related requirements (REQ-*)
- Linear tickets (#CUR-XXX)

### 4. Start Diary

Edit: `agent-ops/sessions/YYYYMMDD_HHMMSS/diary.md`

Add initial entry:

```markdown
## [HH:MM] Session Start

**Goal**: [from plan.md]
**Context**: [current state]
**Tasks**: [list from plan.md]
```

### 5. During Work

**CRITICAL**: Append to diary.md after EVERY action:

```markdown
## [HH:MM] [Action Type]

[What happened]

**Files**: [if applicable]
**Result**: [outcome]
```

Action types: User Request, Investigation, Implementation, Error Encountered, Solution Applied, Decision Made, Task Complete, Blocked

**Update plan.md**: Check off tasks as completed.

## Quick Reference

**Diary entry types**: See `agent-ops/docs/workflows/during-session.md`

**End session**: Run `/agent-end` when done

**Full guide**: `agent-ops/ai/AGENT_GUIDE.md`

---

**Notes**:
- Maintain diary.md continuously (not at end!)
- Reference requirements: REQ-pXXXXX, REQ-oXXXXX, REQ-dXXXXX
- Link to Linear tickets: #CUR-XXX
- Keep plan.md updated with checkboxes
EOF
    echo -e "${GREEN}✓ Created /agent-start${NC}"
fi

# /agent-end command
AGENT_END_FILE="$COMMANDS_DIR/agent-end.md"
if [ -f "$AGENT_END_FILE" ]; then
    echo -e "${GREEN}✓ /agent-end already exists${NC}"
else
    echo -e "${YELLOW}Creating /agent-end...${NC}"
    cat > "$AGENT_END_FILE" << 'EOF'
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
EOF
    echo -e "${GREEN}✓ Created /agent-end${NC}"
fi

# /agent-resume command
AGENT_RESUME_FILE="$COMMANDS_DIR/agent-resume.md"
if [ -f "$AGENT_RESUME_FILE" ]; then
    echo -e "${GREEN}✓ /agent-resume already exists${NC}"
else
    echo -e "${YELLOW}Creating /agent-resume...${NC}"
    cat > "$AGENT_RESUME_FILE" << 'EOF'
---
description: Resume Agent Ops work from previous session
---

# Task: Resume Agent Ops Work

Resume Agent Ops work after reboot, context limit, or new day.

## Instructions

### 1. Check Current State

```bash
./agent-ops/scripts/resume.sh
```

This shows:
- Git status
- Agent CONTEXT.md (your last state)
- Latest session info
- Prompt to start new session

### 2. Read Context

**If you have agent branch** (e.g., `claude/ai-agent-011ABC`):

```bash
# See your last status (no checkout needed!)
git show origin/claude/ai-agent-011ABC:agent-ops/agents/011ABC/CONTEXT.md
```

**Read**:
- Current work
- Last session
- Current state
- Next steps

### 3. Read Latest Results

**If session still exists locally**:
```bash
cat agent-ops/sessions/LATEST/results.md
```

**If archived on agent branch**:
```bash
git show origin/claude/ai-agent-011ABC:agent-ops/archive/LATEST/results.md
```

Look for:
- What was completed
- What's incomplete
- What to do next

### 4. Decide: Resume or New Session

**Resume existing session** if:
- Context limit hit mid-work
- Same task continuing
- Session directory still exists locally

```bash
cd agent-ops/sessions/YYYYMMDD_HHMMSS/

# Continue appending to diary.md
```

Add entry:
```markdown
## [HH:MM] Session Resumed

Last action: [summarize last entry]
Continuing with: [next task]
```

**Start new session** if:
- Starting new task
- After reboot (sessions/ cleared)
- New day

```bash
./agent-ops/scripts/new-session.sh "continue previous work"
```

In plan.md, reference previous session:
```markdown
**Continuing From**: sessions/20251027_160000/ or archive/20251027_name/
```

### 5. Continue Work

Follow normal Agent Ops workflow:
- Maintain diary.md after every action
- Update plan.md checkboxes
- Reference requirements and tickets

## Quick Reference

**Resume script**: `./agent-ops/scripts/resume.sh`
**Start new session**: `/agent-start`
**End session**: `/agent-end`

**Full guide**: `agent-ops/docs/workflows/resume.md`
EOF
    echo -e "${GREEN}✓ Created /agent-resume${NC}"
fi

# /agent-guide command
AGENT_GUIDE_FILE="$COMMANDS_DIR/agent-guide.md"
if [ -f "$AGENT_GUIDE_FILE" ]; then
    echo -e "${GREEN}✓ /agent-guide already exists${NC}"
else
    echo -e "${YELLOW}Creating /agent-guide...${NC}"
    cat > "$AGENT_GUIDE_FILE" << 'EOF'
---
description: Show Agent Ops quick reference and documentation
---

# Agent Ops Quick Reference

## Commands

```bash
# Check for other agents
./agent-ops/scripts/show-agents.sh

# Start session
./agent-ops/scripts/new-session.sh "description"

# End session
./agent-ops/scripts/end-session.sh

# Resume work
./agent-ops/scripts/resume.sh
```

## Slash Commands

- `/agent-start` - Start new session
- `/agent-end` - End current session
- `/agent-resume` - Resume after interruption
- `/agent-guide` - Show this reference

## Documentation

**Quick start**: `agent-ops/ai/AGENT_GUIDE.md` (concise)

**Detailed docs**:
- `agent-ops/docs/concepts.md` - Core concepts
- `agent-ops/docs/two-branch-system.md` - Architecture
- `agent-ops/docs/file-guide.md` - File reference
- `agent-ops/docs/quick-ref.md` - Command cheat sheet

**Workflows**:
- `agent-ops/docs/workflows/start-session.md`
- `agent-ops/docs/workflows/during-session.md`
- `agent-ops/docs/workflows/end-session.md`
- `agent-ops/docs/workflows/resume.md`

## When to Use Agent Ops

**Use when**:
- Work spans multiple sessions
- Need complete audit trail
- Coordinating with other agents
- Want to resume after interruptions

**Don't use when**:
- Simple, single-session task
- Will complete in one go

## File Locations

| File | Location |
|------|----------|
| AI guide | `agent-ops/ai/AGENT_GUIDE.md` |
| Current session | `agent-ops/sessions/LATEST/` |
| Agent state | `agent-ops/agents/{agent-id}/CONTEXT.md` (on agent branch) |
| Templates | `agent-ops/ai/templates/` |

## Two-Branch System

**Product branch**: Your feature work
- Example: `claude/feature-xyz-011ABC`
- Contains: Code, docs, scripts

**Agent branch**: Coordination state
- Pattern: `claude/ai-agent-011ABC`
- Contains: Agent state, archives
- Never merged to main

**Discovery**: `git branch -r | grep "ai-agent-"`

**Read state**: `git show origin/ai-agent-X:agent-ops/agents/X/CONTEXT.md`

## Read More

Run `cat agent-ops/ai/AGENT_GUIDE.md` for the complete quick guide.
EOF
    echo -e "${GREEN}✓ Created /agent-guide${NC}"
fi

# =============================================================================
# 3. Summary
# =============================================================================

echo
echo -e "${GREEN}=== Complete ===${NC}"
echo
echo "Slash commands: /agent-start, /agent-end, /agent-resume, /agent-guide"
echo "Guide: agent-ops/ai/AGENT_GUIDE.md"
echo
echo -e "${BLUE}Ready! Use /agent-start to begin.${NC}"
