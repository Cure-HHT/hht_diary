---
description: Agent Ops quick reference
---

# Agent Ops Quick Reference

## Commands

```bash
./agent-ops/scripts/show-agents.sh  # Check agents
./agent-ops/scripts/new-session.sh "desc"  # Start
./agent-ops/scripts/end-session.sh  # End
./agent-ops/scripts/resume.sh  # Resume
```

Slash: `/agent-start`, `/agent-end`, `/agent-resume`

## Docs

**Quick**: `agent-ops/ai/AGENT_GUIDE.md`
**Detailed**: `agent-ops/docs/` (concepts, workflows, quick-ref)

## When

**Use**: Multi-session work, audit trail, coordination
**Skip**: Single-session tasks

## Two Branches

**Product** (`claude/feature-xyz-011ABC`): Code, merged to main
**Agent** (`claude/ai-agent-011ABC`): State, never merged

Discovery: `git branch -r | grep "ai-agent-"`
Read: `git show origin/ai-agent-X:agent-ops/agents/X/CONTEXT.md`
