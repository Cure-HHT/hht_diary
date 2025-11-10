# Agent Orchestration Guide

**Version**: 1.0.0
**Status**: Active
**Last Updated**: 2025-11-09

## Overview

This guide explains how Claude (the main agent) should act as an **orchestrator** when working with the `anspar-cc-plugins` marketplace. The key principle: **delegate to specialized sub-agents rather than implementing directly**.

## Orchestration Philosophy

### Main Agent's Role

**Think of yourself as a conductor, not a musician:**

- 🎯 **Identify** what needs to be done
- 🔍 **Discover** which agents can help
- 📋 **Delegate** to specialized sub-agents
- 🔄 **Coordinate** multi-agent workflows
- 📊 **Report** results to the user

**You are NOT**:
- ❌ A replacement for sub-agents
- ❌ An implementer of domain logic
- ❌ A fallback when agents fail

### Why Orchestration Matters

**Problem** (Without orchestration):
```
User: "Create a Linear ticket for REQ-p00042"

Main Agent:
  1. Reads spec/ files to find requirement
  2. Parses requirement format inline
  3. Calls Linear API with curl commands
  4. Formats ticket description manually
  5. Writes 80+ lines of bash/python inline

Result: Error-prone, non-reusable, inconsistent
```

**Solution** (With orchestration):
```
User: "Create a Linear ticket for REQ-p00042"

Main Agent (Orchestrator):
  1. Checks /agents: Sees RequirementsAgent and LinearAgent
  2. Delegates to RequirementsAgent: "Fetch REQ-p00042"
  3. Delegates to LinearAgent: "Create ticket with this info"
  4. Reports result: "Created CUR-240"

Result: Reliable, reusable, maintainable
```

### Sub-Agent Specialization Benefits

| Benefit | Description |
|---------|-------------|
| **Expertise** | Sub-agents are experts in their domain |
| **Consistency** | Same logic used every time |
| **Testability** | Agents can be tested independently |
| **Maintainability** | Fix bug once, works everywhere |
| **Discoverability** | `/agents` shows what's available |
| **Reusability** | Other sessions benefit from improvements |

## Agent Discovery

### Using `/agents` Command

**Before implementing anything, check available agents**:

```
Claude: Let me check available agents...
/agents

Available agents:
- workflow-enforcer: Ensures active ticket is claimed
- linear-api-agent: Linear ticket operations
- requirements-agent: Requirement operations and tracking
- spec-compliance-enforcer: spec/ directory compliance
...
```

### Reading Agent Capabilities

Agents expose capabilities via YAML frontmatter:

```yaml
---
name: requirements-agent
description: Specialized agent for requirement operations, change detection, and tracking management
tools: Read, Bash, Grep  # Optional: constrained tools
---
```

**What to look for**:
- **name**: How to invoke the agent
- **description**: What the agent does (decide if relevant)
- **tools**: What tools agent has access to

### Discovery Decision Tree

```
User requests task
    ↓
Is this a domain-specific operation?
├─ Yes → Check /agents for relevant agent
│    ├─ Found → Delegate to sub-agent
│    └─ Not found → Implement directly or ask user
└─ No → Implement directly (simple file operations, etc.)
```

## Delegation Patterns

### Basic Delegation

**Syntax**:
```
Task(
  subagent_type="plugin-name:agent-name",
  prompt="Detailed instructions for the agent"
)
```

**Example**:
```
Task(
  subagent_type="linear-api:linear-api-agent",
  prompt="Fetch ticket CUR-240 and return full details including title, description, status, and labels"
)
```

### Effective Prompt Crafting

**Good delegation prompts**:

✅ **Specific and detailed**:
```
Fetch requirement REQ-d00027 from the spec/ directory.
Return the requirement title, description, file location, and
any implementation notes.
```

✅ **Include necessary context**:
```
User wants to create a Linear ticket for REQ-p00042.
First, fetch the requirement details so we can populate
the ticket title and description appropriately.
```

✅ **Specify expected output format**:
```
Search for tickets with label "bug" and status "in progress".
Return results as a markdown table with columns: ID, Title, Assignee.
```

**Bad delegation prompts**:

❌ **Too vague**:
```
Do something with requirements
```

❌ **Missing context**:
```
Fetch a ticket
(Which ticket? What info do I need from it?)
```

❌ **Assuming agent knowledge**:
```
You know what to do with REQ-p00042
(Agent may not have access to previous conversation)
```

### Passing Context

Sub-agents have access to **conversation history before the Task call**, but it's better to be explicit:

**Option 1: Explicit context in prompt** (Recommended):
```
Task(
  subagent_type="requirements-agent",
  prompt="User is working on ticket CUR-337. They need details for REQ-d00027 to understand implementation requirements."
)
```

**Option 2: Rely on conversation history**:
```
# Earlier in conversation:
User: "I'm working on CUR-337"
Claude: "Great, I'll help with that"

# Later:
Task(
  subagent_type="requirements-agent",
  prompt="Fetch REQ-d00027 details"
)
# Agent can see "CUR-337" context from history
```

### Handling Sub-Agent Responses

**Agent completes successfully**:
```
Task returns: "Fetched REQ-d00027: Database schema validation
Location: spec/dev-database.md:45
Status: Implemented
..."

Claude: Summarize for user:
"Found REQ-d00027 in spec/dev-database.md. It requires database
schema validation. The requirement is already implemented."
```

**Agent reports error**:
```
Task returns: "❌ ERROR: LINEAR_API_TOKEN not configured
Cannot fetch tickets without authentication."

Claude: DO NOT work around. Report to user:
"The Linear agent needs LINEAR_API_TOKEN to be set. Please configure:
export LINEAR_API_TOKEN='your_token'
Get token from: https://linear.app/settings/api"
```

## When to Delegate vs. Implement

### Delegate to Sub-Agent When

| Scenario | Example | Agent |
|----------|---------|-------|
| **Domain-specific operations** | Linear ticket operations | linear-api-agent |
| **External API calls** | Fetch from Linear API | linear-api-agent |
| **Complex parsing** | Parse requirement format | requirements-agent |
| **Validation logic** | Validate spec/ compliance | spec-compliance-enforcer |
| **Workflow enforcement** | Check if ticket claimed | workflow-enforcer |
| **Multi-step domain workflows** | Create ticket with req trace | requirement-traceability-agent |

### Implement Directly When

| Scenario | Example | Tool |
|----------|---------|------|
| **Simple file operations** | Read a single file | Read |
| **Basic text transformations** | Extract lines from output | Bash/grep |
| **User clarification** | Ask user for preferences | AskUserQuestion |
| **Simple git operations** | git status, git log | Bash |
| **One-off calculations** | Count files, sum numbers | Bash |

### Gray Areas

**Sometimes unclear - use judgment**:

| Task | Delegate? | Reasoning |
|------|-----------|-----------|
| Read multiple spec files | Maybe | If parsing complex format → delegate. If just reading → direct |
| Create git commit | Maybe | If workflow-managed project → delegate to workflow-enforcer. Otherwise → direct |
| Search codebase | Maybe | If domain-specific search → delegate. If simple grep → direct |

**Rule of thumb**: If in doubt, check `/agents` first. Better to delegate and learn agent doesn't help than to reimplement.

## Error Handling in Orchestration

### When Sub-Agents Fail

**Critical principle: NEVER work around agent failures**

#### Scenario 1: Missing Dependencies

```
Task(subagent_type="linear-api:linear-api-agent", prompt="Fetch CUR-240")

Returns: "❌ LINEAR_API_TOKEN environment variable not set"

✅ CORRECT Response:
Claude: "The Linear agent requires LINEAR_API_TOKEN to be configured.
Please set it:
export LINEAR_API_TOKEN='your_token'

Get your token from: https://linear.app/settings/api"

❌ WRONG Response:
Claude: "Let me try a different approach. I'll implement Linear API
calls manually using curl..."
(NO! This defeats the purpose of having an agent!)
```

#### Scenario 2: Agent Returns Error

```
Task(subagent_type="requirements-agent", prompt="Fetch REQ-d99999")

Returns: "❌ Requirement REQ-d99999 not found in spec/ directory"

✅ CORRECT Response:
Claude: "I checked with the requirements agent - REQ-d99999 doesn't
exist in the spec/ directory. Would you like me to:
1. Search for similar requirement IDs
2. List all available dev requirements
3. Help you create a new requirement"

❌ WRONG Response:
Claude: "Let me search the files myself..."
(Agent already did the authoritative search!)
```

#### Scenario 3: Agent Unavailable

```
Task(subagent_type="nonexistent-plugin:agent", prompt="...")

Returns: Error: Agent not found

✅ CORRECT Response:
Claude: "It looks like the plugin for this operation isn't installed.
For [TASK], you could:
1. Install the appropriate plugin
2. Let me implement this directly (if simple)
3. Point me to existing scripts/tools"

❌ WRONG Response:
Claude: "I'll just do it myself"
(Consider if task really needs specialized agent)
```

### Escalation to User

**Always escalate when**:
- ❌ Agent requires configuration (env vars, API keys)
- ❌ Agent reports missing dependencies
- ❌ External service is down
- ❌ User decision needed
- ❌ Ambiguous requirements

**Example escalation**:
```
Claude: "I need your help to proceed:

The workflow agent reports no active ticket is claimed.
Before making changes to code, you should claim a ticket.

Would you like me to:
1. Help you claim an existing ticket
2. Guide you to create a new ticket
3. Explain the workflow requirements"
```

## Multi-Agent Workflows

### Sequential Delegation (Common)

**Pattern**: Agent A → Agent B → Agent C

```
User: "Create a Linear ticket for REQ-p00042 and link it to the requirement"

Claude (Orchestrator):
  Step 1: Delegate to requirements-agent
    → Fetch REQ-p00042 details

  Step 2: Delegate to linear-api-agent
    → Create ticket with requirement info

  Step 3: Delegate to requirement-traceability-agent
    → Link REQ-p00042 to new ticket

  Step 4: Report to user
    → "Created CUR-340 linked to REQ-p00042"
```

### Parallel Delegation (Advanced)

**Pattern**: Launch multiple agents simultaneously

```
User: "Show me status of CUR-240 and CUR-241"

Claude (Orchestrator):
  # Launch both in parallel using multiple Task calls in one message
  Task 1: Fetch CUR-240
  Task 2: Fetch CUR-241

  Wait for both to complete

  Combine results and report to user
```

**How to do parallel delegation**:
```
# In a single message, make multiple Task tool calls
Task(subagent_type="linear-api:linear-api-agent", prompt="Fetch CUR-240")
Task(subagent_type="linear-api:linear-api-agent", prompt="Fetch CUR-241")

# Both execute simultaneously
# Results come back together
```

### State Management Across Agents

**Agents don't share state directly**. Orchestrator manages state:

```
User: "Create a ticket and then claim it for work"

Claude (Orchestrator):
  Step 1: Delegate to linear-api-agent → Create ticket
    Returns: "Created CUR-340"

  Step 2: Store ticket ID in working memory
    ticket_id = "CUR-340"

  Step 3: Delegate to workflow-enforcer → Claim ticket
    Pass: "Claim ticket CUR-340"

  Step 4: Report combined result
```

**State lives in**:
- Plugin-specific files (.git/WORKFLOW_STATE, .requirement-cache.json)
- Orchestrator's working memory (this conversation)
- User's environment variables

## Performance Considerations

### When Orchestration Overhead is Worthwhile

**Use orchestration when**:

| Scenario | Overhead | Benefit | Verdict |
|----------|----------|---------|---------|
| Complex API operations | +2-5 sec | Reliability, consistency | ✅ Worth it |
| Domain-specific parsing | +1-2 sec | Correctness, reusability | ✅ Worth it |
| Multi-step workflows | +3-10 sec | Maintainability, testability | ✅ Worth it |
| Simple file read | +1-2 sec | None | ❌ Not worth it |
| Basic text transformation | +1-2 sec | None | ❌ Not worth it |

### Caching Agent Results

**Plugins may cache internally**:
- linear-api: Caches ticket fetches for 24hr
- requirement-traceability: Caches requirement lookups

**You don't need to manage caching** - plugins handle it.

**But don't re-invoke unnecessarily**:
```
❌ BAD:
  Task → Fetch CUR-240 details
  (do some work)
  Task → Fetch CUR-240 details again
  (could have stored result from first fetch)

✅ GOOD:
  Task → Fetch CUR-240 details
  Store result in working memory
  (do work with stored result)
  Use stored result again if needed
```

## Anti-Patterns

### Over-Delegation

**Problem**: Creating overhead where direct implementation is simpler

```
❌ ANTI-PATTERN:
User: "Read the README file"

Claude:
  Task(subagent_type="file-reader-agent", prompt="Read README.md")

(Why? Just use Read tool directly!)

✅ CORRECT:
User: "Read the README file"

Claude:
  Read(file_path="/path/to/README.md")
```

**Rule**: Don't delegate trivial operations.

### Under-Delegation

**Problem**: Reimplementing logic that agents already provide

```
❌ ANTI-PATTERN:
User: "Check if requirement REQ-d00027 has changed"

Claude:
  1. Read spec/dev-database.md
  2. Parse requirement format inline
  3. Read spec/INDEX.md
  4. Compare hashes manually
  5. Report result

(Why? requirements-agent has detect-changes skill!)

✅ CORRECT:
User: "Check if requirement REQ-d00027 has changed"

Claude:
  Task(
    subagent_type="simple-requirements:RequirementsAgent",
    prompt="Detect if requirement REQ-d00027 has changed since last verification"
  )
```

**Rule**: Check `/agents` before implementing domain logic.

### Poor Context Passing

**Problem**: Agent doesn't understand what you need

```
❌ ANTI-PATTERN:
Task(
  subagent_type="linear-api:linear-api-agent",
  prompt="Do the thing"
)

(What thing? Agent has no context!)

✅ CORRECT:
Task(
  subagent_type="linear-api:linear-api-agent",
  prompt="User is working on authentication feature. Fetch all tickets with label 'auth' and status 'in-progress'. Return ticket IDs, titles, and current assignees so we can see who's working on what."
)
```

**Rule**: Be specific. Agents aren't mind readers.

### Working Around Failures

**Problem**: Defeats the purpose of having agents

```
❌ ANTI-PATTERN:
Task returns: "❌ API_TOKEN not configured"

Claude: "Let me try implementing this a different way..."

(NO! If the agent needs configuration, tell the user!)

✅ CORRECT:
Task returns: "❌ API_TOKEN not configured"

Claude: "The agent needs API_TOKEN configured. Here's how to fix it:
export API_TOKEN='your_token'

Once configured, I can proceed with your request."
```

**Rule**: Respect agent failures. Don't work around them.

## Orchestration Checklist

Before implementing any task, ask yourself:

- [ ] Have I checked `/agents` for relevant sub-agents?
- [ ] Is this a domain-specific operation that a plugin might handle?
- [ ] If delegating, is my prompt clear and specific?
- [ ] Am I passing sufficient context to the sub-agent?
- [ ] If agent fails, am I escalating to user (not working around)?
- [ ] Am I avoiding over-delegation of trivial operations?
- [ ] Could this workflow benefit from parallel agent execution?

## Summary

**Core Principles**:

1. **Check `/agents` first** before implementing domain logic
2. **Delegate domain operations** to specialized sub-agents
3. **Implement trivial operations directly** (file reads, simple grep)
4. **Pass clear, specific prompts** with sufficient context
5. **Respect agent failures** - escalate to user, don't work around
6. **Coordinate multi-agent workflows** sequentially or in parallel
7. **Trust agent expertise** - they're domain specialists

**Your role as orchestrator**: Identify needs, discover capabilities, delegate appropriately, coordinate results, and report clearly to users.

## References

- [Architecture Documentation](./ARCHITECTURE.md)
- [Plugin Development Guide](./PLUGIN_DEVELOPMENT.md)
- [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents)
