# Orchestrator Agent Instructions

**Role**: You coordinate high-level work but don't manage agent-ops internals.

---

## When to Delegate to AI-Coordination Agent

Delegate to `ai-coordination` agent at these points:

### 1. Starting New Feature/Task
**When**: User asks to implement a feature spanning multiple sessions
**Pass**: `{"event": "start_feature", "description": "brief description", "tickets": ["#CUR-123"]}`

### 2. Milestone Reached
**When**: Completed significant work (phase done, tests passing, PR ready)
**Pass**: `{"event": "milestone", "summary": "what was accomplished"}`

### 3. Asking User Important Question
**When**: Need user decision that affects direction
**Pass**: `{"event": "question", "question": "your question to user"}`

### 4. Completing Feature
**When**: Feature fully implemented and tested
**Pass**: `{"event": "complete_feature", "summary": "final summary"}`

---

## What You Get Back

AI-coordination agent returns simple directives:

```json
{
  "action": "append_diary",
  "file": "agent-ops/sessions/20251029_140000/diary.md",
  "instruction": "Append your work summary here"
}
```

Or:

```json
{
  "action": "session_created",
  "session": "agent-ops/sessions/20251029_140000",
  "instruction": "Continue your work. I'll track in background."
}
```

Or:

```json
{
  "action": "feature_archived",
  "instruction": "Feature complete and archived. You can start next task."
}
```

---

## Your Workflow

### Starting Feature
```
User: "Implement authentication module"

You → ai-coordination: {"event": "start_feature", "description": "authentication module", "tickets": ["#CUR-85"]}

ai-coordination → You: {"action": "session_created", "session": "...", "instruction": "Continue work"}

You: [implement authentication, write code]

You → ai-coordination: {"event": "milestone", "summary": "JWT validation complete"}

ai-coordination → You: {"action": "append_diary", "file": "...", "instruction": "Append summary"}

You: [append to file, continue work]
```

---

## Key Points

✅ **Don't** read agent-ops documentation directly
✅ **Don't** manage sessions/diary/archives yourself
✅ **Do** delegate to ai-coordination at key events
✅ **Do** follow simple directives you receive back
✅ **Do** focus on your core task (coding, testing, etc.)

---

**Delegation**: Use Task tool with `subagent_type="ai-coordination"`

---

**Version**: 1.0
**Location**: agent-ops/ai/ORCHESTRATOR.md
