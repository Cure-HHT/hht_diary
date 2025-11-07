# REQ-d00064: Plugin JSON Validation Tooling

**Level**: Dev | **Implements**: - | **Status**: Active

## Overview

Automated validation tooling for Claude Code plugin configuration files (plugin.json and hooks.json) to ensure schema compliance and catch errors early in the development process.

## Requirements

### Validation Script

- **REQ-d00064.1**: Provide standalone validation script `validate-plugin-json.sh`
  - Validates JSON syntax using `jq`
  - Validates plugin.json against Claude Code schema
  - Validates hooks.json against hook configuration schema
  - Returns exit code 0 for success, 1 for failure
  - Provides clear error messages with line references

### Plugin.json Schema Validation

- **REQ-d00064.2**: Validate plugin.json required fields
  - name (kebab-case format)
  - version (semver format)
  - description (non-empty string)
  - author (object with required 'name' field)

- **REQ-d00064.3**: Validate plugin.json optional fields
  - keywords (must be array if present)
  - repository, homepage (must be URLs if present)
  - license (string)
  - Component paths: commands, agents, skills, hooks

### Hooks.json Schema Validation

- **REQ-d00064.4**: Validate hooks.json structure
  - Root 'hooks' object required
  - Hook types: SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, PostToolUse
  - Each hook type is an array
  - Hook entries have 'hooks' array
  - Hook objects have 'type' and 'command' fields
  - Optional 'timeout' field (number in milliseconds)

### Hook Integration

- **REQ-d00064.5**: PreToolUse hook integration
  - Detect JSON file edits in plugin directories
  - Provide validation reminder with common errors to avoid
  - Non-blocking (informational only)

- **REQ-d00064.6**: PostToolUse hook integration
  - Automatically validate JSON files after edits
  - Provide immediate feedback on errors
  - Non-blocking (does not prevent save)

### Testing

- **REQ-d00064.7**: Comprehensive test suite
  - Valid fixtures for both file types
  - Invalid fixtures covering:
    - JSON syntax errors
    - Missing required fields
    - Invalid version format
    - Invalid hooks structure
    - Bad hook entry format

### Documentation

- **REQ-d00064.8**: User documentation
  - Usage instructions in plugin-expert README
  - Examples of manual validation
  - List of common errors detected
  - Benefits and features

## Implementation

- **Location**: `tools/anspar-marketplace/plugins/plugin-expert/`
- **Files**:
  - `utilities/validate-plugin-json.sh` - Validation script
  - `hooks/before-tool-use` - PreToolUse hook (updated)
  - `hooks/after-tool-use` - PostToolUse hook (new)
  - `hooks/hooks.json` - Hook registration (updated)
  - `tests/fixtures/valid/` - Valid test cases
  - `tests/fixtures/invalid/` - Invalid test cases
  - `README.md` - Documentation (updated)

## Acceptance Criteria

- ✅ Validation script correctly validates plugin.json syntax and schema
- ✅ Validation script correctly validates hooks.json syntax and schema
- ✅ Clear error messages with actionable fix suggestions
- ✅ Hooks integrate seamlessly into plugin development workflow
- ✅ All test cases pass (valid and invalid scenarios)
- ✅ Documentation complete with usage examples

## Related Requirements

- None (tooling infrastructure)

## Notes

- Non-blocking validation approach - warns but doesn't prevent saves
- Uses `jq` for JSON parsing and validation
- Leverages ${CLAUDE_PLUGIN_ROOT} for portable script paths
- Part of broader marketplace reliability improvements (CUR-240)

*End* *Plugin JSON Validation Tooling* | **Hash**: bc0b4c89
---
