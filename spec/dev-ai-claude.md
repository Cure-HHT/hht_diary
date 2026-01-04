# Dev Ai Claude

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-12-13
**Status**: Draft

---

# REQ-d00064: Plugin JSON Validation Tooling

**Level**: Dev | **Implements**: o00013| **Status**: Draft

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

- **Location**: `tools/anspar-cc-plugins/plugins/plugin-wizard/`
- **Files**:
  - `scripts/utils/validate-plugin-json.sh` - Validation script
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

*End* *Plugin JSON Validation Tooling* | **Hash**: e325d07b
---


---

# REQ-d00065: Plugin Path Validation

**Level**: Dev | **Implements**: d00064 | **Status**: Draft

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

# REQ-d00067: Streamlined Ticket Creation Agent

**Level**: Dev | **Implements**: o00017| **Status**: Draft

## Overview

Intelligent, context-aware ticket creation agent that reduces manual steps and ensures consistent ticket quality through smart defaults, interactive prompting, and automatic requirement linking.

## Requirements

- **REQ-d00067.1**: Context awareness (git status, branch name, recent commits)
- **REQ-d00067.2**: Smart default inference (priority, labels, descriptions)
- **REQ-d00067.3**: Interactive prompting for missing information
- **REQ-d00067.4**: Quality validation (title and description)
- **REQ-d00067.5**: Automatic requirement linking (REQ-* references)
- **REQ-d00067.6**: Workflow integration (offer to claim ticket)
- **REQ-d00067.7**: Duplicate detection with similarity checking

## Implementation

**Files**:
- `agents/ticket-creation-agent.md` - Main agent implementation
- `.claude-plugin/plugin.json` - Agent registration
- `README.md` - Agent documentation
- `CHANGELOG.md` - Version history

**Features**:

1. **Context Gathering**:
   - Current branch name
   - Changed files (git status)
   - Recent commit messages
   - Spec file changes

2. **Smart Defaults**:
   - Priority: Inferred from keywords (bug=high, feature=normal, docs=low)
   - Labels: Based on file changes (frontend/backend/database)
   - Description: Enhanced with commit context

3. **Quality Validation**:
   - Title must be specific and action-oriented
   - Description must include what, why, and how
   - Requirement references must be valid

4. **Workflow Integration**:
   - Checks for active ticket
   - Offers to claim newly created ticket
   - Integrates with workflow plugin

## Benefits

- **Reduced manual steps**: From ~10 steps to ~2 steps
- **Consistent quality**: Enforced validation ensures well-structured tickets
- **Automatic traceability**: Requirement links maintained automatically
- **Better context**: Git context provides relevant information
- **Seamless workflow**: Integration with claim/switch ticket flow

## Related

- REQ-d00064: JSON Validation
- REQ-d00065: Path Validation
- REQ-d00066: Permission Management


*End* *Streamlined Ticket Creation Agent* | **Hash**: 335415e6
---

# REQ-d00068: Enhanced Workflow New Work Detection

**Level**: Dev | **Implements**: o00017| **Status**: Draft

## Overview

Enhanced proactive workflow detection that integrates with the ticket-creation-agent to provide seamless ticket creation guidance when users start new work without an active ticket.

## Requirements

- **REQ-d00068.1**: Extended pattern detection (bug fixes, documentation work)
- **REQ-d00068.2**: Ticket-creation-agent integration in warning messages
- **REQ-d00068.3**: Actionable guidance with clear options
- **REQ-d00068.4**: Context-aware suggestions based on active ticket state
- **REQ-d00068.5**: Non-intrusive reminders (not blocking)

## Implementation

**Files Modified**:
- `hooks/user-prompt-submit` - Enhanced detection patterns and messages
- `README.md` - Updated documentation with examples
- `CHANGELOG.md` - Version 2.2.0 release notes

**Detection Patterns Added**:

1. **Bug Fix Detection**:
   - Patterns: "fix bug", "fix issue", "fix problem", "fix error"
   - Score: +4 to NEW_FEATURE_SCORE

2. **Documentation Work**:
   - Patterns: "update docs", "write README", "add documentation"
   - Score: +3 to NEW_FEATURE_SCORE

**Enhanced Messages**:

1. **No Active Ticket + Implementation Work**:
   - Suggests: "Create a ticket for [description]"
   - Points to ticket-creation-agent
   - Lists 3 clear options: create, claim, explore

2. **Active Ticket + New Feature**:
   - Asks if work is within ticket scope
   - Suggests using ticket-creation-agent for separate ticket
   - Maintains scope discipline

**Integration with Ticket-Creation-Agent**:
- Messages include natural language trigger: "Just say: 'Create a ticket for...'"
- Explains ticket-creation-agent capabilities
- Reduces friction between detection and action

## Benefits

- **Seamless workflow**: From detection → suggestion → creation in natural language
- **Reduced manual steps**: No need to remember script paths
- **Better ticket discipline**: Proactive rather than reactive enforcement
- **Context-aware**: Smart suggestions based on git state
- **Non-intrusive**: User maintains control, guidance not blocking

## Acceptance Criteria

- ✅ Bug fix patterns detected correctly
- ✅ Documentation work patterns detected correctly
- ✅ Messages suggest ticket-creation-agent
- ✅ Clear options provided for different scenarios
- ✅ README documentation updated with examples
- ✅ Non-blocking behavior maintained

## Related

- REQ-d00067: Streamlined Ticket Creation Agent
- REQ-d00064: JSON Validation
- REQ-d00065: Path Validation
- REQ-d00066: Permission Management


*End* *Enhanced Workflow New Work Detection* | **Hash**: f5f3570e
---

## References

(No references yet)
