# Agent Ops Installation

**Quick setup for Claude Code integration.**

---

## One-Time Setup

Run this script to integrate Agent Ops with Claude Code:

```bash
./agent-ops/scripts/init-claude-integration.sh
```

**Safe to re-run** - it's idempotent and won't overwrite existing configs.

---

## What It Does

The script sets up:

1. **Claude Code Instructions** (`.claude/instructions.md`)
   - Adds Agent Ops workflow instructions
   - References key documentation

2. **Slash Commands** (`.claude/commands/`)
   - `/agent-start` - Start new session
   - `/agent-end` - End current session
   - `/agent-resume` - Resume after interruption
   - `/agent-guide` - Show quick reference

3. **File Structure**
   - Creates `.claude/` directories if missing
   - Preserves existing commands and settings

---

## After Installation

### Quick Start

```bash
# Check for other agents
./agent-ops/scripts/show-agents.sh

# Start working
/agent-start
# or
./agent-ops/scripts/new-session.sh "description"
```

### Read the Guide

```bash
cat agent-ops/ai/AGENT_GUIDE.md
# or just use:
/agent-guide
```

---

## Manual Installation

If you prefer to install manually:

### 1. Add to `.claude/instructions.md`:

```markdown
## Agent Ops

This project uses Agent Ops for multi-agent coordination.

**Before starting work**:
1. Check for other agents: `./agent-ops/scripts/show-agents.sh`
2. Read: `agent-ops/ai/AGENT_GUIDE.md`

**Quick reference**: `agent-ops/docs/quick-ref.md`
**Slash commands**: `/agent-start`, `/agent-end`, `/agent-resume`
```

### 2. Copy slash commands:

```bash
cp agent-ops/docs/claude-commands/*.md .claude/commands/
```

(The init script creates these for you)

---

## Verify Installation

Check that slash commands are available:

```bash
ls .claude/commands/agent-*.md
```

Should show:
- `agent-start.md`
- `agent-end.md`
- `agent-resume.md`
- `agent-guide.md`

---

## Uninstall

To remove Agent Ops integration:

```bash
# Remove slash commands
rm .claude/commands/agent-*.md

# Remove instructions section
# Edit .claude/instructions.md and delete "## Agent Ops" section
```

---

## Troubleshooting

### Script fails with "Permission denied"

```bash
chmod +x agent-ops/scripts/init-claude-integration.sh
./agent-ops/scripts/init-claude-integration.sh
```

### Slash commands don't appear

- Restart Claude Code
- Check `.claude/commands/` exists
- Verify files have `.md` extension

### Instructions not showing

- Check `.claude/instructions.md` exists
- Verify "## Agent Ops" section present

---

## Next Steps

1. **Run the init script**: `./agent-ops/scripts/init-claude-integration.sh`
2. **Read the guide**: `agent-ops/ai/AGENT_GUIDE.md`
3. **Try it out**: Use `/agent-start` to begin a session

---

**Version**: 1.0
**Location**: agent-ops/INSTALL.md
