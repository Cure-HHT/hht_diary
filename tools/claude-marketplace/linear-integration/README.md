# Linear Integration Plugin for Claude Code

**Version**: 1.0.0
**Type**: Integration Plugin
**Status**: Active

## Overview

The linear-integration plugin provides CLI tools for integrating Linear project management with the diary project's requirement traceability system. It automates ticket creation from requirements, manages requirement-ticket linking, and provides analysis tools for tracking implementation progress.

## Features

- ✅ **Fetch tickets** - Retrieve assigned tickets with requirement references
- ✅ **Create tickets** - Batch create Linear tickets from spec/ requirements
- ✅ **Link requirements** - Associate existing tickets with requirements
- ✅ **Subsystem checklists** - Auto-generate checklists based on requirement scope
- ✅ **Duplicate detection** - Find overlapping requirement-ticket mappings
- ✅ **Priority mapping** - Automatic priority assignment (PRD=P1, Ops=P2, Dev=P3)
- ✅ **Label automation** - Smart labeling based on requirement keywords

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
source tools/claude-marketplace/linear-integration/scripts/setup-env.sh
```

The `setup-env.sh` script will automatically:
- Query Linear API for your teams
- Export LINEAR_TEAM_ID if you have a single team
- Display available teams if you have multiple

**Manual Setup**: Add to `~/.bashrc` or `~/.zshrc`:

```bash
export LINEAR_API_TOKEN="lin_api_your_token_here"
export LINEAR_TEAM_ID="your-team-id"  # Get from setup-env.sh
```

Then reload:
```bash
source ~/.bashrc
```

**Alternative**: Pass credentials directly to scripts:
```bash
node script.js --token=lin_api_your_token_here --team-id=your-team-id
```

### 3. Node.js Version

Requires Node.js 18.0.0 or higher.

```bash
node --version  # Should be v18.0.0+
```

## Available Scripts

All scripts are located in `tools/claude-marketplace/linear-integration/scripts/`.

### 1. Ticket Fetching

#### fetch-tickets.js

Fetch all tickets assigned to you with requirement analysis.

**Usage**:
```bash
# Using environment variable
node tools/claude-marketplace/linear-integration/scripts/fetch-tickets.js

# With inline token
node tools/claude-marketplace/linear-integration/scripts/fetch-tickets.js --token=$LINEAR_API_TOKEN

# JSON output
node tools/claude-marketplace/linear-integration/scripts/fetch-tickets.js --format=json
```

**Output**:
- Categorized by status (Backlog, Todo, In Progress, etc.)
- Extracted requirement references (REQ-p00001, etc.)
- Priority and due date information
- Parent/child ticket relationships
- Summary statistics

---

#### fetch-tickets-by-label.js

Fetch ALL tickets (not just assigned) filtered by label.

**Usage**:
```bash
node tools/claude-marketplace/linear-integration/scripts/fetch-tickets-by-label.js \
  --token=$LINEAR_API_TOKEN \
  --label="ai:new"
```

**Use cases**:
- Find tickets created by automation
- Query infrastructure/security tickets
- Analyze ticket coverage by topic

---

### 2. Ticket Creation

#### create-requirement-tickets.js

Batch create Linear tickets from requirements in `spec/`.

**Usage**:
```bash
# Dry run (preview without creating)
node tools/claude-marketplace/linear-integration/scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --team-id=$LINEAR_TEAM_ID \
  --dry-run

# Create PRD-level tickets only
node tools/claude-marketplace/linear-integration/scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --team-id=$LINEAR_TEAM_ID \
  --level=PRD

# Create all tickets for a project
node tools/claude-marketplace/linear-integration/scripts/create-requirement-tickets.js \
  --token=$LINEAR_API_TOKEN \
  --team-id=$LINEAR_TEAM_ID \
  --project-id=PROJECT_UUID
```

**Features**:
- Parses all requirements from `spec/*.md`
- Creates tickets for requirements without existing tickets
- Auto-assigns labels based on keywords
- Sets priority by level (PRD=P1, Ops=P2, Dev=P3)
- Adds "ai:new" label to all created tickets
- Maintains exclusion list for requirements with existing tickets

**Smart Labeling**:
- `security` keyword → "security" label
- `database` keyword → "database" label
- `infrastructure` keyword → "infrastructure" label
- Etc.

---

#### create-tickets.sh

Wrapper script to create tickets in order: PRD → Ops → Dev.

**Usage**:
```bash
cd tools/claude-marketplace/linear-integration/scripts
./create-tickets.sh
```

**What it does**:
- Automatically loads nvm for Node.js
- Creates PRD tickets first
- Pauses for review
- Creates Ops tickets
- Pauses for review
- Creates Dev tickets
- Shows summary

---

#### run-dry-run.sh / run-dry-run-all.sh

Preview ticket creation without making API calls.

**Usage**:
```bash
# Preview one level
cd tools/claude-marketplace/linear-integration/scripts
./run-dry-run.sh PRD

# Preview all levels
./run-dry-run-all.sh
```

**Shows**:
- Which tickets would be created
- Which requirements would be skipped (already have tickets)
- Validation of configuration

---

### 3. Ticket Management

#### update-ticket-with-requirement.js

Link an existing Linear ticket to a requirement.

**Usage**:
```bash
node tools/claude-marketplace/linear-integration/scripts/update-ticket-with-requirement.js \
  --token=$LINEAR_API_TOKEN \
  --ticket-id=TICKET_UUID \
  --req-id=p00042
```

**What it does**:
- Updates ticket description to reference requirement
- Prepends `**Requirement**: REQ-<id>` to description
- Preserves existing ticket content

**Use cases**:
- Link manually-created tickets to requirements
- Fix broken requirement references
- Migrate legacy tickets to traceability system

---

#### add-subsystem-checklists.js

Add subsystem checklists to tickets based on requirement analysis.

**Usage**:
```bash
# Add checklists to all tickets
node tools/claude-marketplace/linear-integration/scripts/add-subsystem-checklists.js \
  --token=$LINEAR_API_TOKEN

# Dry run (preview)
node tools/claude-marketplace/linear-integration/scripts/add-subsystem-checklists.js \
  --token=$LINEAR_API_TOKEN \
  --dry-run
```

**What it does**:
- Analyzes requirement text for subsystem keywords
- Adds checklist showing which systems need updates:
  - Supabase (Database & Auth)
  - Google Workspace
  - GitHub, Doppler, Netlify, Linear
  - Development Environment, CI/CD Pipeline
  - Mobile App (Flutter), Web Portal
  - Compliance & Documentation, Backup & Recovery
- Security/access control requirements auto-apply to all cloud services

---

### 4. Analysis Tools

#### check-duplicates.js

Find duplicate requirement-ticket mappings.

**Usage**:
```bash
node tools/claude-marketplace/linear-integration/scripts/check-duplicates.js \
  --token=$LINEAR_API_TOKEN
```

**Identifies**:
- Multiple tickets referencing the same requirement
- Potential consolidation opportunities
- Orphaned tickets

---

#### list-infrastructure-tickets.js

List all tickets tagged with "infrastructure" label.

**Usage**:
```bash
node tools/claude-marketplace/linear-integration/scripts/list-infrastructure-tickets.js \
  --token=$LINEAR_API_TOKEN
```

**Use cases**:
- Infrastructure gap analysis
- Sprint planning
- Compliance audits

---

## Common Workflows

### Workflow 1: Create Tickets for New Requirements

```bash
# 1. Dry run to preview
cd tools/claude-marketplace/linear-integration/scripts
./run-dry-run-all.sh

# 2. Review output, then create tickets
./create-tickets.sh

# 3. Add subsystem checklists
node add-subsystem-checklists.js --token=$LINEAR_API_TOKEN
```

### Workflow 2: Link Existing Ticket to Requirement

```bash
# Find ticket ID from Linear (click ticket → copy UUID from URL)
node tools/claude-marketplace/linear-integration/scripts/update-ticket-with-requirement.js \
  --token=$LINEAR_API_TOKEN \
  --ticket-id=abc123-def456-... \
  --req-id=p00042
```

### Workflow 3: Analyze Ticket Coverage

```bash
# Fetch all tickets
node tools/claude-marketplace/linear-integration/scripts/fetch-tickets.js \
  --format=json | grep -i "REQ-"

# Find duplicates
node tools/claude-marketplace/linear-integration/scripts/check-duplicates.js \
  --token=$LINEAR_API_TOKEN

# Check infrastructure coverage
node tools/claude-marketplace/linear-integration/scripts/list-infrastructure-tickets.js \
  --token=$LINEAR_API_TOKEN
```

## Integration with Requirements System

The linear-integration plugin works seamlessly with the requirement validation system:

1. **Requirement → Ticket**: `create-requirement-tickets.js` reads from `spec/` and creates tickets
2. **Ticket → Requirement**: All tickets include `**Requirement**: REQ-xxx` in description
3. **Validation**: Tools check that requirements aren't duplicated across tickets
4. **Traceability**: Tickets link back to formal requirements for audit trail
5. **Subsystems**: Checklists show which systems need configuration for each requirement

## Configuration

### Exclusion List

The `create-requirement-tickets.js` script maintains a list of requirements that already have tickets (lines 295-308 of the script). Update this list when manually creating tickets or importing from other sources.

### Rate Limiting

All scripts include 100ms delays between API calls to respect Linear's rate limits. Do not modify these delays.

### Priority Mapping

Default priority assignment:
- PRD requirements → P1 (Highest)
- Ops requirements → P2 (High)
- Dev requirements → P3 (Medium)

This can be customized in `plugin.json` configuration.

## Troubleshooting

### Authentication Errors

**Problem**: "Linear API error: Unauthorized"

**Solutions**:
```bash
# 1. Verify token is set
echo $LINEAR_API_TOKEN

# 2. Verify token is valid
# Token should start with lin_api_

# 3. Check token hasn't expired
# Go to https://linear.app/settings/api and verify

# 4. Try passing token inline
node script.js --token=lin_api_YOUR_TOKEN
```

### No Tickets Created

**Problem**: Script runs but no tickets appear in Linear

**Solutions**:
```bash
# 1. Check team ID is correct
# Find your team ID in Linear URL: linear.app/{team-id}/...

# 2. Verify requirements exist
ls spec/*.md

# 3. Run dry-run to see what would be created
node script.js --dry-run

# 4. Check exclusion list in script
# Requirements on exclusion list will be skipped
```

### Rate Limiting

**Problem**: "Too many requests" error

**Solutions**:
- Wait 60 seconds and retry
- Scripts already include delays - don't run multiple scripts simultaneously
- Check if other automation is hitting Linear API

### Script Not Found

**Problem**: "Cannot find module" or script not executable

**Solutions**:
```bash
# Verify plugin location
ls -l tools/claude-marketplace/linear-integration/scripts/

# Make scripts executable
chmod +x tools/claude-marketplace/linear-integration/scripts/*.sh

# Run from repo root
cd /path/to/diary
node tools/claude-marketplace/linear-integration/scripts/fetch-tickets.js
```

## Security

### Token Storage

**Never commit tokens to git!**

✅ **Safe**:
- Environment variables (`export LINEAR_API_TOKEN=...`)
- Shell config files (`~/.bashrc`, `~/.zshrc`)
- Pass inline: `--token=$LINEAR_API_TOKEN`

❌ **Unsafe**:
- Hardcoded in scripts
- `.env` files committed to git
- Shared in plain text

### Token Permissions

Linear Personal API tokens have full account access. Store them securely and rotate regularly.

## Related Documentation

- **Requirement Format**: `spec/requirements-format.md`
- **Requirement Validation**: `tools/claude-marketplace/requirement-validation/README.md`
- **Project Instructions**: `CLAUDE.md` (Linear Integration Tools section)

## Plugin Metadata

- **Plugin Name**: linear-integration
- **Version**: 1.0.0
- **Script Location**: `tools/claude-marketplace/linear-integration/scripts/`
- **Dependencies**: Node.js 18+, Bash 4.0+
- **Environment**: LINEAR_API_TOKEN (required), LINEAR_TEAM_ID (optional)

## Changelog

### v1.0.0 (2025-10-30)

- Initial release as Claude Code plugin
- Moved from `tools/linear-cli/` to plugin structure
- Full script suite for requirement-ticket traceability
- Comprehensive documentation
- Plugin metadata and configuration

## License

Part of the diary project. See project LICENSE for details.

## Credits

**Developed by**: Anspar Foundation
**Integrated with**: Claude Code Plugin System
