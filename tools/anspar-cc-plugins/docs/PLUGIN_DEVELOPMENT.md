# Plugin Development Guide

**Version**: 1.0.0
**Status**: Active
**Last Updated**: 2025-11-09

## Overview

This guide explains how to create plugins for the `anspar-cc-plugins` marketplace using the **2-phase plugin creation workflow**. This approach ensures plugins have proper agent definitions for reliable orchestration.

## Plugin Creation Workflow

### The 2-Phase Approach

The new marketplace uses a **two-phase workflow** designed to create plugins with robust agent orchestration:

```
Phase 1: Create Agent Definition (User + /agent command)
    ↓
Phase 2: Build Plugin Around Agent (plugin-wizard)
    ↓
Result: Complete plugin with proper orchestration
```

### Phase 1: Create Agent Definition

**Who**: User (with Claude Code's `/agent` command)
**Goal**: Define the agent's purpose, capabilities, and interface

**Process**:

1. **Describe your plugin's purpose** to `/agent`:
   ```
   /agent Create an agent for [DOMAIN] that can [CAPABILITIES]
   ```

2. **Append plugin boilerplate** to your description:
   ```
   The agent will be used in a marketplace plugin.

   Describe that agent as if it had access to claude code plugin skills
   that would streamline its common operations. Very briefly describe
   the capabilities of those skills.

   Describe the agent as if it knew about the appropriate hooks included
   in the plugin. It knows when the hooks will be triggered and what it
   will do when informed that each hook is triggered.

   The agent also knows which slash commands the plugin provides for
   the user to do common operations directly without invoking the agent.
   Example: /command-name ARGS
   ```

3. **Review the generated agent definition**:
   - Check the agent's competencies
   - Verify skill descriptions make sense
   - Ensure hook triggers are appropriate
   - Confirm slash commands align with user workflows

**Example**:

```
/agent Create an agent for managing Linear tickets that can fetch ticket
details, create new tickets, update ticket status, and search tickets.

The agent will be used in a marketplace plugin.

Describe that agent as if it had access to claude code plugin skills:
- fetch-tickets.skill: Fetch ticket details by ID
- create-ticket.skill: Create new ticket with title and description
- update-ticket.skill: Update ticket status or description
- search-tickets.skill: Search tickets by keyword

The agent knows about these hooks:
- SessionStart: Check LINEAR_API_TOKEN is configured
- UserPromptSubmit: Detect when user mentions ticket IDs

The agent knows these slash commands:
- /linear:fetch TICKET-ID: Quick ticket lookup
- /linear:create: Interactive ticket creation
```

### Phase 2: Build Plugin with plugin-wizard

**Who**: plugin-wizard tool (coming soon)
**Goal**: Create complete plugin structure around the agent

**Process**:

1. **plugin-wizard locates marketplace**:
   - Searches for `tools/*/marketplace.json`
   - Finds `tools/anspar-cc-plugins/`

2. **Creates plugin scaffold**:
   ```
   plugins/your-plugin/
   ├── .claude-plugin/
   │   └── plugin.json
   ├── agents/
   │   └── YourAgent.md      # Copies agent from Phase 1
   ├── commands/             # Based on agent's slash commands
   ├── hooks/                # Based on agent's hook knowledge
   ├── skills/               # Based on agent's skill descriptions
   ├── scripts/              # Implementation for skills
   ├── tests/
   └── README.md
   ```

3. **Analyzes agent definition**:
   - Reads YAML frontmatter and markdown
   - Identifies needed skills from agent's description
   - Determines appropriate hooks
   - Plans script implementations

4. **Creates plugin elements**:
   - **Skills**: Thin wrappers calling scripts
   - **Hooks**: Event handlers based on agent's knowledge
   - **Commands**: User-facing slash commands
   - **Scripts**: Core implementation logic

5. **Updates marketplace**:
   - Adds plugin to `marketplace.json`
   - Validates plugin structure
   - Runs initial tests

**Design Principles plugin-wizard Follows**:

- **Single-purpose scripts**: Each script does one thing well
- **Separation of concerns**: Skills wrap scripts, hooks trigger actions
- **Cross-plugin awareness**: Can use other plugins' public scripts
- **Command-line options**: Scripts accept parameters, not hard-coded

## Agent Development Best Practices

### YAML Frontmatter Requirements

Every agent **MUST** have YAML frontmatter:

```yaml
---
name: agent-name
description: Clear, concise description of what this agent does
tools: Read, Write, Bash, Grep  # Optional: omit for all tools
---
```

**Field Guidelines**:

**name** (required):
- Lowercase with hyphens (kebab-case)
- Unique within marketplace
- Matches plugin naming pattern
- Example: `linear-api-agent`, `requirement-validator`

**description** (required):
- 1-2 sentences max
- Focus on **what** the agent does, not **how**
- Helps orchestrator decide when to invoke
- Example: "Manages Linear ticket operations including fetch, create, and update"

**tools** (optional):
- Comma-separated list of specific tools
- Omit to inherit all available tools (including MCP)
- Constrain when agent should only use specific tools
- Example: `tools: Read, Bash, Grep` (no Write access)

### Prompt Design Patterns

**Structure your agent markdown in sections**:

```markdown
---
name: my-agent
description: One-sentence summary
---

# Agent Name

Brief overview of agent's purpose.

## Core Capabilities

Bullet list of what agent can do.

## Available Skills

Table of skills with:
- Skill name
- Command to invoke
- Purpose
- Example usage

## Hook Awareness

Explain which hooks this plugin has and when they trigger.

## Slash Commands

List user-facing commands provided by plugin.

## Error Handling

How agent should respond to common errors:
- Missing API keys → Report to user, don't work around
- Validation failures → Show error, suggest fix
- External service down → Inform user, exit cleanly
```

**Key Patterns**:

✅ **Agent knows about skills**: Document every skill with invocation syntax
✅ **Agent knows about hooks**: Explain hook triggers and agent's response
✅ **Agent knows about commands**: List user commands to avoid reimplementing
✅ **Agent exits on blockers**: API key missing? Stop and inform user
✅ **Agent delegates cross-plugin**: Use orchestrator for other plugins

❌ **Agent implements inline**: Avoid 50+ lines of bash/python in agent
❌ **Agent works around errors**: Missing dependencies? Inform user
❌ **Agent assumes state**: Always check preconditions explicitly

### Tool Integration

**Constrained tool access** (when to use `tools` field):

```yaml
---
name: read-only-agent
description: Analyzes code without making changes
tools: Read, Grep, Glob  # No Write, Edit, or Bash
---
```

**Full tool access** (omit `tools` field):

```yaml
---
name: full-access-agent
description: Complete development workflow automation
# tools field omitted = all tools available
---
```

### Error Handling Principles

**CRITICAL: Agents must follow the Failure Visibility Principle**

When skills fail, agents must:

1. **Report error with full context**:
   ```
   ❌ Skill 'fetch-tickets' failed

   Error: LINEAR_API_TOKEN environment variable not set

   I invoked: bash skills/fetch-tickets.skill --id=CUR-240

   Output:
   [paste full error output]
   ```

2. **Explain possible causes**:
   ```
   Possible causes:
   1. LINEAR_API_TOKEN not configured in environment
   2. Token expired
   3. Linear API service down
   ```

3. **Suggest resolution**:
   ```
   To fix:
   export LINEAR_API_TOKEN="your_token_here"

   Get token from: https://linear.app/settings/api
   ```

4. **NEVER work around failures**:
   - ❌ "Let me try a different approach"
   - ❌ "I'll implement this manually"
   - ✅ "I cannot proceed without LINEAR_API_TOKEN being set"

## Skills Development

### Skills as Thin Wrappers

Skills are **bash wrappers** around scripts:

```bash
#!/bin/bash
# skills/do-thing.skill

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Call the actual implementation script
bash "$SCRIPT_DIR/scripts/do-thing.sh" "$@"
```

**Why?**
- Agent-friendly invocation: `bash skills/do-thing.skill --param=value`
- Single source of truth: Script is the implementation
- Testable: Scripts can be tested independently
- Reusable: Scripts can be called by hooks, commands, or other plugins

### Skills vs. Scripts

| Aspect | Skills | Scripts |
|--------|--------|---------|
| **Purpose** | Agent interface | Implementation |
| **Location** | `skills/` | `scripts/` |
| **Complexity** | Thin wrapper (2-5 lines) | Full logic |
| **Invoked by** | Agent via Bash tool | Skills, hooks, commands |
| **Parameters** | Pass-through | Parse and validate |
| **Testing** | Via integration tests | Unit + integration tests |

### Skill Naming Conventions

```
skills/
├── fetch-thing.skill      # Retrieval operations
├── create-thing.skill     # Creation operations
├── update-thing.skill     # Modification operations
├── delete-thing.skill     # Deletion operations
├── list-things.skill      # List/search operations
└── validate-thing.skill   # Validation operations
```

## Hook Development

### Hook Types and Use Cases

**SessionStart**:
```bash
# hooks/session-start
#!/bin/bash

# Check preconditions
if [ -z "$REQUIRED_ENV_VAR" ]; then
  echo "⚠️  Plugin requires REQUIRED_ENV_VAR" >&2
  exit 0  # Non-blocking warning
fi

# Initialize cache
mkdir -p .claude-cache/my-plugin

# Display reminder
echo "📦 my-plugin loaded"
```

**UserPromptSubmit**:
```bash
# hooks/user-prompt-submit
#!/bin/bash

# Read user prompt from stdin
USER_PROMPT=$(cat)

# Detect relevant patterns
if echo "$USER_PROMPT" | grep -qi "create ticket"; then
  echo "💡 TIP: Use /ticket:create for guided ticket creation" >&2
fi

exit 0  # Always non-blocking
```

**PreToolUse**:
```bash
# hooks/pre-tool-use
#!/bin/bash

# Get tool name and parameters from environment
TOOL_NAME="$CLAUDE_TOOL_NAME"

# Validate preconditions before Write/Edit
if [[ "$TOOL_NAME" =~ ^(Write|Edit)$ ]]; then
  if [ ! -f .git/ACTIVE_TICKET ]; then
    echo "❌ ERROR: Claim a ticket before editing files" >&2
    exit 1  # Block the operation
  fi
fi

exit 0  # Allow operation
```

**PostToolUse**:
```bash
# hooks/post-tool-use
#!/bin/bash

TOOL_NAME="$CLAUDE_TOOL_NAME"

# Suggest next steps after git commit
if [[ "$TOOL_NAME" == "Bash" ]] && echo "$CLAUDE_TOOL_INPUT" | grep -q "git commit"; then
  echo "💡 Next: Consider running tests or creating a PR" >&2
fi

exit 0  # Always non-blocking
```

### Hook Best Practices

✅ **Non-blocking warnings**: Use SessionStart and UserPromptSubmit for guidance
✅ **Blocking only when critical**: PreToolUse can block for safety
✅ **Exit 0 for warnings**: Non-zero exits log errors but don't stop session
✅ **Stderr for messages**: Use stderr so stdout remains clean
✅ **Fast execution**: Hooks should complete in <100ms
✅ **Idempotent**: Safe to run multiple times

❌ **Don't perform heavy operations**: No API calls in hooks
❌ **Don't modify files**: Hooks observe, don't change state
❌ **Don't assume context**: Check preconditions explicitly

### Hook Configuration

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start",
            "blocking": false,
            "timeout": 5000
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/user-prompt-submit",
            "blocking": false
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-use",
            "blocking": true
          }
        ]
      }
    ]
  }
}
```

## Command Development

### Slash Command Structure

Commands are **markdown files** with optional frontmatter:

```markdown
---
name: command-name
description: What this command does
---

# Command: /plugin:command-name

## Purpose

One-sentence description.

## Usage

/plugin:command-name [OPTIONS] ARGS

## Implementation

The agent should use the following skills to implement this command:

1. Validate input using validate-input.skill
2. Perform action using do-action.skill
3. Report results to user

## Examples

/plugin:command-name --option value ARG1 ARG2
```

### Command Naming Conventions

```
commands/
├── create.md          # /plugin:create
├── fetch.md           # /plugin:fetch
├── update.md          # /plugin:update
└── list.md            # /plugin:list
```

**Qualified names**: `/plugin-name:command-name`
**Example**: `/workflow:claim`, `/linear:fetch`, `/requirements:validate`

### Command vs. Agent Invocation

**Use slash commands when**:
- User wants direct, quick action
- Operation is straightforward
- No complex decision-making needed
- Example: `/linear:fetch CUR-240` (just fetch, no analysis)

**Use agent invocation when**:
- Complex decision-making required
- Multiple steps with dependencies
- Context analysis needed
- Example: "Analyze these tickets and prioritize them"

## Testing Plugins

### Test Structure

```
tests/
├── test.sh                 # Main test runner
├── unit/                   # Unit tests for scripts
│   ├── test-script-a.sh
│   └── test-script-b.sh
├── integration/            # Integration tests
│   ├── test-skills.sh
│   └── test-hooks.sh
└── fixtures/               # Test data
    ├── valid-input.json
    └── invalid-input.json
```

### Test Runner Pattern

```bash
#!/bin/bash
# tests/test.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Running unit tests..."
for test in "$SCRIPT_DIR/unit"/*.sh; do
  echo -n "  $(basename "$test")... "
  if bash "$test"; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${RED}FAIL${NC}"
    exit 1
  fi
done

echo "Running integration tests..."
for test in "$SCRIPT_DIR/integration"/*.sh; do
  echo -n "  $(basename "$test")... "
  if bash "$test"; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${RED}FAIL${NC}"
    exit 1
  fi
done

echo -e "${GREEN}All tests passed!${NC}"
```

### Unit Test Example

```bash
#!/bin/bash
# tests/unit/test-parse-req.sh

# Source the script (don't execute)
source "$(dirname "$0")/../../scripts/parse-req.sh" || exit 1

# Test valid REQ format
test_valid_req() {
  result=$(parse_req_id "REQ-d00027")
  [ "$result" == "d00027" ] || {
    echo "Expected 'd00027', got '$result'"
    return 1
  }
}

# Test invalid REQ format
test_invalid_req() {
  result=$(parse_req_id "INVALID" 2>/dev/null)
  [ -z "$result" ] || {
    echo "Expected empty result for invalid input"
    return 1
  }
}

# Run tests
test_valid_req || exit 1
test_invalid_req || exit 1

exit 0
```

## Documentation Requirements

### README.md Structure

Every plugin MUST have a comprehensive README:

```markdown
# Plugin Name

One-sentence description.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

Installed automatically as part of anspar-cc-plugins marketplace.

## Configuration

Required environment variables:
- `API_TOKEN`: Description (get from: URL)

Optional configuration:
- `CACHE_DIR`: Where to store cache (default: `.claude-cache/plugin`)

## Usage

### Via Agent

Describe when the main orchestrator will automatically invoke this plugin.

### Via Slash Commands

/plugin:command1 ARGS - Description
/plugin:command2 ARGS - Description

### Via Skills (for other plugins)

bash plugins/my-plugin/skills/skill-name.skill --args

## Examples

### Example 1: Common Use Case

Description of scenario.

User: "Do something"

Agent: Uses MyAgent to...

Result: Output description

### Example 2: Another Use Case

...

## Architecture

Brief explanation of plugin design:
- Agent: Role and capabilities
- Skills: List with purposes
- Hooks: What they detect and do
- Scripts: Core implementations

## Testing

bash tests/test.sh

## Troubleshooting

### Error: Common Issue

**Cause**: Explanation
**Fix**: Solution

## Contributing

See main marketplace CONTRIBUTING.md

## License

MIT
```

## Publishing to Marketplace

### Pre-Publication Checklist

- [ ] plugin.json validates (use shared/validators/)
- [ ] Agent has YAML frontmatter (name, description)
- [ ] All skills have corresponding scripts
- [ ] Hooks are non-blocking unless critical
- [ ] Tests pass (`bash tests/test.sh`)
- [ ] README is complete
- [ ] No secrets in code (API keys must be env vars)
- [ ] Cross-plugin dependencies documented

### Version Management

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
- **MINOR** (1.0.0 → 1.1.0): New features, backward compatible
- **PATCH** (1.0.0 → 1.0.1): Bug fixes

Update these files when versioning:
- `plugin.json` → `version` field
- `README.md` → Version badge or changelog
- `CHANGELOG.md` → Document changes

### Marketplace Submission

1. **Validate plugin**:
   ```bash
   bash tools/anspar-cc-plugins/shared/validators/validate-plugin.sh plugins/my-plugin
   ```

2. **Add to marketplace.json**:
   ```json
   {
     "plugins": [
       {
         "name": "my-plugin",
         "source": "./plugins/my-plugin",
         "description": "One-sentence description",
         "version": "1.0.0"
       }
     ]
   }
   ```

3. **Test marketplace**:
   ```bash
   # Reload Claude Code to pick up new plugin
   # Verify agent appears in /agents
   # Test slash commands
   # Verify hooks trigger appropriately
   ```

4. **Document in marketplace README**

## Core Principles Summary

### Hooks as Workflow Bumpers
- Proactive guidance (not reactive blocking)
- User maintains control
- Non-blocking warnings preferred

### Skills as Thin Wrappers
- Wrap bash scripts with simple interface
- Agent knows when to use each skill
- Goal: No trial-and-error by agent

### Domain Documentation Caching
- Cache docs locally for quick reference
- Agent consults official docs via skills
- Never hard-code documentation in prompts

### API Key Management
- Always use environment variables
- Never work around missing keys
- Inform user and stop if keys missing

### Cross-Plugin Awareness
- Plugins know about each other
- Guide orchestrator on using them together
- Can invoke other plugins' public scripts

## References

- [Architecture Documentation](./ARCHITECTURE.md)
- [Orchestration Patterns](./ORCHESTRATION.md)
- [Plugin Migration Guide](./MIGRATION.md)
- [Claude Code Plugin Reference](https://code.claude.com/docs/en/plugins-reference)
