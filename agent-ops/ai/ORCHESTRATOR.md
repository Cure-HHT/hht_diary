# Orchestrator Agent Instructions

**Role**: You coordinate high-level work. Report your workflow to ai-coordination.

---

## ⚠️ MANDATORY: Session Startup Check ⚠️

**EVERY session MUST begin with the startup command:**

```bash
/startup
```

This runs the `agent-ops-startup` sub-agent which verifies your configuration and announces your agent identity.

**Possible outcomes:**

1. **✅ STATUS: READY** → Announce yourself and proceed with work
   - Example: "Hi, I'm agent motor. Ready to work on branch feature/xyz."

2. **⚠️ STATUS: WARNING - Wrong Worktree** → Tell user to restart Claude from product worktree
   - Do NOT proceed with any work
   - Provide the exact path from the startup report

3. **🚫 STATUS: NOT_INITIALIZED** → Tell user to run initialization
   - Provide command: `./agent-ops/scripts/init-agent.sh`
   - Do NOT proceed with any work

**The `/startup` command is composable** - it will run all registered startup agents, not just agent-ops. Other systems can add their own startup checks.

---

## Setup (One-Time Per Session)

**To initialize agent** (if not already done):
```bash
./agent-ops/scripts/init-agent.sh
```

This script:
1. Generates deterministic agent name from session ID
2. Creates TWO worktrees in same container directory:
   - Agent coordination worktree: `../project-worktrees/{agent_name}-ops/` (for ai-coordination)
   - Product work worktree: `../project-worktrees/{agent_name}/` (for you)
3. Writes config to `untracked-notes/agent-ops.json`

**After initialization**, user must restart Claude from product worktree.

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

**Config file** (`untracked-notes/agent-ops.json`):
- Created by `init-agent.sh` once per session
- Contains agent name, branches, and BOTH worktree paths
- ai-coordination reads this for every operation
- Never committed (in .gitignore)

**Main directory** (`/home/user/diary/`):
- Original repository location
- Used ONLY for initialization
- DO NOT work here - always use product worktree

**TWO Worktrees per agent (in same container directory):**

1. **Agent Coordination Worktree** (e.g., `/home/user/diary-worktrees/motor-ops`):
   - Branch: `claude/motor`
   - Used by: ai-coordination sub-agent
   - Contains: diary.md, results.md (session tracking)
   - You never interact with this

2. **Product Work Worktree** (e.g., `/home/user/diary-worktrees/motor`):
   - Branch: Current feature branch
   - Used by: YOU (orchestrator) for ALL coding work
   - Contains: Your actual code changes
   - This is where you work 100% of the time

**Both worktrees** are siblings in `project-worktrees/` directory

**Benefits**:
- ✅ Multiple Claude instances can work simultaneously without conflicts
- ✅ No branch switching chaos
- ✅ Clear separation between coordination and product work
- ✅ Each agent fully isolated in its own workspace

**Note**: Agent names are deterministically generated from your session ID - same session always gets the same name (wrench, hammer, vise, etc.).

---

**Delegation**: Use Task tool with `subagent_type="ai-coordination"`

---

**Version**: 1.0
**Location**: agent-ops/ai/ORCHESTRATOR.md

