# Plugin Wizard

Builds complete Claude Code plugins around user-defined agents using a 2-phase workflow.

## Features

- **2-Phase Plugin Creation**: Separate agent design (Phase 1) from plugin infrastructure (Phase 2)
- **Automatic Component Generation**: Creates skills, hooks, commands, tests, and documentation
- **Thin Skill Wrappers**: Skills delegate to scripts for clean separation of concerns
- **Proactive Hooks**: Generates workflow bumpers for proactive user guidance
- **Cross-Plugin Awareness**: Can leverage scripts from other marketplace plugins
- **Comprehensive Documentation**: Auto-generates README with usage examples

## Installation

Installed automatically as part of the `anspar-cc-plugins` marketplace.

```bash
# Verify installation
claude-code plugin list

# Check agent available
/agents
# Should show: plugin-wizard
```

## The 2-Phase Workflow

### Why 2 Phases?

**Problem**: Creating agents and plugin infrastructure together is complex and error-prone.

**Solution**: Separate concerns:
1. **Phase 1**: User focuses on agent design (expertise, capabilities)
2. **Phase 2**: Wizard builds infrastructure (skills, hooks, tests)

This ensures:
- Agents have proper YAML frontmatter for orchestration
- Plugin structure follows best practices
- Skills match agent's documented capabilities
- Hooks align with agent's knowledge

### Phase 1: Create Agent Definition

**User does this** using Claude Code's `/agent` command.

#### Step 1: Describe Your Domain

Think about:
- What expertise does the agent provide?
- What operations should be streamlined with skills?
- What proactive guidance should hooks provide?
- What slash commands would be useful?

#### Step 2: Run /agent with Plugin Boilerplate

```
/agent Create an agent for [DOMAIN] that can [CAPABILITIES]

The agent will be used in a marketplace plugin.

Describe the agent as if it had access to claude code plugin skills
that would streamline its common operations. Briefly describe
the capabilities of those skills.

The agent knows about these hooks:
- SessionStart: [what it does]
- UserPromptSubmit: [what it detects]

The agent knows these slash commands:
- /plugin:command: [what it does]
```

#### Example Phase 1 Prompt

```
/agent Create an agent for managing Linear tickets that can fetch ticket
details, create new tickets, update ticket status, and search tickets.

The agent will be used in a marketplace plugin.

Describe the agent as if it had access to these claude code plugin skills:
- fetch-tickets.skill: Fetch ticket details by ID or label
- create-ticket.skill: Create new ticket with title and description
- update-ticket.skill: Update ticket status or description
- search-tickets.skill: Search tickets by keyword

The agent knows about these hooks:
- SessionStart: Check LINEAR_API_TOKEN environment variable is configured
- UserPromptSubmit: Detect when user mentions ticket IDs (CUR-XXX pattern)

The agent knows these slash commands:
- /linear:fetch TICKET-ID: Quick ticket lookup without full agent invocation
- /linear:create: Interactive ticket creation wizard
```

#### Step 3: Review Generated Agent

Claude Code's `/agent` command will create an agent file. Review it for:
- ✅ YAML frontmatter present (name, description)
- ✅ Skills are clearly described
- ✅ Hooks are documented
- ✅ Commands are listed

### Phase 2: Build Plugin with plugin-wizard

**plugin-wizard does this** when you run `/create-plugin`.

#### Step 1: Run create-plugin Command

```
/create-plugin /path/to/your-agent.md
```

#### Step 2: plugin-wizard Works

plugin-wizard will:

1. **Locate marketplace** by searching for `tools/*/marketplace.json`
2. **Analyze agent definition**:
   - Parse YAML frontmatter
   - Extract skill descriptions
   - Identify hooks
   - Find slash commands
3. **Create plugin scaffold**:
   - Directory structure
   - Basic plugin.json
   - Copy agent file
4. **Generate skills**:
   - Thin wrappers (2-5 lines)
   - Implementation scripts (TODO templates)
5. **Generate hooks**:
   - Based on agent's hook knowledge
   - Non-blocking by default
6. **Generate commands**:
   - Slash command markdown files
7. **Create tests**:
   - Basic test runner
   - Validation tests
8. **Generate README**:
   - Feature list
   - Usage examples
   - Skills documentation
9. **Update marketplace.json**:
   - Register new plugin

#### Step 3: Reload Claude Code

**CRITICAL**: Claude Code caches plugins at startup.

```
1. Exit Claude Code
2. Restart Claude Code
3. Verify: /agents (should show your new agent)
```

#### Step 4: Customize Generated Code

plugin-wizard creates templates with TODO markers:

```bash
# Example generated script
echo "TODO: Implement skill logic here"
exit 1
```

**You must**:
1. Implement TODO items in scripts
2. Add proper error handling
3. Write tests for your implementations
4. Update README with specifics
5. Test thoroughly before using

## Usage

### Via Slash Command

```
/create-plugin AGENT_PATH [OPTIONS]
```

**Arguments:**
- `AGENT_PATH`: Path to agent file from Phase 1

**Options:**
- `--marketplace-path=PATH`: Specify marketplace (auto-detected by default)
- `--plugin-name=NAME`: Override plugin name (defaults to agent name)

### Via Agent Invocation

```
User: Create a plugin from this agent: /path/to/my-agent.md

plugin-wizard: [analyzes agent and builds plugin]
```

## Available Skills

All skills are invoked via Bash tool:

### locate-marketplace
```bash
bash skills/locate-marketplace.skill
```
**Purpose**: Find marketplace by searching for `tools/*/marketplace.json`
**Returns**: Marketplace directory path
**Example Output**: `/home/user/project/tools/anspar-cc-plugins`

### analyze-agent
```bash
bash skills/analyze-agent.skill --agent-path=/path/to/agent.md
```
**Purpose**: Parse agent markdown and extract components
**Returns**: JSON with frontmatter, skills, hooks, commands
**Example Output**:
```json
{
  "frontmatter": {
    "name": "my-agent",
    "description": "Agent description"
  },
  "skills": [
    {"name": "fetch-data", "description": "Fetch data from API"}
  ],
  "hooks": [
    {"type": "SessionStart", "description": "Check environment"}
  ],
  "commands": [
    {"name": "plugin:fetch", "description": "Quick fetch"}
  ]
}
```

### create-scaffold
```bash
bash skills/create-scaffold.skill \
  --plugin-name=my-plugin \
  --marketplace-path=/path/to/marketplace \
  --agent-path=/path/to/agent.md
```
**Purpose**: Create plugin directory structure
**Creates**:
- `.claude-plugin/plugin.json`
- `agents/`, `commands/`, `skills/`, `scripts/`, `hooks/`, `tests/`
- Basic test runner

### generate-skills
```bash
bash skills/generate-skills.skill \
  --plugin-path=/path/to/plugin \
  --skills-json='[{"name":"fetch","description":"Fetch data"}]'
```
**Purpose**: Generate skill wrappers and implementation scripts
**Creates**:
- `skills/fetch.skill` (thin wrapper)
- `scripts/fetch.sh` (implementation template)
- Updates `plugin.json` with skill definitions

### generate-hooks
```bash
bash skills/generate-hooks.skill \
  --plugin-path=/path/to/plugin \
  --hooks-json='[{"type":"SessionStart","description":"Initialize"}]'
```
**Purpose**: Generate hook scripts based on type
**Creates**:
- `hooks/session-start` (or other hook types)
- Updates `plugin.json` with hook configuration
**Hook Types**: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse

### update-marketplace
```bash
bash skills/update-marketplace.skill \
  --marketplace-path=/path/to/marketplace \
  --plugin-name=my-plugin \
  --description="Plugin description" \
  --version=1.0.0
```
**Purpose**: Register plugin in marketplace.json
**Updates**: Adds plugin entry to marketplace's plugins array

## Examples

### Example 1: Linear API Plugin

**Phase 1: Create Agent**

```
/agent Create an agent for Linear API integration that manages tickets.

Skills:
- fetch-tickets.skill: Fetch ticket by ID
- create-ticket.skill: Create new ticket
- search-tickets.skill: Search by keyword

Hooks:
- SessionStart: Check LINEAR_API_TOKEN

Commands:
- /linear:fetch ID: Quick ticket lookup
```

Agent created at: `/tmp/linear-agent.md`

**Phase 2: Build Plugin**

```
/create-plugin /tmp/linear-agent.md
```

plugin-wizard output:
```
Analyzing agent definition...
Located marketplace: tools/anspar-cc-plugins

Creating plugin 'linear-api'...
✓ Created directory structure
✓ Generated 3 skills (fetch-tickets, create-ticket, search-tickets)
✓ Generated 1 hook (SessionStart)
✓ Generated 2 commands (fetch, create)
✓ Created tests
✓ Generated README.md
✓ Registered in marketplace

Plugin created at: tools/anspar-cc-plugins/plugins/linear-api

IMPORTANT: Reload Claude Code to use new plugin
```

**Reload and Test**

```
# Exit and restart Claude Code

# Verify plugin loaded
/agents
# Output: linear-api

# Test command
/linear:fetch CUR-240
```

### Example 2: Custom Marketplace

If you have multiple marketplaces:

```
/create-plugin /tmp/my-agent.md --marketplace-path=/home/user/tools/custom-marketplace
```

plugin-wizard will use the specified marketplace instead of auto-detecting.

## Architecture

### Directory Structure

```
plugin-wizard/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest
├── agents/
│   └── plugin-wizard.md      # Agent with YAML frontmatter
├── commands/
│   └── create-plugin.md      # /create-plugin slash command
├── skills/                   # Thin wrappers (2-5 lines)
│   ├── locate-marketplace.skill
│   ├── analyze-agent.skill
│   ├── create-scaffold.skill
│   ├── generate-skills.skill
│   ├── generate-hooks.skill
│   └── update-marketplace.skill
├── scripts/                  # Implementation logic
│   ├── locate-marketplace.sh
│   ├── analyze-agent.js
│   ├── create-scaffold.sh
│   ├── generate-skills.sh
│   ├── generate-hooks.sh
│   └── update-marketplace.js
├── tests/
│   └── test.sh              # Basic test runner
└── README.md                # This file
```

### Design Principles

#### Hooks as Workflow Bumpers

Hooks provide **proactive guidance**, not reactive blocking:

- **Non-blocking warnings**: User maintains control
- **Early detection**: Catch issues before they occur
- **Fast execution**: <100ms to avoid disrupting flow

**Example**: UserPromptSubmit hook detects task switching patterns and suggests claiming new ticket.

#### Skills as Thin Wrappers

Skills are **2-5 line bash scripts** that delegate to implementation scripts:

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$SCRIPT_DIR/scripts/do-thing.sh" "$@"
```

**Why?**
- Agent-friendly invocation
- Single source of truth (script is implementation)
- Testable independently
- Reusable by hooks/commands

#### Single-Purpose Scripts

Each script does **one thing well**:

- Accept command-line parameters (no hardcoding)
- Return structured output (JSON for complex data)
- Exit with clear error codes
- Fail fast with helpful messages

#### Cross-Plugin Awareness

Plugins can use other plugins' scripts:

```bash
# Use linear-api plugin scripts directly
bash ../linear-api/scripts/fetch-ticket.sh --id="$TICKET_ID"
```

**Guidelines**:
- Use public scripts only (document in README)
- Don't couple plugins tightly
- Handle missing dependencies gracefully

## Testing

### Run All Tests

```bash
bash tests/test.sh
```

### Test Output

```
Running plugin tests...
  Validating plugin.json... PASS
  Checking agent file... PASS
  Checking skills... PASS
All tests passed!
```

### Manual Testing

1. **Test marketplace location**:
   ```bash
   bash skills/locate-marketplace.skill
   # Should output: /path/to/marketplace
   ```

2. **Test agent analysis**:
   ```bash
   bash skills/analyze-agent.skill --agent-path=/path/to/agent.md
   # Should output: JSON with agent components
   ```

3. **Test plugin creation** (end-to-end):
   ```
   /create-plugin /tmp/test-agent.md
   # Check generated plugin structure
   ```

## Troubleshooting

### Error: Marketplace not found

**Cause**: No `tools/*/marketplace.json` found

**Fix**: Ensure you have a marketplace:
```bash
# Check for marketplace
find . -name "marketplace.json" -path "*/tools/*"

# If none found, create one
mkdir -p tools/my-marketplace/{.claude-plugin,plugins}
# Add marketplace.json
```

Or specify marketplace path:
```
/create-plugin /path/to/agent.md --marketplace-path=/path/to/marketplace
```

### Error: Agent file missing frontmatter

**Cause**: Agent file doesn't have YAML frontmatter

**Fix**: Add frontmatter to agent file:
```yaml
---
name: agent-name
description: One-sentence description
---
```

### Error: Plugin already exists

**Cause**: Plugin with same name already exists

**Fix**: Choose one:
1. Use different plugin name: `/create-plugin /path/to/agent.md --plugin-name=different-name`
2. Delete existing plugin: `rm -rf plugins/existing-plugin`
3. Edit existing plugin manually (don't regenerate)

### Error: jq command not found

**Cause**: `jq` (JSON parser) not installed

**Fix**: Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Check installation
jq --version
```

### Plugin not appearing after creation

**Cause**: Claude Code caches plugins at startup

**Fix**: Reload Claude Code:
1. Exit Claude Code completely
2. Restart Claude Code
3. Verify: `/agents` should show new agent

## Configuration

### Environment Variables

plugin-wizard requires no environment variables for basic operation.

Generated plugins may require:
- API tokens (e.g., `LINEAR_API_TOKEN`)
- Configuration paths
- Feature flags

**Always document required env vars** in generated plugin's README.

### Customization

Modify `scripts/` to customize generation behavior:

**Common customizations**:
- Change skill template in `generate-skills.sh`
- Add hook types in `generate-hooks.sh`
- Modify plugin.json defaults in `create-scaffold.sh`
- Add validation in `analyze-agent.js`

## Best Practices

### For Agent Creators (Phase 1)

1. **Think through design first**: What operations need skills?
2. **Be specific in descriptions**: "Fetch ticket by ID" > "Get ticket"
3. **Document hooks clearly**: When do they trigger? What do they check?
4. **Plan slash commands**: What quick operations do users need?
5. **Use standard hook types**: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse

### For Plugin Developers (Phase 2)

1. **Test immediately**: Run `bash tests/test.sh` after generation
2. **Implement TODOs**: Generated scripts have TODO markers
3. **Add proper error handling**: Don't just echo errors, handle gracefully
4. **Write comprehensive tests**: Unit tests for scripts, integration tests for skills
5. **Update README**: Customize with plugin-specific details
6. **Document dependencies**: List required env vars, external tools, other plugins

### For Both

1. **Follow naming conventions**: kebab-case for plugins/skills, PascalCase for agents
2. **Keep skills thin**: 2-5 lines max, delegate to scripts
3. **Make hooks fast**: <100ms execution time
4. **Use structured output**: JSON for complex data
5. **Document everything**: README, inline comments, usage examples

## Contributing

Contributions welcome! Areas for enhancement:

1. **More hook templates**: Additional hook types beyond the standard four
2. **Better agent analysis**: Smarter extraction of skills/hooks from agent text
3. **Command generation**: Auto-generate command markdown from agent references
4. **Test generation**: Create unit tests for generated scripts
5. **Interactive mode**: Prompt user for clarifications during generation

See marketplace CONTRIBUTING.md for guidelines.

## Related Documentation

- [Plugin Development Guide](../../docs/PLUGIN_DEVELOPMENT.md) - Comprehensive plugin development guide
- [Orchestration Patterns](../../docs/ORCHESTRATION.md) - How agents work together
- [Architecture Documentation](../../docs/ARCHITECTURE.md) - Marketplace architecture
- [Plugin Wizard Concept](../../../../untracked-notes/plugin-wizard-concept.md) - Original design concept

## License

MIT (same as parent repository)

---

**Version**: 1.0.0
**Created**: 2025-11-09
**Part of**: anspar-cc-plugins marketplace
**Generator**: plugin-wizard (self-created!)
