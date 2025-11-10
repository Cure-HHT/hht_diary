# REQ-d00065: Plugin Path Validation

**Level**: Dev | **Implements**: d00064 | **Status**: Active

## Overview

Path validation tooling for Claude Code plugin configuration files to verify that all referenced files and directories actually exist. This extends REQ-d00064 (JSON validation) with actual filesystem validation.

## Requirements

### Path Validation for plugin.json

- **REQ-d00065.1**: Validate component path references
  - Check `commands` path exists (file or directory)
  - Check `agents` path exists (file or directory)
  - Check `skills` path exists (file or directory) if present
  - Check `hooks` path exists (file, typically hooks.json)
  - All paths resolved relative to plugin root directory

- **REQ-d00065.2**: Detect common path errors
  - Identify old plugin name patterns (anspar-, claude-marketplace)
  - Suggest similar files if path not found (case-insensitive search)
  - Handle both relative and absolute paths correctly
  - Warn about suspicious patterns

### Path Validation for hooks.json

- **REQ-d00065.3**: Validate hook command paths
  - Verify hook command files exist
  - Check hook command files are executable
  - Resolve ${CLAUDE_PLUGIN_ROOT} variable in paths
  - Support absolute paths with warnings
  - Support relative paths with recommendations

- **REQ-d00065.4**: Provide actionable error messages
  - Show resolved absolute path when path doesn't exist
  - Suggest `chmod +x` command for non-executable scripts
  - Recommend ${CLAUDE_PLUGIN_ROOT} for relative paths
  - List similar files when exact match not found

### Implementation

- **REQ-d00065.5**: Command-line interface
  - Add `--check-paths` flag to validation script
  - Path validation opt-in (not enabled by default)
  - Compatible with existing validation workflow
  - Clear output distinguishing path validation from schema validation

### Testing

- **REQ-d00065.6**: Test coverage
  - Valid paths (directories and files)
  - Invalid paths (non-existent)
  - Non-executable hook scripts
  - Old plugin name patterns in paths
  - ${CLAUDE_PLUGIN_ROOT} variable resolution

## Implementation

- **Location**: Extends `tools/anspar-cc-plugins/plugins/plugin-wizard/scripts/utils/validate-plugin-json.sh`
- **Files Modified**:
  - `scripts/utils/validate-plugin-json.sh` - Added path validation logic
  - `README.md` - Documented path validation feature
- **New Test Fixtures**:
  - `tests/fixtures/invalid/bad-paths/plugin.json` - Invalid path test case

## Acceptance Criteria

- ✅ Path validation works for plugin.json component paths
- ✅ Path validation works for hooks.json command paths
- ✅ Detects missing files and directories
- ✅ Checks script executability for hooks
- ✅ Provides helpful error messages with suggestions
- ✅ Opt-in via --check-paths flag
- ✅ Documentation complete

## Related Requirements

- **REQ-d00064**: Plugin JSON Validation Tooling (base validation)

## Notes

- Path validation is opt-in to allow validation in environments where files may not exist yet (e.g., during plugin scaffolding)
- ${CLAUDE_PLUGIN_ROOT} variable resolution enables validation of actual hook paths
- Executability checking helps catch common hook deployment issues
- Part of broader marketplace reliability improvements (CUR-240)

## Usage Examples

```bash
##  Schema validation only
./validate-plugin-json.sh .claude-plugin/plugin.json

## Schema + path validation (recommended for existing plugins)
./validate-plugin-json.sh --check-paths .claude-plugin/plugin.json

## Validate hooks with path checking
./validate-plugin-json.sh --check-paths hooks/hooks.json
```


*End* *Plugin Path Validation* | **Hash**: 770482b7
---
