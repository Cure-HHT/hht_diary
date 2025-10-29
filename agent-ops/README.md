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

1. **Run startup check** (MANDATORY at session start):
   ```bash
   /startup
   ```
   Or manually via Task tool with `agent-ops-startup` agent.

2. **Initialize** agent (if not already done):
   ```bash
   ./agent-ops/scripts/init-agent.sh
   ```

3. **Read**: [`ai/ORCHESTRATOR.md`](ai/ORCHESTRATOR.md)

4. **Delegate** to `ai-coordination` sub-agent at key events:
   - New session (check for outstanding work)
   - Starting feature (create session with plan in diary.md)
   - Reporting work (append to diary.md)
   - Feature complete (archive with results.md)

5. **Follow** simple directives returned

### Agent-Ops-Startup Sub-Agent

1. **Runs FIRST** at session start (via `/startup` command)
2. **Reads**: [`ai/AGENT_OPS_STARTUP.md`](ai/AGENT_OPS_STARTUP.md)
3. **Verifies**: Worktree location, initialization, configuration
4. **Announces**: Agent name and operational status
5. **Returns**: Status report (READY/WARNING/NOT_INITIALIZED)

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
| `ai/AGENT_OPS_STARTUP.md` | agent-ops-startup | Session startup verification |
| `ai/AI_COORDINATION.md` | ai-coordination agent | Session management via worktree |
| `ai/agents.json` | System | Agent configuration (deprecated, use `.claude/agents.json`) |
| `ai/templates/diary.md` | ai-coordination | Session diary template (includes plan) |
| `ai/templates/results.md` | ai-coordination | Session completion template |
| `scripts/install.sh` | Setup | One-time system installation |
| `scripts/init-agent.sh` | Setup | Per-session agent initialization |
| `scripts/register-agents.sh` | Setup | Register agent-ops agents in .claude/agents.json |
| `scripts/new-session.sh` | Manual | Create new session |
| `scripts/end-session.sh` | Manual | Archive completed session |
| `scripts/resume.sh` | Manual | View context and resume work |
| `scripts/show-agents.sh` | Manual | List all active agents |
| `HUMAN.md` | Humans | Human-readable overview |
| `README.md` | Everyone | This file |

---

## Startup System

### Session Startup Sequence

Every Claude session **MUST** begin with the `/startup` command:

```bash
/startup
```

This command:
1. Launches `agent-ops-startup` sub-agent (haiku, fast)
2. Verifies worktree location and configuration
3. Announces agent name and operational status
4. Returns status: READY, WARNING, or NOT_INITIALIZED

**Why it matters**:
- Ensures you're in the correct worktree (not git root)
- Prevents clobbering between multiple Claude sessions
- Validates agent-ops initialization
- Provides clear agent identity for session tracking

### Agent Registration

Agent-ops provides two sub-agents that are automatically registered during initialization:

1. **agent-ops-startup**: Session verification (runs first, every session)
2. **ai-coordination**: Session tracking and coordination (runs as needed)

**Registration is automatic** when you run:
```bash
./agent-ops/scripts/init-agent.sh
```

This script calls `register-agents.sh` which adds agent-ops agents to `.claude/agents.json`.

**Manual registration** (if needed):
```bash
./agent-ops/scripts/register-agents.sh
```

The registration is **idempotent** (safe to run multiple times) and **composable** (other systems can register their own startup agents).

### Extending the Startup Sequence

To add your own startup checks:

1. Create your agent instructions: `path/to/YOUR_STARTUP.md`
2. Register in `.claude/agents.json`:
   ```json
   {
     "name": "your-system-startup",
     "description": "Startup check for your system",
     "instructions_file": "path/to/YOUR_STARTUP.md",
     "tools": ["Bash", "Read"],
     "model": "haiku"
   }
   ```
3. Include "startup" in the description
4. The `/startup` command will auto-discover and run it

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
