# Update Linear Ticket

Update an existing Linear ticket's description, add checklists, or link requirements.

## Usage

Update a ticket:
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/update-ticket.js \
  --ticketId="CUR-312" \
  --description="New description"
```

## Parameters
- `--ticketId`: Linear ticket identifier (required, e.g., "CUR-312")
- `--description`: New description to replace existing
- `--addChecklist`: Markdown checklist to append to description
- `--addRequirement`: Add requirement reference (prepends to description)

## Examples

### Link to Requirement
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/update-ticket.js \
  --ticketId="CUR-312" \
  --addRequirement="REQ-d00027"
```

This prepends: `**Requirement**: REQ-d00027` to the description.

### Replace Description with Requirement
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/update-ticket.js \
  --ticketId="CUR-312" \
  --description="Updated implementation approach\n\nImplements: REQ-d00027"
```

### Add Implementation Checklist
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/update-ticket.js \
  --ticketId="CUR-312" \
  --addChecklist="- [ ] Configure environment variables
- [ ] Set up Linear API token
- [ ] Test connectivity
- [ ] Create initial tickets
- [ ] Document setup process"
```

## Requirement Linking Best Practices

### 1. Use Requirements Agent First
Before linking a requirement, use the requirements agent to:
- Verify the requirement exists and is valid
- Check relevance to the ticket's work
- Ensure proper requirement cascade (PRD → Ops → Dev)
- Get the requirement's acceptance criteria for checklists

### 2. Format Convention
Requirements should be referenced as:
- In description header: `**Requirement**: REQ-xxxxx`
- In body: `Implements: REQ-xxxxx, REQ-yyyyy`
- Multiple requirements comma-separated

### 3. Workflow Integration
```bash
# 1. Find relevant requirement
# (Use requirements agent skill)

# 2. Update ticket with requirement
node ${CLAUDE_PLUGIN_ROOT}/scripts/update-ticket.js \
  --ticketId="CUR-312" \
  --addRequirement="REQ-d00027"

# 3. Add acceptance criteria as checklist
# (Extract from requirement using requirements agent)
node ${CLAUDE_PLUGIN_ROOT}/scripts/update-ticket.js \
  --ticketId="CUR-312" \
  --addChecklist="[acceptance criteria from requirement]"
```

## Notes
- Preserves existing content when adding requirements or checklists
- Replaces entire description only with `--description`
- Returns updated ticket URL
- Maintains traceability between tickets and requirements
- Works with workflow for commit message generation