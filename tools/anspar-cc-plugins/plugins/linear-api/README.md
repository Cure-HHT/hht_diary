# Linear API Plugin

**A generic, reusable Linear API client for Claude Code**

This plugin provides basic CRUD operations for Linear tickets via the Linear GraphQL API. It is completely generic and project-agnostic—it works with ANY Linear workspace.

## Key Features

- **Generic & Reusable**: No project-specific logic or assumptions
- **Complete CRUD**: Fetch, create, update, search tickets
- **Auto-Configuration**: Automatically discovers team IDs
- **Caching**: 24-hour cache for team/label data
- **Skills-Based**: Easily invokable via Claude Code skills
- **Dual Access**: Works with both Linear MCP and direct API
- **Pure API**: Direct GraphQL operations with no abstraction layers

## Access Methods

This plugin supports two methods for accessing Linear:

### 🌐 Linear MCP (Model Context Protocol)
**Best for**: Claude Code web (claude.ai/code)

The plugin automatically uses Linear MCP when available in Claude Code. No configuration required!

**Advantages**:
- ✅ No API token needed
- ✅ OAuth security (managed by Claude Code)
- ✅ Automatic authentication
- ✅ Centrally managed access

**Setup**:
1. In Claude Code, use the `/mcp` command
2. Authenticate with Linear via OAuth
3. Run scripts normally - MCP will be auto-detected

### 🔑 Direct API Access
**Best for**: Claude Code CLI, automation, CI/CD

Uses LINEAR_API_TOKEN for direct GraphQL API access.

**Advantages**:
- ✅ Works in any environment
- ✅ No OAuth flow needed
- ✅ Full API access
- ✅ Scriptable and automatable

**Setup**:
1. Get token from https://linear.app/settings/api
2. Set environment variable:
   ```bash
   export LINEAR_API_TOKEN="lin_api_..."
   ```
3. Or use Doppler: `doppler run -- claude`

### How Access Method is Selected

The plugin automatically detects and uses the best available method:

1. **MCP First** (if in Claude Code web)
   - Checks for connected Linear MCP server
   - Uses OAuth authentication

2. **API Fallback** (if MCP unavailable)
   - Checks for LINEAR_API_TOKEN
   - Uses direct GraphQL API

3. **Automatic Failover**
   - If MCP operation fails, automatically tries API
   - Seamless fallback for reliability

### Check Your Access Method

```bash
node tools/anspar-cc-plugins/plugins/linear-api/scripts/test-access.js
```

This shows:
- Which access method is active
- Whether MCP is available
- Whether API token is set
- Full diagnostic information

## What This Plugin Does NOT Do

This plugin intentionally does NOT include:

- Project-specific business logic
- Requirement validation (REQ-* references)
- Custom checklist generation
- Workflow enforcement
- FDA compliance logic
- Sponsor/context awareness

For project-specific functionality, see the `requirement-traceability` plugin which builds on top of this one.

## Installation

### Prerequisites

1. **Linear API Token**: Get your token from https://linear.app/settings/api
2. **Node.js**: Version 18+ required
3. **Environment Variable**: Set your Linear API token

```bash
export LINEAR_API_TOKEN="lin_api_..."
```

### Plugin Setup

This plugin is designed to be installed in the Claude Code marketplace directory:

```
tools/anspar-cc-plugins/plugins/linear-api/
```

No additional installation steps required. The plugin auto-discovers your Linear team on first use.

### Test Configuration

Verify your setup:

```bash
node tools/anspar-cc-plugins/plugins/linear-api/scripts/test-config.js
```

This will:
- Check for LINEAR_API_TOKEN
- Auto-discover your LINEAR_TEAM_ID
- Display plugin paths
- Confirm API connectivity

## Quick Start

### 1. Fetch a Ticket

```bash
# Fetch specific ticket
bash tools/anspar-cc-plugins/plugins/linear-api/skills/fetch-tickets.skill CUR-240

# Fetch current active ticket (from workflow state)
bash tools/anspar-cc-plugins/plugins/linear-api/skills/fetch-tickets.skill

# Fetch multiple tickets
bash tools/anspar-cc-plugins/plugins/linear-api/skills/fetch-tickets.skill CUR-240 CUR-241
```

### 2. Create a Ticket

```bash
bash tools/anspar-cc-plugins/plugins/linear-api/skills/create-ticket.skill \
  --title="Fix authentication bug" \
  --description="Users cannot log in after password reset" \
  --labels="bug,backend" \
  --priority=high
```

### 3. Update a Ticket

```bash
# Update status
bash tools/anspar-cc-plugins/plugins/linear-api/skills/update-ticket.skill \
  --ticketId=CUR-240 \
  --status=in-progress

# Add checklist
bash tools/anspar-cc-plugins/plugins/linear-api/skills/update-ticket.skill \
  --ticketId=CUR-240 \
  --checklist='- [ ] Fix login endpoint
- [ ] Add tests
- [ ] Update docs'

# Add requirement reference
bash tools/anspar-cc-plugins/plugins/linear-api/skills/update-ticket.skill \
  --ticketId=CUR-240 \
  --add-requirement=REQ-p00001
```

### 4. Search Tickets

```bash
bash tools/anspar-cc-plugins/plugins/linear-api/skills/search-tickets.skill \
  --query="authentication"
```

### 5. List Labels

```bash
# All labels
bash tools/anspar-cc-plugins/plugins/linear-api/skills/list-labels.skill

# Filter by prefix
bash tools/anspar-cc-plugins/plugins/linear-api/skills/list-labels.skill --filter="ai:"
```

## Skills Reference

All skills are located in `skills/` and are executable bash wrappers around the core scripts.

| Skill | Purpose |
| --- | --- |
| `fetch-tickets.skill` | Fetch ticket details by ID |
| `create-ticket.skill` | Create a new ticket |
| `update-ticket.skill` | Update ticket status/description/checklist |
| `search-tickets.skill` | Search tickets by keyword |
| `list-labels.skill` | List available labels |

### Skill Invocation from Claude Code

```bash
# From skills directory
bash tools/anspar-cc-plugins/plugins/linear-api/skills/fetch-tickets.skill CUR-240

# Or directly from scripts
node tools/anspar-cc-plugins/plugins/linear-api/scripts/fetch-tickets.js CUR-240
```

## Scripts Reference

All scripts are located in `scripts/` and can be invoked directly with Node.js.

### fetch-tickets.js

Fetch detailed ticket information.

```bash
node scripts/fetch-tickets.js [TICKET-IDS...]
```

**Arguments**:
- `TICKET-IDS`: One or more ticket identifiers (e.g., CUR-240)
- If no arguments, fetches current active ticket from workflow state

**Output**: Detailed ticket information including:
- Basic info (identifier, title, status, URL)
- Priority and assignment
- Team and project
- Labels
- Parent/children tickets
- Requirement references (if present)
- Timeline (created, updated, started, completed)
- Description
- Recent comments

**Examples**:
```bash
# Current ticket
node scripts/fetch-tickets.js

# Specific ticket
node scripts/fetch-tickets.js CUR-240

# Multiple tickets
node scripts/fetch-tickets.js CUR-240 CUR-241 CUR-242
```

### create-ticket.js

Create a new Linear ticket.

```bash
node scripts/create-ticket.js --title="Title" [options]
```

**Required Options**:
- `--title="..."`: Ticket title

**Optional Options**:
- `--description="..."`: Ticket description
- `--description-file=PATH`: Read description from file
- `--priority=VALUE`: Priority level (see priority values below)
- `--labels="a,b,c"`: Comma-separated label names
- `--project=ID`: Project ID
- `--assignee=ID`: Assignee ID or email

**Priority Values**:
- Numbers: `0` (None), `1` (Urgent), `2` (High), `3` (Normal), `4` (Low)
- Names: `urgent`, `high`, `normal`, `medium`, `low`, `none`
- P-notation: `P0`, `P1`, `P2`, `P3`, `P4`

**Output**:
- Created ticket ID and URL
- Suggested next steps

**Examples**:
```bash
# Simple ticket
node scripts/create-ticket.js --title="Fix login bug" --priority=high

# With description file
node scripts/create-ticket.js \
  --title="Implement OAuth" \
  --description-file=/path/to/spec.md \
  --labels="enhancement,backend" \
  --priority=P2

# Full example
node scripts/create-ticket.js \
  --title="Update API docs" \
  --description="Document new authentication endpoints" \
  --labels="documentation,api" \
  --priority=normal \
  --assignee=user@example.com
```

### update-ticket.js

Update an existing ticket's status, description, checklist, or add requirement references.

```bash
node scripts/update-ticket.js --ticketId=ID [options]
```

**Required Options**:
- `--ticketId=ID`: Ticket identifier (e.g., CUR-240)

**Update Options** (at least one required):
- `--status=STATUS`: Change ticket status
- `--description=TEXT`: Replace entire description
- `--checklist=MARKDOWN`: Add checklist (markdown format)
- `--add-requirement=REQ-ID`: Add requirement reference

**Status Values**:
- `todo`: Move to "To Do" (unstarted)
- `in-progress`: Move to "In Progress" (started)
- `done`: Move to "Done" (completed)
- `backlog`: Move to "Backlog"
- `canceled`: Move to "Canceled"

**Output**:
- Updated ticket status
- Updated fields
- Ticket URL

**Examples**:
```bash
# Update status
node scripts/update-ticket.js --ticketId=CUR-240 --status=in-progress

# Add checklist
node scripts/update-ticket.js \
  --ticketId=CUR-240 \
  --checklist='- [ ] Write tests
- [ ] Update docs
- [ ] Deploy to staging'

# Add requirement reference (generic prepend)
node scripts/update-ticket.js \
  --ticketId=CUR-240 \
  --add-requirement=REQ-p00001

# Multiple updates
node scripts/update-ticket.js \
  --ticketId=CUR-240 \
  --status=done \
  --add-requirement=REQ-p00042
```

**Note**: The `--add-requirement` flag simply prepends text like `**Requirement**: REQ-p00001` to the description. It does NOT validate the requirement or fetch requirement-specific data. For requirement-aware operations, use the `requirement-traceability` plugin.

### search-tickets.js

Search for tickets by keyword in title or description.

```bash
node scripts/search-tickets.js --query="search term" [--format=FORMAT]
```

**Options**:
- `--query=TEXT`: Search term (required)
- `--format=FORMAT`: Output format (`summary` or `json`)

**Output**:
- List of matching tickets
- Ticket identifier, title, status, URL
- Project (if assigned)
- Requirements (if present in description)

**Examples**:
```bash
# Search by keyword
node scripts/search-tickets.js --query="authentication"

# JSON output
node scripts/search-tickets.js --query="login bug" --format=json

# Search for requirement
node scripts/search-tickets.js --query="REQ-p00042"
```

### list-labels.js

List all available labels in the Linear workspace.

```bash
node scripts/list-labels.js [--filter=PREFIX] [--format=FORMAT]
```

**Options**:
- `--filter=PREFIX`: Filter labels by prefix (e.g., `"ai:"`)
- `--format=FORMAT`: Output format (`list` or `json`)

**Output**:
- List of labels with names, descriptions, and colors
- Total count

**Examples**:
```bash
# All labels
node scripts/list-labels.js

# Filter by prefix
node scripts/list-labels.js --filter="ai:"

# JSON output
node scripts/list-labels.js --format=json
```

### test-config.js

Test Linear plugin configuration and connectivity.

```bash
node scripts/test-config.js
```

**Output**:
- API token status
- Team ID (discovered or set)
- Plugin paths
- API endpoint
- Configuration completeness

**Usage**: Run this first to verify your setup before using other scripts.

### setup-env.sh

Auto-discover Linear team ID and provide export commands.

```bash
# Just display team info
bash scripts/setup-env.sh

# Export to current session (must use 'source')
source scripts/setup-env.sh
```

**Output**:
- Discovered team ID
- Export command for shell configuration
- List of teams (if multiple)

**Note**: This is typically not needed as the plugin auto-discovers team ID on first use.

## Library Modules (lib/)

The plugin includes reusable JavaScript modules:

| Module | Purpose |
| --- | --- |
| `config.js` | Configuration management and auto-discovery |
| `env-validation.js` | Environment variable validation |
| `graphql-client.js` | Low-level GraphQL client |
| `ticket-fetcher.js` | Ticket fetching operations |
| `ticket-creator.js` | Ticket creation operations |
| `ticket-updater.js` | Ticket update operations |
| `label-manager.js` | Label fetching and filtering |
| `team-resolver.js` | Team ID resolution and caching |

These modules can be imported by other plugins or scripts:

```javascript
const ticketFetcher = require('./lib/ticket-fetcher');
const ticketCreator = require('./lib/ticket-creator');
const config = require('./lib/config');
```

## Configuration

### Environment Variables

**Required**:
- `LINEAR_API_TOKEN`: Your Linear API token (get from https://linear.app/settings/api)

**Optional** (auto-discovered if not set):
- `LINEAR_TEAM_ID`: Your team ID (plugin will discover automatically)

### Auto-Discovery

On first use, the plugin will:
1. Check for `LINEAR_API_TOKEN`
2. Query Linear API for your teams
3. If single team: auto-select and cache
4. If multiple teams: display list for manual selection
5. Cache team ID for future use (24-hour cache)

### Cache Location

Cache files are stored in:
```
tools/anspar-cc-plugins/plugins/linear-api/.cache/
```

Cache includes:
- Team ID
- Label data
- Other frequently accessed data

Cache expires after 24 hours and is automatically refreshed.

## Error Handling

All scripts provide helpful error messages and exit with code 1 on failure:

**Missing Token**:
```
Error: LINEAR_API_TOKEN is not set

Please set your Linear API token first:
  export LINEAR_API_TOKEN="lin_api_..."

Get your token from: https://linear.app/settings/api
```

**Ticket Not Found**:
```
Error: Ticket 'CUR-240' not found.
```

**Invalid Status**:
```
Error: Invalid status "invalid"
Valid options: todo, in-progress, done, backlog, canceled
```

**API Errors**:
```
Linear API error: 401 Unauthorized
GraphQL errors: [detailed error messages]
```

## Integration with Other Plugins

This plugin is designed as a building block for higher-level plugins. To integrate:

### 1. Import Modules

```javascript
const ticketFetcher = require('../linear-api/lib/ticket-fetcher');
const config = require('../linear-api/lib/config');
```

### 2. Add Business Logic

```javascript
// Validate requirement before adding to ticket
async function addRequirementToTicket(ticketId, reqId) {
    // Your validation logic
    const isValid = await validateRequirement(reqId);

    if (!isValid) {
        throw new Error(`Invalid requirement: ${reqId}`);
    }

    // Use linear-api to update ticket
    const { execSync } = require('child_process');
    execSync(`bash linear-api/skills/update-ticket.skill --ticketId=${ticketId} --add-requirement=${reqId}`);
}
```

### 3. Extend Functionality

Build custom agents that combine linear-api operations with:
- Requirement validation
- Checklist generation
- Workflow enforcement
- Project-specific labels
- Custom fields

## Example: Building a Higher-Level Plugin

```javascript
// my-plugin/scripts/create-validated-ticket.js
const ticketCreator = require('../../linear-api/lib/ticket-creator');
const myValidator = require('../lib/my-validator');

async function createValidatedTicket(options) {
    // Custom validation
    await myValidator.validateOptions(options);

    // Generate custom checklist
    const checklist = await myValidator.generateChecklist(options.requirementId);

    // Create ticket using linear-api
    const ticket = await ticketCreator.createTicket({
        title: options.title,
        description: `Requirement: ${options.requirementId}\n\n${options.description}\n\n${checklist}`,
        labels: options.labels,
        priority: options.priority
    });

    // Custom post-processing
    await myValidator.recordTicket(ticket.id, options.requirementId);

    return ticket;
}
```

## API Documentation

### GraphQL Queries Used

The plugin uses the following Linear GraphQL operations:

**Issue Queries**:
- `issue(id: String!)`: Fetch single ticket
- `issues(filter: IssueFilter!)`: Search/filter tickets

**Issue Mutations**:
- `issueCreate(input: IssueCreateInput!)`: Create ticket
- `issueUpdate(id: String!, input: IssueUpdateInput!)`: Update ticket

**Other Queries**:
- `viewer.organization.teams`: Fetch teams
- `team.labels`: Fetch labels
- `team.states`: Fetch workflow states

For full API documentation, see: https://developers.linear.app/docs

## Security

For best practices on managing Linear API tokens securely, see [Secret Management Guide](../../../../docs/security-secret-management.md).

## Troubleshooting

### Token Issues

**Problem**: `Error: LINEAR_API_TOKEN is not set`

**Solution**:
```bash
# Get token from Linear
# https://linear.app/settings/api

# Set in environment
export LINEAR_API_TOKEN="lin_api_..."

# Or add to ~/.bashrc or ~/.zshrc
echo 'export LINEAR_API_TOKEN="lin_api_..."' >> ~/.bashrc
```

### Team Discovery Issues

**Problem**: "No teams found" or "Multiple teams"

**Solution**:
```bash
# Test configuration
node scripts/test-config.js

# If multiple teams, manually set:
export LINEAR_TEAM_ID="team-id-here"
```

### Permission Issues

**Problem**: "Permission denied" or "401 Unauthorized"

**Solution**:
- Verify your LINEAR_API_TOKEN is valid
- Check token permissions in Linear settings
- Ensure you have access to the workspace/team

### Script Not Found

**Problem**: "Cannot find module './lib/...'"

**Solution**:
```bash
# Ensure you're running from the correct directory
cd tools/anspar-cc-plugins/plugins/linear-api

# Or use absolute paths
node /full/path/to/scripts/fetch-tickets.js
```

## Performance

- **Caching**: Team and label data cached for 24 hours
- **Rate Limiting**: Linear API has rate limits; the plugin does not implement throttling
- **Batch Operations**: Use multiple ticket IDs in fetch-tickets.js for efficiency

## Security

- **Token Storage**: NEVER commit LINEAR_API_TOKEN to git
- **Environment Variables**: Always use environment variables for secrets
- **Cache**: Cache does not store sensitive data (only team IDs, label info)

## Troubleshooting

### MCP Issues

**Problem**: "MCP not available" in Claude Code web

**Solution**:
1. Run `/mcp` in Claude Code
2. Check if Linear is listed
3. If not, connect Linear MCP
4. Authenticate when prompted

**Problem**: "OAuth authentication failed"

**Solution**:
1. Run `/mcp` in Claude Code
2. Select "Manage authentication" for Linear
3. Re-authenticate with your Linear account

### API Token Issues

**Problem**: "LINEAR_API_TOKEN not found"

**Solution**:
- Set the environment variable:
  ```bash
  export LINEAR_API_TOKEN="lin_api_..."
  ```
- Or use Doppler:
  ```bash
  doppler run -- claude
  ```
- Get your token from: https://linear.app/settings/api

**Problem**: "Authentication failed" with API token

**Solution**:
- Verify your token is valid (check Linear settings)
- Ensure the token has the required permissions
- Try generating a new token

### Fallback Not Working

**Problem**: "Both MCP and API failed"

**Solution**:
- Check MCP connection: `/mcp`
- Check API token: `echo $LINEAR_API_TOKEN`
- Check network connectivity
- Check Linear service status
- Run diagnostics:
  ```bash
  node tools/anspar-cc-plugins/plugins/linear-api/scripts/test-access.js --verbose
  ```

### When to Use Which Method

| Scenario | Recommended Method |
| -------- | ------------------ |
| Claude Code web (claude.ai/code) | MCP (automatic) |
| Claude Code CLI | API token |
| CI/CD pipelines | API token |
| Automation scripts | API token |
| Team collaboration | MCP (OAuth) |
| Personal use | Either |

## Contributing

This plugin is part of the Anspar marketplace. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Test with `test-config.js` and manual operations
5. Submit pull request

## License

MIT License

## Support

- **Repository**: https://github.com/anspar/diary
- **Plugin Location**: `tools/anspar-cc-plugins/plugins/linear-api/`
- **Linear API Docs**: https://developers.linear.app/docs
- **Issues**: Submit via GitHub Issues

## Related Plugins

- **linear-api**: Diary-specific Linear integration with requirement validation
- **workflow**: Git workflow enforcement
- **simple-requirements**: Requirement format validation

## Version History

### 3.0.0 (Current)
- **Linear MCP Support**: Added Model Context Protocol integration
- **Dual Access**: Automatic detection of MCP vs API access
- **Graceful Fallback**: Auto-fallback from MCP to API on errors
- **Enhanced Diagnostics**: New test-access.js for troubleshooting
- **Updated Documentation**: Comprehensive MCP setup and usage guides
- Implements: REQ-d00053 (Development Environment and Tooling Setup)

### 2.0.0
- Initial release as standalone generic plugin
- Extracted from linear-api plugin
- Consolidated update operations into single script
- Added skills-based invocation
- Auto-discovery of team IDs
- Comprehensive documentation

## Roadmap

Future enhancements (contributions welcome):

- Attachment support
- Comment operations (add, list, update)
- Bulk update operations
- Custom field support
- Webhook integration
- Rate limiting and retry logic
- OAuth token refresh
