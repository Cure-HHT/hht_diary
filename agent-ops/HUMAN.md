# Agent Ops - For Humans

## What Is This?

System for coordinating multiple AI agents working simultaneously without conflicts.

## How It Works

**Two Git Branches**:

1. **Product Branch** (`claude/feature-xyz-011ABC`)
   - Your feature code
   - Merged to `main` when done

2. **Agent Branch** (`claude/ai-agent-011ABC`)
   - Session tracking, diary, archives
   - Never merged, persists for history

**Key**: Agents work on product branch, track work on agent branch.

## Agents Involved

**Orchestrator** - Does the actual coding/testing
**AI-Coordination** - Manages session tracking in background

## See What Agents Are Working On

```bash
git fetch --all
git branch -r | grep "ai-agent-"
git show origin/ai-agent-alice:agent-ops/agents/alice/CONTEXT.md
```

## Session Archives

Located on agent branches in `agent-ops/archive/YYYYMMDD_HHMMSS_name/`:
- `plan.md` - What was planned
- `diary.md` - Chronological log of all actions
- `results.md` - Summary of outcomes

## Scripts

```bash
./agent-ops/scripts/show-agents.sh     # See all active agents
./agent-ops/scripts/new-session.sh     # Create session manually
./agent-ops/scripts/end-session.sh     # End session manually
```

## FAQ

**Q: Do I need to use this as a human developer?**
A: No, it's for AI agent coordination. Humans can work normally.

**Q: Will this create merge conflicts?**
A: No, each agent owns their namespace on their agent branch.

**Q: Where are the archives?**
A: On agent branches: `git show origin/ai-agent-X:agent-ops/archive/`

**Q: Can I delete old agent branches?**
A: Yes, but you lose history. They're kept for audit trail.

---

**Version**: 3.0
