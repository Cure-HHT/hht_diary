# Agent Ops - For Humans

## What Is This?

System for coordinating multiple AI agents working simultaneously without conflicts.

## How It Works

**Two Git Branches**:

1. **Product Branch** (`claude/feature-xyz-011ABC`)
   - Your feature code
   - Merged to `main` when done

2. **Agent Branch** (`claude/wrench`, `claude/hammer`, etc.)
   - Named after mechanical objects (deterministic from session ID)
   - Session tracking, diary, archives
   - Never merged, persists for history

**Key**: Agents work on product branch, track work on agent branch via git worktree.

## Agents Involved

**Orchestrator** - Does the actual coding/testing (stays on product branch)
**AI-Coordination** - Manages session tracking via worktree (never switches branches)

## See What Agents Are Working On

```bash
git fetch --all
git branch -r | grep "claude/"
git show origin/claude/wrench:agent-ops/agents/wrench/CONTEXT.md
```

## Session Archives

Located on agent branches in flat structure: `agent-ops/archive/YYYYMMDD_HHMMSS_{agent-name}.md`

Each archive contains:
- Session plan (at top of diary)
- Chronological log of all actions
- Results summary

Example: `agent-ops/archive/20251029_143000_wrench.md`

## Scripts

```bash
./agent-ops/scripts/init-agent.sh      # Initialize agent for session (run once)
./agent-ops/scripts/show-agents.sh     # See all active agents
./agent-ops/scripts/new-session.sh     # Create session manually
./agent-ops/scripts/end-session.sh     # End session manually
./agent-ops/scripts/resume.sh          # View current context and resume work
```

## FAQ

**Q: Do I need to use this as a human developer?**
A: No, it's for AI agent coordination. Humans can work normally.

**Q: Will this create merge conflicts?**
A: No, each agent owns their namespace on their agent branch. Agents use git worktree to avoid branch switching.

**Q: Where are the archives?**
A: On agent branches in flat structure: `git show origin/claude/wrench:agent-ops/archive/`

**Q: Can I delete old agent branches?**
A: Yes, but you lose history. They're kept for audit trail.

**Q: What are agent names?**
A: Deterministically generated mechanical object names (wrench, hammer, gear, etc.) based on session ID.

**Q: How does worktree isolation work?**
A: ai-coordination sub-agent works in a separate worktree directory (e.g., `/home/user/project-wrench/`) to manage the agent branch, while the orchestrator stays on the product branch in the main directory. This prevents branch switching chaos.

---

**Version**: 4.0 (Simplified - No plan.md)
