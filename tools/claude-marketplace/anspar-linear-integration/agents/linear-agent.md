# Linear Integration Agent

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
Claim a Linear ticket for the current worktree (integrates with anspar-workflow).

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