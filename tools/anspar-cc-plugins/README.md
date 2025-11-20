# Anspar Foundation Plugin Marketplace

**Version**: 1.0.0
**Owner**: Anspar Foundation
**Repository**: https://github.com/anspar-foundation/diary

## Overview

The `anspar-cc-plugins` marketplace provides specialized Claude Code plugins for FDA-compliant clinical trial software development. These plugins enforce requirement traceability, git workflow discipline, and compliance verification for projects following FDA 21 CFR Part 11 standards.

## Plugin Catalog

| Plugin | Version | Purpose |
| --- | --- | --- |
| **plugin-wizard** | 1.0.0 | Create new plugins using 2-phase workflow |
| **linear-api** | 2.0.0 | Generic Linear API integration for ticket management |
| **workflow** | 3.0.0 | Git workflow enforcement with requirement traceability |
| **simple-requirements** | 2.0.0 | Requirement validation and change tracking |
| **requirement-traceability** | 1.0.0 | Requirement-to-ticket traceability mapping |
| **spec-compliance** | 1.0.0 | Automated spec/ directory compliance validation |
| **compliance-verification** | 1.0.0 | FDA 21 CFR Part 11 compliance verification |
| **traceability-matrix** | 1.0.0 | Auto-regenerate traceability matrices |

## Installation

### Important: Project-Level Installation

**These plugins should be installed at the PROJECT level**, not user level. This ensures:
- ✅ Project-specific plugins don't affect other projects
- ✅ Each project can use different plugin versions
- ✅ Team members get consistent plugin configurations
- ✅ Proper plugin isolation and dependency management

### Installation Steps

1. **Ensure the marketplace is in your project**:
   ```bash
   # The marketplace should be located at:
   # your-project/tools/anspar-cc-plugins/

   # Verify marketplace exists:
   ls -la tools/anspar-cc-plugins/.claude-plugin/marketplace.json
   ```

2. **Create/edit project-level settings**:
   ```bash
   # Create .claude directory if it doesn't exist:
   mkdir -p .claude

   # Edit project settings (NOT ~/.claude/settings.json):
   nano .claude/settings.json
   ```

3. **Add plugins to project settings**:
   ```json
   {
     "$schema": "https://json.schemastore.org/claude-code-settings.json",
     "enabledPlugins": {
       "plugin-wizard@anspar-cc-plugins": true,
       "linear-api@anspar-cc-plugins": true,
       "workflow@anspar-cc-plugins": true,
       "simple-requirements@anspar-cc-plugins": true,
       "requirement-traceability@anspar-cc-plugins": true,
       "spec-compliance@anspar-cc-plugins": true,
       "compliance-verification@anspar-cc-plugins": true,
       "traceability-matrix@anspar-cc-plugins": true
     }
   }
   ```

4. **Verify installation**:
   ```bash
   # Restart Claude Code, then check available plugins:
   # In Claude Code, type: /help
   # You should see commands from the installed plugins
   ```

### ⚠️ Common Mistake: User-Level Installation

**DO NOT** add these plugins to `~/.claude/settings.json` (user-level settings) unless you want them available in ALL your projects. User-level plugins are loaded globally, which can cause:
- ❌ Unrelated projects loading diary-specific plugins
- ❌ Plugin version conflicts across projects
- ❌ Unexpected plugin behavior in non-compliant projects
- ❌ Pollution of other projects with FDA-specific workflows

**Correct approach**:
```
✅ Project-level: .claude/settings.json        (plugins for THIS project only)
❌ User-level:    ~/.claude/settings.json      (plugins for ALL projects)
```

## Plugin Details

### Core Plugins

#### plugin-wizard
Creates new plugins using a 2-phase workflow (agent definition → plugin scaffold).

**Use cases**:
- Creating new domain-specific plugins
- Extending marketplace capabilities
- Custom workflow automation

**Documentation**: [plugins/plugin-wizard/README.md](plugins/plugin-wizard/README.md)

---

#### linear-api
Generic Linear API integration for ticket CRUD operations.

**Features**:
- Fetch ticket details by ID
- Create/update tickets
- Search tickets by keyword
- GraphQL API integration

**Prerequisites**:
- Linear API token (from https://linear.app/settings/api)
- Set `LINEAR_API_TOKEN` environment variable

**Documentation**: [plugins/linear-api/README.md](plugins/linear-api/README.md)

---

#### workflow
Enhanced git workflow enforcement with requirement traceability and ticket lifecycle management.

**Features**:
- Per-worktree state management
- Proactive task-switch detection
- Dev container detection warnings
- Secret scanning (gitleaks integration)
- REQ reference validation in commits
- Active ticket enforcement

**Documentation**: [plugins/workflow/README.md](plugins/workflow/README.md)

---

### Compliance Plugins

#### simple-requirements
Comprehensive requirement management: validation, change tracking, and implementation verification.

**Features**:
- Requirement format validation (REQ-{p|o|d}NNNNN)
- Change detection and tracking
- Implementation file verification
- Requirement dependency validation

**Documentation**: [plugins/simple-requirements/README.md](plugins/simple-requirements/README.md)

---

#### requirement-traceability
Requirement-to-ticket traceability for spec/ requirements.

**Features**:
- Maps requirements to Linear tickets
- Validates requirement references in tickets
- Generates traceability reports

**Documentation**: [plugins/requirement-traceability/README.md](plugins/requirement-traceability/README.md)

---

#### spec-compliance
Enforces spec/ directory compliance through automated validation.

**Features**:
- File naming convention validation (prd-*, ops-*, dev-*)
- Audience scope validation (no code in PRD files)
- Requirement format validation
- Pre-commit hook integration

**Documentation**: [plugins/spec-compliance/README.md](plugins/spec-compliance/README.md)

---

#### compliance-verification
FDA 21 CFR Part 11 compliance verification workflows.

**Features**:
- Requirement change detection
- Subsystem impact analysis
- Validation status tracking
- Audit trail verification

**Documentation**: [plugins/compliance-verification/README.md](plugins/compliance-verification/README.md)

---

#### traceability-matrix
Auto-regenerates requirement traceability matrices on spec/ changes.

**Features**:
- Pre-commit hook for automatic regeneration
- HTML/Markdown/CSV output formats
- Multi-sponsor support
- Test coverage mapping

**Documentation**: [plugins/traceability-matrix/README.md](plugins/traceability-matrix/README.md)

---

## Usage Examples

### Claiming a Ticket (workflow plugin)

```bash
# Via slash command:
/workflow:claim CUR-123

# Or use the workflow sub-agent:
# "I need to start work on ticket CUR-123"
```

### Fetching Linear Tickets (linear-api plugin)

```bash
# Via slash command:
/linear:fetch CUR-123

# Or use the linear-api sub-agent:
# "Show me the details for ticket CUR-123"
```

### Validating Spec Compliance (spec-compliance plugin)

```bash
# Automatically runs on pre-commit hook
# Or use the spec-compliance sub-agent:
# "Check if my spec files are compliant"
```

## Development

### Creating New Plugins

See [docs/PLUGIN_DEVELOPMENT.md](docs/PLUGIN_DEVELOPMENT.md) for the 2-phase plugin creation workflow.

**Quick summary**:
1. **Phase 1**: Define agent with `/agent` command
2. **Phase 2**: Use `plugin-wizard` to create plugin scaffold

### Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for marketplace architecture details.

### Orchestration Patterns

See [docs/ORCHESTRATION.md](docs/ORCHESTRATION.md) for agent orchestration best practices.

## Support

- **Issues**: https://github.com/anspar-foundation/diary/issues
- **Email**: plugins@anspar.org
- **Documentation**: See individual plugin README files

## License

MIT License - See individual plugin directories for details.

## Version History

| Version | Date | Changes |
| --- | --- | --- |
| 1.0.0 | 2025-11-09 | Initial marketplace release with 8 plugins |
