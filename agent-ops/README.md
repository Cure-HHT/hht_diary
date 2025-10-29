# Agent Ops - Multi-Agent Coordination System

**Purpose**: Coordinate multiple AI agents and developers working in parallel without conflicts.

**Version**: 2.0 (Two-Branch Architecture)

---

## Installation

```bash
./agent-ops/scripts/init-claude-integration.sh
```

Creates slash commands and updates `.claude/instructions.md`. See [INSTALL.md](INSTALL.md).

---

## Quick Start

### For AI Agents

1. **Install**: `./agent-ops/scripts/init-claude-integration.sh`
2. **Read**: [AI Agent Guide](ai/AGENT_GUIDE.md)
3. **Check agents**: `./agent-ops/scripts/show-agents.sh`
4. **Start**: `/agent-start`

### For Humans

1. **Install**: `./agent-ops/scripts/init-claude-integration.sh`
2. **Read**: [Core Concepts](docs/concepts.md), [Two-Branch System](docs/two-branch-system.md)
3. **Reference**: [Quick Reference](docs/quick-ref.md)

---

## The Problem

Traditional tracking fails when:
- Multiple AI agents work simultaneously
- Sessions interrupted (context limits, reboots)
- Need to coordinate without merge conflicts
- Want complete audit trail

---

## The Solution

**Two branches**:
- **Product** (`claude/feature-name-011ABC`): Code + docs, merged to `main`
- **Agent** (`*/ai-agent-{agent-id}`): Coordination state, never merged

**Result**: No conflicts, async coordination, clean history.

---

## Key Features

✅ **No merge conflicts**: Each agent owns their namespace
✅ **Parallel work**: Multiple agents simultaneously
✅ **Async discovery**: See others' state via git
✅ **Complete audit trail**: Timestamped diary of all actions
✅ **FDA compliant**: Immutable history, requirement traceability
✅ **Linear integration**: Reference tickets in agent state

---

## Documentation

### For AI Assistants

- **[AI Agent Guide](ai/AGENT_GUIDE.md)** - Concise workflow (start here!)
- [Session Templates](ai/templates/) - plan.md, diary.md, results.md

### System Documentation

- **[Core Concepts](docs/concepts.md)** - Fundamental ideas
- [Two-Branch System](docs/two-branch-system.md) - Architecture details
- [File Guide](docs/file-guide.md) - What each file does
- [Quick Reference](docs/quick-ref.md) - Command cheat sheet

### Workflows

- [Start Session](docs/workflows/start-session.md)
- [During Session](docs/workflows/during-session.md)
- [End Session](docs/workflows/end-session.md)
- [Resume Work](docs/workflows/resume.md)

---

## Commands

| Command | Purpose |
|---------|---------|
| `./agent-ops/scripts/show-agents.sh` | Check for other agents |
| `./agent-ops/scripts/new-session.sh` | Start work session |
| `./agent-ops/scripts/end-session.sh` | End and archive session |
| `./agent-ops/scripts/resume.sh` | Show current state |
| `./agent-ops/scripts/sync-agents.sh` | Update agent cache |

---

## Directory Structure

```
agent-ops/
├── README.md                  # This file
├── docs/                      # System documentation
│   ├── concepts.md            # Core concepts
│   ├── two-branch-system.md   # Architecture
│   ├── file-guide.md          # File reference
│   ├── quick-ref.md           # Commands
│   └── workflows/             # Step-by-step guides
├── ai/                        # AI assistant resources
│   ├── AGENT_GUIDE.md         # Concise AI workflow
│   └── templates/             # Session templates
├── scripts/                   # Automation tools
├── sessions/                  # Active work (gitignored)
└── (On agent branches only):
    ├── agents/{agent-id}/     # Agent state
    └── archive/               # Completed sessions
```

---

## Example Workflow

```bash
# 1. Check for other agents
./agent-ops/scripts/show-agents.sh

# 2. Start session
./agent-ops/scripts/new-session.sh "implement feature X"

# 3. Work and maintain diary
# - Edit agent-ops/sessions/YYYYMMDD_HHMMSS/diary.md
# - Append after every action

# 4. End session
./agent-ops/scripts/end-session.sh

# 5. Update agent branch (if milestone complete)
git checkout claude/ai-agent-011ABC
# Move session to archive/, commit, push
```

---

## Two-Branch Architecture Summary

### Product Branch (`claude/feature-xyz-011ABC`)
- Contains: Product code, system docs, scripts
- Work: Implement features, commit code
- Merge: To `main` when complete

### Agent Branch (`claude/ai-agent-011ABC`)
- Contains: Agent state, session archives
- Work: Update CONTEXT.md, archive sessions
- Merge: Never (persists for coordination)

### Coordination
- Agents discover via: `git branch -r | grep "ai-agent-"`
- Read state via: `git show origin/ai-agent-X:agent-ops/agents/X/CONTEXT.md`
- No conflicts: Each agent owns their directory

---

## Integration with Claude Code

Add to `CLAUDE.md`:

```markdown
## Agent Ops

**Before**: Check agents, read `agent-ops/ai/AGENT_GUIDE.md`, start with `/agent-start`
**During**: Maintain `diary.md`, reference REQ-*, update `plan.md`
**After**: `/agent-end`, update agent branch
```

---

## Support

- **Questions?** Read: [Core Concepts](docs/concepts.md)
- **AI workflow?** Read: [AI Agent Guide](ai/AGENT_GUIDE.md)
- **Daily use?** Read: [Quick Reference](docs/quick-ref.md)
- **Commands?** Run scripts in: `agent-ops/scripts/`

---

**Created**: 2025-10-28
**Version**: 2.0
**Location**: agent-ops/README.md
