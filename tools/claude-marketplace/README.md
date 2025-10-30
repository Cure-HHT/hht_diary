# Claude Code Plugin Marketplace

**Version**: 1.0.0
**Type**: Project-Local Marketplace
**Status**: Active

## Overview

This is the official plugin marketplace for the diary project. It contains curated, production-ready plugins for validation, automation, and development workflows integrated with Claude Code.

All plugins in this marketplace are designed to work together as part of the project's quality assurance and development infrastructure.

## Philosophy

### Reference, Don't Duplicate

Plugins in this marketplace follow a "thin wrapper" pattern:
- **Core implementation** lives in canonical locations (`tools/requirements/`, etc.)
- **Plugins provide integration** (git hooks, AI agents, automation)
- **Single source of truth** - CI/CD and local development use the same code

This ensures consistency across all environments and eliminates version drift.

## Available Plugins

### 1. spec-compliance

**Category**: Validation
**Version**: 1.0.0
**Status**: ✅ Active

**Description**: Enforces spec/ directory compliance through automated validation and AI-powered analysis.

**Features**:
- AI agent (spec-compliance-enforcer) for intelligent validation
- Validates file naming conventions
- Enforces audience scope rules (PRD/Ops/Dev)
- Detects code in PRD files
- Validates requirement format
- Git hook integration

**Components**:
- AI Agent: `agent.md`
- Git Hook: `hooks/pre-commit-spec-compliance`
- Validation Script: `scripts/validate-spec-compliance.sh`

**Documentation**: `spec-compliance/README.md`

---

### 2. requirement-validation

**Category**: Validation
**Version**: 1.0.0
**Status**: ✅ Active

**Description**: Validates requirement format, uniqueness, and links before allowing commits.

**Features**:
- Requirement ID format validation
- Uniqueness checking across all spec/ files
- "Implements" link validation
- Level consistency verification
- Orphaned requirement detection

**Components**:
- Git Hook: `hooks/pre-commit-requirement-validation`
- Implementation: `tools/requirements/validate_requirements.py` (referenced)

**Documentation**: `requirement-validation/README.md`

---

### 3. traceability-matrix

**Category**: Automation
**Version**: 1.0.0
**Status**: ✅ Active

**Description**: Automatically regenerates requirement traceability matrices when spec/ files change.

**Features**:
- Auto-regeneration on spec/ modifications
- Multiple output formats (Markdown, HTML, CSV)
- Interactive HTML with collapsible hierarchy
- Automatic staging of updated matrices
- Requirement relationship visualization

**Components**:
- Git Hook: `hooks/pre-commit-traceability-matrix`
- Implementation: `tools/requirements/generate_traceability.py` (referenced)

**Documentation**: `traceability-matrix/README.md`

---

## Marketplace Structure

```
tools/claude-marketplace/
├── settings.json                           # Marketplace configuration
├── README.md                               # This file
│
├── spec-compliance/
│   ├── plugin.json                         # Plugin metadata
│   ├── README.md                           # Full documentation
│   ├── agent.md                            # AI agent definition
│   ├── hooks/
│   │   └── pre-commit-spec-compliance      # Git hook
│   └── scripts/
│       └── validate-spec-compliance.sh     # Validation script
│
├── requirement-validation/
│   ├── plugin.json                         # Plugin metadata
│   ├── README.md                           # Full documentation
│   └── hooks/
│       └── pre-commit-requirement-validation  # Git hook (calls tools/requirements/)
│
└── traceability-matrix/
    ├── plugin.json                         # Plugin metadata
    ├── README.md                           # Full documentation
    └── hooks/
        └── pre-commit-traceability-matrix     # Git hook (calls tools/requirements/)
```

## Installation

### Prerequisites

- Claude Code installed
- Git repository with `.githooks/` configured
- Python 3.8+
- Bash 4.0+

### Quick Setup

1. **Enable git hooks**:
   ```bash
   git config core.hooksPath .githooks
   ```

2. **Verify marketplace is configured**:
   ```bash
   cat tools/claude-marketplace/settings.json
   ```

3. **Make all hooks executable**:
   ```bash
   chmod +x tools/claude-marketplace/*/hooks/*
   chmod +x tools/claude-marketplace/spec-compliance/scripts/*
   ```

4. **Test plugins**:
   ```bash
   # Test traceability matrix
   tools/claude-marketplace/traceability-matrix/hooks/pre-commit-traceability-matrix

   # Test requirement validation
   tools/claude-marketplace/requirement-validation/hooks/pre-commit-requirement-validation

   # Test spec compliance
   tools/claude-marketplace/spec-compliance/hooks/pre-commit-spec-compliance
   ```

5. **Verify integration**:
   ```bash
   # Main hook should call all plugins
   grep "claude-marketplace" .githooks/pre-commit
   ```

### Individual Plugin Installation

Each plugin can be installed independently. See plugin-specific README.md files for detailed instructions.

## Usage

### Automatic (Git Hooks)

Plugins run automatically when you commit:

```bash
git add spec/prd-app.md
git commit -m "Add new requirement"

# Output shows all plugin validations:
# 1. Dockerfile linting (if Dockerfiles changed)
# 2. Traceability matrix regeneration (if spec/ changed)
# 3. Requirement validation (always)
# 4. Spec compliance validation (if spec/ changed)
```

### Manual Execution

Run plugins manually anytime:

```bash
# Traceability matrix
python3 tools/requirements/generate_traceability.py --format both

# Requirement validation
python3 tools/requirements/validate_requirements.py

# Spec compliance
tools/claude-marketplace/spec-compliance/scripts/validate-spec-compliance.sh
```

### AI Agent (spec-compliance-enforcer)

The spec-compliance-enforcer AI agent can be invoked directly in Claude Code:

1. Open Claude Code
2. Use the Task tool with `subagent_type="spec-compliance-enforcer"`
3. Provide context about spec/ changes to validate

## Plugin Execution Order

Pre-commit hooks run plugins in this sequence:

1. **Dockerfile linting** (hadolint) - If Dockerfiles changed
2. **traceability-matrix** - If spec/ files changed
3. **requirement-validation** - Always
4. **spec-compliance** - If spec/ files changed

This order ensures:
- Matrices are regenerated before validation
- Validation checks the updated state
- Spec compliance is the final gate

## Configuration

### Marketplace Settings

Edit `settings.json` to configure the marketplace:

```json
{
  "plugins": [...],
  "configuration": {
    "auto_enable_new_plugins": false,
    "require_explicit_approval": true,
    "check_dependencies": true
  }
}
```

### Plugin Configuration

Each plugin has its own `plugin.json` for configuration:

```bash
# View plugin config
cat tools/claude-marketplace/spec-compliance/plugin.json
cat tools/claude-marketplace/requirement-validation/plugin.json
cat tools/claude-marketplace/traceability-matrix/plugin.json
```

## Troubleshooting

### Plugins Not Running

**Problem**: Git hooks don't execute plugins

**Solutions**:
```bash
# 1. Verify hooks path
git config --get core.hooksPath
# Should output: .githooks

# 2. Verify main hook calls plugins
cat .githooks/pre-commit | grep claude-marketplace

# 3. Make hooks executable
chmod +x tools/claude-marketplace/*/hooks/*

# 4. Test individual plugin
tools/claude-marketplace/requirement-validation/hooks/pre-commit-requirement-validation
```

### Plugin Not Found Warnings

**Problem**: Hook shows "WARNING: Plugin not found"

**Solutions**:
```bash
# Verify plugin exists
ls -l tools/claude-marketplace/

# Verify hook exists
ls -l tools/claude-marketplace/*/hooks/

# Check file paths in .githooks/pre-commit
cat .githooks/pre-commit
```

### Dependency Issues

**Problem**: Python or bash version issues

**Solutions**:
```bash
# Check Python version (need 3.8+)
python3 --version

# Check Bash version (need 4.0+)
bash --version

# Test scripts directly
python3 tools/requirements/validate_requirements.py
```

## CI/CD Integration

Plugins are designed to work both locally (via git hooks) and in CI/CD pipelines.

**GitHub Actions Example**:
```yaml
name: Validate Requirements
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'

      # Use the same scripts the plugins use
      - name: Validate Requirements
        run: python3 tools/requirements/validate_requirements.py

      - name: Generate Traceability Matrix
        run: python3 tools/requirements/generate_traceability.py --format both
```

This ensures local development and CI/CD use identical validation logic.

## Development

### Adding a New Plugin

1. **Create plugin directory**:
   ```bash
   mkdir -p tools/claude-marketplace/my-plugin/hooks
   ```

2. **Create plugin.json**:
   ```json
   {
     "name": "my-plugin",
     "version": "1.0.0",
     "description": "...",
     "components": { ... }
   }
   ```

3. **Create hook script**:
   ```bash
   touch tools/claude-marketplace/my-plugin/hooks/pre-commit-my-plugin
   chmod +x tools/claude-marketplace/my-plugin/hooks/pre-commit-my-plugin
   ```

4. **Document the plugin**:
   ```bash
   touch tools/claude-marketplace/my-plugin/README.md
   ```

5. **Register in marketplace**:
   Add entry to `settings.json` plugins array

6. **Integrate with main hook**:
   Add call in `.githooks/pre-commit`

### Plugin Standards

All plugins should:
- ✅ Have comprehensive README.md
- ✅ Include plugin.json metadata
- ✅ Be executable (chmod +x)
- ✅ Exit 0 on success, non-zero on failure
- ✅ Provide clear error messages
- ✅ Document dependencies
- ✅ Reference (not duplicate) core implementations when possible

## Related Documentation

- **Git Hooks**: `.githooks/README.md`
- **Project Instructions**: `CLAUDE.md`
- **Requirements Tools**: `tools/requirements/README.md`
- **Spec Guidelines**: `spec/README.md`
- **Requirement Format**: `spec/requirements-format.md`

## Plugin Categories

- **Validation**: Enforce quality standards and compliance
- **Automation**: Automate repetitive tasks
- **AI Integration**: Leverage AI for intelligent analysis
- **Development Tools**: Enhance developer workflows

## Marketplace Metadata

- **Marketplace Name**: diary-marketplace
- **Version**: 1.0.0
- **Type**: project-local
- **Plugins**: 3 active
- **Configuration**: `settings.json`

## Changelog

### v1.0.0 (2025-10-30)

- Initial marketplace release
- 3 plugins: spec-compliance, requirement-validation, traceability-matrix
- Extracted from monolithic `.githooks/pre-commit`
- Implemented reference-based architecture (no code duplication)
- Full documentation for each plugin
- Marketplace configuration and metadata

## License

Part of the diary project. See project LICENSE for details.

## Support

For issues or questions about plugins:
1. Check plugin-specific README.md
2. Verify installation steps followed correctly
3. Test plugin independently
4. Check related documentation
5. Review git hook logs

Each plugin is production-ready and actively maintained as part of the project infrastructure.
