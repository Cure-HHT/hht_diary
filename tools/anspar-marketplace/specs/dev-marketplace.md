# ANSPAR Marketplace Plugin System

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-31
**Status**: Active

> **See**: README.md for spec/ directory governance rules
> **See**: ../plugins/ for individual plugin implementations

---

## Executive Summary

This document defines the requirements for the ANSPAR Marketplace, a curated collection of Claude Code plugins that automate development workflow, enforce requirements traceability, and integrate with project management tools.

---

## Technology Stack

- **Plugin System**: Claude Code Plugin API v1.0
- **Distribution**: Git-based marketplace with marketplace.json manifest
- **Plugin Languages**: JavaScript/Node.js, Bash, Python
- **Integration Points**: Git hooks, Claude Code agents/skills/commands, Linear API

---

### REQ-d00100: Marketplace Plugin Discovery

**Level**: Dev | **Status**: Required | **Maintenance**: Set-and-Forget

The marketplace SHALL provide automated plugin discovery via marketplace.json manifest, enabling Claude Code to enumerate available plugins and install plugins from the marketplace.

Implementation SHALL include:
- marketplace.json file in .claude-plugin/ directory
- Plugin metadata: name, version, source path, description
- Plugin source paths relative to marketplace root (./plugins/*)
- Owner information and repository URL

**Rationale**: Standardized plugin discovery enables automated installation. Manifest-based approach allows validation before installation. Relative paths enable marketplace portability.

**Acceptance Criteria**:
- marketplace.json follows Claude Code marketplace specification
- All plugins listed have corresponding directories in plugins/
- Plugin source paths are relative to marketplace root
- Claude Code can discover and list all marketplace plugins

---

### REQ-d00101: Plugin Quality Standards

**Level**: Dev | **Status**: Required | **Maintenance**: Set-and-Forget

Marketplace plugins SHALL meet quality standards with clear pass/fail criteria for security, functionality, and documentation.

Quality standards SHALL ensure:
- **CRITICAL (must pass)**:
  - Security: No hardcoded secrets, API keys, passwords, or credentials
  - Security: File permissions correct (755 for executables, 644 for data)
  - Functionality: Core features work as documented
- **REQUIRED (must pass or fix next release)**:
  - Valid plugin.json with all required fields
  - Documentation: README.md, CHANGELOG.md, LICENSE present
  - Naming conventions: kebab-case for plugins/commands, PascalCase for agents/skills
  - No hardcoded paths (use ${CLAUDE_PLUGIN_ROOT})
- **RECOMMENDED (suggested improvements)**:
  - Code quality: Linting passes, no obvious bugs
  - Test coverage: Basic integration tests present
  - Error handling: Clear, actionable error messages

**Rationale**: Removes arbitrary scores. Provides clear pass/fail criteria practical for small teams. CRITICAL failures protect security, REQUIRED failures allow work-in-progress with warnings.

**Acceptance Criteria**:
- Validation reports: CRITICAL, REQUIRED, RECOMMENDED levels
- CRITICAL failures: Plugin rejected from marketplace
- REQUIRED failures: Plugin accepted with warnings, documented in plugin README
- RECOMMENDED failures: Plugin accepted, suggestions provided for improvement
- Security scan detects common credential patterns (AWS keys, tokens, passwords)

---

### REQ-d00102: Plugin Versioning

**Level**: Dev | **Status**: Required | **Maintenance**: Periodic

Plugins SHALL follow semantic versioning (MAJOR.MINOR.PATCH) with changes documented in CHANGELOG.md and version consistency across plugin.json and CHANGELOG.md.

Version management SHALL ensure:
- Semantic versioning for all plugins
- CHANGELOG.md entry for every version
- Breaking changes clearly marked with migration guides
- Version in plugin.json matches CHANGELOG
- Deprecation timeline: Minimum 90 days notice before removal

**Rationale**: Semantic versioning communicates update impact. CHANGELOG provides historical context. Deprecation timeline gives users time to migrate.

**Acceptance Criteria**:
- All plugins use semantic versioning
- plugin.json version matches CHANGELOG latest entry
- Breaking changes documented with migration guides
- CHANGELOG includes: version, date, changes (added/changed/fixed/removed)
- Deprecated plugins marked with removal date (minimum 90 days out)

---

### REQ-d00103: Plugin Maintenance Classification

**Level**: Dev | **Status**: Required | **Maintenance**: Set-and-Forget

Plugins SHALL be classified by maintenance burden to guide small team resource allocation and set expectations for plugin consumers.

Maintenance classifications:
- **Set-and-Forget**: Runs automatically, rarely needs updates
  - Examples: anspar-spec-compliance, anspar-requirement-validation, anspar-traceability-matrix
  - Update frequency: Only on breaking changes or security issues
- **Periodic**: Requires occasional updates for external API changes or feature additions
  - Examples: anspar-linear-integration (Linear API changes)
  - Update frequency: Quarterly or as needed for API compatibility
- **High-Touch**: Requires frequent attention, refinement, and feature development
  - Examples: plugin-expert (template updates, new patterns)
  - Update frequency: Monthly or as new use cases emerge

**Rationale**: Small teams need transparency about maintenance costs. Clear classification enables informed plugin adoption decisions and resource planning.

**Acceptance Criteria**:
- Each plugin README includes "Maintenance Classification" section
- Classification reviewed quarterly
- High-touch plugins have active maintainer assigned
- Marketplace README lists plugins by maintenance classification
- Classification criteria documented with examples

---

## References

- **Claude Code Plugin Docs**: https://docs.claude.com/en/docs/claude-code/plugins-reference
- **Main Project Spec**: ../../spec/README.md
- **Marketplace README**: ../README.md

---

**Document Classification**: Internal Use - Development Standards
**Review Frequency**: Quarterly
**Owner**: Development Lead
