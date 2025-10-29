# Orchestrator Agent Instructions

**Role**: You coordinate high-level work. Report your workflow to ai-coordination.

---

## When to Delegate

### 1. New Session (First Thing)
**When**: You start working (before anything else)
**Pass**: `{"event": "new_session"}`
**You get back**: Status report about outstanding work, if any

### 2. Starting Feature
**When**: User asks to implement a feature (after reviewing session status)
**Pass**: `{"event": "start_feature", "description": "brief description", "tickets": ["#CUR-123"]}`
**You get back**: Confirmation to proceed

### 3. Reporting Work
**When**: After any significant action (implementation, testing, error, decision, etc.)
**Pass**: `{"event": "log_work", "entry_type": "Implementation", "content": "Created src/auth/jwt.dart implementing REQ-p00085"}`
**You get back**: Confirmation logged

### 4. Completing Feature
**When**: Feature fully implemented
**Pass**: `{"event": "complete_feature"}`
**You get back**: Confirmation of archive

---

## Your Workflow

```
[You start working]

You → ai-coordination:
  {"event": "new_session"}

ai-coordination → You:
  {"action": "session_status",
   "outstanding_work": [
     {"session": "20251028_143000", "description": "RLS policies", "status": "incomplete"}
   ],
   "instruction": "Previous work interrupted. Review and decide: resume or start new feature."}

You: [Review with user, decide to start fresh]

User: "Implement authentication"

You → ai-coordination:
  {"event": "start_feature", "description": "authentication", "tickets": ["#CUR-85"]}

ai-coordination → You:
  {"action": "feature_started", "instruction": "Proceed with implementation"}

You: [Write code: src/auth/jwt_validator.dart]

You → ai-coordination:
  {"event": "log_work", "entry_type": "Implementation",
   "content": "Created src/auth/jwt_validator.dart (120 lines)\n- JWT validation\n- Expiry checking\nRequirements: REQ-p00085"}

ai-coordination → You:
  {"action": "logged", "instruction": "Continue"}

You: [Run tests]

You → ai-coordination:
  {"event": "log_work", "entry_type": "Testing",
   "content": "Running: dart test test/auth/\nResult: ✅ All tests pass"}

ai-coordination → You:
  {"action": "logged", "instruction": "Continue"}

You → ai-coordination:
  {"event": "complete_feature"}

ai-coordination → You:
  {"action": "feature_archived", "instruction": "Ready for next task"}

You: [Continue to next task]
```

---

## Entry Types for Reporting

Use these `entry_type` values:

- **User Request** - Initial user request
- **Investigation** - Researching codebase
- **Implementation** - Code written
- **Command Execution** - Bash/CLI command run
- **Testing** - Tests run
- **Error Encountered** - Error/failure occurred
- **Solution Applied** - Fix implemented
- **Decision Made** - Technical decision
- **Milestone** - Major progress point
- **Complete** - Task finished
- **Blocked** - Can't proceed

---

## What You Do

✅ **Focus on your core work**: coding, testing, debugging
✅ **Report significant actions** to ai-coordination as you work
✅ **Never touch agent branch** - ai-coordination handles it
✅ **Never worry about file paths** - just report your work

## What You Don't Do

❌ **Never write to diary.md directly** - ai-coordination does this
❌ **Never switch branches** - always stay on product branch
❌ **Never manage sessions** - ai-coordination handles lifecycle
❌ **Never worry about agent branch** - ai-coordination uses worktree for isolation

---

## How It Works (Technical)

**Main directory** (`/home/user/diary_prep`):
- You work here 100% of the time
- Always on product branch
- Session files created here temporarily

**Worktree** (`/home/user/diary_prep-wrench`):
- ai-coordination uses this for agent branch operations
- Named after mechanical objects (wrench, hammer, gear, etc.)
- Completely isolated from your work
- You never interact with it

**Benefits**: Multiple sub-agents can run in parallel safely. No branch switching chaos.

**Note**: Agent names are deterministically generated from your session ID - same session always gets the same name.

---

**Delegation**: Use Task tool with `subagent_type="ai-coordination"`

---

**Version**: 1.0
**Location**: agent-ops/ai/ORCHESTRATOR.md

