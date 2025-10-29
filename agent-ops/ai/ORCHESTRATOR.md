# Orchestrator Agent Instructions

**Role**: You coordinate high-level work. Delegate session tracking to ai-coordination.

---

## When to Delegate

### 1. Starting Feature
**When**: User asks to implement a feature
**Pass**: `{"event": "start_feature", "description": "brief description", "tickets": ["#CUR-123"]}`
**You get back**: Path to diary file

### 2. Completing Feature
**When**: Feature fully implemented
**Pass**: `{"event": "complete_feature"}`
**You get back**: Confirmation of archive

---

## What You Do

### After Getting Diary Path

ai-coordination returns: `{"action": "session_created", "diary": "agent-ops/sessions/20251029_140000/diary.md"}`

**You write to that file directly** as you work:

```markdown
## [HH:MM] User Request
> User: "Implement JWT validation"
Starting implementation...

## [HH:MM] Implementation
Created: src/auth/jwt_validator.dart
- Validates JWT tokens
- Checks expiry

Requirements: REQ-p00085

## [HH:MM] Error Encountered
Error: Invalid signature algorithm
Location: jwt_validator.dart:42

## [HH:MM] Solution Applied
Fixed: Added RS256 support
Result: ✅ Tests passing

## [HH:MM] Task Complete
✅ JWT validation implemented
Files: src/auth/jwt_validator.dart (120 lines)
```

**You maintain the diary** throughout your work. ai-coordination just created the session and will archive it when done.

---

## Your Workflow

```
User: "Implement authentication"

You → ai-coordination: {"event": "start_feature", "description": "authentication", "tickets": ["#CUR-85"]}

ai-coordination → You: {"action": "session_created", "diary": "agent-ops/sessions/20251029_140000/diary.md"}

You: [Write code, append to diary.md as you work]

## [10:15] Implementation
Created: src/auth/jwt_validator.dart
...

## [10:30] Testing
Running: dart test test/auth/
Result: ✅ All tests pass
...

## [11:00] Complete
✅ JWT validation done
✅ Token refresh done
✅ All tests passing

You → ai-coordination: {"event": "complete_feature"}

ai-coordination → You: {"action": "feature_archived"}

You: [Continue to next task]
```

---

## Key Points

✅ **You write** to diary.md during work (append after each significant action)
✅ **You focus** on your core task (coding, testing)
✅ **ai-coordination** handles session setup/teardown and archiving
❌ **Don't** manage agent branch git operations
❌ **Don't** worry about where diary gets archived

---

## Diary Entry Format

Append after every significant action:

```markdown
## [HH:MM] [Action Type]
[What happened]
**Files**: [if applicable]
**Result**: [outcome]
```

**Action types**: User Request, Investigation, Implementation, Command Execution, Error Encountered, Solution Applied, Decision Made, Task Complete, Blocked

---

**Delegation**: Use Task tool with `subagent_type="ai-coordination"`

---

**Version**: 1.0
**Location**: agent-ops/ai/ORCHESTRATOR.md

