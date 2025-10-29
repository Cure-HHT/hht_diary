# Agent Ops - Modular AI Agent Coordination

**Purpose**: Multi-agent coordination with role separation and simplified session tracking.

**Version**: 4.0 (Simplified - No plan.md)

---

## Quick Start

### 1. Install (One-Time Setup)

```bash
./agent-ops/scripts/install.sh
```

This will:
- Check prerequisites (jq, git)
- Set up `.gitignore` entries
- Configure CLAUDE.md integration
- Set up .claude/instructions.md
- Verify system readiness

### 2. Initialize Agent (Per Session)

```bash
./agent-ops/scripts/init-agent.sh
```

Generates deterministic agent name (wrench, hammer, etc.) from your session ID.

### 3. Start Working

Follow the orchestrator workflow or use scripts directly (see below).

---

## Agent Workflow

### Orchestrator Agent (Primary AI Agent)

1. **Initialize** agent (once per session):
   ```bash
   ./agent-ops/scripts/init-agent.sh
   ```
2. **Read**: [`ai/ORCHESTRATOR.md`](ai/ORCHESTRATOR.md)
3. **Delegate** to `ai-coordination` sub-agent at key events:
   - New session (check for outstanding work)
   - Starting feature (create session with plan in diary.md)
   - Reporting work (append to diary.md)
   - Feature complete (archive with results.md)
4. **Follow** simple directives returned

### AI-Coordination Sub-Agent

1. **Read**: [`ai/AI_COORDINATION.md`](ai/AI_COORDINATION.md)
2. **Handle** session lifecycle (plan embedded in diary.md)
3. **Manage** agent branch git operations via worktree
4. **Return** simple directives to orchestrator

### For Humans

See: [`HUMAN.md`](HUMAN.md)

---

## Architecture

**Two branches**:
- **Product** (`claude/feature-xyz-011CUamedUhto5wQEfRLSKTQ`): Your code, you manage
- **Agent** (`claude/wrench`): Session tracking, ai-coordination manages via worktree

**Agent naming**: Mechanical objects (wrench, hammer, gear, etc.) - deterministic from session ID

**Worktree**: ai-coordination works in `/home/user/project-wrench/` (isolated from main directory)

**Key**: ai-coordination handles agent branch via worktree, orchestrator stays on product branch 100% of time.

**Simplified Structure**: Session plan embedded in diary.md (no separate plan.md file).

---

## Files

| File | Read By | Purpose |
|------|---------|---------|
| `ai/ORCHESTRATOR.md` | Orchestrator agent | High-level coordination instructions |
| `ai/AI_COORDINATION.md` | ai-coordination agent | Session management via worktree |
| `ai/agents.json` | System | Agent configuration |
| `ai/templates/diary.md` | ai-coordination | Session diary template (includes plan) |
| `ai/templates/results.md` | ai-coordination | Session completion template |
| `scripts/install.sh` | Setup | One-time system installation |
| `scripts/init-agent.sh` | Setup | Per-session agent initialization |
| `scripts/new-session.sh` | Manual | Create new session |
| `scripts/end-session.sh` | Manual | Archive completed session |
| `scripts/resume.sh` | Manual | View context and resume work |
| `scripts/show-agents.sh` | Manual | List all active agents |
| `HUMAN.md` | Humans | Human-readable overview |
| `README.md` | Everyone | This file |

---

## Manual Scripts (Human/Orchestrator Use)

```bash
# Setup (once)
./agent-ops/scripts/install.sh

# Per session init
./agent-ops/scripts/init-agent.sh

# Session management
./agent-ops/scripts/new-session.sh [session-name]
./agent-ops/scripts/end-session.sh [session-directory]
./agent-ops/scripts/resume.sh

# View agents
./agent-ops/scripts/show-agents.sh
```

---

**Version**: 4.0 (Simplified - No plan.md)
**Last Updated**: 2025-10-29
