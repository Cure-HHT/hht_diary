# Spec Compliance Plugin for Claude Code

**Version**: 1.0.0
**Type**: Validation Plugin
**Status**: Active

## Overview

The spec-compliance plugin enforces strict adherence to specification guidelines defined in `spec/README.md`. It prevents non-compliant content from entering the repository by validating spec/ directory files through automated checks and AI-powered analysis.

## Features

### 1. **AI-Powered Validation Agent**

- **Agent**: `spec-compliance-enforcer`
- **Capabilities**:
  - Validates file naming conventions
  - Enforces audience-specific content restrictions (PRD/Ops/Dev)
  - Checks requirement format compliance
  - Detects code in PRD files (forbidden)
  - Validates hierarchical requirement cascade
  - Provides detailed violation reports with remediation steps

### 2. **Automated Git Hooks**

- **Pre-commit Hook**: Validates spec/ changes before commit
- **Triggers**: Automatically runs when spec/*.md files are staged
- **Blocking**: Prevents commits with violations (can bypass with --no-verify)
- **Notifications**: Plays audio alert on validation failure

### 3. **Standalone Validation**

- **Script**: `validate-spec-compliance.sh`
- **Usage**: Run manually to check spec/ files without committing
- **Features**: Color-coded output, detailed violation reports, summary statistics

## Installation

### Prerequisites

- Claude Code installed and configured
- Git repository with `.githooks/` directory
- Bash shell (version 4.0+)
- Python 3.8+ (for agent invocation)

### Step 1: Enable the Plugin

The plugin is already in your repository at `.claude/plugins/spec-compliance/`.

### Step 2: Configure Git Hooks

If not already configured, enable custom git hooks:

```bash
git config core.hooksPath .githooks
```

### Step 3: Integrate with Main Pre-Commit Hook

Add the spec-compliance hook to your main pre-commit hook at `.githooks/pre-commit`:

```bash
# Add this section to .githooks/pre-commit after existing validation steps

# =====================================================
# 4. Spec Compliance Validation (Plugin)
# =====================================================

if [ -f ".claude/plugins/spec-compliance/hooks/pre-commit-spec-compliance" ]; then
    .claude/plugins/spec-compliance/hooks/pre-commit-spec-compliance
fi
```

### Step 4: Make Scripts Executable

```bash
chmod +x .claude/plugins/spec-compliance/hooks/pre-commit-spec-compliance
chmod +x .claude/plugins/spec-compliance/scripts/validate-spec-compliance.sh
```

### Step 5: Verify Installation

```bash
# Test the validation script
./.claude/plugins/spec-compliance/scripts/validate-spec-compliance.sh

# Test the git hook (dry run)
git diff --cached --name-only | grep '^spec/' && \
  .claude/plugins/spec-compliance/hooks/pre-commit-spec-compliance
```

## Usage

### Automatic Validation (Git Hook)

The plugin runs automatically when you commit changes to spec/ files:

```bash
# Normal commit - validation runs automatically
git add spec/prd-app.md
git commit -m "Update PRD requirements"

# Output:
# 📋 Spec Compliance Validation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Detected changes in spec/ directory:
#   - spec/prd-app.md
# Running spec compliance checks...
# ✅ Spec compliance validation passed!
```

### Manual Validation

Run validation anytime without committing:

```bash
# Validate all spec/ files
./.claude/plugins/spec-compliance/scripts/validate-spec-compliance.sh

# Validate specific files
./.claude/plugins/spec-compliance/scripts/validate-spec-compliance.sh spec/prd-app.md spec/ops-deployment.md
```

### AI Agent Invocation

Invoke the spec-compliance-enforcer agent directly in Claude Code:

1. Open Claude Code
2. Use the Task tool with `subagent_type="spec-compliance-enforcer"`
3. Provide context about spec/ changes to validate

Example:

```
I've updated spec/prd-app.md to add some features. Please validate it for compliance.
```

The agent will:

- Read spec/README.md for current guidelines
- Analyze the modified file
- Report violations with line numbers and corrective actions
- Suggest how to fix issues

### Bypassing Validation (Not Recommended)

If you need to commit despite validation failures:

```bash
git commit --no-verify -m "Draft: WIP requirements"
```

**Warning**: Only bypass for:

- Draft requirements (fix before pushing)
- Emergency hotfixes (fix immediately after)
- Temporary broken state (fix in next commit)

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

#### PRD files (prd-\*)

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

**Action**: Use `/remove-prd-code` command to strip code from PRD files

#### Ops files (ops-\*)

**Purpose**: How to deploy, monitor, and maintain

**Allowed**:

- ✅ CLI commands and scripts
- ✅ Configuration file examples
- ✅ Monitoring queries
- ✅ Runbooks and checklists

#### Dev files (dev-\*)

**Purpose**: How to implement features

**Allowed**:

- ✅ Code examples (any language)
- ✅ API documentation
- ✅ Library usage examples
- ✅ Implementation patterns

### 3. Requirement Format

**Rule**: Requirements must follow format defined in `spec/requirements-format.md`

**Format**: `### REQ-{level}{5-digit-number}: {Title}`

**Valid levels**: `p` (PRD), `o` (Ops), `d` (Dev)

**Example**:

```markdown
### REQ-p00042: User Authentication

The system SHALL authenticate users via email and password.
```

**Requirements**:

- Use prescriptive language: SHALL, MUST, SHOULD, MAY
- Don't describe existing code (use future tense)
- Maintain hierarchical cascade: PRD → Ops → Dev → Code

### 4. Cross-Reference Guidelines

**Rule**: Files should reference other docs instead of duplicating content

**Format**: `**See**: {filename} for {specific topic}`

**Example**:

```markdown
For audit trail implementation, **see**: prd-database.md
For compliance requirements, **see**: prd-clinical-trials.md
```

## Violation Examples and Fixes

### Example 1: Code in PRD File

**Violation**:

```
❌ VIOLATION: spec/prd-mobile-app.md:45-52
Rule: PRD files must not contain code examples
Found: Dart code block implementing user authentication
Action: Remove code block and rewrite as business requirement
```

**Fix**:

Before (❌):

```markdown
## User Authentication

Users are authenticated using the following code:

\`\`\`dart
Future<User> authenticateUser(String email, String password) async {
  final response = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );
  return User.fromJson(response.user);
}
\`\`\`
```

After (✅):

```markdown
## User Authentication

### REQ-p00042: User Authentication

The system SHALL authenticate users via email and password. The authentication process SHALL:

- Accept user credentials (email and password)
- Validate credentials against stored records
- Create authenticated session upon success
- Return user profile data to the application
- Handle authentication failures gracefully

**See**: dev-security.md for implementation details
```

### Example 2: Invalid File Name

**Violation**:

```
❌ Invalid filename format: requirements.md
Expected: {audience}-{topic}(-{subtopic}).md
Valid audiences: prd-, ops-, dev-
```

**Fix**:

```bash
# Rename file to follow convention
git mv spec/requirements.md spec/prd-requirements.md
```

### Example 3: Invalid Requirement Format

**Violation**:

```
❌ Invalid requirement format at line 67
Found: ### REQ-42: User Login
Expected: ### REQ-{p|o|d}00XXX: Title
See: spec/requirements-format.md
```

**Fix**:

Before (❌):

```markdown
### REQ-42: User Login
```

After (✅):

```markdown
### REQ-p00042: User Login
```

## Troubleshooting

### Hook Not Running

**Problem**: Git hook doesn't execute when committing spec/ changes

**Solutions**:

```bash
# 1. Verify hooks path is configured
git config --get core.hooksPath
# Should output: .githooks

# 2. Set hooks path if not configured
git config core.hooksPath .githooks

# 3. Verify hook is executable
ls -l .claude/plugins/spec-compliance/hooks/pre-commit-spec-compliance
# Should show: -rwxr-xr-x

# 4. Make executable if needed
chmod +x .claude/plugins/spec-compliance/hooks/pre-commit-spec-compliance
```

### Validation Script Fails

**Problem**: Validation script exits with errors

**Solutions**:

```bash
# 1. Verify script exists and is executable
ls -l .claude/plugins/spec-compliance/scripts/validate-spec-compliance.sh

# 2. Check for dependencies
which bash grep sed awk

# 3. Run script directly to see full error
bash -x ./.claude/plugins/spec-compliance/scripts/validate-spec-compliance.sh
```

### False Positives

**Problem**: Validation flags valid content as violations

**Solutions**:

1. **ASCII Diagrams in PRD**: Use plain \`\`\` blocks without language tags
2. **External Links**: Links are always allowed, not violations
3. **Architecture Diagrams**: Allowed in any spec/ file

If you believe a validation is incorrect, check `spec/README.md` for the exact rules.

### Agent Not Available

**Problem**: Agent invocation fails

**Solutions**:

```bash
# 1. Verify agent exists
ls -l .claude/plugins/spec-compliance/agent.md

# 2. Verify Claude Code can see the agent
# Open Claude Code and check available agents
# The spec-compliance-enforcer should be listed

# 3. Check Claude Code configuration
cat ~/.claude/config.json
```

## Configuration

### Plugin Configuration

Edit `.claude/plugins/spec-compliance/plugin.json` to customize:

```json
{
  "configuration": {
    "auto_invoke_agent": true,
    "block_on_violation": true,
    "notification_sound": "~/freesound/762115__jerryberumen__alarm-misc-message-alert-notification-quick-short-arp.wav"
  }
}
```

**Options**:

- `auto_invoke_agent`: Automatically invoke AI agent for validation
- `block_on_violation`: Block commits when violations found
- `notification_sound`: Audio file to play on validation failure

### Hook Configuration

Edit `.claude/plugins/spec-compliance/hooks/pre-commit-spec-compliance`:

```bash
# Disable color output
RED=''
GREEN=''
# ... etc

# Change notification sound
NOTIFICATION_SOUND="/path/to/your/sound.wav"
```

## Related Documentation

- **Compliance Rules**: `spec/README.md`
- **Requirement Format**: `spec/requirements-format.md`
- **Remove PRD Code**: `.claude/commands/remove-prd-code.md`
- **Project Instructions**: `CLAUDE.md`
- **Agent Definition**: `.claude/plugins/spec-compliance/agent.md`

## Development

### Plugin Structure

```
.claude/plugins/spec-compliance/
├── plugin.json                           # Plugin metadata
├── README.md                              # This file
├── agent.md                               # AI agent definition
├── hooks/
│   └── pre-commit-spec-compliance         # Git pre-commit hook
└── scripts/
    └── validate-spec-compliance.sh        # Standalone validation script
```

### Adding New Validation Rules

1. **Update agent definition**: Edit `agent.md` to add new rule descriptions
2. **Update validation script**: Add new check functions in `validate-spec-compliance.sh`
3. **Update documentation**: Add examples and troubleshooting to this README
4. **Update spec/README.md**: Document the new compliance rule
5. **Test**: Run validation on existing spec/ files to ensure no false positives

### Testing

```bash
# Test validation script on all spec/ files
./.claude/plugins/spec-compliance/scripts/validate-spec-compliance.sh

# Test specific validation rules by creating test files
mkdir -p /tmp/spec-test
cat > /tmp/spec-test/test-prd.md <<EOF
# Test PRD
\`\`\`sql
SELECT * FROM users;
\`\`\`
EOF

./.claude/plugins/spec-compliance/scripts/validate-spec-compliance.sh /tmp/spec-test/test-prd.md
# Should report violation: PRD file contains code block

# Test git hook
git add spec/prd-app.md
git commit -m "Test commit"
# Should trigger validation
```

## Changelog

### v1.0.0 (2025-10-30)

- Initial release
- AI-powered spec-compliance-enforcer agent
- Pre-commit git hook integration
- Standalone validation script
- Comprehensive validation rules:
  - File naming conventions
  - Audience scope enforcement
  - Requirement format validation
  - PRD code detection

## License

Part of the diary project. See project LICENSE for details.

## Support

For issues or questions:

1. Check this README for troubleshooting
2. Review `spec/README.md` for compliance rules
3. Run validation manually to see detailed output
4. Check Claude Code documentation at docs.claude.com

## Credits

**Agent Definition**: Based on spec/README.md guidelines
**Developed by**: Anspar Foundation
**Powered by**: Claude Code AI Agent System
