# Anspar CC Plugins Marketplace

A refactored Claude Code plugin marketplace with enhanced agent orchestration and proper sub-agent integration.

## Overview

This marketplace replaces `tools/anspar-marketplace/` with improved architecture:

- **Proper Agent Orchestration**: Main Claude agent delegates to specialized sub-agents
- **YAML Frontmatter**: All agents have proper metadata (name, description, tools)
- **Idempotent Configuration**: SessionStart hook safely configures CLAUDE.md
- **Shared Utilities**: Common scripts and validators reduce duplication
- **CI/CD Integration**: Validation pipeline for plugin quality

## Status

**Phase 1: Scaffold Created** (Current)
- ✅ Marketplace structure established
- ✅ SessionStart hook for orchestration guidance
- ✅ Shared utilities structure
- ✅ Documentation placeholders
- ⏳ Plugin migration (upcoming)

## Directory Structure

```
tools/anspar-cc-plugins/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace manifest
├── plugins/                       # Plugin directory (empty - to be populated)
├── shared/                        # Shared utilities across plugins
│   ├── scripts/                  # Common bash/Python scripts
│   ├── validators/               # JSON schema validators
│   └── templates/                # Plugin scaffolding templates
├── hooks/
│   ├── hooks.json                # Marketplace-level hooks
│   └── session-start             # CLAUDE.md configuration hook
├── docs/
│   ├── ARCHITECTURE.md           # Marketplace architecture (placeholder)
│   ├── PLUGIN_DEVELOPMENT.md     # Plugin dev guide (placeholder)
│   ├── ORCHESTRATION.md          # Agent orchestration guide (placeholder)
│   └── MIGRATION.md              # Migration guide (placeholder)
└── README.md                      # This file
```

## Key Improvements Over Previous Marketplace

### 1. Agent Orchestration

**Problem (Old)**: Plugins lacked proper agent definitions, causing the main agent to not use them effectively.

**Solution (New)**:
- All agents have YAML frontmatter with name, description, and tools
- SessionStart hook configures CLAUDE.md with orchestration guidance
- Clear patterns for when to delegate vs. implement

### 2. Idempotent Configuration

**Problem (Old)**: Manual CLAUDE.md updates were error-prone and inconsistent.

**Solution (New)**:
- SessionStart hook automatically configures orchestration guidance
- Version markers prevent duplication
- Safe to run multiple times

### 3. Shared Utilities

**Problem (Old)**: Plugins duplicated common code (validation, JSON parsing, etc.)

**Solution (New)**:
- `shared/scripts/`: Common utilities
- `shared/validators/`: JSON schema validators
- `shared/templates/`: Plugin scaffolding templates

### 4. CI/CD Integration

**Problem (Old)**: Validation scripts scattered across repository.

**Solution (New)**:
- Centralized validators in `shared/validators/`
- Clear integration points for GitHub Actions
- Consistent validation patterns

## SessionStart Hook

The marketplace includes a SessionStart hook that automatically configures your project's CLAUDE.md with agent orchestration guidance.

**Features**:
- ✅ Idempotent: Safe to run multiple times
- ✅ Version-aware: Detects existing/outdated content
- ✅ Non-destructive: Never removes user content
- ✅ Transparent: Logs all actions

**What it adds to CLAUDE.md**:
```markdown
## Agent Orchestration Pattern

- ALWAYS check for available sub-agents before implementing complex tasks
- Use `/agents` command to see available specialized agents
- Delegate to sub-agents when their expertise matches the task
- Act as orchestrator, not implementer, when agents are available
```

## Installation

This marketplace is currently in development. Once plugins are migrated, installation will be:

```bash
# Add marketplace to Claude Code configuration
claude-code plugin add /path/to/tools/anspar-cc-plugins

# Verify installation
claude-code plugin list
```

## Plugin Migration Plan

Plugins from `tools/anspar-marketplace/` will be migrated in phases:

**Phase 1**: Scaffold (Current)
- ✅ Marketplace structure
- ✅ SessionStart hook
- ✅ Shared utilities structure

**Phase 2**: Core Plugins
- ⏳ workflow plugin (git workflow enforcement)
- ⏳ linear-api plugin (Linear API client)
- ⏳ requirement-traceability plugin (REQ-to-ticket mapping)

**Phase 3**: Supporting Plugins
- ⏳ simple-requirements plugin (requirement validation)
- ⏳ spec-compliance plugin (spec/ directory compliance)

**Phase 4**: Cleanup
- ⏳ Deprecate old marketplace
- ⏳ Update all documentation references
- ⏳ Remove `tools/anspar-marketplace/`

## Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Marketplace architecture design (placeholder)
- [PLUGIN_DEVELOPMENT.md](docs/PLUGIN_DEVELOPMENT.md) - Plugin development guide (placeholder)
- [ORCHESTRATION.md](docs/ORCHESTRATION.md) - Agent orchestration patterns (placeholder)
- [MIGRATION.md](docs/MIGRATION.md) - Migration from old marketplace (placeholder)

Documentation will be completed as plugins are migrated and patterns emerge.

## Integration with Existing Tools

The new marketplace structure accounts for existing CI/CD scripts:

**Existing Scripts** (remain at current location):
- `tools/requirements/validate_requirements.py`
- `tools/requirements/generate_traceability.py`
- `tools/requirements/validate_index.py`

**Future Enhancement**: These may be refactored into `shared/validators/` or into requirement-traceability plugin as the migration progresses.

## Design Principles

1. **Separation of Concerns**: Each plugin has single responsibility
2. **Agent Specialization**: Sub-agents provide deep domain expertise
3. **Idempotent Operations**: All hooks and scripts are safe to run multiple times
4. **Clear Error Messages**: All failures provide actionable guidance
5. **Environment-Based Configuration**: No hardcoded paths or secrets
6. **Version-Aware Updates**: Configuration changes use version markers

## References

- **Claude Code Documentation**: https://docs.claude.com/en/docs/claude-code/plugins
- **Sub-Agent Guide**: https://docs.claude.com/en/docs/claude-code/sub-agents
- **Original Marketplace**: `tools/anspar-marketplace/` (to be deprecated)
- **Plugin Wizard Concept**: `untracked-notes/plugin-wizard-concept.md`

## Contributing

**Current Phase**: Scaffold only - no plugins yet.

Once plugins are migrated, contributions should:
1. Follow plugin development guide (docs/PLUGIN_DEVELOPMENT.md)
2. Include proper agent YAML frontmatter
3. Pass validation checks in `shared/validators/`
4. Include comprehensive README and examples
5. Add tests for all functionality

## License

Same as parent repository (Anspar Foundation Clinical Trial Diary Platform).

---

**Created**: 2025-11-09
**Version**: 1.0.0
**Status**: Scaffold phase - ready for plugin migration
