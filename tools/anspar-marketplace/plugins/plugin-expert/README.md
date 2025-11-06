# Plugin Expert for Claude Code

A comprehensive plugin development system for Claude Code that provides expert guidance, automation, and validation for creating high-quality plugins.

![Version](https://img.shields.io/badge/version-1.2.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## 🎯 Overview

Plugin Expert is a sophisticated meta-plugin that helps you create, validate, and manage Claude Code plugins. It implements a four-layer architecture that ensures your plugins follow best practices, conventions, and security guidelines.

## ✨ Features

- **🚀 Guided Plugin Creation**: Interactive interviews to gather requirements
- **📋 Template Library**: Pre-configured templates for common plugin types
- **✅ Comprehensive Validation**: Structure, syntax, security, and performance checks
- **🔧 Auto-Fix Capabilities**: Automatically correct common syntax and structure issues
- **📚 Documentation Generation**: Complete docs, README, and usage guides
- **🧪 Test Suite Creation**: Automated test generation and runners
- **🔒 Security Analysis**: Identify potential security issues
- **📦 Marketplace Ready**: Proper structure for easy publishing
- **🎯 Proactive Plugin Work Detection** (NEW): Auto-invokes when plugin development is detected
- **💡 Proactive Pattern Recommendations** (NEW): Suggests UserPromptSubmit hooks and auto-invocation patterns

### 🎯 Proactive Architecture Enforcement (NEW)

**v1.1 Enhancement**: Plugin Expert now proactively detects when you're working on plugins and automatically provides architectural guidance.

**How it works**:
- **UserPromptSubmit Hook**: Analyzes your prompts for plugin-related keywords
- **Auto-Invocation**: Automatically invokes PluginExpert agent when plugin work detected
- **Pattern Recommendations**: Reviews plugins and suggests proactive patterns (UserPromptSubmit hooks, auto-invocation triggers, etc.)
- **Architectural Guardian**: Ensures separation of concerns and best practices

**Example Interaction**:

```
You: "Add a UserPromptSubmit hook to the workflow plugin"

Plugin Expert:
🔌 PLUGIN WORK DETECTED

Plugin development/modification is architectural work that requires careful design.

⚡ AUTO-INVOKING PluginExpert agent for:
- Architecture enforcement
- Separation of concerns validation
- Best practices guidance
- Integration pattern review

[PluginExpert agent is now active to guide your work]
```

**Pattern Recommendations**:

When reviewing or creating plugins, PluginExpert now evaluates opportunities for:
1. **UserPromptSubmit hooks**: Detect when users start relevant work
2. **Auto-invocation triggers**: Make agents invoke themselves proactively
3. **PreToolUse validation**: Preventive checks before file operations
4. **PostToolUse assistance**: Helpful suggestions after operations
5. **Cross-plugin integration**: Coordination with other plugins

These recommendations are INFO-level (not errors) and focus on enhancing user experience.

**Benefits**:
- ✅ Automatic expert guidance when working on plugins
- ✅ Prevents architectural violations early
- ✅ Promotes proactive patterns across all plugins
- ✅ Ensures consistent quality and best practices

### 🔍 JSON Validation (NEW)

**v1.2 Enhancement**: Automatic validation of plugin configuration files (plugin.json and hooks.json).

**How it works**:
- **PreToolUse Hook**: Provides validation reminder when editing JSON files
- **PostToolUse Hook**: Automatically validates JSON after edits
- **Validation Script**: Standalone utility for manual validation

**Validated schemas**:

**plugin.json**:
- ✅ JSON syntax (proper commas, quotes, braces)
- ✅ Required fields: name, version, description, author
- ✅ Name format: kebab-case (lowercase with hyphens)
- ✅ Version format: semantic versioning (e.g., 1.0.0)
- ✅ Author structure: must have 'name' field
- ✅ Optional fields: keywords (array), repository, homepage, license
- ✅ Component paths: commands, agents, skills, hooks

**hooks.json**:
- ✅ JSON syntax
- ✅ Root 'hooks' object required
- ✅ Hook types: SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, PostToolUse
- ✅ Hook structure: proper nesting with 'hooks' arrays
- ✅ Hook objects: must have 'type' and 'command' fields
- ✅ Optional timeout field (number in milliseconds)
- ✅ Command paths: validates ${CLAUDE_PLUGIN_ROOT} usage

**Manual validation**:

```bash
# Validate plugin.json
${CLAUDE_PLUGIN_ROOT}/utilities/validate-plugin-json.sh .claude-plugin/plugin.json

# Validate hooks.json
${CLAUDE_PLUGIN_ROOT}/utilities/validate-plugin-json.sh hooks/hooks.json
```

**Example output**:

```
Validating: .claude-plugin/plugin.json

✓ JSON syntax is valid

ℹ Validating plugin.json schema...
✓ Required field 'name' present
✓ Required field 'version' present
✓ Required field 'description' present
✓ Required field 'author' present
✓ Plugin name 'my-plugin' follows kebab-case convention
✓ Version '1.0.0' follows semver format
✓ Author object has required 'name' field

✓ Validation passed: .claude-plugin/plugin.json
```

**Common errors detected**:
- ❌ Missing commas between properties
- ❌ Trailing commas in arrays/objects
- ❌ Missing required fields
- ❌ Invalid version format (must be semver)
- ❌ Keywords as string instead of array
- ❌ Invalid hook structure
- ❌ Missing 'hooks' array in hook entries

**Benefits**:
- ✅ Catch JSON errors before committing
- ✅ Ensure plugin.json follows Claude Code schema
- ✅ Validate hook configuration correctness
- ✅ Clear error messages with fix suggestions
- ✅ Automatic validation on save

## 🏗️ Architecture

Plugin Expert uses a sophisticated four-layer architecture:

```
Layer 4: Entry Points (Top)
├── commands/create-plugin.md    # Main command interface
└── agents/PluginExpert.md       # Expert agent

Layer 3: Process Coordinators
├── interview-conductor.js       # Gather specifications
├── plugin-assembler.js         # Coordinate assembly
└── validator.js                # Comprehensive validation

Layer 2: Component Builders
├── metadata-builder.js         # Build configurations
├── prompt-builder.js          # Generate prompts
├── command-builder.js         # Create commands
├── hook-builder.js           # Setup hooks
├── docs-builder.js           # Generate documentation
├── test-builder.js           # Create tests
├── parser.js                 # Parse existing plugins
├── syntax-corrector.js       # Fix syntax issues
└── organization.js           # Handle file structure

Layer 1: Atomic Utilities (Foundation)
├── path-manager.js           # Safe path operations
├── config-manager.js         # Configuration handling
├── validation.js             # Input validation
├── string-helpers.js         # Text transformations
├── escape-helpers.js         # String escaping
├── file-ops.js              # Safe file operations
└── json-yaml.js             # Config serialization
```

## 📦 Installation

### From Claude Code

```bash
claude-code plugin install plugin-expert
```

### Manual Installation

```bash
cd ~/.claude-code/plugins
git clone https://github.com/claude-code/plugin-expert.git
```

## 🚀 Quick Start

### Create a New Plugin (Interactive)

```bash
/create-plugin
```

You'll be guided through:
- Plugin name and description
- Author information
- Component selection (commands, agents, skills, hooks)
- Feature configuration

### Use a Template

```bash
/create-plugin data-analysis --name my-analyzer
```

Available templates:
- `data-analysis` - Data analysis and visualization
- `code-quality` - Code review and quality checks
- `deployment` - CI/CD automation
- `documentation` - Doc generation

### Fix an Existing Plugin

```bash
/create-plugin --migrate ./old-plugin --fix-syntax
```

## 📁 Generated Plugin Structure

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Metadata
├── commands/                # Slash commands
├── agents/                  # Sub-agents
├── skills/                  # Agent skills
├── hooks/                   # Event hooks
├── tests/                   # Test suite
├── docs/                    # Documentation
├── examples/                # Usage examples
├── README.md
├── CONTRIBUTING.md
└── CHANGELOG.md
```

## 🛠️ Core Components

### Commands

- **/create-plugin**: Main plugin creation interface

### Agents

- **PluginExpert**: Comprehensive plugin development assistant

### Key Utilities

#### PathManager
Ensures safe path operations and prevents directory traversal:
```javascript
const pathManager = new PathManager(pluginPath);
pathManager.ensureDir('commands');
pathManager.getComponentPath('agents');
```

#### Escape Helpers
Properly escape strings for various contexts:
```javascript
escapeForJSON(multilineString);
escapeForShell(commandArg);
escapePromptForMarkdown(content);
```

#### Validators
Comprehensive validation at every level:
```javascript
validatePlugin(pluginPath, {
  runTests: true,
  checkSecurity: true,
  strict: true
});
```

## 🔒 Security Features

- Automatic detection of sensitive data in configurations
- Path traversal prevention
- Shell command escaping
- Permission checks
- Dangerous pattern detection in hooks

## 🧪 Testing

Plugin Expert generates complete test suites:

```bash
# Generated test runners
tests/test.sh     # Bash runner
tests/test.js     # Node.js runner
tests/test.py     # Python runner
```

Run tests:
```bash
cd my-plugin
./tests/test.sh
```

## 📚 Documentation

- [Plugin Development Guide](https://docs.claude.com/en/docs/claude-code/plugins)
- [Sub-Agent Documentation](https://docs.claude.com/en/docs/claude-code/sub-agents)
- [Example Plugins](https://github.com/jeremylongshore/claude-code-plugins-plus)

## 🤝 Contributing

Contributions are welcome! The Plugin Expert system is designed to be extensible:

1. **Add Templates**: Create new templates in `interview-conductor.js`
2. **Extend Validators**: Add validation rules in `validator.js`
3. **New Builders**: Create builders for additional component types
4. **Improve Utilities**: Enhance Layer 1 utilities for broader use

## 📋 Best Practices Applied

Every plugin created with Plugin Expert automatically follows:

- ✅ Proper directory structure and naming conventions
- ✅ Valid metadata with all required fields
- ✅ Comprehensive error handling
- ✅ Security best practices
- ✅ Performance optimizations
- ✅ Complete documentation
- ✅ Test coverage

## 🚧 Roadmap

- [ ] Marketplace publisher coordinator
- [ ] Plugin migration utilities
- [ ] Advanced template library
- [ ] Visual plugin designer
- [ ] Dependency management
- [ ] Version upgrade assistant

## 📄 License

MIT

## 🙏 Acknowledgments

Built for the Claude Code community to streamline plugin development and ensure high-quality, secure plugins.

---

**Note**: This is a meta-plugin that helps create other plugins. It demonstrates advanced plugin development patterns and can be used as a reference implementation.