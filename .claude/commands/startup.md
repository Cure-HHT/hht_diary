---
description: Execute session startup checks and system initialization
---

# Session Startup

Execute all startup checks and system initialization in the correct order.

## Objective

Verify the development environment is properly configured and all required systems are initialized before beginning work. This command orchestrates multiple startup agents to provide comprehensive session initialization.

## Execution Order

Launch the following agents **sequentially** using the Task tool:

### 1. Agent-Ops Startup Check

**Agent**: `agent-ops-startup`
**Purpose**: Verify worktree isolation and agent identity
**Must complete**: Before any other work

Use the Task tool with:
```
subagent_type: "agent-ops-startup"
description: "Agent-ops startup check"
model: "haiku"
```

**Wait for result** before proceeding. Check the agent's report for:
- ✅ Status: READY → Continue to next agent
- ⚠️ Status: WARNING → Address issues if critical, or continue with awareness
- 🚫 Status: NOT_INITIALIZED → Stop and instruct user to run initialization

**Expected output**: Agent name, worktree paths, current branch, git status

---

### 2. Additional Startup Agents (If Configured)

Check `.claude/agents.json` for additional agents with startup requirements:

```bash
# Read agents config
cat .claude/agents.json | jq -r '.agents[] | select(.description | contains("startup") or contains("STARTUP")) | .name'
```

For each additional startup agent found (excluding `agent-ops-startup` which already ran):
- Launch using Task tool
- Wait for completion
- Collect results

---

## Reporting Results

After all startup agents complete, provide a consolidated summary:

```markdown
# Session Startup Complete

## Agent Identity
**Agent Name**: {from agent-ops-startup}
**Worktree**: {product_worktree_path}
**Branch**: {current_branch}

## System Checks
- ✅ Agent-ops: {status}
- {Additional checks from other startup agents}

## Ready to Work
{Summary of session state and any warnings}

## Next Steps
{If all READY: "You can now begin work."}
{If issues: "Please address the following before proceeding: {list}"}
```

## Error Handling

If ANY startup agent fails or returns NOT_INITIALIZED:
1. **Stop** the startup sequence immediately
2. **Report** which agent failed and why
3. **Provide** specific instructions from the failed agent
4. **Do NOT** proceed with other agents or begin work

## Usage Notes

- **Automatic**: This command should be run automatically at the start of every session
- **Manual**: User can also run `/startup` manually to re-check configuration
- **Extensible**: New systems can add their own startup agents to `.claude/agents.json`
- **Fast**: Uses lightweight agents (haiku model) for quick checks

## Composability

To add a new startup agent to this sequence:

1. **Create agent instructions**: `path/to/your/STARTUP.md`
2. **Register in agents.json**:
   ```json
   {
     "name": "your-system-startup",
     "description": "Startup check for your system",
     "instructions_file": "path/to/your/STARTUP.md",
     "tools": ["Bash", "Read"],
     "model": "haiku"
   }
   ```
3. **Ensure description contains "startup"**: This command will auto-detect and run it

The `/startup` command will automatically discover and execute your agent in the sequence.

## Implementation Details

**Sequential Execution**: Agents run one at a time to ensure:
- Proper dependency order (agent-ops first, others after)
- Clear error reporting (know exactly which check failed)
- Resource efficiency (don't start later checks if early ones fail)

**Parallel NOT Supported**: Startup checks must run sequentially because later checks may depend on earlier ones passing.

---

**Usage**: Run `/startup` at the beginning of each Claude session to verify environment configuration.
