# Anspar Marketplace - Comprehensive Test Plan

**Version**: 1.0.0
**Last Updated**: 2025-10-30
**Purpose**: Systematic testing of all anspar-marketplace Claude Code plugins

---

## Overview

This test plan provides comprehensive test procedures for all plugins in the anspar-marketplace. Use this document to:

- ✅ Validate plugin installation and configuration
- ✅ Test all features and components systematically
- ✅ Verify integration with git hooks and Claude Code
- ✅ Ensure plugins work in worktree environments
- ✅ Document test results for future reference

---

## Test Environment Setup

### Prerequisites

Before running tests, ensure:

- [ ] **Git**: Repository configured with custom hooks path
  ```bash
  git config core.hooksPath .githooks
  ```

- [ ] **Node.js**: >=18.0.0 (for anspar-linear-integration)
  ```bash
  node --version
  ```

- [ ] **Python**: >=3.8 (for validation/traceability plugins)
  ```bash
  python3 --version
  ```

- [ ] **Bash**: >=4.0
  ```bash
  bash --version
  ```

- [ ] **jq**: JSON processor
  ```bash
  jq --version
  ```

- [ ] **Claude Code**: Latest version installed

### Environment Variables

Set up required environment variables:

```bash
# For anspar-linear-integration
export LINEAR_API_TOKEN="lin_api_YOUR_TOKEN"
export LINEAR_TEAM_ID="your-team-id"  # Optional - auto-discovered

# For workflow testing (optional)
export TEST_WORKTREE_PATH="/path/to/test/worktree"
```

### Test Worktree Creation

Create a clean test worktree for testing:

```bash
# From main repository
git worktree add ../diary-test-worktree test-plugins

# Navigate to test worktree
cd ../diary-test-worktree
```

---

## Plugin Test Matrix

| Plugin | Git Hooks | AI Agent | Scripts | Node.js | Python | Status |
|--------|-----------|----------|---------|---------|--------|--------|
| anspar-workflow | ✅ | ✅ | ✅ | ❌ | ❌ | 🟢 |
| anspar-spec-compliance | ✅ | ❌ | ✅ | ❌ | ❌ | 🟡 |
| anspar-requirement-validation | ✅ | ❌ | ❌ | ❌ | ✅ | 🟡 |
| anspar-traceability-matrix | ✅ | ❌ | ❌ | ❌ | ✅ | 🟡 |
| anspar-linear-integration | ❌ | ❌ | ✅ | ✅ | ❌ | 🟡 |

**Legend**: 🟢 Fully tested | 🟡 Partially tested | 🔴 Not tested

---

## Test Procedures by Plugin

### 1. anspar-workflow

**Category**: Workflow Enforcement
**Components**: Git hooks, Session hook, Scripts, AI agent
**Test Environment**: Requires worktree

#### 1.1 Installation Tests

- [ ] **Hook Installation**
  ```bash
  # Verify hooks are executable
  test -x tools/claude-marketplace/anspar-workflow/hooks/pre-commit && echo "✅ pre-commit"
  test -x tools/claude-marketplace/anspar-workflow/hooks/commit-msg && echo "✅ commit-msg"
  test -x tools/claude-marketplace/anspar-workflow/hooks/post-commit && echo "✅ post-commit"
  test -x tools/claude-marketplace/anspar-workflow/hooks/session-start && echo "✅ session-start"
  ```

- [ ] **Script Installation**
  ```bash
  # Verify all workflow scripts are executable
  for script in tools/claude-marketplace/anspar-workflow/scripts/*.sh; do
    test -x "$script" && echo "✅ $(basename $script)" || echo "❌ $(basename $script)"
  done
  ```

#### 1.2 Worktree State Management Tests

- [ ] **WORKFLOW_STATE Path Resolution**
  ```bash
  # Test in regular repo
  cd /path/to/regular/repo
  ./tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh TEST-001

  # Verify state file location
  GIT_DIR=$(git rev-parse --git-dir)
  test -f "$GIT_DIR/WORKFLOW_STATE" && echo "✅ Regular repo state file" || echo "❌ FAILED"

  # Test in worktree
  cd /path/to/worktree
  ./tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh TEST-002

  # Verify state file location (should be in .git/worktrees/...)
  GIT_DIR=$(git rev-parse --git-dir)
  test -f "$GIT_DIR/WORKFLOW_STATE" && echo "✅ Worktree state file" || echo "❌ FAILED"
  echo "State file location: $GIT_DIR/WORKFLOW_STATE"
  ```

- [ ] **Claim Ticket**
  ```bash
  cd tools/claude-marketplace/anspar-workflow
  ./scripts/claim-ticket.sh TEST-001

  # Expected: Creates WORKFLOW_STATE with activeTicket.id = "TEST-001"
  ```

- [ ] **Check Active Ticket**
  ```bash
  ./scripts/check-active-ticket.sh
  # Expected output: TEST-001

  ./scripts/get-active-ticket.sh --format=human
  # Expected: Full ticket details
  ```

- [ ] **Release Ticket**
  ```bash
  ./scripts/release-ticket.sh "Testing complete"

  # Expected: activeTicket = null, history preserved
  ```

#### 1.3 Ticket Lifecycle Tests

- [ ] **Switch Ticket Workflow**
  ```bash
  ./scripts/claim-ticket.sh TEST-001
  ./scripts/switch-ticket.sh TEST-002 "Focus pivot"

  # Expected: TEST-001 released, TEST-002 claimed, history shows both
  ```

- [ ] **Resume Ticket Workflow**
  ```bash
  ./scripts/claim-ticket.sh TEST-003
  ./scripts/release-ticket.sh "Pausing work"
  ./scripts/resume-ticket.sh TEST-003

  # Expected: TEST-003 re-claimed, history shows claim → release → claim
  ```

- [ ] **Resume Interactive Selection**
  ```bash
  ./scripts/resume-ticket.sh

  # Expected: Shows list of recently released tickets, allows selection
  ```

- [ ] **History Viewing**
  ```bash
  ./scripts/list-history.sh
  ./scripts/list-history.sh --limit=5
  ./scripts/list-history.sh --action=claim
  ./scripts/list-history.sh --format=json

  # Expected: Formatted history with all actions
  ```

#### 1.4 Git Hook Tests

- [ ] **Pre-Commit Hook (Active Ticket Enforcement)**
  ```bash
  # Without active ticket (should fail)
  ./scripts/release-ticket.sh "Testing"
  echo "test" > test.txt
  git add test.txt
  git commit -m "Test commit"
  # Expected: ❌ ERROR: No active ticket claimed

  # With active ticket (should succeed)
  ./scripts/claim-ticket.sh TEST-001
  git commit -m "Test commit\n\nImplements: REQ-d00001"
  # Expected: ✅ Commit succeeds
  ```

- [ ] **Commit-Msg Hook (REQ Reference Validation)**
  ```bash
  ./scripts/claim-ticket.sh TEST-001
  echo "test" > test.txt
  git add test.txt

  # Without REQ reference (should fail)
  git commit -m "Test commit"
  # Expected: ❌ ERROR: Commit message must contain requirement reference

  # With REQ reference (should succeed)
  git commit -m "Test commit\n\nImplements: REQ-d00027"
  # Expected: ✅ Commit succeeds
  ```

- [ ] **Post-Commit Hook (History Recording)**
  ```bash
  ./scripts/claim-ticket.sh TEST-001
  echo "test" > test.txt
  git add test.txt
  git commit -m "Test\n\nImplements: REQ-d00027"

  # Check history for commit record
  ./scripts/list-history.sh --action=commit
  # Expected: Shows commit with hash and REQ references
  ```

- [ ] **Session-Start Hook**
  ```bash
  # Run session-start hook manually
  ./tools/claude-marketplace/anspar-workflow/hooks/session-start

  # Expected: JSON output with workflow status
  # If active ticket: Shows ticket ID and recent commits
  # If no ticket: Shows warning to claim ticket
  ```

#### 1.5 REQ Suggestion Tests

- [ ] **Suggest REQ from Active Ticket**
  ```bash
  ./scripts/claim-ticket.sh CUR-262  # Ticket with requirements
  ./scripts/suggest-req.sh

  # Expected: Lists REQ IDs from ticket's requirements array
  ```

- [ ] **Suggest REQ from Recent Commits**
  ```bash
  # Make a commit with REQ references
  ./scripts/claim-ticket.sh TEST-001
  echo "test" > test.txt
  git add test.txt
  git commit -m "Test\n\nImplements: REQ-d00027"

  # Suggest should show REQ-d00027
  ./scripts/suggest-req.sh
  ```

- [ ] **Suggest REQ from Changed Files**
  ```bash
  # Edit a file with REQ references in header
  echo "# IMPLEMENTS REQUIREMENTS: REQ-p00042" > test-code.sql
  git add test-code.sql
  ./scripts/suggest-req.sh

  # Expected: Shows REQ-p00042
  ```

#### 1.6 Multiple Worktree Tests

- [ ] **Independent State Across Worktrees**
  ```bash
  # Worktree 1
  cd /path/to/worktree1
  ./tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh WT1-TICKET

  # Worktree 2
  cd /path/to/worktree2
  ./tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh WT2-TICKET

  # Verify independence
  cd /path/to/worktree1
  ./tools/claude-marketplace/anspar-workflow/scripts/get-active-ticket.sh --format=id
  # Expected: WT1-TICKET

  cd /path/to/worktree2
  ./tools/claude-marketplace/anspar-workflow/scripts/get-active-ticket.sh --format=id
  # Expected: WT2-TICKET
  ```

- [ ] **Same Ticket in Multiple Worktrees (Valid Scenario)**
  ```bash
  # Worktree 1: Implementation
  cd /path/to/worktree1
  ./tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh SHARED-TICKET

  # Worktree 2: Tests for same feature
  cd /path/to/worktree2
  ./tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh SHARED-TICKET

  # Expected: Both succeed - multiple worktrees can work on same ticket
  ```

#### 1.7 Agent Integration Tests

- [ ] **Workflow Enforcer Agent Invocation**
  ```
  # In Claude Code session:
  # (These are manual tests to perform in Claude Code interface)

  1. Start Claude Code session in worktree without active ticket
  2. Attempt to commit changes
  3. Expected: Agent should proactively warn about missing active ticket

  4. Claim ticket via script
  5. Attempt commit without REQ reference
  6. Expected: Agent should suggest REQ references
  ```

---

### 2. anspar-spec-compliance

**Category**: Validation
**Components**: Git hook, Validation script, AI agent
**Test Environment**: Requires spec/ directory with test files

#### 2.1 Installation Tests

- [ ] **Hook Installation**
  ```bash
  test -x tools/claude-marketplace/anspar-spec-compliance/hooks/pre-commit-spec-compliance && echo "✅ pre-commit hook"
  ```

- [ ] **Script Installation**
  ```bash
  test -x tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh && echo "✅ validation script"
  ```

#### 2.2 File Naming Validation Tests

- [ ] **Valid Naming Conventions**
  ```bash
  # Create test files
  touch spec/prd-test.md
  touch spec/ops-test-deployment.md
  touch spec/dev-test-api.md

  # Run validation
  ./tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh

  # Expected: ✅ All files pass naming validation
  ```

- [ ] **Invalid Naming Conventions**
  ```bash
  # Create invalid test files
  touch spec/product-requirements.md  # Wrong prefix
  touch spec/test.md                  # Missing audience prefix

  # Run validation
  ./tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh

  # Expected: ❌ Errors reported for naming violations

  # Clean up
  git checkout spec/
  ```

#### 2.3 Audience Scope Tests

- [ ] **PRD Files - Code Detection**
  ```bash
  # Create PRD file with code (forbidden)
  cat > spec/prd-test-violation.md <<'EOF'
  # Test PRD

  ## Feature

  User authentication shall work like this:

  ```sql
  SELECT * FROM users WHERE email = 'test@example.com';
  ```
  EOF

  # Run validation
  ./tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh spec/prd-test-violation.md

  # Expected: ❌ Error: Code detected in PRD file

  # Clean up
  rm spec/prd-test-violation.md
  ```

- [ ] **Ops Files - CLI Commands Allowed**
  ```bash
  # Create ops file with CLI commands (allowed)
  cat > spec/ops-test-allowed.md <<'EOF'
  # Test Ops

  ## Deployment

  Deploy with:

  ```bash
  kubectl apply -f deployment.yaml
  ```
  EOF

  # Run validation
  ./tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh spec/ops-test-allowed.md

  # Expected: ✅ Passes validation

  # Clean up
  rm spec/ops-test-allowed.md
  ```

- [ ] **Dev Files - Code Allowed**
  ```bash
  # Create dev file with code (allowed)
  cat > spec/dev-test-allowed.md <<'EOF'
  # Test Dev

  ## Implementation

  ```dart
  class AuthService {
    Future<User> login(String email, String password) {
      // Implementation
    }
  }
  ```
  EOF

  # Run validation
  ./tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh spec/dev-test-allowed.md

  # Expected: ✅ Passes validation

  # Clean up
  rm spec/dev-test-allowed.md
  ```

#### 2.4 Requirement Format Tests

- [ ] **Valid Requirement Format**
  ```bash
  # Create file with valid requirement
  cat > spec/test-req-valid.md <<'EOF'
  ### REQ-p00999: Test Requirement

  **Level**: PRD | **Implements**: - | **Status**: Active

  The system SHALL provide test functionality.
  EOF

  # Run validation
  ./tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh spec/test-req-valid.md

  # Expected: ✅ Passes

  # Clean up
  rm spec/test-req-valid.md
  ```

- [ ] **Invalid Requirement Format**
  ```bash
  # Create file with invalid requirement
  cat > spec/test-req-invalid.md <<'EOF'
  ### REQ-p00999: Test Requirement

  The system will provide test functionality.
  EOF

  # Run validation
  ./tools/claude-marketplace/anspar-spec-compliance/scripts/validate-spec-compliance.sh spec/test-req-invalid.md

  # Expected: ❌ Error: Missing metadata

  # Clean up
  rm spec/test-req-invalid.md
  ```

#### 2.5 Git Hook Integration Tests

- [ ] **Automatic Validation on Commit**
  ```bash
  # Create valid spec file
  echo "# Test PRD" > spec/prd-test.md
  git add spec/prd-test.md
  git commit -m "Test spec compliance"

  # Expected: Validation runs automatically, commit succeeds

  # Clean up
  git reset HEAD~1
  rm spec/prd-test.md
  ```

- [ ] **Validation Blocks Invalid Commits**
  ```bash
  # Create invalid spec file (code in PRD)
  cat > spec/prd-invalid.md <<'EOF'
  ```sql
  SELECT * FROM users;
  ```
  EOF

  git add spec/prd-invalid.md
  git commit -m "Test invalid spec"

  # Expected: ❌ Commit blocked, validation error shown

  # Clean up
  git reset
  rm spec/prd-invalid.md
  ```

#### 2.6 AI Agent Tests (Manual)

- [ ] **Spec Compliance Enforcer Agent**
  ```
  # In Claude Code session:

  1. Create spec file with violations
  2. Ask Claude: "Validate spec/prd-test.md for compliance"
  3. Expected: Agent identifies violations with remediation steps

  4. Fix violations
  5. Ask Claude to validate again
  6. Expected: Agent confirms compliance
  ```

---

### 3. anspar-requirement-validation

**Category**: Validation
**Components**: Git hook, Python validation script (shared)
**Test Environment**: Requires spec/ directory, Python

#### 3.1 Installation Tests

- [ ] **Hook Installation**
  ```bash
  test -x tools/claude-marketplace/anspar-requirement-validation/hooks/pre-commit-requirement-validation && echo "✅ pre-commit hook"
  ```

- [ ] **Validation Script Exists**
  ```bash
  test -f tools/requirements/validate_requirements.py && echo "✅ validation script"
  ```

#### 3.2 Requirement Format Validation

- [ ] **Valid Requirement Format**
  ```bash
  # Run validation on all specs
  python3 tools/requirements/validate_requirements.py

  # Expected: ✅ No errors, shows requirement count
  ```

- [ ] **Invalid Requirement ID Format**
  ```bash
  # Create spec with invalid REQ ID
  cat > spec/test-invalid-id.md <<'EOF'
  ### REQ-invalid: Bad Format

  **Level**: PRD | **Implements**: - | **Status**: Active

  Test SHALL work.
  EOF

  python3 tools/requirements/validate_requirements.py spec/test-invalid-id.md

  # Expected: ❌ Error: Invalid requirement ID format

  # Clean up
  rm spec/test-invalid-id.md
  ```

#### 3.3 Uniqueness Validation

- [ ] **Duplicate Requirement Detection**
  ```bash
  # Create two files with same REQ ID
  cat > spec/test-dup-1.md <<'EOF'
  ### REQ-p00998: Duplicate Test

  **Level**: PRD | **Implements**: - | **Status**: Active

  Test SHALL work.
  EOF

  cat > spec/test-dup-2.md <<'EOF'
  ### REQ-p00998: Duplicate Test Copy

  **Level**: PRD | **Implements**: - | **Status**: Active

  Test SHALL work differently.
  EOF

  python3 tools/requirements/validate_requirements.py

  # Expected: ❌ Error: Duplicate requirement ID REQ-p00998

  # Clean up
  rm spec/test-dup-*.md
  ```

#### 3.4 Link Validation

- [ ] **Parent Requirement Exists**
  ```bash
  # Create child without parent
  cat > spec/test-orphan.md <<'EOF'
  ### REQ-d00997: Orphan Requirement

  **Level**: Dev | **Implements**: REQ-p99999 | **Status**: Active

  Implementation SHALL exist.
  EOF

  python3 tools/requirements/validate_requirements.py

  # Expected: ⚠️ Warning: REQ-d00997 implements non-existent REQ-p99999

  # Clean up
  rm spec/test-orphan.md
  ```

- [ ] **Valid Parent-Child Hierarchy**
  ```bash
  # Create parent and child
  cat > spec/test-parent.md <<'EOF'
  ### REQ-p00996: Parent Requirement

  **Level**: PRD | **Implements**: - | **Status**: Active

  Parent SHALL exist.
  EOF

  cat > spec/test-child.md <<'EOF'
  ### REQ-d00995: Child Requirement

  **Level**: Dev | **Implements**: REQ-p00996 | **Status**: Active

  Implementation SHALL reference parent.
  EOF

  python3 tools/requirements/validate_requirements.py

  # Expected: ✅ Validation passes, no orphan warnings

  # Clean up
  rm spec/test-parent.md spec/test-child.md
  ```

#### 3.5 Git Hook Integration

- [ ] **Automatic Validation on Commit**
  ```bash
  # Modify existing spec
  echo "" >> spec/prd-app.md
  git add spec/prd-app.md
  git commit -m "Test requirement validation"

  # Expected: Validation runs, shows requirement count

  # Clean up
  git reset HEAD~1
  git checkout spec/prd-app.md
  ```

---

### 4. anspar-traceability-matrix

**Category**: Automation
**Components**: Git hook, Python generation script (shared)
**Test Environment**: Requires spec/ directory, Python

#### 4.1 Installation Tests

- [ ] **Hook Installation**
  ```bash
  test -x tools/claude-marketplace/anspar-traceability-matrix/hooks/pre-commit-traceability-matrix && echo "✅ pre-commit hook"
  ```

- [ ] **Generation Script Exists**
  ```bash
  test -f tools/requirements/generate_traceability.py && echo "✅ generation script"
  ```

#### 4.2 Matrix Generation Tests

- [ ] **Markdown Matrix Generation**
  ```bash
  python3 tools/requirements/generate_traceability.py --format markdown

  # Expected: Creates traceability_matrix.md
  test -f traceability_matrix.md && echo "✅ Markdown matrix generated"

  # Verify content
  grep -q "## PRD Requirements" traceability_matrix.md && echo "✅ Contains PRD section"
  grep -q "## Ops Requirements" traceability_matrix.md && echo "✅ Contains Ops section"
  grep -q "## Dev Requirements" traceability_matrix.md && echo "✅ Contains Dev section"
  ```

- [ ] **HTML Matrix Generation**
  ```bash
  python3 tools/requirements/generate_traceability.py --format html

  # Expected: Creates traceability_matrix.html
  test -f traceability_matrix.html && echo "✅ HTML matrix generated"

  # Verify it's valid HTML
  grep -q "<html>" traceability_matrix.html && echo "✅ Valid HTML structure"
  grep -q "<style>" traceability_matrix.html && echo "✅ Contains styling"
  ```

- [ ] **Both Formats Generation**
  ```bash
  python3 tools/requirements/generate_traceability.py --format both

  # Expected: Creates both files
  test -f traceability_matrix.md && test -f traceability_matrix.html && echo "✅ Both formats generated"
  ```

#### 4.3 Matrix Content Validation

- [ ] **Hierarchy Representation**
  ```bash
  # Generate matrix
  python3 tools/requirements/generate_traceability.py --format markdown

  # Check for parent-child relationships
  grep -A 5 "REQ-p00042" traceability_matrix.md | grep -q "Implemented By:" && echo "✅ Shows implementation hierarchy"
  ```

- [ ] **Implementation Tracking**
  ```bash
  # Generate matrix
  python3 tools/requirements/generate_traceability.py --format markdown

  # Check for code references
  grep -q "Implemented In Code:" traceability_matrix.md && echo "✅ Shows code implementations"
  ```

- [ ] **File Locations**
  ```bash
  # Generate matrix
  python3 tools/requirements/generate_traceability.py --format markdown

  # Check for file paths
  grep -q "**File**:" traceability_matrix.md && echo "✅ Shows file locations"
  ```

#### 4.4 Git Hook Integration

- [ ] **Automatic Regeneration on Spec Changes**
  ```bash
  # Modify spec file
  echo "" >> spec/prd-app.md
  git add spec/prd-app.md
  git commit -m "Test matrix regeneration"

  # Expected: Hook regenerates matrices and adds to commit
  git show HEAD --name-only | grep -q "traceability_matrix.md" && echo "✅ Markdown added to commit"
  git show HEAD --name-only | grep -q "traceability_matrix.html" && echo "✅ HTML added to commit"

  # Clean up
  git reset HEAD~1
  git checkout spec/prd-app.md traceability_matrix.*
  ```

- [ ] **No Regeneration on Non-Spec Changes**
  ```bash
  # Modify non-spec file
  echo "test" > test.txt
  git add test.txt

  # Get matrix timestamp before commit
  BEFORE=$(stat -c %Y traceability_matrix.md 2>/dev/null || echo 0)

  git commit -m "Test non-spec change"

  # Get matrix timestamp after commit
  AFTER=$(stat -c %Y traceability_matrix.md 2>/dev/null || echo 0)

  # Expected: Matrix not regenerated
  [ "$BEFORE" -eq "$AFTER" ] && echo "✅ Matrix not regenerated for non-spec changes"

  # Clean up
  git reset HEAD~1
  rm test.txt
  ```

---

### 5. anspar-linear-integration

**Category**: Integration
**Components**: Node.js scripts, Environment setup
**Test Environment**: Requires LINEAR_API_TOKEN, Node.js, spec/ directory

#### 5.1 Installation Tests

- [ ] **Node.js Version**
  ```bash
  node --version | grep -qE 'v(1[8-9]|[2-9][0-9])' && echo "✅ Node.js >=18.0.0"
  ```

- [ ] **Scripts Executable**
  ```bash
  for script in tools/claude-marketplace/anspar-linear-integration/scripts/*.sh; do
    test -x "$script" && echo "✅ $(basename $script)" || echo "❌ $(basename $script)"
  done
  ```

#### 5.2 Environment Setup Tests

- [ ] **Environment Variable Auto-Discovery**
  ```bash
  # Test setup-env.sh
  source tools/claude-marketplace/anspar-linear-integration/scripts/setup-env.sh

  # Expected: Discovers and exports LINEAR_TEAM_ID
  [ -n "$LINEAR_TEAM_ID" ] && echo "✅ LINEAR_TEAM_ID discovered: $LINEAR_TEAM_ID"
  ```

- [ ] **Manual Environment Variables**
  ```bash
  export LINEAR_API_TOKEN="lin_api_test"
  export LINEAR_TEAM_ID="test-team-id"

  # Run a script to verify it reads env vars
  node tools/claude-marketplace/anspar-linear-integration/scripts/fetch-tickets.js --dry-run

  # Expected: Script acknowledges environment variables
  ```

#### 5.3 Caching System Tests

- [ ] **Cache Creation**
  ```bash
  # Remove existing cache
  rm -f tools/claude-marketplace/anspar-linear-integration/scripts/config/requirement-ticket-cache.json

  # Run script that uses cache
  node tools/claude-marketplace/anspar-linear-integration/scripts/create-requirement-tickets.js \
    --token=$LINEAR_API_TOKEN \
    --team-id=$LINEAR_TEAM_ID \
    --dry-run

  # Expected: Cache file created
  test -f tools/claude-marketplace/anspar-linear-integration/scripts/config/requirement-ticket-cache.json && echo "✅ Cache created"
  ```

- [ ] **Cache Age Detection**
  ```bash
  # Create old cache (older than 24 hours)
  touch -t 202301010000 tools/claude-marketplace/anspar-linear-integration/scripts/config/requirement-ticket-cache.json

  # Run script
  node tools/claude-marketplace/anspar-linear-integration/scripts/create-requirement-tickets.js \
    --token=$LINEAR_API_TOKEN \
    --team-id=$LINEAR_TEAM_ID \
    --dry-run

  # Expected: Reports stale cache and refreshes
  ```

- [ ] **Force Cache Refresh**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/create-requirement-tickets.js \
    --token=$LINEAR_API_TOKEN \
    --team-id=$LINEAR_TEAM_ID \
    --refresh-cache \
    --dry-run

  # Expected: Refreshes cache regardless of age
  ```

#### 5.4 Ticket Fetching Tests

- [ ] **Fetch Assigned Tickets**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/fetch-tickets.js \
    --token=$LINEAR_API_TOKEN

  # Expected: Lists tickets assigned to you with REQ references
  ```

- [ ] **Fetch by Label**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/fetch-tickets-by-label.js \
    --token=$LINEAR_API_TOKEN \
    --label="ai:new"

  # Expected: Lists all tickets with "ai:new" label
  ```

- [ ] **JSON Output Format**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/fetch-tickets.js \
    --token=$LINEAR_API_TOKEN \
    --format=json | jq '.' > /dev/null

  # Expected: Valid JSON output
  [ $? -eq 0 ] && echo "✅ Valid JSON output"
  ```

#### 5.5 Ticket Creation Tests

- [ ] **Dry Run Mode**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/create-requirement-tickets.js \
    --token=$LINEAR_API_TOKEN \
    --team-id=$LINEAR_TEAM_ID \
    --dry-run

  # Expected: Shows what would be created without making API calls
  ```

- [ ] **Level Filtering**
  ```bash
  # PRD only
  node tools/claude-marketplace/anspar-linear-integration/scripts/create-requirement-tickets.js \
    --token=$LINEAR_API_TOKEN \
    --team-id=$LINEAR_TEAM_ID \
    --level=PRD \
    --dry-run

  # Expected: Only shows PRD-level requirements
  ```

- [ ] **Smart Labeling**
  ```bash
  # Check that security requirements get security label
  node tools/claude-marketplace/anspar-linear-integration/scripts/create-requirement-tickets.js \
    --token=$LINEAR_API_TOKEN \
    --team-id=$LINEAR_TEAM_ID \
    --dry-run | grep -A 5 "security\|auth" | grep -q "security"

  # Expected: Security-related requirements show "security" label
  [ $? -eq 0 ] && echo "✅ Smart labeling works"
  ```

#### 5.6 Ticket Management Tests

- [ ] **Update Ticket with Requirement**
  ```bash
  # Note: Requires actual ticket ID
  TICKET_ID="<actual-linear-ticket-uuid>"

  node tools/claude-marketplace/anspar-linear-integration/scripts/update-ticket-with-requirement.js \
    --token=$LINEAR_API_TOKEN \
    --ticket-id=$TICKET_ID \
    --req-id=p00042

  # Expected: Ticket description updated with "**Requirement**: REQ-p00042"
  ```

- [ ] **Add Subsystem Checklists**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/add-subsystem-checklists.js \
    --token=$LINEAR_API_TOKEN \
    --dry-run

  # Expected: Shows which tickets would get checklists
  ```

#### 5.7 Analysis Tools Tests

- [ ] **Duplicate Detection**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/check-duplicates.js \
    --token=$LINEAR_API_TOKEN

  # Expected: Reports any duplicate requirement-ticket mappings
  ```

- [ ] **Advanced Duplicate Analysis**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/check-duplicates-advanced.js \
    --token=$LINEAR_API_TOKEN

  # Expected: Deep analysis with similarity detection
  ```

- [ ] **Infrastructure Ticket Listing**
  ```bash
  node tools/claude-marketplace/anspar-linear-integration/scripts/list-infrastructure-tickets.js \
    --token=$LINEAR_API_TOKEN

  # Expected: Lists all tickets with "infrastructure" label
  ```

#### 5.8 Batch Operations Tests

- [ ] **Dry Run All Levels**
  ```bash
  cd tools/claude-marketplace/anspar-linear-integration/scripts
  ./run-dry-run-all.sh

  # Expected: Shows preview of PRD, Ops, and Dev tickets to create
  ```

- [ ] **Create Tickets Script**
  ```bash
  cd tools/claude-marketplace/anspar-linear-integration/scripts
  # Note: This creates real tickets - use with caution!
  # ./create-tickets.sh

  # Expected: Creates tickets in batches with pauses for review
  ```

---

## Integration Tests

### Cross-Plugin Integration

- [ ] **Workflow + Requirement Validation**
  ```bash
  # Claim ticket
  tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh TEST-001

  # Create commit with valid REQ
  echo "test" > test.txt
  git add test.txt
  git commit -m "Test\n\nImplements: REQ-d00027"

  # Expected: Both workflow and requirement validation pass
  ```

- [ ] **Spec Compliance + Requirement Validation**
  ```bash
  # Create spec file with valid requirement
  cat > spec/test-integration.md <<'EOF'
  ### REQ-p00994: Integration Test

  **Level**: PRD | **Implements**: - | **Status**: Active

  Integration SHALL work.
  EOF

  git add spec/test-integration.md
  git commit -m "Test integration\n\nImplements: REQ-p00994"

  # Expected: All plugins validate successfully

  # Clean up
  git reset HEAD~1
  rm spec/test-integration.md
  ```

- [ ] **Traceability Matrix + Linear Integration**
  ```bash
  # Generate matrix
  python3 tools/requirements/generate_traceability.py --format markdown

  # Create tickets from requirements
  node tools/claude-marketplace/anspar-linear-integration/scripts/create-requirement-tickets.js \
    --token=$LINEAR_API_TOKEN \
    --team-id=$LINEAR_TEAM_ID \
    --dry-run

  # Expected: Tickets match requirements in matrix
  ```

### Full Workflow Integration Test

- [ ] **End-to-End Feature Implementation**
  ```bash
  # 1. Create requirement in spec
  cat > spec/test-e2e.md <<'EOF'
  ### REQ-p00993: E2E Test Feature

  **Level**: PRD | **Implements**: - | **Status**: Active

  The system SHALL support end-to-end testing.

  ### REQ-d00992: E2E Implementation

  **Level**: Dev | **Implements**: REQ-p00993 | **Status**: Active

  Implementation SHALL use test framework.
  EOF

  # 2. Create Linear ticket
  # (Manual or via create-requirement-tickets.js)

  # 3. Claim ticket in workflow
  tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh E2E-TEST

  # 4. Make code changes
  echo "// IMPLEMENTS REQUIREMENTS: REQ-d00992" > test-feature.dart
  git add test-feature.dart spec/test-e2e.md

  # 5. Commit
  git commit -m "Implement E2E test feature

  This adds end-to-end testing support with proper framework.

  Implements: REQ-p00993, REQ-d00992"

  # Expected:
  # - Spec compliance validates spec file
  # - Requirement validation checks REQ format
  # - Workflow checks active ticket
  # - Traceability matrix regenerates
  # - All hooks pass, commit succeeds

  # 6. Verify traceability
  grep -A 10 "REQ-p00993" traceability_matrix.md
  # Expected: Shows REQ-d00992 as implementation, test-feature.dart as code

  # Clean up
  git reset HEAD~1
  rm spec/test-e2e.md test-feature.dart
  tools/claude-marketplace/anspar-workflow/scripts/release-ticket.sh "Test complete"
  ```

---

## Performance Tests

### Hook Performance

- [ ] **Pre-Commit Hook Execution Time**
  ```bash
  # Measure hook execution time
  time .githooks/pre-commit

  # Expected: < 2 seconds for typical spec changes
  # Expected: < 5 seconds for large spec updates
  ```

- [ ] **Matrix Generation Performance**
  ```bash
  # Measure matrix generation time
  time python3 tools/requirements/generate_traceability.py --format both

  # Expected: < 3 seconds for ~100 requirements
  # Expected: < 10 seconds for ~500 requirements
  ```

### Script Performance

- [ ] **Linear API Query Performance**
  ```bash
  # Measure ticket fetch time
  time node tools/claude-marketplace/anspar-linear-integration/scripts/fetch-tickets.js --token=$LINEAR_API_TOKEN

  # Expected: < 5 seconds with cache
  # Expected: < 15 seconds without cache
  ```

---

## Error Handling Tests

### Invalid Input Tests

- [ ] **Missing Environment Variables**
  ```bash
  unset LINEAR_API_TOKEN

  node tools/claude-marketplace/anspar-linear-integration/scripts/fetch-tickets.js

  # Expected: Clear error message about missing token
  ```

- [ ] **Invalid Ticket ID Format**
  ```bash
  tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh INVALID

  # Expected: Error about invalid ticket ID format
  ```

- [ ] **Corrupted WORKFLOW_STATE**
  ```bash
  # Create invalid JSON
  echo "{invalid json" > $(git rev-parse --git-dir)/WORKFLOW_STATE

  tools/claude-marketplace/anspar-workflow/scripts/get-active-ticket.sh

  # Expected: Clear error about corrupted state file
  ```

### Recovery Tests

- [ ] **Workflow State Recovery**
  ```bash
  # Backup and corrupt state
  GIT_DIR=$(git rev-parse --git-dir)
  cp "$GIT_DIR/WORKFLOW_STATE" "$GIT_DIR/WORKFLOW_STATE.bak"
  echo "corrupt" > "$GIT_DIR/WORKFLOW_STATE"

  # Attempt recovery
  rm "$GIT_DIR/WORKFLOW_STATE"
  tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh RECOVERY-001

  # Expected: Creates new valid state file

  # Restore
  mv "$GIT_DIR/WORKFLOW_STATE.bak" "$GIT_DIR/WORKFLOW_STATE"
  ```

---

## Documentation Tests

### README Accuracy

- [ ] **Installation Instructions**
  ```
  # For each plugin:
  1. Follow installation instructions in README.md
  2. Verify all prerequisites are documented
  3. Test that setup commands work as written
  4. Note any discrepancies
  ```

- [ ] **Usage Examples**
  ```
  # For each plugin:
  1. Execute example commands from README.md
  2. Verify output matches documented expectations
  3. Note any outdated examples
  ```

### Help Text Accuracy

- [ ] **Script Help Messages**
  ```bash
  # Test help for each major script
  tools/claude-marketplace/anspar-workflow/scripts/claim-ticket.sh --help 2>&1 | grep -q "Usage"
  # Expected: Shows usage information
  ```

---

## Test Result Documentation

### Test Execution Log

After running tests, document results in this format:

```markdown
## Test Execution: YYYY-MM-DD

### Environment
- OS: [Linux/macOS/Windows]
- Git version: [version]
- Node.js version: [version]
- Python version: [version]
- Bash version: [version]
- Worktree: [yes/no]

### Results Summary

| Plugin | Tests Run | Passed | Failed | Skipped | Pass Rate |
|--------|-----------|--------|--------|---------|-----------|
| anspar-workflow | 30 | 28 | 2 | 0 | 93% |
| anspar-spec-compliance | 15 | 15 | 0 | 0 | 100% |
| anspar-requirement-validation | 12 | 11 | 1 | 0 | 92% |
| anspar-traceability-matrix | 10 | 10 | 0 | 0 | 100% |
| anspar-linear-integration | 20 | 18 | 0 | 2 | 90% |
| **TOTAL** | **87** | **82** | **3** | **2** | **94%** |

### Failed Tests

1. **anspar-workflow: Resume Interactive Selection**
   - Error: [description]
   - Root Cause: [analysis]
   - Fix: [action taken]

2. **anspar-workflow: Session-Start Hook**
   - Error: [description]
   - Root Cause: [analysis]
   - Fix: [action taken]

### Skipped Tests

1. **anspar-linear-integration: Create Tickets Script**
   - Reason: Requires real Linear tickets, skipped in test environment

2. **anspar-linear-integration: Update Ticket with Requirement**
   - Reason: Requires actual ticket ID

### Performance Results

- Pre-commit hook: 1.2s avg
- Matrix generation: 2.8s for 112 requirements
- Linear API fetch: 4.5s with cache

### Issues Found

1. [Issue description]
   - Severity: [High/Medium/Low]
   - Plugin: [name]
   - Status: [Fixed/Open/Wontfix]

### Recommendations

1. [Recommendation]
2. [Recommendation]
```

---

## Continuous Testing

### Automated Test Script

Create `tools/claude-marketplace/run-tests.sh`:

```bash
#!/bin/bash
# Automated test execution script

set -e

echo "🧪 Running Anspar Marketplace Plugin Tests"
echo "=========================================="
echo ""

# Configuration
FAILED_TESTS=0
PASSED_TESTS=0

# Test anspar-workflow
echo "Testing anspar-workflow..."
# [Add automated tests here]

# Test anspar-spec-compliance
echo "Testing anspar-spec-compliance..."
# [Add automated tests here]

# Summary
echo ""
echo "=========================================="
echo "Test Summary:"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"
echo "=========================================="

[ $FAILED_TESTS -eq 0 ] && exit 0 || exit 1
```

### CI/CD Integration

Add to `.github/workflows/test-plugins.yml`:

```yaml
name: Test Plugins

on: [push, pull_request]

jobs:
  test-plugins:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.8'

      - name: Install dependencies
        run: |
          sudo apt-get install -y jq
          chmod +x tools/claude-marketplace/*/hooks/*
          chmod +x tools/claude-marketplace/*/scripts/*.sh

      - name: Run plugin tests
        run: |
          bash tools/claude-marketplace/run-tests.sh
```

---

## Maintenance Schedule

### Weekly
- [ ] Run smoke tests (basic functionality)
- [ ] Check for broken links in READMEs
- [ ] Verify hook execution times

### Monthly
- [ ] Full test plan execution
- [ ] Update test plan for new features
- [ ] Review and update documentation

### Per Release
- [ ] Complete test plan execution
- [ ] Document test results
- [ ] Update plugin versions
- [ ] Tag release with test report

---

## Version History

| Version | Date | Changes | Tested By |
|---------|------|---------|-----------|
| 1.0.0 | 2025-10-30 | Initial test plan created | - |

---

**End of Test Plan**
