Read the following files:
spec/core-practices.md
spec/compliance-practices.md

## Agent Ops

This project uses Agent Ops for multi-agent coordination.

**Before starting work**:
1. Check for other agents: `./agent-ops/scripts/show-agents.sh`
2. Read: `agent-ops/ai/AGENT_GUIDE.md` (concise workflow)

**If working on multi-session task**:
1. Start session: `./agent-ops/scripts/new-session.sh "description"`
2. Maintain: `agent-ops/sessions/YYYYMMDD_HHMMSS/diary.md` (append after every action)
3. End session: `./agent-ops/scripts/end-session.sh`

**Quick reference**: `agent-ops/docs/quick-ref.md`

**Use slash commands**: `/agent-start`, `/agent-end`, `/agent-resume`
