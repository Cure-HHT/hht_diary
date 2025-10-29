# Orchestrator Agent Instructions

**Role**: You coordinate high-level work. Report your workflow to ai-coordination.

---

## Setup (One-Time Per Session)

**Before first delegation**, initialize the agent:
```bash
./agent-ops/scripts/init-agent.sh
```

This creates `untracked-notes/agent-ops.json` with your agent name (wrench, hammer, etc.) and worktree path.

---

## When to Delegate

### 1. New Session (First Thing)
**When**: You start working (after running init-agent.sh)
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

You: Run ./agent-ops/scripts/init-agent.sh
     ✓ Agent initialized: wrench

You → ai-coordination:
  {"event": "new_session"}

ai-coordination → You:
  {"action": "session_status",
   "outstanding_work": [
     {
       "session": "20251028_143000",
       "location": "local",
       "state": "stale_abandoned",
       "description": "RLS policies",
       "last_entry": "Error: permission denied on table users",
       "recommended_action": "clean_up"
     }
   ],
   "instruction": "Previous work interrupted. Review and decide: resume or start new feature."}

You: [Review session state: stale_abandoned = safe to clean up]
You: [Inform user about abandoned session, decide to start fresh]

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

## Understanding Session States

When you call `new_session`, ai-coordination reports outstanding work with state information. Here's how to interpret and respond:

### State Types

**🟢 `active`** - Process running, recent activity (<10min)
- **Meaning**: Another Claude Code instance may be actively working
- **Action**: **WARN USER** - Risk of conflict if you continue
- **Response**: Ask user if they want to:
  - Wait for other instance to finish
  - Take over (other instance will detect abandoned state)
  - Work on different feature (avoid conflicts)

**🟡 `active_idle`** - Process running, no recent activity (>10min)
- **Meaning**: Claude Code running but agent paused/idle
- **Action**: **INFORM USER** - Likely safe but verify first
- **Response**: Check if user has another window open, then:
  - If same instance: Resume normally
  - If different instance: Treat as `active` above

**🟠 `recently_abandoned`** - Process dead, recent activity (<1hr)
- **Meaning**: Crash or close happened recently
- **Action**: **INVESTIGATE** - Check what was being worked on
- **Response**: Show user last diary entries, then:
  - Resume if work is valuable
  - Start fresh if work was exploratory

**🔴 `stale_abandoned`** - Process dead, old activity (>1hr)
- **Meaning**: Old session never properly closed
- **Action**: **SAFE TO CLEAN UP** - Can start fresh
- **Response**: Inform user about abandoned session:
  - Option 1: Start new feature (recommended)
  - Option 2: Check diary first if user wants to review
  - Suggest: Run cleanup-abandoned.sh

### Recommended Actions (from ai-coordination)

- `resume`: Session can be continued - offer to continue or start fresh
- `investigate`: Check diary entries before deciding - show to user
- `start_fresh`: Safe to proceed with new work - just inform user
- `clean_up`: Should clean up first - suggest cleanup-abandoned.sh

### Decision Framework

```
IF state is "active":
  WARN user about potential conflict
  DO NOT proceed without explicit confirmation

ELSE IF state is "active_idle":
  INFORM user (may be same instance paused)
  PROCEED with caution

ELSE IF state is "recently_abandoned":
  SHOW last diary entries to user
  LET user decide: resume vs start fresh

ELSE IF state is "stale_abandoned":
  INFORM user (old abandoned session)
  PROCEED with new session
  SUGGEST cleanup later
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

**Config file** (`untracked-notes/agent-ops.json`):
- Created by `init-agent.sh` once per session
- Contains agent name, branch, and worktree path
- ai-coordination reads this for every operation
- Never committed (in .gitignore)

**Main directory** (`/home/user/diary_prep`):
- You work here 100% of the time
- Always on product branch
- Session files created here temporarily

**Worktree** (e.g., `/home/user/diary_prep-wrench`):
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

