# Architecture: anspar-cc-plugins Marketplace

**Version**: 1.0.0
**Status**: Active
**Last Updated**: 2025-11-09

## Overview

The `anspar-cc-plugins` marketplace is a refactored plugin system designed to solve a critical limitation in the previous marketplace: **proper agent orchestration**. The core problem was that plugins lacked well-defined agent interfaces, causing the main orchestrating agent to bypass sub-agents and implement functionality directly, leading to unreliable behavior.

### Design Philosophy

1. **Orchestration First**: Main agent acts as coordinator, delegating to specialized sub-agents
2. **Agent Discoverability**: Every plugin exposes capabilities through properly-defined agents
3. **Clear Interfaces**: Agents specify tools, competencies, and invocation patterns
4. **Separation of Concerns**: Each plugin has single responsibility with clear boundaries

## Marketplace Structure

```
tools/anspar-cc-plugins/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace manifest
├── plugins/                       # Individual plugins
│   └── plugin-name/
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin manifest
│       ├── agents/               # Sub-agents (REQUIRED for most plugins)
│       │   └── AgentName.md      # YAML frontmatter + markdown
│       ├── commands/             # User-facing slash commands
│       ├── hooks/                # Event hooks
│       ├── skills/               # Agent-invoked automation
│       ├── scripts/              # Implementation logic
│       └── README.md
├── shared/                       # Cross-plugin utilities
│   ├── scripts/                  # Common bash/Python scripts
│   ├── validators/               # Schema validation
│   └── templates/                # Plugin scaffolding
├── hooks/                        # Marketplace-level hooks
│   ├── hooks.json
│   └── session-start
└── docs/                         # Architecture documentation
```

### Directory Organization Rationale

**plugins/**: Isolated plugin directories following Claude Code plugin spec
- Each plugin is self-contained
- No direct dependencies between plugins
- Cross-plugin coordination via orchestrator pattern

**shared/**: Common utilities used by multiple plugins
- Avoids code duplication
- CI/CD scripts can live here or in tools/requirements/
- Validators ensure consistent quality

**hooks/**: Marketplace-level hooks that run before plugin hooks
- SessionStart: Configure CLAUDE.md for orchestration
- Can add marketplace-wide policies

## Agent Orchestration Patterns

### The Problem (Old Marketplace)

```
User: "Create a Linear ticket for REQ-p00042"

Main Agent:
  ❌ Directly implements ticket creation
  ❌ Parses requirement ID inline
  ❌ Formats ticket description with ad-hoc code
  ❌ Writes 50+ lines of inline implementation

Result: Unreliable, non-reusable, error-prone
```

### The Solution (New Marketplace)

```
User: "Create a Linear ticket for REQ-p00042"

Main Agent (Orchestrator):
  1. Recognizes: This needs requirement info + ticket creation
  2. Checks /agents: Sees simple-requirements:simple-requirements and linear-api:linear-api
  3. Delegates:
     - simple-requirements:simple-requirements → Fetch REQ-p00042 details
     - linear-api:linear-api → Create ticket with details
  4. Reports: Success with ticket URL

Result: Reliable, reusable, maintainable
```

### Agent Definition Requirements

Every plugin agent MUST have YAML frontmatter:

```yaml
---
name: agent-name
description: Clear, concise description of agent's purpose
tools: Read, Write, Bash, Grep  # Optional: specific tools only
---
```

**Why this matters**:
- `name`: Unique identifier for orchestrator to invoke
- `description`: Helps orchestrator decide when to use agent
- `tools`: Constrains agent capabilities (omit for full access)

### Communication Patterns

**1. Main Agent → Sub-Agent** (Primary pattern)
```
Main Agent invokes via Task tool:
  Task(subagent_type="plugin-name:agent-name", prompt="...")
```

**2. Sub-Agent → Skills** (Preferred implementation)
```
Agent reads YAML frontmatter → knows available skills
Agent invokes: bash plugin/skills/do-thing.skill --param=value
```

**3. Sub-Agent → Scripts** (Direct invocation)
```
Agent invokes: node ${CLAUDE_PLUGIN_ROOT}/scripts/script.js --args
```

**4. Cross-Plugin Communication** (Orchestrator pattern)
```
PluginA Agent does NOT directly call PluginB
Instead:
  PluginA Agent reports back to Main Agent
  Main Agent decides if PluginB needed
  Main Agent invokes PluginB Agent
```

### When to Delegate vs. Implement

**Delegate to Sub-Agent When**:
- Task matches a plugin's domain (tickets, requirements, workflow)
- Multiple steps requiring domain expertise
- External API calls or complex operations
- Reusable functionality across sessions

**Implement Directly When**:
- Simple file read/write operations
- One-off transformations
- User clarification questions
- Basic git operations (unless workflow-specific)

## Plugin Interaction Model

### Independence Principle

Plugins are **independently deployable** and **loosely coupled**:
- Plugin A does NOT import Plugin B's code
- Plugin A does NOT directly invoke Plugin B's scripts
- Plugin A CAN invoke bash commands that happen to use Plugin B's public scripts

### Shared State Management

**Per-Plugin State**:
```bash
# Each plugin manages its own state
.git/WORKFLOW_STATE           # workflow plugin
.requirement-cache.json       # requirement-traceability plugin
.claude-cache/linear/         # linear-api plugin
```

**Cross-Plugin State** (Orchestrator responsibility):
```bash
# Main agent coordinates state across plugins
1. Workflow plugin claims ticket → updates .git/WORKFLOW_STATE
2. Main agent reads ticket ID from state
3. Main agent passes ticket ID to requirement plugin
```

### Cross-Plugin Coordination

**Anti-Pattern** (Old marketplace):
```bash
# workflow/scripts/do-thing.sh
source ../requirement-traceability/scripts/helper.sh  # ❌ Direct coupling
```

**Correct Pattern** (New marketplace):
```bash
# workflow/scripts/do-thing.sh
SHARED_VALIDATOR="tools/anspar-cc-plugins/shared/validators/req-format.sh"
source "$SHARED_VALIDATOR"  # ✅ Via shared utilities

# OR invoke other plugin's public script as external command
bash tools/anspar-cc-plugins/plugins/requirements/scripts/parse-req.sh  # ✅ Public API
```

## Shared Utilities Architecture

### Organization

```
shared/
├── scripts/              # Common bash/Python utilities
│   ├── json-helper.sh
│   ├── path-resolver.sh
│   └── error-handlers.sh
├── validators/           # Schema and format validators
│   ├── plugin-json.schema
│   ├── req-format-validator.sh
│   └── ticket-format-validator.sh
└── templates/            # Plugin scaffolding
    ├── basic-plugin/
    ├── agent-plugin/
    └── hook-plugin/
```

### When to Use Shared vs. Plugin-Specific

**Move to shared/** when:
- ✅ Used by 2+ plugins
- ✅ No plugin-specific business logic
- ✅ Pure utility function
- ✅ CI/CD needs it

**Keep in plugin/** when:
- ✅ Single plugin uses it
- ✅ Contains domain-specific logic
- ✅ Tightly coupled to plugin's purpose

### Validator Design

Validators follow a standard pattern:

```bash
#!/bin/bash
# validators/something-validator.sh

# Input: File path or stdin
# Output: 0 (valid) or 1 (invalid) + error messages to stderr
# Contract: Machine-parseable error format

validate_something() {
  local input="$1"
  # Validation logic
  if [[ ! condition ]]; then
    echo "ERROR: Specific issue at line X" >&2
    return 1
  fi
  return 0
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  validate_something "$1"
fi
```

### Template System

Templates provide scaffolding for new plugins:

```
templates/
├── basic-plugin/         # Minimal plugin (commands only)
├── agent-plugin/         # Plugin with sub-agent (most common)
└── hook-plugin/          # Plugin with hooks (workflow-style)
```

**Template Contents**:
- Directory structure
- Placeholder plugin.json
- Example agent with YAML frontmatter
- README template
- Test structure

## Hook Execution Lifecycle

### Marketplace-Level Hooks

Run **before** plugin hooks:

```
Session Start:
  1. marketplace/hooks/session-start (configure CLAUDE.md)
  2. plugin-a/hooks/session-start
  3. plugin-b/hooks/session-start
```

### Plugin-Level Hooks

Multiple hooks can trigger on same event:

```
UserPromptSubmit:
  1. workflow plugin detects task switches
  2. spec-compliance plugin checks for spec/ modifications
  3. Each hook gets context + can add warnings
```

### Hook Types and Use Cases

**SessionStart**:
- Configure project environment
- Check for missing dependencies
- Display important reminders

**UserPromptSubmit**:
- Detect context changes (task switching)
- Proactive guidance ("You might want to...")
- Non-blocking warnings

**PreToolUse**:
- Validate preconditions before Write/Edit
- Enforce policies (e.g., "claim ticket before editing")
- Can block if critical

**PostToolUse**:
- Suggest next steps after operations
- Update caches or state
- Offer automated follow-ups

## CI/CD Integration

### GitHub Actions Integration

Plugins can be validated in CI:

```yaml
# .github/workflows/plugin-validation.yml
- name: Validate Plugins
  run: |
    for plugin in tools/anspar-cc-plugins/plugins/*/; do
      bash tools/anspar-cc-plugins/shared/validators/validate-plugin.sh "$plugin"
    done
```

### Requirement Validation

Requirement validation and traceability generation now uses the `elspais` CLI:
- `elspais validate` - Validate requirement format, links, hashes
- `elspais trace` - Generate traceability matrices
- `elspais hash verify/update` - Manage requirement hashes
- `elspais index` - Validate or regenerate INDEX.md
- `elspais analyze` - Hierarchy, orphans, and coverage analysis

Install with: `pip install elspais`
Configuration: `.elspais.toml` in repository root

### Plugin Testing Framework

Each plugin includes `tests/` directory:

```
plugin/tests/
├── test.sh               # Main test runner
├── unit/                 # Unit tests for scripts
└── integration/          # End-to-end tests
```

## Design Principles Summary

1. **Orchestration First**: Main agent coordinates, sub-agents execute
2. **Agent Discoverability**: Every plugin capability exposed via well-defined agents
3. **Loose Coupling**: Plugins interact via orchestrator or shared utilities
4. **Single Responsibility**: Each plugin has one clear purpose
5. **Shared When Useful**: Extract common patterns, keep domain logic in plugins
6. **Idempotent Hooks**: Safe to run multiple times, non-destructive
7. **Documentation-Driven**: Every pattern documented, every plugin follows standards

## References

- [Claude Code Plugin Documentation](https://code.claude.com/docs/en/plugins)
- [Sub-Agent Configuration Guide](https://code.claude.com/docs/en/sub-agents)
- [Plugin Marketplace Schema](https://code.claude.com/docs/en/plugin-marketplaces)
- [Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
