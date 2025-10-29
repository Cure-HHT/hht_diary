# Agent-Ops System Development Guide

**Purpose**: This file contains instructions for **MODIFYING** the agent-ops system itself. If you're here to **USE** agent-ops for session tracking, read the root `CLAUDE.md` instead.

---

## When to Read This File

Read this file when:
- ✅ Modifying agent-ops scripts in `agent-ops/scripts/`
- ✅ Updating AI instructions in `agent-ops/ai/`
- ✅ Changing session templates in `agent-ops/ai/templates/`
- ✅ Fixing bugs in the agent-ops system
- ✅ Adding new features to agent-ops

Do NOT read this for:
- ❌ Normal feature development using sessions
- ❌ Working on product code with session tracking

---

## Architecture Overview

### Directory Structure

```
agent-ops/
├── ai/                          # AI agent instructions
│   ├── ORCHESTRATOR.md          # Main Claude instance workflow
│   ├── AI_COORDINATION.md       # ai-coordination sub-agent instructions
│   ├── AGENT_NAMES.md           # Agent naming system
│   └── templates/               # Session file templates
│       ├── diary.md
│       └── results.md
├── scripts/                     # Automation scripts
│   ├── install.sh               # One-time project setup
│   ├── init-agent.sh            # Per-session agent initialization
│   ├── new-session.sh           # Create new session
│   ├── end-session.sh           # Manual session completion
│   ├── resume.sh                # Resume interrupted session
│   ├── show-agents.sh           # List active agents
│   └── sync-*.sh                # Agent branch sync utilities
├── sessions/                    # Active sessions (gitignored)
│   └── YYYYMMDD_HHMMSS/
│       └── diary.md
├── agents/                      # Agent state (on agent branches)
│   └── {agent_name}/
│       └── CONTEXT.md
└── archive/                     # Completed sessions (on agent branches)
```

### Two-Branch Model

**Product Branch** (main, feature/*, etc.):
- Where orchestrator (main Claude) works 100% of the time
- Active sessions live in `agent-ops/sessions/` (gitignored)
- Never switches branches during work

**Agent Branch** (claude/wrench, claude/hammer, etc.):
- Managed via git worktree by ai-coordination sub-agent
- Archives completed sessions
- Tracks agent state in CONTEXT.md
- One branch per agent name (mechanical objects)

### Workflow

1. Orchestrator runs `init-agent.sh` → creates `untracked-notes/agent-ops.json`
2. Orchestrator delegates to `ai-coordination` sub-agent via Task tool
3. ai-coordination reads config, uses worktree for agent branch operations
4. ai-coordination creates/updates sessions, always returns to main directory
5. No branch switching in main directory → parallel agents safe

---

## Modifying AI Instructions

### ORCHESTRATOR.md

**Audience**: Main Claude Code instance (you!)

**Purpose**:
- When to use session tracking
- How to delegate to ai-coordination
- Event types and formats

**Update when**:
- Changing session workflow
- Adding new event types
- Modifying delegation patterns

### AI_COORDINATION.md

**Audience**: ai-coordination Task sub-agent

**Purpose**:
- Session lifecycle management
- Agent branch operations via worktree
- JSON response formats

**Update when**:
- Changing session file structure
- Modifying agent branch layout
- Adding new coordination features

**Critical**: ai-coordination is invoked via Task tool. Changes here affect the sub-agent's behavior directly.

---

## Modifying Scripts

### Script Development Guidelines

1. **Always use `set -euo pipefail`** at the top
2. **Read agent config first**: `untracked-notes/agent-ops.json` via jq
3. **Use worktrees**: Never `git checkout` in main directory
4. **Preserve working directory**: `cd` back to main dir after worktree ops
5. **Validate inputs**: Check for required config/arguments
6. **Color output**: Use GREEN/YELLOW/RED/CYAN for clarity

### Testing Scripts

```bash
# Test in a clean branch
git checkout -b test/agent-ops-changes

# Run with bash -x to see execution
bash -x ./agent-ops/scripts/init-agent.sh

# Check agent config
cat untracked-notes/agent-ops.json

# Clean up
rm untracked-notes/agent-ops.json
git checkout -
git branch -D test/agent-ops-changes
```

---

## Adding New Features

### Adding a New Event Type

1. **Update AI_COORDINATION.md**: Add event handler documentation
2. **Update ORCHESTRATOR.md**: Document when to use the event
3. **Create/modify scripts**: Add script support if needed
4. **Test**: Create test session and verify end-to-end

### Adding a New Script

1. **Create in `agent-ops/scripts/`**: Use existing scripts as templates
2. **Make executable**: `chmod +x agent-ops/scripts/new-script.sh`
3. **Follow guidelines**: Read agent config, use worktrees, validate inputs
4. **Document**: Add to README.md and relevant AI instruction files
5. **Update install.sh**: If script needs setup, add to installation

---

## Installation System

The `install.sh` script sets up agent-ops for new projects:

1. Checks prerequisites (jq, git)
2. Configures .gitignore
3. Creates directories
4. **Adds agent-ops section to root CLAUDE.md**
5. Installs ai-coordination Task sub-agent to `.claude/agents/`
6. Verifies installation

**When modifying install.sh**:
- Update CLAUDE.md template (lines 143-159) to match root CLAUDE.md format
- Keep ai-coordination agent definition (lines 213-261) in sync with latest features
- Update version number if making significant changes

---

## Common Patterns

### Reading Agent Config

```bash
CONFIG_FILE="untracked-notes/agent-ops.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Agent not initialized. Run: ./agent-ops/scripts/init-agent.sh"
  exit 1
fi

AGENT_NAME=$(jq -r '.agent_name' "$CONFIG_FILE")
AGENT_BRANCH=$(jq -r '.agent_branch' "$CONFIG_FILE")
WORKTREE_PATH=$(jq -r '.worktree_path' "$CONFIG_FILE")
MAIN_DIR=$(pwd)
```

### Using Worktree Safely

```bash
# Setup worktree if needed
if [ ! -d "$WORKTREE_PATH" ]; then
  git worktree add "$WORKTREE_PATH" "$AGENT_BRANCH"
fi

# Work in worktree
cd "$WORKTREE_PATH"

# Do work...
echo "Working on agent branch"
git add .
git commit -m "Update"
git push

# ALWAYS return to main directory
cd "$MAIN_DIR"
```

### Session Directory Paths

```bash
# Active session on product branch (main directory)
SESSION_DIR="agent-ops/sessions/$(date +%Y%m%d_%H%M%S)"

# Archive on agent branch (worktree)
ARCHIVE_DIR="$WORKTREE_PATH/agent-ops/archive/$(basename $SESSION_DIR)_feature_name"
```

---

## Troubleshooting Development

### Worktree Issues

```bash
# List all worktrees
git worktree list

# Remove stuck worktree
git worktree remove /path/to/worktree

# Prune deleted worktrees
git worktree prune
```

### Agent Config Issues

```bash
# View current config
cat untracked-notes/agent-ops.json

# Regenerate config
rm untracked-notes/agent-ops.json
./agent-ops/scripts/init-agent.sh
```

### Testing Without Committing

Use `--dry-run` patterns in scripts or wrap operations in:

```bash
if [ "${DRY_RUN:-false}" = "true" ]; then
  echo "Would execute: git commit -m 'message'"
else
  git commit -m "message"
fi
```

---

## Version History

- **v4.0**: Simplified system (removed plan.md, sessions tracked via diary only)
- **v3.0**: Added worktree support for parallel agents
- **v2.0**: Introduced ai-coordination Task sub-agent
- **v1.0**: Initial agent-ops system

---

**For usage instructions**: See root `CLAUDE.md` → "Agent Ops System" section
**For human users**: See `agent-ops/HUMAN.md`
