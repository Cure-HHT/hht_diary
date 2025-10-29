# Agent Ops - Modular AI Agent Coordination

**Purpose**: Multi-agent coordination with role separation.

---

## Setup (One-Time)

```bash
./agent-ops/scripts/init-claude-integration.sh
```

---

## Agent Workflow

### Orchestrator Agent (You)

1. **Initialize** agent (once per session):
   ```bash
   ./agent-ops/scripts/init-agent.sh
   ```
2. **Read**: [`ai/ORCHESTRATOR.md`](ai/ORCHESTRATOR.md)
3. **Delegate** to `ai-coordination` sub-agent at key events:
   - New session (check for outstanding work)
   - Starting feature
   - Reporting work
   - Feature complete
4. **Follow** simple directives returned

### AI-Coordination Sub-Agent

1. **Read**: [`ai/AI_COORDINATION.md`](ai/AI_COORDINATION.md)
2. **Handle** session lifecycle
3. **Manage** agent branch git operations
4. **Return** simple directives to orchestrator

### For Humans

See: [`HUMAN.md`](HUMAN.md)

---

## Architecture

**Two branches**:
- **Product** (`claude/feature-xyz-011CUamedUhto5wQEfRLSKTQ`): Your code, you manage
- **Agent** (`claude/wrench`): Session tracking, ai-coordination manages via worktree

**Agent naming**: Mechanical objects (wrench, hammer, gear, etc.) - deterministic from session ID

**Worktree**: ai-coordination works in `/home/user/diary_prep-wrench/` (isolated from main directory)

**Key**: ai-coordination handles agent branch via worktree, you stay on product branch 100% of time.

---

## Files

| File | Read By |
|------|---------|
| `ai/ORCHESTRATOR.md` | Orchestrator agent |
| `ai/AI_COORDINATION.md` | ai-coordination agent |
| `ai/agents.json` | System |
| `ai/templates/` | ai-coordination (session creation) |
| `scripts/` | ai-coordination (automation) |
| `HUMAN.md` | Humans |

---

**Version**: 3.0 (Role-Based)
