# Agent Ops Installation

## One-Time Setup

```bash
./agent-ops/scripts/init-claude-integration.sh
```

**Idempotent** - safe to re-run.

---

## What It Does

1. **Updates** `.claude/instructions.md` with Agent Ops workflow
2. **Creates slash commands** in `.claude/commands/`:
   - `/agent-start` - Start session
   - `/agent-end` - End session
   - `/agent-resume` - Resume work
   - `/agent-guide` - Quick reference
3. **Preserves** existing configs

---

## After Installation

```bash
# Check for other agents
./agent-ops/scripts/show-agents.sh

# Start working
/agent-start

# Quick reference
/agent-guide
```

---

## Manual Installation

### 1. Add to `.claude/instructions.md`:

```markdown
## Agent Ops

**Before work**: Check agents (`./agent-ops/scripts/show-agents.sh`), read `agent-ops/ai/AGENT_GUIDE.md`
**Commands**: `/agent-start`, `/agent-end`, `/agent-resume`, `/agent-guide`
```

### 2. Create slash command files in `.claude/commands/`

(Or just run `init-claude-integration.sh`)

---

## Verify

```bash
ls .claude/commands/agent-*.md
# Should show: agent-start.md, agent-end.md, agent-resume.md, agent-guide.md
```

---

## Uninstall

```bash
rm .claude/commands/agent-*.md
# Then edit .claude/instructions.md to remove "## Agent Ops" section
```

---

## Troubleshooting

**Permission denied**: `chmod +x agent-ops/scripts/init-claude-integration.sh`
**Commands don't appear**: Restart Claude Code, check `.claude/commands/` exists

---

**Version**: 1.0
**Location**: agent-ops/INSTALL.md
