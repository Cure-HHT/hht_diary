# Anspar Claude Code Marketplace

**Independent, Distributable Plugins for Claude Code**

## Overview

This marketplace contains independently distributable Claude Code plugins developed by the Anspar Foundation. Each plugin is fully self-contained and can be extracted, published, or shared separately.

## Available Plugins

### 1. anspar-workflow

**Category**: Workflow | **Version**: 1.0.0

Git workflow enforcement for requirement traceability and ticket lifecycle management with distributed worktree support.

**Key Features**:
- Per-worktree state management (.git/WORKFLOW_STATE)
- REQ reference validation in commit messages
- Active ticket enforcement before commits
- Paused/resumed ticket workflow
- Distributed worktree support
- Tracker-agnostic design

**Location**: `anspar-workflow/`
**Documentation**: [README.md](./anspar-workflow/README.md)
**License**: MIT

---

### 2. anspar-linear-integration

**Category**: Integration | **Version**: 1.0.0

Linear API integration tools for requirement-ticket traceability and project management automation.

**Key Features**:
- Batch ticket creation from requirements
- Intelligent caching system (24-hour auto-refresh)
- Environment variable auto-discovery
- Smart labeling and priority assignment
- 15+ automation scripts

**Location**: `anspar-linear-integration/`
**Documentation**: [README.md](./anspar-linear-integration/README.md)
**License**: MIT

---

### 3. anspar-spec-compliance

**Category**: Validation | **Version**: 1.0.0

Enforces spec/ directory compliance through automated validation and AI-powered analysis.

**Key Features**:
- AI-powered validation agent
- Git pre-commit hook integration
- File naming convention enforcement
- Audience scope rules (PRD/Ops/Dev)
- Code detection in PRD files

**Location**: `anspar-spec-compliance/`
**Documentation**: [README.md](./anspar-spec-compliance/README.md)
**License**: MIT

---

### 4. anspar-requirement-validation

**Category**: Validation | **Version**: 1.0.0

Validates requirement format, uniqueness, and links before commits.

**Key Features**:
- Requirement format validation
- Uniqueness checking (no duplicate IDs)
- Link validation (parent requirements exist)
- Git pre-commit hook integration
- References shared validation script (CI/CD compatible)

**Location**: `anspar-requirement-validation/`
**Documentation**: [README.md](./anspar-requirement-validation/README.md)
**License**: MIT

---

### 5. anspar-traceability-matrix

**Category**: Automation | **Version**: 1.0.0

Auto-regenerates requirement traceability matrices on spec/ changes.

**Key Features**:
- Automatic matrix regeneration
- Markdown and HTML output formats
- Requirement hierarchy visualization
- Implementation tracking (requirements → code)
- Git pre-commit hook integration

**Location**: `anspar-traceability-matrix/`
**Documentation**: [README.md](./anspar-traceability-matrix/README.md)
**License**: MIT

---

## Plugin Architecture

### Independence Principle

Each plugin is **fully self-contained** and relocatable:

- ✅ Complete documentation (README, CHANGELOG, LICENSE)
- ✅ All necessary files included
- ✅ Can be extracted and published separately
- ✅ No dependencies on marketplace structure
- ✅ Individual versioning and release cycles

### Directory Structure

```
tools/claude-marketplace/
├── anspar-linear-integration/           # Independent plugin
│   ├── .claude-plugin/
│   │   └── plugin.json                  # Claude Code manifest
│   ├── package.json                     # npm manifest (if Node.js)
│   ├── README.md                        # Standalone documentation
│   ├── LICENSE                          # MIT
│   ├── CHANGELOG.md                     # Version history
│   ├── docs/
│   ├── scripts/
│   └── ...
│
├── anspar-spec-compliance/              # Independent plugin
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── README.md
│   ├── LICENSE
│   ├── CHANGELOG.md
│   └── ...
│
├── anspar-requirement-validation/       # Independent plugin
│   └── ... (same structure)
│
└── anspar-traceability-matrix/          # Independent plugin
    └── ... (same structure)
```

### Reference Architecture

Some plugins follow a "thin wrapper" pattern, referencing shared scripts for CI/CD compatibility:

```
anspar-requirement-validation/
└── hooks/
    └── pre-commit-requirement-validation  ← Git hook (plugin)
                 |
                 v
        tools/requirements/
        └── validate_requirements.py       ← Shared script (CI/CD)
```

**Benefits**:
- ✅ Single source of truth
- ✅ Git hooks and CI/CD use same logic
- ✅ No code duplication
- ✅ Updates apply everywhere

## Installation

### Install All Plugins

```bash
# From repository root
git config core.hooksPath .githooks

# Make hooks executable
chmod +x tools/claude-marketplace/*/hooks/*

# Verify installation
.githooks/pre-commit
```

### Install Individual Plugin

Each plugin can be installed independently. See the plugin's README for specific instructions.

**Example** (anspar-linear-integration):
```bash
# Clone just this plugin
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/anspar/diary.git
cd diary
git sparse-checkout set tools/claude-marketplace/anspar-linear-integration

# Follow plugin README for setup
cd tools/claude-marketplace/anspar-linear-integration
cat README.md
```

## Usage

### Claude Code Integration

Claude Code automatically discovers plugins with `.claude-plugin/plugin.json` manifests.

**Available components**:
- **Agents**: AI sub-agents for specialized tasks
- **Hooks**: Git hook integration
- **Commands**: Custom slash commands (not used in these plugins)
- **MCP Servers**: Model Context Protocol servers (not used in these plugins)

### Git Hook Integration

All validation and automation plugins integrate with git pre-commit hook:

```bash
# Hooks run automatically on commit
git add spec/prd-app.md
git commit -m "Update requirements"

# Output:
# ✅ Regenerating traceability matrix...
# ✅ Validating requirements...
# ✅ Checking spec compliance...
# ✅ All validations passed!
```

### Manual Execution

Each plugin can be run manually:

**Spec Compliance**:
```bash
tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh
```

**Requirement Validation**:
```bash
python3 tools/requirements/validate_requirements.py
```

**Traceability Matrix**:
```bash
python3 tools/requirements/generate_traceability.py --format both
```

**Linear Integration**:
```bash
node tools/claude-marketplace/anspar-linear-integration/scripts/fetch-tickets.js
```

## Dependencies

### System Requirements

**All plugins require**:
- Bash >=4.0
- Git

**Individual plugin requirements**:
- **anspar-linear-integration**: Node.js >=18.0.0
- **anspar-spec-compliance**: Claude Code (for AI agent)
- **anspar-requirement-validation**: Python >=3.8
- **anspar-traceability-matrix**: Python >=3.8

### Plugin Dependencies

No inter-plugin dependencies - each plugin is fully independent.

However, plugins work best together:
- **requirement-validation** ensures requirements are valid
- **traceability-matrix** shows requirement relationships
- **spec-compliance** enforces file organization
- **linear-integration** creates tickets from requirements

## Configuration

### Environment Variables

**anspar-linear-integration**:
- `LINEAR_API_TOKEN` (required)
- `LINEAR_TEAM_ID` (optional, auto-discovered)

**Other plugins**: No environment variables required

See individual plugin documentation for details.

### Git Hooks

Customize hook behavior in `.githooks/pre-commit`:
- Execution order
- Error handling
- Conditional execution

## Publishing Plugins

Each plugin can be published independently:

### As npm Package

```bash
cd tools/claude-marketplace/anspar-linear-integration
npm publish
```

### As Git Repository

```bash
# Extract plugin to separate repo
git subtree split --prefix=tools/claude-marketplace/anspar-linear-integration -b plugin-linear
git push git@github.com:anspar/linear-integration.git plugin-linear:main
```

### As Claude Code Plugin

Submit to Claude Code plugin registry (when available).

## Versioning

Each plugin follows [Semantic Versioning](https://semver.org/):
- **Major**: Breaking changes
- **Minor**: New features (backward compatible)
- **Patch**: Bug fixes

See each plugin's CHANGELOG.md for version history.

## License

All plugins are licensed under the MIT License. See individual LICENSE files.

## Contributing

Contributions welcome! Each plugin has its own:
- README.md (usage and development)
- CHANGELOG.md (version history)
- LICENSE (MIT)

## Support

For issues, questions, or contributions:
- **Repository**: https://github.com/anspar/diary
- **Marketplace Path**: `tools/claude-marketplace/`
- **Individual Plugins**: See each plugin's README

## Plugin Development

### Creating a New Plugin

Use existing plugins as templates:

**Bash-only plugin** (no external dependencies):
```bash
cp -r anspar-spec-compliance anspar-new-plugin
cd anspar-new-plugin
# Edit .claude-plugin/plugin.json
# Edit README.md, CHANGELOG.md
# Add your scripts
```

**Node.js plugin** (with dependencies):
```bash
cp -r anspar-linear-integration anspar-new-plugin
cd anspar-new-plugin
# Edit .claude-plugin/plugin.json
# Edit package.json
# Edit README.md, CHANGELOG.md
# Add your scripts
```

**Python plugin** (reference architecture):
```bash
cp -r anspar-requirement-validation anspar-new-plugin
cd anspar-new-plugin
# Edit .claude-plugin/plugin.json
# Edit README.md, CHANGELOG.md
# Add your hooks (reference external scripts)
```

### Plugin Checklist

- [ ] `.claude-plugin/plugin.json` (Claude Code manifest)
- [ ] `package.json` (if Node.js dependencies)
- [ ] `README.md` (standalone documentation)
- [ ] `LICENSE` (MIT)
- [ ] `CHANGELOG.md` (version history)
- [ ] Executable scripts (`chmod +x`)
- [ ] Test locally before publishing

## Related Documentation

- **Project Instructions**: [CLAUDE.md](../../CLAUDE.md)
- **Requirement Format**: [spec/requirements-format.md](../../spec/requirements-format.md)
- **Claude Code Plugins**: https://docs.claude.com/en/docs/claude-code/plugins-reference

## Credits

**Developed by**: Anspar Foundation
**Plugin System**: Claude Code by Anthropic

---

**Version**: 1.0.0
**Last Updated**: 2025-10-30
**Total Plugins**: 5
