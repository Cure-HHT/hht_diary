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

**Level**: Dev | **Status**: Active

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

**Level**: Dev | **Status**: Active

Marketplace plugins SHALL achieve minimum validation score of 90/100 with comprehensive documentation, security validation, and proper file permissions.

Standards SHALL ensure:
- Valid plugin.json with all required fields
- Naming conventions: kebab-case for plugins/commands, PascalCase for agents/skills
- Security: no secrets, safe permissions (755 for executables, 644 for data)
- Documentation: README.md, CHANGELOG.md, LICENSE
- No hardcoded paths (use ${CLAUDE_PLUGIN_ROOT})

**Rationale**: Quality standards ensure reliable user experience. Documentation enables self-service usage. Security prevents credential leakage.

**Acceptance Criteria**:
- Automated validation checks all standards
- Plugins scoring below 90/100 rejected
- Security scan detects hardcoded credentials
- Permission validator ensures correct file modes
- Path validator detects hardcoded paths

---

### REQ-d00102: Plugin Versioning

**Level**: Dev | **Status**: Active

Plugins SHALL follow semantic versioning (MAJOR.MINOR.PATCH) with changes documented in CHANGELOG.md and version consistency across plugin.json and CHANGELOG.md.

Version management SHALL ensure:
- Semantic versioning for all plugins
- CHANGELOG.md entry for every version
- Breaking changes clearly marked
- Version in plugin.json matches CHANGELOG

**Rationale**: Semantic versioning communicates update impact. CHANGELOG provides historical context.

**Acceptance Criteria**:
- All plugins use semantic versioning
- plugin.json version matches CHANGELOG latest entry
- Breaking changes documented with migration guides
- CHANGELOG includes: version, date, changes

---

## References

- **Claude Code Plugin Docs**: https://docs.claude.com/en/docs/claude-code/plugins-reference
- **Main Project Spec**: ../../spec/README.md
- **Marketplace README**: ../README.md

---

**Document Classification**: Internal Use - Development Standards
**Review Frequency**: Quarterly
**Owner**: Development Lead
