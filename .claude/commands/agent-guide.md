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
