# Anspar Marketplace Architecture

## Overview

The anspar-marketplace uses a **plugin wrapper architecture** where Claude Code plugins provide integration layers around shared core tools.

## Directory Structure

```
tools/
├── anspar-marketplace/
│   └── plugins/              # Claude Code plugins
│       ├── workflow/         # Git workflow enforcement
│       ├── simple-requirements/  # Requirements validation wrapper
│       ├── traceability-matrix/  # Traceability generation wrapper
│       ├── spec-compliance/  # Spec directory compliance
│       └── linear-integration/   # Linear API integration
│
└── requirements/             # Shared core tools
    ├── validate_requirements.py      # Core validator
    ├── generate_traceability.py      # Core generator
    ├── update-REQ-hashes.py          # Hash calculator
    └── validate_index.py             # INDEX.md validator
```

## Design Philosophy

### Shared Core Tools (`tools/requirements/`)

**Purpose**: Single source of truth for validation and generation logic

**Characteristics**:
- Pure Python scripts
- No plugin dependencies
- Can be run directly from command line
- Used by multiple plugins
- Maintained independently

**Examples**:
```bash
# Direct usage (no plugin needed)
python3 tools/requirements/validate_requirements.py
python3 tools/requirements/generate_traceability.py
python3 tools/requirements/update-REQ-hashes.py
```

### Plugin Wrappers (`tools/anspar-marketplace/plugins/*/`)

**Purpose**: Integrate core tools into Claude Code and git workflows

**Characteristics**:
- Thin wrappers around core tools
- Provide git hook integration
- Provide Claude Code hook integration
- Handle user interaction and formatting
- Plugin-specific features (e.g., workflow state)

**Integration Points**:

1. **Git Hooks** (called by git)
   - Location: `plugins/*/hooks/pre-commit`, etc.
   - Path resolution: Use `git rev-parse --show-toplevel`
   - Reference shared tools: `$REPO_ROOT/tools/requirements/*.py`

2. **Claude Code Hooks** (called by Claude Code)
   - Location: `plugins/*/hooks/hooks.json`
   - Path resolution: Use `${CLAUDE_PLUGIN_ROOT}` variable
   - Reference plugin files: `${CLAUDE_PLUGIN_ROOT}/scripts/*.sh`

## Path Resolution Patterns

### ✅ Recommended: Dynamic Detection

```bash
# Git hooks should find repo root dynamically
REPO_ROOT="$(git rev-parse --show-toplevel)"
SHARED_TOOL="$REPO_ROOT/tools/requirements/validate_requirements.py"
PLUGIN_DIR="$REPO_ROOT/tools/anspar-marketplace/plugins/simple-requirements"
```

### ✅ Acceptable: Hardcoded Shared Tool Paths

```bash
# OK when referencing shared tools (not plugin-specific files)
VALIDATION_SCRIPT="tools/requirements/validate_requirements.py"
```

### ❌ Avoid: Hardcoded Plugin Paths

```bash
# BAD: Breaks if plugin is moved or renamed
PLUGIN_SCRIPT="/absolute/path/to/plugin/script.sh"
```

## Two Hook Systems

### 1. Git Hooks (Shell Scripts)

**Called by**: Git during commit process
**Environment**: No Claude Code variables
**Path Resolution**: Must use git commands or relative paths

```bash
#!/bin/bash
# Git hook example
REPO_ROOT="$(git rev-parse --show-toplevel)"
python3 "$REPO_ROOT/tools/requirements/validate_requirements.py"
```

**Files**:
- `.githooks/pre-commit` (orchestrator - auto-discovers plugins)
- `plugins/*/hooks/pre-commit` (plugin-specific)
- `plugins/*/hooks/commit-msg`
- `plugins/*/hooks/post-commit`

### 2. Claude Code Hooks (JSON Configuration)

**Called by**: Claude Code during events
**Environment**: `${CLAUDE_PLUGIN_ROOT}` variable available
**Path Resolution**: Use plugin-relative paths

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start"
      }
    ]
  }
}
```

**Files**:
- `plugins/*/hooks/hooks.json` (configuration)
- `plugins/*/.claude-plugin/plugin.json` (references hooks.json)

## Plugin Installation

### Auto-Discovery System

Plugins are automatically discovered by:
1. `.githooks/pre-commit` scans `tools/anspar-marketplace/plugins/*/hooks/pre-commit`
2. `.githooks/commit-msg` scans `tools/anspar-marketplace/plugins/*/hooks/commit-msg`
3. `.githooks/post-commit` scans `tools/anspar-marketplace/plugins/*/hooks/post-commit`

**No manual configuration needed** - plugins work immediately when installed!

### Claude Code Registration

Claude Code discovers plugins via:
1. `plugin.json` in `tools/anspar-marketplace/plugins/*/.claude-plugin/`
2. Hooks defined in `hooks.json` referenced by `plugin.json`

## Benefits of This Architecture

### ✅ Separation of Concerns
- Core logic in `tools/requirements/` (testable, reusable)
- Integration logic in plugins (git hooks, Claude Code)

### ✅ Single Source of Truth
- One validator, used by multiple plugins
- One generator, used by multiple contexts
- Changes to core logic benefit all users

### ✅ Flexibility
- Core tools can be used standalone (CLI, CI/CD)
- Plugins can be added/removed without affecting core
- Multiple plugins can wrap same tool differently

### ✅ Maintainability
- Core tools have no plugin dependencies
- Plugins are thin, mostly configuration
- Easy to test core logic independently

## Migration Notes

When renaming plugins or moving files:
1. Update `plugin.json` name field
2. Update comments in git hook files
3. Update README references
4. **No need** to update `.githooks/*` (auto-discovery)
5. **No need** to update `hooks.json` (uses `${CLAUDE_PLUGIN_ROOT}`)
