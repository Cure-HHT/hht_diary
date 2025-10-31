---
name: create-plugin
description: Expert guidance for creating Claude Code plugins
arguments: "[plugin-type] [--name <name>] [--output <path>] [--interactive] [--template <type>]"
---

# /create-plugin Command

Expert assistance for creating well-structured Claude Code plugins with best practices built-in.

## Purpose

The `/create-plugin` command provides comprehensive guidance and automation for creating Claude Code plugins. It handles everything from initial setup through validation and testing, ensuring your plugin follows best practices and conventions.

## Usage

```bash
/create-plugin                                    # Interactive mode
/create-plugin data-analysis                      # Use template
/create-plugin --name my-plugin --output ./       # Quick creation
/create-plugin --template code-quality --interactive  # Template + customization
```

## Arguments

### `plugin-type` *(optional)*

Pre-defined plugin template to use:
- `data-analysis` - Data analysis and visualization plugin
- `code-quality` - Code review and quality analysis
- `deployment` - CI/CD and deployment automation
- `documentation` - Documentation generation
- `custom` - Start from scratch with guided setup

### Options

- `--name <name>`: Plugin name (kebab-case)
- `--output <path>`: Output directory (default: current directory)
- `--interactive`: Run interactive interview for customization
- `--template <type>`: Use specific template
- `--no-docs`: Skip documentation generation
- `--no-tests`: Skip test generation
- `--validate`: Validate after creation
- `--fix-syntax`: Auto-fix common syntax issues

## Execution Steps

1. **Setup Phase**
   - Validate arguments and options
   - Determine plugin specifications (template, interactive, or defaults)
   - Set up PathManager for output directory

2. **Interview Phase** (if interactive)
   - Gather basic information (name, description, author)
   - Determine plugin capabilities and purpose
   - Select components (commands, agents, skills, hooks)
   - Configure advanced options

3. **Planning Phase**
   - Analyze requirements and plan architecture
   - Determine file structure and dependencies
   - Identify integration points

4. **Assembly Phase**
   - Create directory structure
   - Build and write metadata files
   - Generate component files
   - Create documentation
   - Set up test suite

5. **Validation Phase**
   - Check structure and organization
   - Validate syntax and metadata
   - Run security checks
   - Generate validation report

6. **Finalization Phase**
   - Apply syntax corrections if needed
   - Create examples
   - Display summary and next steps

## Examples

### Basic Interactive Creation

```bash
/create-plugin

# You'll be guided through:
# - Plugin name and description
# - Author information
# - Component selection
# - Feature configuration
```

### Quick Template-Based Creation

```bash
/create-plugin data-analysis --name data-viz --output ./plugins/

# Creates a data analysis plugin with:
# - Pre-configured commands: analyze, visualize, report
# - DataAnalysis and Visualization skills
# - Complete documentation
# - Test suite
```

### Custom Plugin with Specific Components

```bash
/create-plugin custom \
  --name code-formatter \
  --interactive \
  --validate

# Interactive creation with:
# - Custom component selection
# - Immediate validation
# - Syntax auto-correction
```

### Migration of Existing Plugin

```bash
/create-plugin --migrate ./old-plugin \
  --output ./new-plugin \
  --fix-syntax

# Migrates and fixes:
# - Directory structure
# - File naming conventions
# - Syntax issues
# - Missing documentation
```

## Implementation Details

When invoked, this command will:

1. **Load all necessary utilities and builders**
   ```javascript
   const { PathManager } = require('../utilities/path-manager');
   const { conductInterview } = require('../coordinators/interview-conductor');
   const { assemblePlugin } = require('../coordinators/plugin-assembler');
   const { validatePlugin } = require('../coordinators/validator');
   ```

2. **Process user input and determine workflow**
   - Parse arguments and options
   - Select appropriate template or start interview
   - Configure output paths

3. **Execute plugin creation workflow**
   - Run interview if needed
   - Plan architecture
   - Assemble all components
   - Generate documentation and tests
   - Validate result

4. **Provide detailed feedback**
   - Show creation progress
   - Display validation results
   - Suggest next steps
   - Provide usage examples

## Error Handling

The command handles various error scenarios:

- **Invalid plugin names**: Automatically converts to kebab-case
- **Missing required fields**: Prompts for required information
- **Syntax errors**: Offers auto-correction
- **File conflicts**: Creates backups before overwriting
- **Permission issues**: Provides clear error messages

## Best Practices Applied

The command automatically ensures:

- ✅ Proper directory structure following conventions
- ✅ Valid plugin.json with all required fields
- ✅ Consistent naming conventions
- ✅ Comprehensive documentation
- ✅ Test suite setup
- ✅ Security best practices
- ✅ Performance considerations

## Output Structure

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── commands/                 # Slash commands
│   ├── build.md
│   └── deploy.md
├── agents/                   # Sub-agents
│   └── CodeReviewer.md
├── skills/                   # Agent skills
│   └── DataAnalysis/
│       └── SKILL.md
├── hooks/                    # Event hooks
│   ├── hooks.json
│   └── before-tool-use.sh
├── tests/                    # Test suite
│   ├── test.sh
│   ├── test.js
│   └── test-config.json
├── docs/                     # Documentation
│   ├── INSTALLATION.md
│   └── USAGE.md
├── examples/                 # Usage examples
│   ├── commands.md
│   └── configuration.md
├── README.md                 # Main documentation
├── CONTRIBUTING.md           # Contribution guide
└── CHANGELOG.md             # Version history
```

## Integration with Plugin-Expert System

This command leverages the full plugin-expert architecture:

- **Layer 1 Utilities**: Path management, validation, escaping
- **Layer 2 Builders**: Component generation, parsing, syntax correction
- **Layer 3 Coordinators**: Interview, assembly, validation
- **Layer 4 Interface**: This command

## Related Commands

- **/validate-plugin**: Validate an existing plugin
- **/fix-plugin**: Auto-fix common issues
- **/publish-plugin**: Publish to marketplace
- **/test-plugin**: Run plugin tests

## Notes

- The command saves interview answers for future use
- Templates are continuously updated based on best practices
- Validation is performed automatically but can be skipped with `--no-validate`
- The command integrates with git if available, creating an initial commit

## Resources

- [Plugin Documentation](https://docs.claude.com/en/docs/claude-code/plugins)
- [Example Plugins](https://github.com/jeremylongshore/claude-code-plugins-plus/tree/main/plugins)
- [Sub-Agent Guide](https://docs.claude.com/en/docs/claude-code/sub-agents)