# Plugin Templates

This directory contains templates for creating new plugins using the plugin-wizard tool.

## Purpose

- Provide consistent plugin structure across the marketplace
- Accelerate plugin development with pre-configured boilerplate
- Ensure new plugins follow best practices and conventions

## Planned Templates

- `basic-plugin/`: Minimal plugin with single command
- `agent-plugin/`: Plugin with agent, skills, and commands
- `integration-plugin/`: Plugin for external API integration
- `hook-plugin/`: Plugin focused on workflow hooks
- `orchestrator-plugin/`: Plugin that coordinates other plugins

## Template Structure

Each template directory contains:
```
template-name/
├── .claude-plugin/
│   └── plugin.json.template
├── agents/
│   └── AgentName.md.template
├── commands/
│   └── command-name.md.template
├── scripts/
│   └── example-script.sh.template
├── hooks/
│   └── hooks.json.template
└── README.md.template
```

## Usage with Plugin-Wizard

The plugin-wizard tool (future implementation) will:
1. Prompt for plugin details (name, description, type)
2. Select appropriate template
3. Substitute variables ({{PLUGIN_NAME}}, {{DESCRIPTION}}, etc.)
4. Generate complete plugin structure

## Current Status

**EMPTY** - This directory is part of the marketplace scaffold. Templates will be created after we establish plugin development patterns and before implementing plugin-wizard.

See `untracked-notes/plugin-wizard-concept.md` for design considerations.
