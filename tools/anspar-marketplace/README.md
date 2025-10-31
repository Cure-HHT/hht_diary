# ANSPAR Marketplace

Curated collection of Claude Code plugins for the ANSPAR ecosystem.

## Structure

```
anspar-marketplace/
├── .claude-plugin/
│   └── marketplace.json                  # Marketplace configuration
├── plugins/
│   ├── plugin-expert/                    # Plugin development expert
│   ├── anspar-workflow/                  # Git workflow enforcement
│   ├── anspar-linear-integration/        # Linear API integration
│   ├── anspar-spec-compliance/           # Spec directory compliance
│   ├── anspar-requirement-validation/    # Requirement format validation
│   └── anspar-traceability-matrix/       # Traceability matrix generation
└── README.md
```

**Total Plugins**: 6

## Plugins

### plugin-expert (v1.0.0)
Expert guidance and automation for creating Claude Code plugins with best practices.

**Validation Score**: 100/100 ✅

**Features**:
- Interactive plugin creation with guided interviews
- Template library for common plugin types
- Comprehensive validation (structure, syntax, security, performance)
- Auto-fix capabilities
- Complete documentation generation
- Test suite creation

---

### anspar-workflow (v1.0.0)
Git workflow enforcement for requirement traceability and ticket lifecycle management.

**Implements**: REQ-o00017 (Version Control Workflow)
**Validation Score**: 85/100 ✅

**Features**:
- Per-worktree state management (.git/WORKFLOW_STATE)
- REQ reference validation in commit messages
- Active ticket enforcement before commits
- Paused/resumed ticket workflow
- Distributed worktree support
- Tracker-agnostic design
- Comprehensive audit trail

**Components**: 9 scripts, 4 git hooks, 1 agent

---

### anspar-linear-integration (v1.0.0)
Linear API integration tools for requirement-ticket traceability and project management automation.

**Implements**: REQ-d00027 (Development Environment and Tooling Setup)
**Validation Score**: 95/100 ✅ (A-)

**Features**:
- Batch ticket creation from requirements
- Intelligent caching system (24-hour auto-refresh)
- Environment variable auto-discovery
- Smart labeling and priority assignment
- Subsystem checklist generation
- Duplicate detection and analysis
- 20+ automation scripts

**Components**: 20 scripts, 9 skills, 3 commands, 1 agent

---

### anspar-spec-compliance (v1.0.0)
Enforces spec/ directory compliance through automated validation and AI-powered analysis.

**Implements**: REQ-o00015 (Documentation Structure Enforcement)
**Validation Score**: 100/100 ✅

**Features**:
- AI-powered validation agent
- Git pre-commit hook integration
- File naming convention enforcement
- Audience scope rules (PRD/Ops/Dev)
- Code detection in PRD files
- PostToolUse hook for real-time validation

**Components**: 1 validation script, 1 agent, 2 hooks

---

### anspar-requirement-validation (v1.0.0)
Validates requirement format, uniqueness, and links before commits.

**Implements**: REQ-d00014 (Requirement Validation Tooling)
**Validation Score**: 100/100 ✅

**Features**:
- Requirement format validation (REQ-[pdo]NNNNN)
- Uniqueness checking (no duplicate IDs)
- Link validation (parent requirements exist)
- Level consistency verification
- Git pre-commit hook integration
- References shared validation script (CI/CD compatible)

**Components**: 1 hook script, shared Python validation script

---

### anspar-traceability-matrix (v1.0.0)
Auto-regenerates requirement traceability matrices on spec/ changes.

**Implements**: REQ-d00015 (Traceability Matrix Auto-Generation)
**Validation Score**: 100/100 ✅

**Features**:
- Automatic matrix regeneration on spec/ changes
- Markdown, HTML, and CSV output formats
- Requirement hierarchy visualization
- Implementation tracking (requirements → code)
- Interactive HTML with expand/collapse controls
- Color-coded by level (PRD/Ops/Dev)
- Git pre-commit hook integration

**Components**: 1 hook script, shared Python generation script

## Usage

To use this marketplace with Claude Code:

```bash
# Link the marketplace
claude-code plugin add-marketplace /path/to/anspar-marketplace

# Install a plugin
claude-code plugin install plugin-expert
```

## Adding New Plugins

1. Validate the plugin using plugin-expert
2. Add plugin directory to `plugins/`
3. Update `marketplace.json` with plugin entry
4. Ensure plugin has proper structure and validation score
5. Commit changes

## Validation

All plugins in this marketplace must:
- Have valid `plugin.json` with all required fields
- Follow naming conventions (kebab-case for plugins/commands, PascalCase for agents/skills)
- Pass security checks (no secrets, safe permissions)
- Include comprehensive documentation
- Achieve validation score of 90+
