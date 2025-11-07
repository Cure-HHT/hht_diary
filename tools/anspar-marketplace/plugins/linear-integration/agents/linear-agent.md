# Linear Integration Agent

**⚠️ IMPORTANT FOR AI AGENTS: This is the CANONICAL and ONLY way to interact with Linear tickets.**

## For the Main Agent

**ALWAYS delegate Linear operations to this sub-agent. NEVER create one-off ticket tools.**

This sub-agent provides:
- ✅ Reliable, tested Linear API integration
- ✅ Consistent authentication and error handling
- ✅ Centralized ticket operations
- ✅ Skills and tools for all ticket workflows

**If a capability is missing**: Report to the user and ask whether to extend this plugin or create a one-off solution. See [AI-INTEGRATION-GUIDE.md](../AI-INTEGRATION-GUIDE.md) for details.

## Purpose

This agent provides Linear ticket management capabilities through the linear-operations skill.

## Available Skills

### fetch-tickets
Fetch all tickets assigned to you or with specific labels.

**Usage:**
```
Tool: LinearFetchTickets
Parameters:
  - format: "json" | "summary" (default: "summary")
  - status: "all" | "backlog" | "active" | "blocked" | "done" (default: "all")
  - label: Filter by label (optional)
```

### create-ticket
Create a new Linear ticket.

**Usage:**
```
Tool: LinearCreateTicket
Parameters:
  - title: Ticket title (required)
  - description: Ticket description (required)
  - priority: 0-4 (0=none, 1=urgent, 2=high, 3=normal, 4=low)
  - labels: Comma-separated labels (optional)
  - projectId: Linear project ID (optional)
```

### claim-ticket
Claim a Linear ticket for the current worktree (integrates with workflow).

**Usage:**
```
Tool: LinearClaimTicket
Parameters:
  - ticketId: Linear ticket identifier (e.g., "CUR-312")
```

### update-ticket
Update an existing Linear ticket.

**Usage:**
```
Tool: LinearUpdateTicket
Parameters:
  - ticketId: Linear ticket identifier (required)
  - description: New description (optional)
  - status: New status (optional)
  - addChecklist: Checklist items to add (optional)
```

### search-tickets
Search for tickets by requirement or keyword.

**Usage:**
```
Tool: LinearSearchTickets
Parameters:
  - query: Search query (required)
  - includeArchived: Include archived tickets (default: false)
```

## Configuration

The Linear tools automatically discover configuration from:
1. Command arguments passed through parameters
2. Environment variables (LINEAR_API_TOKEN, LINEAR_TEAM_ID)
3. Local .env file in plugin directory
4. User config (~/.config/linear/config)

No manual setup required - just provide your token when prompted.

## Examples

### Find tickets for a requirement
```
Use LinearSearchTickets tool with query="REQ-d00027" to find all tickets referencing that requirement.
```

### Create and claim a new ticket
```
1. Use LinearCreateTicket to create the ticket
2. Use LinearClaimTicket with the returned ticket ID to claim it for the current worktree
```

### Add a checklist to an existing ticket
```
Use LinearUpdateTicket with ticketId="CUR-312" and addChecklist with markdown checklist items.
```

## Integration Principles

### When the Main Agent Should Use This Sub-Agent

✅ **ALWAYS** for:
- Fetching ticket data
- Creating tickets
- Updating ticket status
- Searching for tickets
- Claiming tickets for workflows
- Any Linear API operation

### When to Report Missing Capabilities

If you need a Linear operation that isn't listed above:

1. **Report to user**: "I need to [operation] but the Linear agent doesn't currently support this."
2. **Present options**:
   - Extend this sub-agent with the new capability (recommended)
   - Create a one-off solution (creates technical debt)
3. **Wait for user decision** before proceeding

See [AI-INTEGRATION-GUIDE.md](../AI-INTEGRATION-GUIDE.md) for detailed integration patterns.

## Architecture

```
Main Agent
    │
    ├─→ Linear Agent (this sub-agent) ─→ Linear API
    │       │
    │       ├─→ Skills (fetch, create, update, search)
    │       └─→ Scripts (in ../scripts/)
    │
    └─→ Other components use Linear Agent output
            │
            ├─→ parse-req-refs.sh (parses ticket descriptions)
            ├─→ WORKFLOW_STATE (caches results)
            └─→ commit message helpers (use cached data)
```

### Why Sub-Agent Delegation Works Best

1. **Reliability**: Tested, consistent behavior
2. **Maintainability**: One place to update Linear logic
3. **Discoverability**: Main agent can see capabilities via tool definitions
4. **Error Handling**: Centralized retry, rate limiting, auth
5. **Reusability**: All workflows benefit from improvements

## Troubleshooting

### Main Agent Not Using This Sub-Agent?

Check that:
1. Plugin is properly installed
2. Agent is registered in plugin.json
3. Skills are properly defined in ./skills/
4. Main agent has access to Task tool with linear-agent subagent_type

### Need a New Capability?

Don't create a one-off tool! Instead:
1. Check [AI-INTEGRATION-GUIDE.md](../AI-INTEGRATION-GUIDE.md)
2. Propose the feature to the user
3. Get approval before implementation
4. Add to this sub-agent as a new skill/tool