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

1. **Read**: [`ai/ORCHESTRATOR.md`](ai/ORCHESTRATOR.md)
2. **Delegate** to `ai-coordination` sub-agent at key events:
   - Starting feature
   - Milestone reached
   - User question
   - Feature complete
3. **Follow** simple directives returned

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
- **Product** (`claude/feature-xyz-011ABC`): Your code, you manage
- **Agent** (`claude/ai-agent-011ABC`): Session tracking, ai-coordination manages

**Key**: ai-coordination handles agent branch, you handle product branch.

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
