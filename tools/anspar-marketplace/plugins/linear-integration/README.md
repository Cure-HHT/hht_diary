# Anspar Linear Integration

**Claude Code Plugin for Linear API Integration**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js Version](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen)](https://nodejs.org/)

## Overview

The Anspar Linear Integration plugin provides comprehensive CLI tools for integrating Linear project management with requirement traceability systems. It automates ticket creation from requirements, manages requirement-ticket linking, and provides analysis tools for tracking implementation progress.

**Key Features**:
- ✅ **Intelligent ticket creation agent** - Context-aware, minimal-step ticket creation
- ✅ Batch ticket creation from requirement specifications
- ✅ Intelligent caching system with automatic refresh
- ✅ Environment variable auto-discovery
- ✅ Smart labeling and priority assignment
- ✅ Subsystem checklist generation
- ✅ Duplicate detection and analysis
- ✅ Future-ready for Doppler secret management

## Installation

### As Claude Code Plugin

1. Clone or copy this directory to your Claude Code plugins location
2. The plugin will be automatically discovered by Claude Code

### As Standalone Tool

```bash
# Clone the repository
git clone https://github.com/anspar/diary.git
cd diary/tools/anspar-marketplace/plugins/linear-integration

# Verify Node.js version
node --version  # Should be v18.0.0+
```

## Prerequisites

### 1. Linear API Token

Get your Personal API token:
1. Go to [Linear Settings > API](https://linear.app/settings/api)
2. Create a new Personal API Key
3. Copy the token (starts with `lin_api_`)

### 2. Environment Setup

**Quick Setup** (Auto-discover team ID):

```bash
# Set your API token
export LINEAR_API_TOKEN="lin_api_your_token_here"

# Discover and export team ID automatically
source scripts/setup-env.sh
```

The `setup-env.sh` script will automatically:
- Query Linear API for your teams
- Export LINEAR_TEAM_ID if you have a single team
- Display available teams if you have multiple

**Persistent Setup**: Add to `~/.bashrc` or `~/.zshrc`:

```bash
export LINEAR_API_TOKEN="lin_api_your_token_here"
export LINEAR_TEAM_ID="your-team-id"  # Optional - auto-discovered if omitted
```

Then reload: `source ~/.bashrc`

**Alternative**: Pass credentials directly to scripts:
```bash
node script.js --token=lin_api_your_token_here --team-id=your-team-id
```

### 3. Node.js Version

Requires Node.js 18.0.0 or higher.

```bash
node --version  # Should be v18.0.0+
```

## Features

### 1. Intelligent Caching System

The plugin maintains a local cache of requirement-ticket mappings with automatic management:

- **Auto-refresh**: Cache refreshes automatically after 24 hours
- **On-demand refresh**: Use `--refresh-cache` flag to force refresh
- **Fallback**: Stale cache used if API unavailable
- **Smart exclusion**: Automatically skips requirements with existing tickets

**Cache location**: `scripts/config/requirement-ticket-cache.json` (gitignored)

**Example output**:
```
✓ Using cached mappings (3h old, 96 requirements)
Skipped 55 requirements that already have tickets
Creating tickets for 5 requirements
```

### 2. Environment Validation

All scripts validate environment variables at startup:

- Reports which variables are being used (not their values)
- Auto-discovers LINEAR_TEAM_ID if missing
- Provides clear instructions for missing configuration
- Future-ready for Doppler integration

**Example output**:
```
🔧 Checking environment variables...

✓ Using LINEAR_API_TOKEN from environment
⚡ LINEAR_TEAM_ID not set, auto-discovering...
  Found team: Cure HHT Diary (CUR)
✓ Successfully discovered LINEAR_TEAM_ID
```

### 3. Smart Labeling

Tickets are automatically labeled based on requirement keywords:

| Keyword | Label |
|---------|-------|
| security, auth, rbac | security |
| database, schema, sql | database |
| infrastructure, deployment | infrastructure |
| compliance, audit, fda | compliance |
| mobile, app, flutter | mobile |
| backend, api, server | backend |
| documentation, spec | documentation |

### 4. Priority Mapping

Automatic priority assignment based on requirement level:

| Requirement Level | Linear Priority |
|-------------------|-----------------|
| PRD | P1 (Urgent) |
| Ops | P2 (High) |
| Dev | P3 (Normal) |

## Claude Code Agents

This plugin provides intelligent agents that integrate with Claude Code's task system.

### Ticket Creation Agent

**Purpose**: Intelligent, context-aware ticket creation with minimal manual steps.

**Auto-invokes when**: User requests to create a new Linear ticket.

**Key features**:
- **Context awareness**: Reads git status, branch names, and recent commits
- **Smart defaults**: Infers priority, labels, and descriptions from context
- **Interactive prompting**: Asks for clarification on ambiguous requests
- **Quality validation**: Ensures tickets have meaningful titles and descriptions
- **Requirement linking**: Automatically detects and suggests REQ-* references
- **Workflow integration**: Offers to claim ticket after creation

**Example interaction**:
```
User: "Create a ticket for the login redirect loop"

Agent:
[Analyzes context]
- Branch: main
- Changed files: packages/app/lib/auth/login_handler.dart
- Recent commits: "WIP: fixing auth flow"

📋 Ready to create Linear ticket:

Title: Fix login redirect loop in authentication handler
Description:
Users experiencing redirect loop when attempting to login.

Context:
- Affects: packages/app/lib/auth/login_handler.dart
- Recent work: Authentication flow refactoring

Priority: High (login is critical user flow)
Labels: bug, backend

Does this look good, or would you like to provide more details?
```

**Benefits**:
- Reduces manual steps in ticket creation
- Ensures consistent ticket quality
- Automatically links to requirements and workflow
- Provides intelligent suggestions based on context

**Location**: `agents/ticket-creation-agent.md`

### Linear Agent

**Purpose**: General Linear ticket management and operations.

**Provides**:
- Fetch tickets by status, label, or assignment
- Update ticket descriptions and checklists
- Search tickets by requirement or keyword
- Claim tickets for workflow integration

**Location**: `agents/linear-agent.md`

## Slash Commands

This plugin provides convenient slash commands for quick access to common operations.

### /ticket (alias: /issue)

**Quick ticket management with workflow integration.**

```
/ticket              # Show current active ticket
/ticket new          # Create a new ticket (launches ticket-creation-agent)
/ticket CUR-XXX      # Switch to ticket CUR-XXX (claims it + sets Linear status to In Progress)
```

**Features**:
- **No arguments**: Displays current active ticket from workflow
- **`new`**: Guides you to use the intelligent ticket-creation-agent
- **Ticket ID**: Switches to the specified ticket:
  - Claims ticket in workflow (creates/updates WORKFLOW_STATE)
  - Updates Linear status to "In Progress"
  - Provides confirmation and next steps

**Example workflow**:
```
User: /ticket
Output: Active ticket: CUR-320 (core)

User: /ticket CUR-322
Output:
🔄 Switching to ticket: CUR-322
✅ Successfully switched to CUR-322
📊 Updating Linear status to 'In Progress'...
✅ Linear status updated
🎯 Now working on: CUR-322

User: /ticket new
Output: [Instructions for using ticket-creation-agent]
```

### /req (alias: /requirement)

**Query and manage formal requirements.**

```
/req                    # Show help and recent requirements
/req REQ-d00027         # Display full requirement details
/req search <term>      # Search for requirements by keyword
/req new                # Guide for creating new requirements
/req validate           # Run requirement validation
```

**Features**:
- **No arguments**: Shows usage help and lists the 5 most recent requirements
- **REQ-xxx**: Displays full requirement content from spec files
- **`search <term>`**: Searches all spec files for matching requirements
- **`new`**: Provides step-by-step guide for creating new requirements
- **`validate`**: Runs the requirement validation tool

**Example workflow**:
```
User: /req
Output:
📋 REQUIREMENT MANAGEMENT
[Usage instructions]
Recent requirements (last 5):
[List of requirements]
📁 Total requirements: 160

User: /req REQ-d00067
Output:
🔍 Looking up: REQ-d00067
📌 REQ-d00067
📄 File: dev-marketplace-streamlined-tickets.md
📝 Title: Streamlined Ticket Creation Agent
[Full requirement content...]

User: /req search "ticket"
Output:
🔍 Searching requirements for: ticket
Found in:
  📄 dev-marketplace-streamlined-tickets.md - REQ-d00067
  📄 dev-marketplace-workflow-detection.md - REQ-d00068
```

## Available Scripts

All scripts are located in the `scripts/` directory.

### Ticket Fetching

#### fetch-tickets.js

Fetch all tickets assigned to you with requirement analysis.

```bash
# Using environment variable
node scripts/fetch-tickets.js

# With inline token
node scripts/fetch-tickets.js --token=$LINEAR_API_TOKEN

# JSON output
node scripts/fetch-tickets.js --format=json
```

**Output**:
- Categorized by status (Backlog, Todo, In Progress, etc.)
- Extracted requirement references (REQ-p00001, etc.)
- Priority and due date information
- Summary statistics

#### fetch-tickets-by-label.js

Fetch ALL tickets (not just assigned) filtered by label.

```bash
node scripts/fetch-tickets-by-label.js --token=$LINEAR_API_TOKEN --label="ai:new"
```

**Use cases**:
- Find tickets created by automation
- Query infrastructure/security tickets
- Analyze ticket coverage by topic

### Ticket Creation

#### create-requirement-tickets.js

Batch create Linear tickets from requirements in `spec/` directory.

```bash
# Dry run (preview without creating)
node scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --team-id=$LINEAR_TEAM_ID \
  --dry-run

# Create PRD-level tickets only
node scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --team-id=$LINEAR_TEAM_ID \
  --level=PRD

# Force cache refresh
node scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --team-id=$LINEAR_TEAM_ID \
  --refresh-cache
```

**Features**:
- Parses all requirements from `spec/*.md`
- Uses intelligent caching to skip requirements with existing tickets
- Auto-assigns labels based on keywords
- Sets priority by level (PRD=P1, Ops=P2, Dev=P3)
- Adds "ai:new" label to all created tickets
- Auto-discovers LINEAR_TEAM_ID if not provided

#### create-tickets.sh

Wrapper script to create tickets in order: PRD → Ops → Dev.

```bash
cd scripts
./create-tickets.sh
```

**What it does**:
- Automatically loads nvm for Node.js
- Creates PRD tickets first, pauses for review
- Creates Ops tickets, pauses for review
- Creates Dev tickets
- Shows summary

#### run-dry-run.sh / run-dry-run-all.sh

Preview ticket creation without making API calls.

```bash
cd scripts
./run-dry-run.sh PRD          # Preview one level
./run-dry-run-all.sh          # Preview all levels
```

### Ticket Management

#### update-ticket.js

General-purpose ticket updater for descriptions, checklists, and requirements.

```bash
# Update ticket description
node scripts/update-ticket.js \
  --ticketId=CUR-123 \
  --description="New description text"

# Add checklist items
node scripts/update-ticket.js \
  --ticketId=CUR-123 \
  --addChecklist="- [ ] Task 1\n- [ ] Task 2"

# Add requirement reference
node scripts/update-ticket.js \
  --ticketId=CUR-123 \
  --addRequirement=REQ-d00042
```

**What it does**:
- Updates any ticket field (description, checklist, requirements)
- Can combine multiple updates in one call
- Preserves existing content when adding new items
- Uses LINEAR_API_TOKEN environment variable

#### update-ticket-with-requirement.js

Link an existing Linear ticket to a requirement with formatted GitHub link.

```bash
node scripts/update-ticket-with-requirement.js \
  --token=$LINEAR_API_TOKEN \
  --ticket-id=CUR-123 \
  --req-id=d00042
```

**What it does**:
- Looks up requirement in spec/ files
- Updates ticket description with formatted requirement link
- Format: `Requirement: REQ-xxx | Title | [filename](github-url)`
- Preserves existing ticket content

#### enhance-req-links.js

Bulk update REQ references in Linear tickets to properly formatted GitHub links.

```bash
# Update a specific ticket
node scripts/enhance-req-links.js --ticket-id=CUR-123

# Update all tickets with REQ references
node scripts/enhance-req-links.js --all

# Dry run to preview changes
node scripts/enhance-req-links.js --all --dry-run

# Force update even if links already exist
node scripts/enhance-req-links.js --ticket-id=CUR-123 --force
```

**What it does**:
- Finds all plain REQ-xxx references in ticket descriptions
- Looks up requirements in spec/ files to get title and location
- Replaces with formatted links: `Requirement: REQ-xxx | Title | [filename](github-url)`
- Handles multiple REQs per ticket (creates separate lines for each)
- Skips tickets that already have properly formatted links (unless --force)
- Uses LINEAR_API_TOKEN environment variable

**Use cases**:
- Fix malformed REQ links after format changes
- Bulk update after requirement reorganization
- Add titles and GitHub links to existing plain REQ references

#### add-subsystem-checklists.js

Add subsystem checklists to tickets based on requirement analysis.

```bash
# Add checklists to all tickets
node scripts/add-subsystem-checklists.js --token=$LINEAR_API_TOKEN

# Dry run (preview)
node scripts/add-subsystem-checklists.js --token=$LINEAR_API_TOKEN --dry-run
```

**Subsystems tracked**:
- Supabase (Database & Auth)
- Google Workspace
- GitHub, Doppler, Netlify, Linear
- Development Environment, CI/CD Pipeline
- Mobile App (Flutter), Web Portal
- Compliance & Documentation, Backup & Recovery

### Analysis Tools

#### check-duplicates.js

Find duplicate requirement-ticket mappings.

```bash
node scripts/check-duplicates.js --token=$LINEAR_API_TOKEN
```

#### list-infrastructure-tickets.js

List all tickets tagged with "infrastructure" label.

```bash
node scripts/list-infrastructure-tickets.js --token=$LINEAR_API_TOKEN
```

## Common Workflows

### Workflow 1: Create Tickets for New Requirements

```bash
# 1. Dry run to preview
cd scripts
./run-dry-run-all.sh

# 2. Review output, then create tickets
./create-tickets.sh

# 3. Add subsystem checklists
node add-subsystem-checklists.js --token=$LINEAR_API_TOKEN
```

### Workflow 2: Link Existing Ticket to Requirement

```bash
# Find ticket ID from Linear (click ticket → copy UUID from URL)
node scripts/update-ticket-with-requirement.js \
  --token=$LINEAR_API_TOKEN \
  --ticket-id=abc123-def456-... \
  --req-id=p00042
```

### Workflow 3: Refresh Cache and Sync

```bash
# Force refresh cache from Linear
node scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --refresh-cache \
  --dry-run

# Review what needs to be created
# Then create if needed
node scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN
```

## Configuration

### Cache Management

The requirement-ticket cache is stored in `scripts/config/requirement-ticket-cache.json`:

```json
{
  "timestamp": 1761845358329,
  "mappings": {
    "p00001": ["CUR-123", "CUR-456"],
    "o00007": ["CUR-789"]
  },
  "metadata": {
    "totalIssues": 277,
    "totalMappings": 96,
    "lastRefresh": "2025-10-30T17:29:18.329Z"
  }
}
```

- **Auto-refresh**: After 24 hours
- **Manual refresh**: `--refresh-cache` flag
- **Fallback**: Uses stale cache if API unavailable

### Rate Limiting

All scripts include 100ms delays between API calls to respect Linear's rate limits. Do not modify these delays or run multiple scripts simultaneously.

## Troubleshooting

### Authentication Errors

**Problem**: "Linear API error: Unauthorized"

**Solutions**:
```bash
# Verify token is set
echo $LINEAR_API_TOKEN

# Verify token format (should start with lin_api_)
# Check token hasn't expired at https://linear.app/settings/api

# Try passing token inline
node script.js --token=lin_api_YOUR_TOKEN
```

### No Tickets Created

**Problem**: Script runs but no tickets appear in Linear

**Solutions**:
```bash
# Run with --refresh-cache to ensure cache is up to date
node scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --refresh-cache \
  --dry-run

# Verify requirements exist in spec/ directory
ls spec/*.md

# Check that team ID is correct
node scripts/setup-env.sh
```

### Cache Issues

**Problem**: Cache not updating or showing stale data

**Solutions**:
```bash
# Force refresh cache
node scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --refresh-cache \
  --dry-run

# Delete cache and regenerate
rm scripts/config/requirement-ticket-cache.json
node scripts/create-requirement-tickets.js --dry-run
```

## Security

### Token Storage

**Never commit secrets to git!**

✅ **Recommended**:
- Use environment variables for all secrets
- Manage secrets via Doppler or similar secret management systems
- Run with: `doppler run -- claude` to inject environment variables
- Linear API token is stored in `LINEAR_API_TOKEN` environment variable

❌ **Unsafe**:
- Hardcoded tokens in scripts
- Committing secrets to git (including `.env` files)
- Storing secrets in plain text files
- Sharing secrets via chat or email

### Token Permissions

Linear Personal API tokens have full account access. Store them securely and rotate regularly.

### Doppler Integration

This project uses Doppler for secret management. All environment variables (including `LINEAR_API_TOKEN`) are automatically injected when running `doppler run -- claude`. The plugin's config system prioritizes environment variables over file-based configuration.

## npm Scripts

Convenience scripts available via `npm run`:

```bash
npm run fetch-tickets       # Fetch assigned tickets
npm run create-tickets      # Create tickets from requirements
npm run setup-env           # Auto-discover LINEAR_TEAM_ID
```

## Dependencies

- **Node.js**: >=18.0.0
- **Bash**: >=4.0
- **External APIs**: Linear GraphQL API

## License

MIT License - see [LICENSE](./LICENSE) file for details.

## Contributing

This plugin is part of the Anspar Foundation tooling ecosystem. Contributions welcome!

## Credits

**Developed by**: Anspar Foundation
**Plugin System**: Claude Code by Anthropic

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for version history.

## Related Documentation

- **Environment Variables**: [docs/environment-variables.md](./docs/environment-variables.md)
- **Requirement Format**: See spec/requirements-format.md in parent project
- **Claude Code Plugins**: https://docs.claude.com/en/docs/claude-code/plugins-reference

## Support

For issues, questions, or contributions:
- **Repository**: https://github.com/anspar/diary
- **Plugin Path**: `tools/anspar-marketplace/plugins/linear-integration`
