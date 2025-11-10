# Plugin Expert Scripts

This directory contains all executable scripts organized by purpose.

## Directory Structure

### `generators/`
Code generation scripts that create plugin components from templates:
- `command-builder.js` - Generates slash command files
- `docs-builder.js` - Generates documentation files
- `hook-builder.js` - Generates git hook files
- `metadata-builder.js` - Generates plugin metadata (plugin.json, marketplace.json)
- `organization.js` - Organizes plugin file structure
- `parser.js` - Parses plugin specifications
- `prompt-builder.js` - Generates agent prompt files
- `syntax-corrector.js` - Corrects syntax in generated files
- `test-builder.js` - Generates test files

### `orchestrators/`
High-level coordination scripts that manage multi-step workflows:
- `interview-conductor.js` - Conducts interactive plugin creation interviews
- `plugin-assembler.js` - Assembles complete plugin packages
- `validator.js` - Validates plugin structure and compliance

### `utils/`
Reusable utility scripts and helpers:
- `config-manager.js` - Configuration file management
- `escape-helpers.js` - String escaping utilities
- `file-ops.js` - File operation helpers
- `json-yaml.js` - JSON/YAML conversion utilities
- `manage-permissions.sh` - File permission management
- `path-manager.js` - Path resolution and validation
- `string-helpers.js` - String manipulation utilities
- `validate-plugin-json.sh` - Plugin manifest validation
- `validation.js` - General validation functions

## Root Scripts

Scripts in the root `scripts/` directory are user-facing utilities:
- `cache-docs.sh` - Downloads and caches Claude Code documentation
- `check-doc-cache.sh` - Verifies documentation cache status
- `generate-plugin-tests.js` - Generates test suites for plugins
- `generate-self-tests.js` - Generates self-tests for plugin-expert
- `install.sh` - Installs plugin-expert dependencies
- `uninstall.sh` - Removes plugin-expert

## Usage by Agents

When the PluginExpert agent needs to invoke these scripts, it uses the Bash tool:

```bash
# Code generation
node scripts/generators/command-builder.js --name="example"

# Orchestration
node scripts/orchestrators/plugin-assembler.js --config=plugin.yaml

# Utilities
bash scripts/utils/validate-plugin-json.sh plugin.json
```

## Script Count Limits

According to plugin architecture best practices:
- **Current total:** ~30 scripts across all subdirectories
- **Recommended max:** 20 scripts per plugin
- **Status:** Acceptable for meta-plugin (plugin-expert is special case)

Plugin-expert is a meta-plugin for creating other plugins, so higher script counts are justified by its complexity.
