# ANSPAR Marketplace

Curated collection of Claude Code plugins for the ANSPAR ecosystem.

## Structure

```
anspar-marketplace/
├── .claude-plugin/
│   └── marketplace.json     # Marketplace configuration
├── plugins/
│   └── plugin-expert/       # Individual plugins
└── README.md
```

## Plugins

### plugin-expert (v1.0.0)
Expert guidance and automation for creating Claude Code plugins with best practices.

**Validation Score**: 100/100 ✅

**Features**:
- Interactive plugin creation with guided interviews
- Template library for common plugin types
- Comprehensive validation (structure, syntax, security, performance)
- Auto-fix capabilities
- Complete documentation generation
- Test suite creation

## Usage

To use this marketplace with Claude Code:

```bash
# Link the marketplace
claude-code plugin add-marketplace /path/to/anspar-marketplace

# Install a plugin
claude-code plugin install plugin-expert
```

## Adding New Plugins

1. Validate the plugin using plugin-expert
2. Add plugin directory to `plugins/`
3. Update `marketplace.json` with plugin entry
4. Ensure plugin has proper structure and validation score
5. Commit changes

## Validation

All plugins in this marketplace must:
- Have valid `plugin.json` with all required fields
- Follow naming conventions (kebab-case for plugins/commands, PascalCase for agents/skills)
- Pass security checks (no secrets, safe permissions)
- Include comprehensive documentation
- Achieve validation score of 90+
