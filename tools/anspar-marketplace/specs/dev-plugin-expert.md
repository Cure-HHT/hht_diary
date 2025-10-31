# Plugin Expert - Claude Code Plugin Development System

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-31
**Status**: Active

> **See**: README.md for spec/ directory governance rules
> **See**: ../plugins/plugin-expert/ for implementation

---

## Executive Summary

Plugin Expert provides comprehensive guidance and automation for creating Claude Code plugins following best practices, including interactive plugin creation, template library, validation, auto-fix capabilities, and documentation generation.

---

### REQ-d00110: Interactive Plugin Creation

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: High-Touch

Plugin Expert SHALL provide guided interview workflow for creating new Claude Code plugins, gathering requirements through structured questions and generating complete plugin structure with all necessary components.

Implementation SHALL include:
- Interactive question flow for plugin specification
- Component selection (agents, skills, commands, hooks)
- Dependency specification and validation
- Template application based on plugin type
- Complete file structure generation
- Initial plugin.json configuration
- Session pause/resume: Save incomplete interviews for later completion
- Quick mode: Skip interview with defaults for experienced users
- Regeneration: Generate plugin from previously saved answers

**Rationale**: Interactive creation reduces friction in plugin development. Structured questions ensure complete specification. Template-based generation ensures consistency. Pause/resume accommodates interruptions common in small teams. Quick mode enables fast iteration for experienced users.

**Acceptance Criteria**:
- Interview covers: name, description, components, dependencies
- Generates valid plugin.json with all required fields
- Creates directory structure matching component selections
- Applies appropriate templates for selected components
- Generated plugins pass validation without modification
- Incomplete sessions saved to .plugin-interview-state.json
- Resume prompts: "Continue previous interview or start new?"
- Quick mode flag: --quick generates plugin with sensible defaults

---

### REQ-d00111: Plugin Validation

**Level**: Dev | **Implements**: d00101 | **Status**: Required | **Maintenance**: Set-and-Forget

Plugin Expert SHALL validate plugins using marketplace quality standards (REQ-d00101), providing detailed feedback on CRITICAL, REQUIRED, and RECOMMENDED issues.

Validation SHALL use same criteria as REQ-d00101:
- **CRITICAL**: Security issues, broken core functionality
- **REQUIRED**: Missing documentation, naming violations, hardcoded paths
- **RECOMMENDED**: Code quality, test coverage, error handling

**Rationale**: Single source of truth for validation rules. Avoids duplication between plugin-expert and marketplace. Clear severity levels guide fixing priorities for small teams.

**Acceptance Criteria**:
- Validation reports CRITICAL, REQUIRED, RECOMMENDED levels
- Each issue includes: severity, location, description, fix suggestion
- Exit codes: 1 if CRITICAL failures, 0 otherwise
- Summary shows: X CRITICAL, Y REQUIRED, Z RECOMMENDED
- References REQ-d00101 for validation rule definitions

---

### REQ-d00112: Auto-Fix Capabilities

**Level**: Dev | **Implements**: d00101 | **Status**: Recommended | **Maintenance**: Periodic

Plugin Expert SHALL automatically fix common plugin issues with explicit safety mechanisms protecting against data loss.

Auto-fix SHALL handle:
- File permissions (755 for executables, 644 for data)
- Path corrections (replace hardcoded paths with ${CLAUDE_PLUGIN_ROOT})
- Missing required files (README.md, CHANGELOG.md, LICENSE)
- plugin.json schema corrections
- Documentation formatting (consistent headings, structure)

Safety mechanisms (CRITICAL for small teams):
- Non-destructive: Creates .bak files before any modification
- Explicit consent: Lists ALL changes, requires y/n confirmation
- Dry-run mode: --dry-run shows changes without applying
- Rollback command: Provides undo command if changes unwanted
- Atomic operations: All fixes applied together or none applied

**Rationale**: Auto-fix reduces manual effort. Safety mechanisms prevent data loss critical for small teams without extensive backups. Dry-run enables review before commitment.

**Acceptance Criteria**:
- Backup files created with .bak extension before modification
- User sees full change list before confirmation prompt
- --dry-run flag shows changes without modifying files
- On completion, shows: "To undo: plugin-expert rollback <plugin-dir>"
- Rollback restores .bak files and deletes generated files
- If any fix fails, all fixes rolled back (transaction semantics)

---

### REQ-d00113: Template Library

**Level**: Dev | **Implements**: d00100 | **Status**: Recommended | **Maintenance**: Periodic

Plugin Expert SHALL provide template library for common plugin patterns including workflow automation, API integration, validation enforcement, and documentation generation, accelerating plugin development.

Template library SHALL include:
- Workflow automation templates (git hooks, state management)
- API integration templates (REST, GraphQL clients)
- Validation templates (pre-commit hooks, format checkers)
- Documentation templates (README structure, CHANGELOG format)
- Component templates (agents, skills, commands, hooks)

**Rationale**: Templates encode best practices. Pre-built components accelerate development. Consistency across plugins improved.

**Acceptance Criteria**:
- Templates available for each plugin type
- Templates include placeholder comments for customization
- Generated code from templates passes validation
- Templates demonstrate best practices (error handling, logging)
- Template catalog documented with examples

---

### REQ-d00114: Documentation Generation

**Level**: Dev | **Implements**: d00102 | **Status**: Required | **Maintenance**: Set-and-Forget

Plugin Expert SHALL generate comprehensive plugin documentation including README.md with standard sections, CHANGELOG.md with version history, and inline code documentation following language conventions.

Documentation generation SHALL produce:
- README.md: Overview, Features, Installation, Usage, Examples, Troubleshooting
- CHANGELOG.md: Version history with semantic versioning
- LICENSE: MIT license template
- Inline docs: JSDoc for JavaScript, docstrings for Python, comments for Bash
- plugin.json: Complete metadata with homepage URL

**Rationale**: Automated documentation ensures completeness. Standard structure improves discoverability. Version history aids maintenance.

**Acceptance Criteria**:
- Generated README includes all required sections
- CHANGELOG follows Keep a Changelog format
- LICENSE is valid MIT license
- Inline documentation generated for all exported functions
- plugin.json includes: name, version, description, author, license, homepage

---

### REQ-d00115: Test Suite Creation

**Level**: Dev | **Status**: Recommended | **Maintenance**: Set-and-Forget

Plugin Expert SHALL generate minimum viable test suite focusing on structure and basic functionality, with optional complex tests for API-heavy plugins.

Minimum viable test suite (always generated):
- Structure test: plugin.json is valid JSON and schema-compliant
- Reference test: All files referenced in plugin.json exist
- Permission test: Scripts are executable (755), data files are not (644)
- Hook syntax test: Hooks have valid shebang and pass bash -n validation

Optional tests (generated for complex plugins):
- Integration tests: For plugins with API interactions
- End-to-end tests: For workflow plugins with multi-step operations
- Performance tests: For plugins processing large datasets

**Rationale**: Minimum viable tests catch 80% of issues with 20% of effort (Pareto principle). Small teams benefit from quick, reliable tests over comprehensive coverage. Optional tests add value for complex plugins without burdening simple plugins.

**Acceptance Criteria**:
- All plugins get 4 minimum viable tests
- Test runner: npm test or ./run-tests.sh
- Test output format: TAP (Test Anything Protocol) or simple pass/fail
- Test runner exits 0 only if all tests pass
- Optional tests generated if plugin has: API clients, multi-step workflows, data processing
- README includes: "Running Tests" section with examples

---

## Plugin Architecture

Plugin Expert uses layered architecture:

**Layer 1: Utilities** - Atomic operations (validation, file ops, string helpers)
**Layer 2: Builders** - Component construction (metadata, prompts, hooks, docs)
**Layer 3: Coordinators** - Workflow orchestration (interview, assembly, validation)
**Layer 4: Entry Points** - User-facing commands and agents

No circular dependencies. Each layer depends only on lower layers.

---

## References

- **Implementation**: ../plugins/plugin-expert/
- **Marketplace Spec**: dev-marketplace.md
- **Claude Code Plugin API**: https://docs.claude.com/en/docs/claude-code/plugins-reference

---

**Document Classification**: Internal Use - Development Standards
**Review Frequency**: Quarterly
**Owner**: Plugin Expert Maintainers
