# Dev Ai Claude

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-12-13
**Status**: Draft

---

# REQ-d00064: Plugin JSON Validation Tooling

**Level**: Dev | **Status**: Draft | **Implements**: o00013

## Rationale

This requirement establishes automated validation tooling for Claude Code plugin configuration files to ensure schema compliance and catch configuration errors early in the development process. The tooling provides both standalone validation scripts and automated hook-based validation integrated into the plugin development workflow. This supports the broader marketplace reliability improvements by preventing malformed plugin configurations from being deployed.

## Assertions

A. The system SHALL provide a standalone validation script named 'validate-plugin-json.sh' that validates JSON syntax using jq.

B. The validation script SHALL validate plugin.json files against the Claude Code plugin schema.

C. The validation script SHALL validate hooks.json files against the hook configuration schema.

D. The validation script SHALL return exit code 0 for successful validation and exit code 1 for validation failure.

E. The validation script SHALL provide clear error messages that include line references for validation failures.

F. The system SHALL validate that plugin.json contains the required fields: name (kebab-case format), version (semver format), description (non-empty string), and author (object with required 'name' field).

G. The system SHALL validate plugin.json optional fields when present: keywords (must be array), repository (must be URL), homepage (must be URL), license (string), and component paths (commands, agents, skills, hooks).

H. The system SHALL validate that hooks.json contains a required root 'hooks' object.

I. The system SHALL validate that hooks.json supports the hook types: SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, and PostToolUse.

J. The system SHALL validate that each hook type in hooks.json is an array.

K. The system SHALL validate that hook entries contain a 'hooks' array.

L. The system SHALL validate that hook objects contain 'type' and 'command' fields.

M. The system SHALL validate that the optional 'timeout' field in hook objects is a number in milliseconds.

N. The PreToolUse hook SHALL detect JSON file edits in plugin directories.

O. The PreToolUse hook SHALL provide validation reminders with common errors to avoid.

P. The PreToolUse hook SHALL be non-blocking and informational only.

Q. The PostToolUse hook SHALL automatically validate JSON files after edits.

R. The PostToolUse hook SHALL provide immediate feedback on validation errors.

S. The PostToolUse hook SHALL be non-blocking and not prevent file saves.

T. The system SHALL include a comprehensive test suite with valid fixtures for both plugin.json and hooks.json file types.

U. The test suite SHALL include invalid fixtures covering: JSON syntax errors, missing required fields, invalid version format, invalid hooks structure, and bad hook entry format.

V. The system SHALL provide user documentation including usage instructions in the plugin-expert README.

W. The documentation SHALL include examples of manual validation.

X. The documentation SHALL list common errors detected by the validation tooling.

Y. The documentation SHALL describe the benefits and features of the validation tooling.

Z. The validation script SHALL use the ${CLAUDE_PLUGIN_ROOT} environment variable for portable script paths.

*End* *Plugin JSON Validation Tooling* | **Hash**: ade1a4f4
---


---

# REQ-d00065: Plugin Path Validation

**Level**: Dev | **Status**: Draft | **Implements**: d00064

## Rationale

This requirement ensures the integrity of Claude Code plugin configurations by validating that all referenced filesystem paths actually exist and are correctly configured. Path validation extends JSON schema validation (REQ-d00064) by performing actual filesystem checks, catching common deployment issues like missing files, incorrect permissions, and obsolete path patterns. This validation is particularly important for hook commands that must be executable and for component paths that must resolve correctly at runtime. The opt-in design allows flexibility during plugin development while providing rigorous validation for production deployments.

## Assertions

A. The validation tool SHALL verify that the `commands` path specified in plugin.json exists as either a file or directory.

B. The validation tool SHALL verify that the `agents` path specified in plugin.json exists as either a file or directory.

C. The validation tool SHALL verify that the `skills` path specified in plugin.json exists as either a file or directory when the skills field is present.

D. The validation tool SHALL verify that the `hooks` path specified in plugin.json exists as a file.

E. The validation tool SHALL resolve all component paths relative to the plugin root directory.

F. The validation tool SHALL identify path references using old plugin name patterns including 'anspar-' and 'claude-marketplace'.

G. The validation tool SHALL suggest similar files using case-insensitive search when an exact path match is not found.

H. The validation tool SHALL handle both relative and absolute paths correctly during validation.

I. The validation tool SHALL warn about suspicious path patterns.

J. The validation tool SHALL verify that hook command files specified in hooks.json exist in the filesystem.

K. The validation tool SHALL check that hook command files are executable.

L. The validation tool SHALL resolve ${CLAUDE_PLUGIN_ROOT} variable references when validating hook command paths.

M. The validation tool SHALL support validation of absolute paths with warnings.

N. The validation tool SHALL support validation of relative paths with recommendations.

O. The validation tool SHALL display the resolved absolute path in error messages when a path does not exist.

P. The validation tool SHALL suggest the `chmod +x` command in error messages for non-executable hook scripts.

Q. The validation tool SHALL recommend using ${CLAUDE_PLUGIN_ROOT} for relative paths in error messages.

R. The validation tool SHALL list similar files in error messages when an exact match is not found.

S. The validation tool SHALL provide a `--check-paths` command-line flag to enable path validation.

T. Path validation SHALL be opt-in and SHALL NOT be enabled by default.

U. The path validation feature SHALL be compatible with the existing validation workflow.

V. The validation tool SHALL provide output that clearly distinguishes path validation results from schema validation results.

W. The validation tool SHALL correctly validate directory paths referenced in plugin.json components.

X. The validation tool SHALL correctly validate file paths referenced in plugin.json components.

Y. The validation tool SHALL correctly validate paths that reference non-existent files or directories.

Z. The validation tool SHALL correctly validate the executability status of hook scripts.

*End* *Plugin Path Validation* | **Hash**: 09911117
---

# REQ-d00067: Streamlined Ticket Creation Agent

**Level**: Dev | **Status**: Draft | **Implements**: o00017

## Rationale

This requirement defines a context-aware ticket creation agent that streamlines the ticket creation process from approximately 10 manual steps to 2 steps. The agent leverages git context (branch names, file changes, commit history) to intelligently infer ticket metadata (priority, labels, descriptions) and enforces quality standards before ticket creation. By automating requirement linking, duplicate detection, and workflow integration, the agent ensures consistent ticket quality while reducing cognitive load on developers. This supports the project's requirement traceability mandates and integrates with the existing workflow plugin to maintain compliance with the development process outlined in REQ-o00017.

## Assertions

A. The agent SHALL gather context from the current git branch name.

B. The agent SHALL gather context from changed files reported by git status.

C. The agent SHALL gather context from recent commit messages.

D. The agent SHALL gather context from changes to files in the spec/ directory.

E. The agent SHALL infer default priority values based on keywords in the ticket context, using high priority for bug-related keywords, normal priority for feature-related keywords, and low priority for documentation-related keywords.

F. The agent SHALL infer default label values based on file changes, including frontend, backend, and database labels as appropriate.

G. The agent SHALL enhance ticket descriptions with relevant commit context.

H. The agent SHALL prompt interactively for any missing required ticket information.

I. The agent SHALL validate that ticket titles are specific and action-oriented.

J. The agent SHALL validate that ticket descriptions include what is being done, why it is being done, and how it will be done.

K. The agent SHALL validate that all `REQ-*` references in the ticket are valid requirement identifiers.

L. The agent SHALL automatically link tickets to referenced requirements using `REQ-*` pattern matching.

M. The agent SHALL detect duplicate tickets using similarity checking.

N. The agent SHALL check whether an active ticket is already claimed before creating a new ticket.

O. The agent SHALL offer to claim a newly created ticket after successful creation.

P. The agent SHALL integrate with the workflow plugin for ticket claiming and switching operations.

*End* *Streamlined Ticket Creation Agent* | **Hash**: f6d9e288
---

# REQ-d00068: Enhanced Workflow New Work Detection

**Level**: Dev | **Status**: Draft | **Implements**: o00017

## Rationale

This requirement enhances the workflow plugin's proactive detection capabilities to guide developers toward proper ticket discipline without blocking their work. The requirement integrates with the ticket-creation-agent to reduce friction between detecting new work and creating appropriate tracking tickets. By expanding pattern detection to include bug fixes and documentation work, and providing context-aware guidance based on git state and active ticket status, the system helps maintain requirement traceability (a critical FDA 21 CFR Part 11 compliance obligation) while keeping the developer experience smooth and non-intrusive. The integration with ticket-creation-agent enables natural language ticket creation directly from warning messages, eliminating the need to remember script paths or commands.

## Assertions

A. The system SHALL detect bug fix work patterns including 'fix bug', 'fix issue', 'fix problem', and 'fix error'.

B. The system SHALL detect documentation work patterns including 'update docs', 'write README', and 'add documentation'.

C. The system SHALL increment the NEW_FEATURE_SCORE by 4 points when bug fix patterns are detected.

D. The system SHALL increment the NEW_FEATURE_SCORE by 3 points when documentation work patterns are detected.

E. The system SHALL provide ticket-creation-agent integration guidance in warning messages when new work is detected without an active ticket.

F. The system SHALL suggest ticket creation with the natural language trigger 'Create a ticket for [description]' when implementation work is detected without an active ticket.

G. The system SHALL present three clear options (create, claim, explore) when new work is detected without an active ticket.

H. The system SHALL ask whether work is within scope when new feature patterns are detected with an active ticket.

I. The system SHALL suggest creating a separate ticket via ticket-creation-agent when new feature work appears outside active ticket scope.

J. The system SHALL provide context-aware suggestions based on both git state and active ticket status.

K. The system SHALL maintain non-blocking behavior for all workflow detection warnings.

L. Warning messages SHALL include explanations of ticket-creation-agent capabilities.

M. The system SHALL NOT block user actions when providing workflow guidance or warnings.

*End* *Enhanced Workflow New Work Detection* | **Hash**: 951ecf65
---

## References

(No references yet)
