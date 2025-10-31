# Linear Operations Skill

This skill provides Linear ticket management operations integrated with the workflow system.

## Available Operations

### Fetch Tickets
Retrieve tickets assigned to you or with specific labels.

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js --format=json --status=active
```

### Search Tickets
Search for tickets by requirement ID or keyword.

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/search-tickets.js --query="REQ-d00027"
```

### Create Ticket
Create a new Linear ticket with proper requirement linking.

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-single-ticket.js \
  --title="Title" \
  --description="Description" \
  --priority=3
```

### Update Ticket
Update an existing ticket's description or add checklists.

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/update-ticket.js \
  --ticketId="CUR-312" \
  --addChecklist="- [ ] Task 1\n- [ ] Task 2"
```

### Test Configuration
Verify Linear API configuration and connectivity.

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/test-config.js
```

## Configuration

The skill automatically discovers configuration from:
1. Command arguments
2. Environment variables (LINEAR_API_TOKEN, LINEAR_TEAM_ID)
3. Local .env.local file in plugin directory
4. User config (~/.config/linear/config)

## Pre-Approvals

All Linear plugin scripts are pre-approved for execution:
- `node ${CLAUDE_PLUGIN_ROOT}/scripts/*.js:*`

## Examples

### Find all tickets for a requirement
```
Search for tickets containing REQ-d00027 to find all related work items.
```

### Create and claim a ticket for current work
```
1. Create a new ticket with appropriate title and description
2. Link it to the relevant requirements
3. Use anspar-workflow to claim it for the current worktree
```

### Add implementation checklist to a ticket
```
Update the ticket with a markdown checklist of implementation tasks based on the requirement's acceptance criteria.
```