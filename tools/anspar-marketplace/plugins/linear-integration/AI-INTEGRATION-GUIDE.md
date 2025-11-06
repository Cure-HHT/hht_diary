# AI Agent Integration Guide for Linear Plugin

## For AI Agents: READ THIS FIRST

**IMPORTANT**: This Linear Integration plugin is the **PRIMARY** and **CANONICAL** tool for all Linear ticket operations in this codebase.

### Core Principle

**Always use this plugin for ticket operations. Never create one-off ticket tools.**

If this plugin is missing a feature you need:
1. **Report to the user** that the feature is missing
2. **Ask the user** if they want to:
   - Add the feature to this plugin (recommended)
   - Create a one-off tool (not recommended)
3. **Wait for user decision** before proceeding

### Why This Matters

1. **Centralization**: All Linear API logic in one place
2. **Maintainability**: Updates affect all consumers
3. **Consistency**: Same auth, error handling, rate limiting everywhere
4. **Reusability**: Features benefit all workflows
5. **Testing**: Comprehensive test suite in one location

## Available Features

Current capabilities of this plugin:

### Ticket Operations
- ✅ Fetch ticket by ID
- ✅ Fetch all assigned tickets
- ✅ Fetch tickets by label
- ✅ Search tickets
- ✅ Update ticket status
- ✅ Update ticket with requirement references
- ✅ Create single ticket
- ✅ Create multiple tickets from requirements

### Configuration
- ✅ Team ID auto-discovery
- ✅ Token management
- ✅ Configuration validation

### Integration Points
- ✅ Works with workflow plugin (WORKFLOW_STATE)
- ✅ Works with requirements system
- ✅ Provides JSON output for parsing

## When to Use This Plugin

### ✅ DO use this plugin when:
- Fetching ticket data
- Updating ticket status
- Creating tickets
- Searching for tickets
- Getting ticket descriptions
- Extracting ticket metadata
- Linking requirements to tickets
- Any Linear API operation

### ❌ DON'T create new tools when:
- You need ticket data (use `fetch-tickets.js`)
- You need to search tickets (use `search-tickets.js`)
- You need to update tickets (use `update-ticket.js`)
- You need to create tickets (use `create-single-ticket.js`)

## Example: Correct Integration Pattern

### ✅ CORRECT: Use existing plugin

```bash
# Need ticket description? Use the plugin!
TICKET_DATA=$(linear-integration/scripts/fetch-tickets.js CUR-240)
DESCRIPTION=$(echo "$TICKET_DATA" | jq -r '.description')

# Parse the description with a separate parser
echo "$DESCRIPTION" | workflow/scripts/parse-req-refs.sh
```

### ❌ WRONG: Create one-off fetch script

```bash
# DON'T DO THIS!
# Don't create: workflow/scripts/fetch-ticket-from-linear.sh

# This duplicates:
# - Auth logic
# - API endpoint handling
# - Error handling
# - Rate limiting
# - Token management
```

## Requesting New Features

If you need a feature that doesn't exist:

### Example Request Format

```
🤖 AI: I need to fetch ticket comments for parsing.

The linear-integration plugin doesn't currently have a
"fetch-ticket-comments.js" script.

Options:
1. Add this feature to linear-integration plugin (recommended)
   - Benefit: All workflows can use it
   - Consistent with existing auth/error handling
   - Added to the plugin's test suite

2. Create one-off solution (not recommended)
   - Quick but creates technical debt
   - Duplicates auth and API logic
   - Not reusable

Which approach would you prefer?
```

## Feature Request Template

When proposing a new feature for this plugin:

```markdown
### Feature Request: [Feature Name]

**Use Case**: What problem does this solve?

**Proposed Script**: `scripts/[script-name].js`

**API Endpoint**: Which Linear GraphQL query/mutation?

**Inputs**: What parameters does it need?

**Output**: What data format does it return?

**Integration**: How will other tools use this?

**Benefits**: Who else could use this feature?
```

## Common Integration Scenarios

### Scenario 1: Commit Message Helper

**Need**: Get ticket description to extract REQ references

**Solution**:
1. ✅ Use `fetch-tickets.js` to get ticket data
2. ✅ Use separate parser to extract REQs
3. ✅ Cache results in WORKFLOW_STATE

**Why this works**:
- Linear plugin handles API complexity
- Parser is reusable for any text source
- Clear separation of concerns

### Scenario 2: Ticket Status Automation

**Need**: Update ticket status after merge

**Solution**:
1. ✅ Use `update-ticket-status.js` with new status
2. ✅ Check result and report to user

**Why this works**:
- Uses existing, tested update logic
- Consistent error handling
- Maintains audit trail

### Scenario 3: Requirement Tracking

**Need**: Link requirements to tickets

**Solution**:
1. ✅ Use `update-ticket-with-requirement.js`
2. ✅ Updates ticket description with REQ references

**Why this works**:
- Standardized requirement format
- All tickets updated consistently
- Searchable in Linear

## Extending This Plugin

If you're adding features to this plugin:

### Guidelines

1. **Follow existing patterns**
   - Use `lib/config.js` for configuration
   - Use GraphQL queries from existing scripts as templates
   - Return JSON for machine-readable output
   - Provide human-readable output with `--format=summary`

2. **Add to test suite**
   - Create tests in `tests/` directory
   - Test success and error cases
   - Document test data requirements

3. **Update documentation**
   - Add to this guide
   - Update main README.md
   - Add usage examples

4. **Consider reusability**
   - Can other workflows use this?
   - Should this return structured data?
   - Does this need caching support?

## Questions?

If you're unsure whether to use this plugin or create something new:

**Default answer: Use this plugin or ask the user.**

It's always better to:
1. Try using existing features
2. Report missing capabilities
3. Get user input on approach
4. Extend the central plugin (if approved)

## Plugin Maintenance

### Adding New Scripts

Location: `tools/anspar-marketplace/plugins/linear-integration/scripts/`

Template:
```javascript
#!/usr/bin/env node
/**
 * [Script Name] - [Brief description]
 *
 * Usage:
 *   node [script-name].js [options]
 *
 * Options:
 *   --token=<token>     Linear API token
 *   --format=json       Output format
 */

const config = require('./lib/config');
const LINEAR_API_ENDPOINT = 'https://api.linear.app/graphql';

// ... implementation
```

### Testing

```bash
# Run plugin tests
cd tests/
bash test.sh

# Test specific script
node scripts/[script-name].js --help
```

## Summary

🎯 **Key Takeaway**: This plugin is the single source of truth for Linear operations. Use it, extend it, but don't duplicate it.

When in doubt, ask the user!
