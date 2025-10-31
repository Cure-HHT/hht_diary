# Anspar Spec Compliance

**Claude Code Plugin for Specification Compliance Enforcement**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Version](https://img.shields.io/badge/bash-%3E%3D4.0-brightgreen)](https://www.gnu.org/software/bash/)

## Overview

The Anspar Spec Compliance plugin enforces strict adherence to specification guidelines through automated validation and AI-powered analysis. It prevents non-compliant content from entering your repository by validating spec/ directory files at commit time.

**Key Features**:
- ✅ AI-powered validation agent
- ✅ Git pre-commit hook integration
- ✅ Automatic audience scope enforcement (PRD/Ops/Dev)
- ✅ File naming convention validation
- ✅ Code detection in PRD files (forbidden)
- ✅ Requirement format compliance

## Installation

### As Claude Code Plugin

1. Clone or copy this directory to your Claude Code plugins location
2. The plugin will be automatically discovered by Claude Code
3. Configure git hooks (see below)

### As Standalone Tool

```bash
# Clone the repository
git clone https://github.com/anspar/diary.git
cd diary/tools/anspar-marketplace/plugins/anspar-spec-compliance

# Make scripts executable
chmod +x hooks/pre-commit-spec-compliance
chmod +x scripts/validate-spec-compliance.sh
```

## Prerequisites

- **Claude Code**: For AI agent features
- **Git**: For hook integration
- **Bash**: >=4.0
- **spec/**: Directory with specification files following spec/README.md guidelines

## Setup

### 1. Configure Git Hooks

Enable custom git hooks if not already configured:

```bash
# From repository root
git config core.hooksPath .githooks
```

### 2. Integrate with Pre-Commit Hook

Add the spec-compliance hook to your main pre-commit hook at `.githooks/pre-commit`:

```bash
# Spec Compliance Validation (Plugin)
SPEC_COMPLIANCE_HOOK="tools/anspar-marketplace/plugins/anspar-spec-compliance/hooks/pre-commit-spec-compliance"
if [ -f "$SPEC_COMPLIANCE_HOOK" ]; then
    "$SPEC_COMPLIANCE_HOOK" || exit 1
fi
```

### 3. Verify Installation

```bash
# Test the validation script
./tools/anspar-marketplace/plugins/anspar-spec-compliance/scripts/validate-spec-compliance.sh

# Test with a spec file
git add spec/prd-app.md
git commit -m "test" --dry-run
```

## Features

### 1. AI-Powered Validation Agent

**Agent**: `spec-compliance-enforcer`

**Capabilities**:
- Validates file naming conventions
- Enforces audience-specific content restrictions (PRD/Ops/Dev)
- Checks requirement format compliance
- Detects code in PRD files (forbidden)
- Validates hierarchical requirement cascade
- Provides detailed violation reports with remediation steps

**Usage in Claude Code**:

```
I've updated spec/prd-app.md to add some features. Please validate it for compliance.
```

The agent will analyze the file and report any violations with corrective actions.

### 2. Automated Git Hooks

**Pre-commit Hook**: Validates spec/ changes before commit

**Behavior**:
- Automatically runs when spec/*.md files are staged
- Blocks commits with violations
- Can be bypassed with `--no-verify` (not recommended)
- Plays audio alert on validation failure

**Example Output**:
```
📋 Spec Compliance Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Detected changes in spec/ directory:
  - spec/prd-app.md
Running spec compliance checks...
✅ Spec compliance validation passed!
```

### 3. Standalone Validation

**Script**: `scripts/validate-spec-compliance.sh`

**Usage**:
```bash
# Validate all spec/ files
./scripts/validate-spec-compliance.sh

# Validate specific files
./scripts/validate-spec-compliance.sh spec/prd-app.md spec/ops-deployment.md
```

**Features**:
- Color-coded output
- Detailed violation reports
- Summary statistics
- File-by-file analysis

## Validation Rules

### 1. File Naming Convention

**Rule**: Files must follow pattern `{audience}-{topic}(-{subtopic}).md`

**Valid audiences**: `prd-`, `ops-`, `dev-`

**Examples**:
- ✅ `prd-app.md`
- ✅ `ops-deployment.md`
- ✅ `dev-security-RBAC.md`
- ❌ `product-requirements.md` (wrong audience prefix)
- ❌ `app.md` (missing audience prefix)

### 2. Audience Scope Rules

#### PRD files (prd-*)

**Purpose**: Define WHAT and WHY from user/business perspective

**Allowed**:
- User workflows and use cases
- Architecture diagrams (ASCII art)
- Data structure descriptions (conceptual)
- Feature lists and capabilities

**FORBIDDEN**:
- ❌ Code examples (any language)
- ❌ SQL queries or schema DDL
- ❌ CLI commands
- ❌ API endpoint definitions
- ❌ Configuration file examples

#### Ops files (ops-*)

**Purpose**: How to deploy, monitor, and maintain

**Allowed**:
- CLI commands and shell scripts
- Configuration file examples
- Deployment procedures
- Infrastructure setup

#### Dev files (dev-*)

**Purpose**: How to implement features

**Allowed**:
- Code examples in any language
- API definitions
- Implementation patterns
- Technical specifications

### 3. Requirement Format

Requirements must follow the format:

```markdown
### REQ-{type}{number}: {Title}

**Level**: PRD|Ops|Dev | **Implements**: REQ-xxx,REQ-yyy | **Status**: Active|Draft|Deprecated

{Description using SHALL/MUST/MAY}
```

**Types**: `p` (PRD), `o` (Ops), `d` (Dev)

**Example**:
```markdown
### REQ-p00042: User Authentication

**Level**: PRD | **Implements**: - | **Status**: Active

The system SHALL authenticate users via email and password.
```

### 4. Hierarchical Cascade

Requirements must follow top-down cascade:
1. **PRD level** (REQ-p00xxx): Business need
2. **Ops level** (REQ-o00xxx): How to deploy/operate (implements PRD)
3. **Dev level** (REQ-d00xxx): How to implement (implements Ops or PRD)

## Usage

### Automatic Validation (Recommended)

The plugin runs automatically when you commit changes to spec/ files:

```bash
# Normal workflow - validation runs automatically
git add spec/prd-app.md
git commit -m "Update PRD requirements"

# If validation fails, fix issues and retry
# Fix violations...
git add spec/prd-app.md
git commit -m "Update PRD requirements"
```

### Manual Validation

Run validation anytime without committing:

```bash
# Validate all spec/ files
./scripts/validate-spec-compliance.sh

# Validate specific files
./scripts/validate-spec-compliance.sh spec/prd-app.md
```

### AI Agent Invocation

Invoke the spec-compliance-enforcer agent directly in Claude Code:

1. Open Claude Code
2. Use the Task tool with `subagent_type="spec-compliance-enforcer"`
3. Provide context about spec/ changes to validate

Example:
```
I've added new requirements to spec/dev-security-RBAC.md.
Please validate for compliance and check the requirement hierarchy.
```

### Bypassing Validation (Not Recommended)

If you need to commit despite validation failures:

```bash
git commit --no-verify -m "Draft: WIP requirements"
```

**Only bypass for**:
- Draft requirements (fix before pushing)
- Emergency hotfixes (fix immediately after)
- Temporary broken state (fix in next commit)

## Common Violations and Fixes

### Violation: Code in PRD File

**Error**:
```
❌ spec/prd-app.md contains code examples (forbidden in PRD files)
   Line 42: SQL query detected
```

**Fix**:
1. Move code to appropriate dev-* file
2. Reference the dev-* file from PRD
3. Or use conceptual description instead of code

### Violation: Wrong File Naming

**Error**:
```
❌ spec/product-requirements.md: Invalid naming convention
   Expected: {audience}-{topic}.md (e.g., prd-app.md)
```

**Fix**:
```bash
git mv spec/product-requirements.md spec/prd-app.md
```

### Violation: Malformed Requirement

**Error**:
```
❌ spec/dev-api.md: Line 15: Invalid requirement format
   Missing metadata: **Level**: Dev | **Implements**: ... | **Status**: Active
```

**Fix**:
```markdown
### REQ-d00042: API Authentication Implementation

**Level**: Dev | **Implements**: REQ-p00015 | **Status**: Active

The API SHALL implement OAuth2 authentication...
```

### Violation: Missing Parent Requirement

**Error**:
```
❌ REQ-d00042 implements REQ-p00999, but REQ-p00999 not found
```

**Fix**:
1. Create the parent requirement (REQ-p00999)
2. Or update REQ-d00042 to implement correct parent

## Configuration

### Environment Variables

This plugin currently has no required environment variables. Future versions will integrate with Doppler or similar secret management systems.

**Template available**: `scripts/lib/env-validation.sh`

### Validation Behavior

Edit `scripts/validate-spec-compliance.sh` to customize:
- Which files to check
- Validation strictness
- Output verbosity

### Git Hook Behavior

Edit `hooks/pre-commit-spec-compliance` to customize:
- When to trigger validation
- How to handle failures
- Notification behavior

## Troubleshooting

### Validation Fails But Changes Look Correct

**Cause**: Validation script may be out of sync with spec/README.md guidelines

**Solution**:
1. Read spec/README.md for current guidelines
2. Verify your file follows those guidelines
3. If guidelines changed, update validation script
4. If validation is wrong, report issue

### Hook Not Running

**Cause**: Git hooks path not configured or hook not executable

**Solution**:
```bash
# Check git hooks path
git config core.hooksPath

# Should show: .githooks

# If not set:
git config core.hooksPath .githooks

# Make hook executable
chmod +x tools/anspar-marketplace/plugins/anspar-spec-compliance/hooks/pre-commit-spec-compliance
```

### Agent Not Found in Claude Code

**Cause**: Agent not registered or plugin not discovered

**Solution**:
1. Verify plugin.json exists at `.claude-plugin/plugin.json`
2. Restart Claude Code
3. Check Claude Code logs for plugin discovery errors

## Script Reference

### validate-spec-compliance.sh

**Location**: `scripts/validate-spec-compliance.sh`

**Usage**:
```bash
./scripts/validate-spec-compliance.sh [file1] [file2] ...
```

**Exit Codes**:
- `0`: All validations passed
- `1`: Validation failures found

**Options**:
- No arguments: Validate all spec/*.md files
- With arguments: Validate specific files only

### pre-commit-spec-compliance

**Location**: `hooks/pre-commit-spec-compliance`

**Purpose**: Git pre-commit hook wrapper

**Behavior**:
1. Detects changes in spec/ directory
2. Runs validation on changed files
3. Blocks commit if validation fails
4. Plays audio alert on failure

## Dependencies

- **Bash**: >=4.0
- **Git**: For hook integration
- **Claude Code**: For AI agent features (optional)
- **Audio player**: `paplay` (optional, for failure notifications)

## Integration

### With Other Plugins

This plugin works alongside:
- **anspar-requirement-validation**: Validates requirement syntax
- **anspar-traceability-matrix**: Generates traceability matrices

### With CI/CD

Add to your CI pipeline:

```yaml
# .github/workflows/validate.yml
- name: Validate Spec Compliance
  run: |
    chmod +x tools/anspar-marketplace/plugins/anspar-spec-compliance/scripts/validate-spec-compliance.sh
    ./tools/anspar-marketplace/plugins/anspar-spec-compliance/scripts/validate-spec-compliance.sh
```

## License

MIT License - see [LICENSE](./LICENSE) file for details.

## Contributing

This plugin is part of the Anspar Foundation tooling ecosystem. Contributions welcome!

## Credits

**Developed by**: Anspar Foundation
**Plugin System**: Claude Code by Anthropic

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for version history.

## Related Documentation

- **Spec Guidelines**: See spec/README.md in parent project
- **Requirement Format**: See spec/requirements-format.md in parent project
- **Claude Code Plugins**: https://docs.claude.com/en/docs/claude-code/plugins-reference

## Support

For issues, questions, or contributions:
- **Repository**: https://github.com/anspar/diary
- **Plugin Path**: `tools/anspar-marketplace/plugins/anspar-spec-compliance`
