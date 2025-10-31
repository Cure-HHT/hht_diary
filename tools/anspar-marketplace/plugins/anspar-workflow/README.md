# Anspar Workflow

**Claude Code Plugin for Git Workflow Enforcement**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Version](https://img.shields.io/badge/bash-%3E%3D4.0-brightgreen)](https://www.gnu.org/software/bash/)

## Overview

The Anspar Workflow plugin enforces requirement traceability and ticket lifecycle management through git hooks and per-worktree state tracking. It ensures all commits reference formal requirements and are linked to active tickets.

**Designed for distributed workflows**: Multiple worktrees can work concurrently on same or different tickets, with each worktree maintaining its own state.

**Key Features**:
- ✅ Per-worktree state management (.git/WORKFLOW_STATE)
- ✅ REQ reference validation in commit messages
- ✅ Active ticket enforcement before commits
- ✅ Distributed worktree support
- ✅ Tracker-agnostic design (Linear integration via anspar-linear-integration)
- ✅ Comprehensive audit trail (append-only history)

## Installation

### As Claude Code Plugin

1. Clone or copy this directory to your Claude Code plugins location
2. The plugin will be automatically discovered by Claude Code
3. Configure git hooks (see below)

### Prerequisites

- **Bash**: >=4.0
- **Git**: For hook integration and worktree support
- **jq**: For JSON parsing in scripts
  ```bash
  # Install jq
  sudo apt-get install jq  # Ubuntu/Debian
  brew install jq          # macOS
  ```
- **Optional**: anspar-linear-integration plugin for Linear API integration

## Setup

### 1. Make Scripts Executable

```bash
# From repository root
chmod +x tools/anspar-marketplace/plugins/anspar-workflow/scripts/*.sh
chmod +x tools/anspar-marketplace/plugins/anspar-workflow/hooks/*
```

### 2. Configure Git Hooks

Enable custom git hooks if not already configured:

```bash
# From repository root
git config core.hooksPath .githooks
```

### 3. Integrate with Pre-Commit Hook

Add the workflow hooks to your main pre-commit hook at `.githooks/pre-commit`:

```bash
# Workflow Enforcement (Plugin)
WORKFLOW_PRECOMMIT_HOOK="tools/anspar-marketplace/plugins/anspar-workflow/hooks/pre-commit"
if [ -f "$WORKFLOW_PRECOMMIT_HOOK" ]; then
    "$WORKFLOW_PRECOMMIT_HOOK" || exit 1
fi
```

### 4. Integrate with commit-msg Hook

Add the workflow hook to `.githooks/commit-msg`:

```bash
#!/bin/bash
# Git Hook: commit-msg

# Workflow Enforcement (Plugin)
WORKFLOW_COMMITMSG_HOOK="tools/anspar-marketplace/plugins/anspar-workflow/hooks/commit-msg"
if [ -f "$WORKFLOW_COMMITMSG_HOOK" ]; then
    "$WORKFLOW_COMMITMSG_HOOK" "$1" || exit 1
fi

exit 0
```

Make it executable:
```bash
chmod +x .githooks/commit-msg
```

### 5. Integrate with post-commit Hook

Create `.githooks/post-commit`:

```bash
#!/bin/bash
# Git Hook: post-commit

# Workflow State Tracking (Plugin)
WORKFLOW_POSTCOMMIT_HOOK="tools/anspar-marketplace/plugins/anspar-workflow/hooks/post-commit"
if [ -f "$WORKFLOW_POSTCOMMIT_HOOK" ]; then
    "$WORKFLOW_POSTCOMMIT_HOOK"
fi

exit 0
```

Make it executable:
```bash
chmod +x .githooks/post-commit
```

### 6. Verify Installation

```bash
# Attempt a commit without claiming a ticket (should fail)
git add README.md
git commit -m "Test commit"

# Expected error:
# ❌ ERROR: No active ticket claimed for this worktree
```

## How It Works

### Architecture

```
anspar-workflow/
├── .git/WORKFLOW_STATE                  ← Per-worktree state (source of truth)
├── hooks/
│   ├── pre-commit                       ← Validates active ticket exists
│   ├── commit-msg                       ← Validates REQ reference in message
│   └── post-commit                      ← Records commit in history
└── scripts/
    ├── claim-ticket.sh                  ← Claim ticket for this worktree
    ├── release-ticket.sh                ← Release active ticket
    ├── get-active-ticket.sh             ← Read active ticket from state
    ├── validate-commit-msg.sh           ← Check REQ-xxx references
    └── suggest-req.sh                   ← Suggest REQ IDs for commit
```

### State Management

**Source of Truth**: `.git/WORKFLOW_STATE` (per-worktree JSON file)

**Why per-worktree?**
- Each worktree has independent state
- Multiple worktrees can work on same ticket (valid scenario)
- Multiple worktrees can work on different tickets
- State automatically cleaned up when worktree deleted

**Linear Integration**: Coordination layer only (not ownership lock)
- Linear ticket status = "In Progress" (informational)
- Multiple agents can set same ticket "In Progress" (valid)
- `.git/WORKFLOW_STATE` is the authoritative source for "this worktree is working on this ticket"

See [docs/workflow-state-schema.md](docs/workflow-state-schema.md) for complete state file specification.

### Workflow Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Claim Ticket                                             │
│    ./scripts/claim-ticket.sh CUR-262                        │
│    → Creates .git/WORKFLOW_STATE with activeTicket          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Work on Code                                             │
│    Edit files, stage changes                                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Attempt Commit                                           │
│    git commit -m "Implement feature\n\nImplements: REQ-xxx" │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Pre-Commit Hook Runs                                     │
│    ✅ Checks .git/WORKFLOW_STATE for active ticket          │
│    ❌ Blocks commit if no active ticket                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Commit-Msg Hook Runs                                     │
│    ✅ Validates REQ-xxx reference in message                │
│    ❌ Blocks commit if no REQ reference                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Commit Succeeds                                          │
│    Commit created with requirement traceability             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Post-Commit Hook Runs                                    │
│    → Appends commit to .git/WORKFLOW_STATE history          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Release Ticket (When Done)                               │
│    ./scripts/release-ticket.sh                              │
│    → Sets activeTicket = null in .git/WORKFLOW_STATE        │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Workflow

```bash
# 1. Claim a ticket
cd tools/anspar-marketplace/plugins/anspar-workflow
./scripts/claim-ticket.sh CUR-262

# Output:
# 📋 Claiming ticket: CUR-262
#    Worktree: /home/user/diary-worktrees/feature-xyz
#    Branch: feature-xyz
#    Agent: human
# ✅ Ticket claimed successfully!

# 2. Work on your changes
cd /home/user/diary-worktrees/feature-xyz
# ... edit files ...
git add .

# 3. Commit with REQ reference
git commit -m "Implement workflow plugin

This adds comprehensive workflow enforcement with per-worktree
state management and distributed ticket tracking.

Implements: REQ-d00027
"

# Output:
# ✅ Active ticket: CUR-262
# 📝 Updated workflow state history
# [feature-xyz abc123] Implement workflow plugin

# 4. When done with ticket
cd tools/anspar-marketplace/plugins/anspar-workflow
./scripts/release-ticket.sh "Work complete"

# Output:
# 📋 Releasing ticket: CUR-262
#    Reason: Work complete
# ✅ Ticket released successfully!
```

### Paused/Resumed Workflow

**Scenario**: You're working on ticket A, but need to pivot to ticket B (higher priority, blocker, short attention span, etc.), then later resume ticket A.

The workflow plugin supports this through **history-based ticket management**:

```bash
# 1. Working on ticket A
./scripts/claim-ticket.sh CUR-262
# ... work on feature A ...
git commit -m "Add authentication\n\nImplements: REQ-d00027"

# 2. Need to switch to ticket B (blocker)
./scripts/switch-ticket.sh CUR-263 "Blocked - waiting for review"

# Output:
# 🔄 Switching tickets...
# Current ticket: CUR-262
# New ticket: CUR-263
# Reason: Blocked - waiting for review
#
# 📋 Releasing current ticket...
# 📋 Claiming new ticket...
# ✅ Successfully switched to ticket CUR-263

# 3. Work on ticket B
# ... work on blocker ...
git commit -m "Fix blocker\n\nImplements: REQ-d00089"

# 4. Resume ticket A later
./scripts/resume-ticket.sh

# Output:
# 📋 Recently Released Tickets
#
# Select a ticket to resume:
#
#   1  CUR-262
#      Released: 2025-10-30 12:00
#      Reason: Switching to CUR-263: Blocked - waiting for review
#
#   2  CUR-260
#      Released: 2025-10-29 15:30
#      Reason: Work complete
#
# Enter number (1-2) or 'q' to quit: 1
#
# 📋 Resuming ticket: CUR-262
# ✅ Successfully resumed ticket CUR-262
```

**Key features**:
- ✅ History preserves all past tickets with reasons
- ✅ Interactive resume with recent ticket list
- ✅ Direct resume by ticket ID: `./scripts/resume-ticket.sh CUR-262`
- ✅ Full audit trail: `./scripts/list-history.sh`

### Common Workflow Patterns

#### Pattern 1: Blocked by Dependency

```bash
# Working on feature requiring API changes
./scripts/claim-ticket.sh CUR-262

# Realize API needs updating first
./scripts/switch-ticket.sh CUR-265 "Blocked - need API update first"

# Complete API update
# ... work on API ...
./scripts/release-ticket.sh "API update complete"

# Resume original feature
./scripts/resume-ticket.sh CUR-262
```

#### Pattern 2: Focus Pivot (ADHD-friendly)

```bash
# Start on ticket A
./scripts/claim-ticket.sh CUR-262

# Attention shifts to ticket B
./scripts/switch-ticket.sh CUR-263 "Focus pivot"

# Later, want to resume
./scripts/resume-ticket.sh
# Interactive selection shows recent tickets
```

#### Pattern 3: High Priority Interruption

```bash
# Working on planned feature
./scripts/claim-ticket.sh CUR-262

# Urgent bug reported
./scripts/switch-ticket.sh CUR-270 "P0 bug - production issue"

# Fix bug, release
./scripts/release-ticket.sh "Bug fixed"

# Resume planned work
./scripts/resume-ticket.sh CUR-262
```

#### Pattern 4: Multiple PRs for One Ticket

```bash
# Worktree 1: Initial implementation
cd ~/diary-worktrees/feature-auth
./scripts/claim-ticket.sh CUR-262
# ... implement core auth ...
git commit -m "Add auth core\n\nImplements: REQ-d00027"
# Create PR #1

# Worktree 2: Tests for same ticket
cd ~/diary-worktrees/feature-auth-tests
./scripts/claim-ticket.sh CUR-262  # Same ticket!
# ... write tests ...
git commit -m "Add auth tests\n\nImplements: REQ-d00027"
# Create PR #2

# Both worktrees working on CUR-262 - this is valid!
```

### Viewing History

```bash
# Full history
./scripts/list-history.sh

# Last 10 actions
./scripts/list-history.sh --limit=10

# Only claims
./scripts/list-history.sh --action=claim

# Only releases (shows paused tickets)
./scripts/list-history.sh --action=release

# JSON output for scripting
./scripts/list-history.sh --format=json
```

### Script Reference

#### claim-ticket.sh

Claims a ticket for this worktree.

```bash
./scripts/claim-ticket.sh <TICKET-ID> [AGENT-TYPE]

# Examples:
./scripts/claim-ticket.sh CUR-262
./scripts/claim-ticket.sh CUR-262 claude
```

**Arguments**:
- `TICKET-ID`: Ticket ID (e.g., CUR-262, PROJ-123)
- `AGENT-TYPE`: Agent type: `claude` or `human` (default: `human`)

**What it does**:
- Creates/updates `.git/WORKFLOW_STATE`
- Sets `activeTicket` with ticket ID and metadata
- Optionally fetches requirements from Linear (if available)
- Appends claim action to history

#### release-ticket.sh

Releases the active ticket for this worktree.

```bash
./scripts/release-ticket.sh [REASON]

# Examples:
./scripts/release-ticket.sh
./scripts/release-ticket.sh "Switching to different ticket"
./scripts/release-ticket.sh "Work blocked - need review"
```

**Arguments**:
- `REASON`: Optional reason for release (default: "Work complete")

**What it does**:
- Sets `activeTicket = null` in `.git/WORKFLOW_STATE`
- Appends release action to history
- Optionally adds Linear comment (if integration available)

#### get-active-ticket.sh

Retrieves the active ticket for this worktree.

```bash
./scripts/get-active-ticket.sh [--format=<FORMAT>]

# Formats:
#   --format=json     Output as JSON (default)
#   --format=id       Output only ticket ID
#   --format=reqs     Output only requirements array
#   --format=human    Output human-readable summary

# Examples:
./scripts/get-active-ticket.sh
./scripts/get-active-ticket.sh --format=id
./scripts/get-active-ticket.sh --format=reqs
```

**Exit codes**:
- `0`: Success (ticket found)
- `1`: No active ticket
- `2`: State file not found

#### validate-commit-msg.sh

Validates commit message contains REQ reference.

```bash
./scripts/validate-commit-msg.sh <COMMIT-MSG-FILE>
```

**Called by**: `commit-msg` git hook

**Exit codes**:
- `0`: Valid (REQ reference found)
- `1`: Invalid (no REQ reference)

#### suggest-req.sh

Suggests REQ IDs for commit message.

```bash
./scripts/suggest-req.sh

# Output:
# REQ-d00027
# REQ-p00042
```

**Suggestion sources**:
1. Active ticket in `.git/WORKFLOW_STATE`
2. Recent commits in this branch
3. Changed files (REQ references in file headers)

#### switch-ticket.sh

Switches from current ticket to a new ticket with automatic release/claim.

```bash
./scripts/switch-ticket.sh <NEW-TICKET-ID> <REASON>

# Examples:
./scripts/switch-ticket.sh CUR-263 "Blocked - waiting for review"
./scripts/switch-ticket.sh CUR-264 "Focus pivot to higher priority"
./scripts/switch-ticket.sh CUR-262 "Resuming previous work"
```

**Arguments**:
- `NEW-TICKET-ID`: Ticket ID to switch to
- `REASON`: Reason for pausing current ticket

**What it does**:
1. Releases current ticket (if any) with reason "Switching to <NEW-TICKET-ID>: <REASON>"
2. Claims new ticket
3. Shows recent activity history

#### resume-ticket.sh

Resumes a previously released ticket with interactive selection.

```bash
./scripts/resume-ticket.sh [TICKET-ID]

# Examples:
./scripts/resume-ticket.sh              # Interactive selection
./scripts/resume-ticket.sh CUR-262      # Resume specific ticket
```

**Arguments**:
- `TICKET-ID`: Optional - ticket ID to resume directly

**What it does**:
1. Shows recently released tickets from history (last 20)
2. Allows interactive selection or direct specification
3. Claims the selected ticket

**Interactive output**:
```
📋 Recently Released Tickets

Select a ticket to resume:

  1  CUR-262
      Released: 2025-10-30 12:00
      Reason: Blocked - waiting for review

  2  CUR-260
      Released: 2025-10-29 15:30
      Reason: Work complete

Enter number (1-2) or 'q' to quit:
```

#### list-history.sh

Lists workflow history for this worktree.

```bash
./scripts/list-history.sh [OPTIONS]

# Options:
#   --limit=N         Show only last N actions
#   --action=ACTION   Filter by: claim|release|commit
#   --format=FORMAT   Output: human|json

# Examples:
./scripts/list-history.sh
./scripts/list-history.sh --limit=10
./scripts/list-history.sh --action=claim
./scripts/list-history.sh --action=release
./scripts/list-history.sh --format=json
```

**What it shows**:
- All ticket claims (when work started)
- All ticket releases (when work paused/completed)
- All commits (with REQ references)

**Output format** (human-readable):
```
📜 Workflow History

[2025-10-30 12:00:00] ✓ CLAIM: CUR-262
[2025-10-30 12:15:00] ◆ COMMIT: CUR-262 - abc123
[2025-10-30 13:00:00] ○ RELEASE: CUR-262 - Blocked - waiting for review
[2025-10-30 13:05:00] ✓ CLAIM: CUR-263

Legend:
  ✓ CLAIM   - Ticket claimed for this worktree
  ○ RELEASE - Ticket released (paused/completed)
  ◆ COMMIT  - Commit created
```

### Multiple Worktrees

**Scenario**: Working on multiple features concurrently

```bash
# Worktree 1: Feature A
cd ~/diary-worktrees/feature-a
./tools/anspar-marketplace/plugins/anspar-workflow/scripts/claim-ticket.sh CUR-262
# Work on feature A...

# Worktree 2: Feature B (different ticket)
cd ~/diary-worktrees/feature-b
./tools/anspar-marketplace/plugins/anspar-workflow/scripts/claim-ticket.sh CUR-263
# Work on feature B...

# Worktree 3: Also feature A (same ticket as worktree 1)
cd ~/diary-worktrees/feature-a-fix
./tools/anspar-marketplace/plugins/anspar-workflow/scripts/claim-ticket.sh CUR-262
# Work on second PR for feature A...

# Each worktree has independent state!
```

**Valid scenarios**:
- ✅ Multiple worktrees on different tickets
- ✅ Multiple worktrees on same ticket (multiple PRs for one feature)
- ✅ Switching tickets within a worktree (release then claim)

**Invalid scenarios**:
- ❌ Committing without claiming a ticket
- ❌ Commit message without REQ reference

## Git Hooks

### pre-commit

**Enforces**: Active ticket must be claimed before commit

```bash
# Hook checks .git/WORKFLOW_STATE for activeTicket
# Blocks commit if activeTicket = null
```

**Error message**:
```
❌ ERROR: No active ticket claimed for this worktree

Before committing, claim a ticket:
  cd tools/anspar-marketplace/plugins/anspar-workflow
  ./scripts/claim-ticket.sh <TICKET-ID>
```

**Bypass** (not recommended):
```bash
git commit --no-verify
```

### commit-msg

**Enforces**: Commit message must contain REQ-xxx reference

```bash
# Hook validates commit message for REQ-{type}{number}
# Type: p (PRD), o (Ops), d (Dev)
# Number: 5 digits (e.g., 00042)
```

**Valid examples**:
```
Implements: REQ-p00042
Implements: REQ-d00027, REQ-o00015
Fixes: REQ-d00089
```

**Error message**:
```
❌ ERROR: Commit message must contain at least one requirement reference

Expected format: REQ-{type}{number}
  Type: p (PRD), o (Ops), d (Dev)
  Number: 5 digits (e.g., 00042)

Examples:
  Implements: REQ-p00042
  Implements: REQ-d00027, REQ-o00015
```

### post-commit

**Records**: Commit hash and REQ references in history

```bash
# Hook appends commit action to .git/WORKFLOW_STATE history
# Always succeeds (does not block commits)
```

**History entry**:
```json
{
  "action": "commit",
  "timestamp": "2025-10-30T12:15:00Z",
  "ticketId": "CUR-262",
  "details": {
    "commitHash": "abc123def456",
    "requirements": ["REQ-d00027"]
  }
}
```

## Configuration

### Workflow State Schema

See [docs/workflow-state-schema.md](docs/workflow-state-schema.md) for:
- Complete JSON schema
- State transitions
- Example state files
- Design principles
- Troubleshooting

### Tracker Integration

This plugin is designed to be tracker-agnostic. Linear integration is provided through the anspar-linear-integration plugin.

**Integration points**:
- `claim-ticket.sh`: Optionally fetch requirements from ticket tracker
- `release-ticket.sh`: Optionally add comment to ticket tracker
- `trackerMetadata` field in state: Extensible for different trackers

**Supported trackers** (future):
- Linear (via anspar-linear-integration)
- Notion (planned)
- Jira (planned)
- GitHub Issues (planned)

## Troubleshooting

### Error: No active ticket

**Cause**: Attempted commit without claiming a ticket

**Solution**:
```bash
cd tools/anspar-marketplace/plugins/anspar-workflow
./scripts/claim-ticket.sh <TICKET-ID>
```

### Error: No REQ reference in commit message

**Cause**: Commit message lacks REQ-xxx reference

**Solution**:
```bash
# Get suggestions
./scripts/suggest-req.sh

# Or manually add to commit message:
git commit -m "Your message

Implements: REQ-d00027
"
```

### State file corrupted

**Cause**: Manual editing or unexpected error

**Solution**:
```bash
# Backup and recreate
mv .git/WORKFLOW_STATE .git/WORKFLOW_STATE.bak
./scripts/claim-ticket.sh <TICKET-ID>
```

### Multiple worktrees confused

**Cause**: Not understanding per-worktree state

**Solution**:
```bash
# Check each worktree's state independently
cd /path/to/worktree1
./scripts/get-active-ticket.sh --format=human

cd /path/to/worktree2
./scripts/get-active-ticket.sh --format=human

# Each worktree has independent state - this is normal!
```

### jq command not found

**Cause**: jq not installed

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Or download from https://stedolan.github.io/jq/download/
```

## Integration

### With Other Plugins

This plugin works alongside:
- **anspar-linear-integration**: Provides Linear API integration
- **anspar-requirement-validation**: Validates requirement format
- **anspar-traceability-matrix**: Generates traceability matrices
- **anspar-spec-compliance**: Enforces spec/ directory compliance

### With CI/CD

This plugin enforces local workflow discipline. CI/CD should validate:
- All commits have REQ references (parse git log)
- All REQ references are valid (run requirement validation)
- All tickets referenced in PRs are tracked

**Example CI check**:
```yaml
- name: Validate Commit Messages
  run: |
    git log --oneline origin/main..HEAD | while read line; do
      if ! echo "$line" | grep -qE 'REQ-[pdo][0-9]{5}'; then
        echo "ERROR: Commit missing REQ reference: $line"
        exit 1
      fi
    done
```

## Advanced Usage

### Custom Ticket ID Patterns

Edit `claim-ticket.sh` to support different ticket ID formats:

```bash
# Current pattern: PROJECT-NUMBER (e.g., CUR-262)
if ! [[ "$TICKET_ID" =~ ^[A-Z]+-[0-9]+$ ]]; then

# Example: Support JIRA format (PROJ-123)
if ! [[ "$TICKET_ID" =~ ^[A-Z]{3,}-[0-9]+$ ]]; then
```

### Custom REQ Reference Patterns

Edit `validate-commit-msg.sh` to support different REQ formats:

```bash
# Current pattern: REQ-{type}{number} (e.g., REQ-d00027)
if echo "$COMMIT_MSG" | grep -qE 'REQ-[pdo][0-9]{5}'; then

# Example: Support different requirement IDs
if echo "$COMMIT_MSG" | grep -qE 'REQUIREMENT-[A-Z]{3}-[0-9]{4}'; then
```

### Scripting with Workflow State

```bash
# Get active ticket ID
TICKET=$(./scripts/get-active-ticket.sh --format=id)

# Get requirements for commit message
REQS=$(./scripts/suggest-req.sh | head -n 1)
git commit -m "My change

Implements: $REQS
"

# Check if ticket is active
if ./scripts/get-active-ticket.sh --format=id &>/dev/null; then
    echo "Ticket active"
else
    echo "No ticket"
fi
```

## Dependencies

- **Bash**: >=4.0
- **Git**: For hooks and worktree support
- **jq**: For JSON parsing (required)
- **Optional**: anspar-linear-integration for Linear API features

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

- **Workflow State Schema**: [docs/workflow-state-schema.md](docs/workflow-state-schema.md)
- **Requirement Format**: See spec/requirements-format.md in parent project
- **Linear Integration**: tools/anspar-marketplace/plugins/anspar-linear-integration
- **Claude Code Plugins**: https://docs.claude.com/en/docs/claude-code/plugins-reference

## Support

For issues, questions, or contributions:
- **Repository**: https://github.com/anspar/diary
- **Plugin Path**: `tools/anspar-marketplace/plugins/anspar-workflow`
