---
name: create-plugin
description: Create a complete plugin from an agent definition (Phase 2 of 2-phase workflow)
---

# Command: /create-plugin

Creates a complete Claude Code plugin around a user-defined agent using the plugin-wizard 2-phase workflow.

## Purpose

This command implements **Phase 2** of the plugin creation workflow. After you've created an agent definition using `/agent` (Phase 1), this command builds the complete plugin infrastructure around that agent.

## Usage

```
/create-plugin AGENT_PATH [OPTIONS]
```

**Arguments:**
- `AGENT_PATH`: Path to the agent markdown file created in Phase 1

**Options:**
- `--marketplace-path=PATH`: Specify marketplace directory (optional, auto-detected if not provided)
- `--plugin-name=NAME`: Override plugin name (optional, defaults to agent name from frontmatter)

## The 2-Phase Workflow

### Phase 1: Create Agent (User Does This)

Use the `/agent` command to create your agent definition:

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

### Phase 2: Build Plugin (This Command)

Once your agent is created, run:

```
/create-plugin /path/to/your-agent.md
```

plugin-wizard will:
1. Locate the marketplace (searches for `tools/*/marketplace.json`)
2. Analyze your agent definition
3. Create plugin directory structure
4. Generate skills (thin wrappers calling scripts)
5. Generate hooks (based on agent's hook knowledge)
6. Generate implementation scripts
7. Create tests and documentation
8. Update marketplace.json to register the plugin

## What Gets Created

```
plugins/your-plugin/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── agents/
│   └── your-agent.md            # Your agent (copied from Phase 1)
├── commands/                    # Slash commands (if agent references any)
│   └── command-name.md
├── skills/                      # Thin wrappers (2-5 lines)
│   ├── skill-one.skill
│   └── skill-two.skill
├── scripts/                     # Implementation logic
│   ├── skill-one.sh
│   └── skill-two.sh
├── hooks/                       # Event handlers (if agent references any)
│   ├── session-start
│   └── user-prompt-submit
├── tests/
│   └── test.sh                  # Basic test runner
└── README.md                    # Comprehensive documentation
```

## Implementation

The plugin-wizard agent performs the following steps:

### 1. Locate Marketplace
```bash
bash skills/locate-marketplace.skill
```
Finds marketplace by searching for `tools/*/marketplace.json`.

### 2. Analyze Agent
```bash
bash skills/analyze-agent.skill --agent-path=/path/to/agent.md
```
Extracts:
- YAML frontmatter (name, description, tools)
- Skills mentioned in agent content
- Hooks the agent references
- Slash commands the agent uses

### 3. Create Scaffold
```bash
bash skills/create-scaffold.skill \
  --plugin-name=my-plugin \
  --marketplace-path=/path/to/marketplace \
  --agent-path=/path/to/agent.md
```
Creates directory structure and basic plugin.json.

### 4. Generate Skills
```bash
bash skills/generate-skills.skill \
  --plugin-path=/path/to/plugin \
  --skills-json='[{"name":"skill-name","description":"What it does"}]'
```
Generates thin skill wrappers and implementation scripts.

### 5. Generate Hooks
```bash
bash skills/generate-hooks.skill \
  --plugin-path=/path/to/plugin \
  --hooks-json='[{"type":"SessionStart","description":"Initialize"}]'
```
Creates hook scripts as workflow bumpers (non-blocking guidance).

### 6. Update Marketplace
```bash
bash skills/update-marketplace.skill \
  --marketplace-path=/path/to/marketplace \
  --plugin-name=my-plugin \
  --description="Plugin description" \
  --version=1.0.0
```
Registers plugin in marketplace.json.

### 7. Generate Documentation
Creates comprehensive README.md with:
- Feature list
- Installation instructions
- Usage examples
- Skills documentation
- Hooks explanation
- Troubleshooting guide

## Examples

### Example 1: Basic Plugin Creation

```
User: /create-plugin /tmp/linear-agent.md

plugin-wizard:
Analyzing agent definition...
Located marketplace: tools/anspar-cc-plugins

Creating plugin 'linear-api'...
- Created directory structure
- Generated 3 skills (fetch-tickets, create-ticket, update-ticket)
- Generated 1 hook (SessionStart: Check LINEAR_API_TOKEN)
- Created tests and documentation
- Registered in marketplace

Plugin created successfully!

IMPORTANT: Reload Claude Code to use new plugin:
1. Exit Claude Code
2. Restart Claude Code
3. Verify with: /agents (should show linear-api)
```

### Example 2: Specify Custom Marketplace

```
User: /create-plugin /tmp/my-agent.md --marketplace-path=/home/user/tools/my-marketplace

plugin-wizard:
Using specified marketplace: /home/user/tools/my-marketplace

Creating plugin 'my-plugin'...
[... creation process ...]

Plugin created successfully!
```

## Agent Requirements

Your agent file MUST have YAML frontmatter:

```yaml
---
name: agent-name
description: One-sentence description of what this agent does
tools: Read, Write, Bash  # Optional: omit for all tools
---
```

Without valid frontmatter, plugin creation will fail with a clear error message.

## Design Principles

plugin-wizard follows these architectural patterns:

### Hooks as Workflow Bumpers
- Proactive guidance (detect issues before they occur)
- Non-blocking warnings (user maintains control)
- Fast execution (<100ms)

### Skills as Thin Wrappers
- Skills are 2-5 lines calling scripts
- Scripts contain all implementation logic
- Agent knows exactly how to invoke each skill

### Single-Purpose Scripts
- Each script does one thing well
- Accept command-line parameters
- Return structured output (JSON when complex)

### Cross-Plugin Awareness
- Plugins can use other plugins' scripts
- Document cross-plugin dependencies

## After Plugin Creation

Once your plugin is created:

1. **Reload Claude Code** (required):
   - Exit and restart Claude Code CLI
   - Plugins are cached at startup

2. **Verify plugin loaded**:
   ```
   /agents
   ```
   Should show your new agent in the list

3. **Test slash commands**:
   ```
   /your-plugin:command-name
   ```

4. **Review and customize**:
   - Edit `README.md` with specific details
   - Implement TODO items in generated scripts
   - Add tests in `tests/` directory
   - Customize hooks for your workflow

5. **Test thoroughly**:
   ```bash
   bash plugins/your-plugin/tests/test.sh
   ```

## Troubleshooting

### Error: Marketplace not found

**Cause**: No `tools/*/marketplace.json` found

**Fix**: Create marketplace structure:
```bash
mkdir -p tools/my-marketplace/{.claude-plugin,plugins,shared}
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
1. Use different plugin name: `--plugin-name=different-name`
2. Delete existing plugin first
3. Edit existing plugin manually (don't use wizard)

## Best Practices

1. **Start with agent design**: Think through capabilities before creating agent
2. **Be specific in agent description**: Clear skill descriptions → better generated code
3. **Use standard hook types**: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse
4. **Document slash commands**: Agent should reference commands by name
5. **Test immediately**: Run `bash tests/test.sh` after creation
6. **Customize generated code**: Templates are starting points, not final implementation
7. **Follow naming conventions**: kebab-case for plugins, PascalCase for agents

## See Also

- [Plugin Development Guide](../../docs/PLUGIN_DEVELOPMENT.md)
- [Orchestration Patterns](../../docs/ORCHESTRATION.md)
- [Plugin Architecture](../../docs/ARCHITECTURE.md)
- [Plugin Wizard Concept](../../../../untracked-notes/plugin-wizard-concept.md)

## Support

For issues with plugin creation:
1. Check plugin-wizard agent definition for guidance
2. Consult PLUGIN_DEVELOPMENT.md for conventions
3. Review existing plugins as examples
4. File issues in repository

---

**Created by**: plugin-wizard v1.0.0
**Part of**: anspar-cc-plugins marketplace
