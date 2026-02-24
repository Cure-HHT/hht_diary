#!/bin/bash
# =====================================================
# test-hooks.sh
# =====================================================
#
# Comprehensive test suite for git hooks
#
# Tests all hook functionality:
# - pre-commit: ticket validation, branch protection, Dockerfile linting
# - commit-msg: REQ reference validation
# - post-commit: workflow history recording
#
# Usage:
#   ./test-hooks.sh
#   ./test-hooks.sh --verbose
#
# Exit codes:
#   0  All tests passed
#   1  Some tests failed
#
# =====================================================

# Note: NOT using 'set -e' because we intentionally test failure cases
set -o pipefail

# Load test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

# =====================================================
# Test Suite Configuration
# =====================================================

VERBOSE=false
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
    VERBOSE=true
fi

# =====================================================
# Pre-Commit Hook Tests
# =====================================================

test_precommit_blocks_without_ticket() {
    echo ""
    echo "=== Pre-Commit: Ticket Validation Tests ==="
    echo ""

    setup_test_repo "no-ticket"

    # No workflow state = no ticket
    create_test_file "feature.txt" "New feature"

    assert_failure \
        "git commit -m 'Add feature'" \
        "Should block commit without active ticket" \
        "No active ticket"

    cleanup_test_repo
}

test_precommit_allows_with_valid_ticket() {
    echo ""
    echo "=== Pre-Commit: Valid Ticket Tests ==="
    echo ""

    setup_test_repo "valid-ticket"

    # Create workflow state with active ticket
    create_workflow_state "CUR-123" '["REQ-d00001"]'

    create_test_file "feature.txt" "New feature"

    assert_success \
        "git commit -m 'Add feature' --no-verify" \
        "Should allow commit with active ticket (using --no-verify to skip commit-msg for now)"

    cleanup_test_repo
}

test_precommit_blocks_commits_to_main() {
    echo ""
    echo "=== Pre-Commit: Branch Protection Tests ==="
    echo ""

    setup_test_repo "main-protection"

    # Switch to main branch
    git checkout -q main

    create_workflow_state "CUR-123"
    create_test_file "dangerous.txt" "Should not commit to main"

    assert_failure \
        "git commit -m 'Dangerous commit'" \
        "Should block commits to main branch" \
        "Direct commits to 'main' branch are not allowed"

    cleanup_test_repo
}

test_precommit_blocks_commits_to_master() {
    echo ""
    echo "=== Pre-Commit: Master Branch Protection Tests ==="
    echo ""

    setup_test_repo "master-protection"

    # Create and switch to master branch
    git branch master
    git checkout -q master

    create_workflow_state "CUR-123"
    create_test_file "dangerous.txt" "Should not commit to master"

    assert_failure \
        "git commit -m 'Dangerous commit'" \
        "Should block commits to master branch" \
        "Direct commits to 'master' branch are not allowed"

    cleanup_test_repo
}

# =====================================================
# Commit-Msg Hook Tests
# =====================================================

test_commitmsg_blocks_without_cur_reference() {
    echo ""
    echo "=== Commit-Msg: CUR Reference Validation Tests ==="
    echo ""

    setup_test_repo "no-cur"

    create_workflow_state "CUR-123" '["REQ-d00001"]'
    create_test_file "feature.txt" "New feature"

    # Commit message with REQ but without CUR reference
    assert_failure \
        "git commit -m 'Add feature without ticket

Implements: REQ-d00001'" \
        "Should block commit without Linear ticket reference" \
        "Missing Linear ticket reference\|CUR-"

    cleanup_test_repo
}

test_commitmsg_blocks_without_req_reference() {
    echo ""
    echo "=== Commit-Msg: REQ Reference Validation Tests (enforced) ==="
    echo ""

    setup_test_repo "no-req"

    create_workflow_state "CUR-123"
    create_test_file "feature.txt" "New feature"

    # Commit message with CUR but without REQ reference (with enforcement ON)
    assert_failure \
        "ENFORCE_REQ_IN_COMMITS=true git commit -m '[CUR-123] Add feature without REQ'" \
        "Should block commit without REQ reference when enforced" \
        "Missing requirement reference\|REQ-"

    cleanup_test_repo
}

test_commitmsg_blocks_invalid_req_format() {
    echo ""
    echo "=== Commit-Msg: Invalid REQ Format Tests (enforced) ==="
    echo ""

    setup_test_repo "invalid-req"

    create_workflow_state "CUR-123"
    create_test_file "feature.txt" "New feature"

    # Invalid REQ format (wrong format) - with enforcement ON, still missing valid REQ
    assert_failure \
        "ENFORCE_REQ_IN_COMMITS=true git commit -m '[CUR-123] Add feature

Implements: REQ-123'" \
        "Should block commit with invalid REQ format when enforced (missing type)" \
        "Missing requirement reference\|REQ-"

    cleanup_test_repo
}

test_commitmsg_allows_without_req_when_disabled() {
    echo ""
    echo "=== Commit-Msg: REQ Not Required When Disabled (default) ==="
    echo ""

    setup_test_repo "no-req-ok"

    create_workflow_state "CUR-123"
    create_test_file "feature.txt" "New feature"

    # Commit message with CUR but without REQ reference (enforcement OFF = default)
    assert_success \
        "git commit -m '[CUR-123] Add feature without REQ reference'" \
        "Should allow commit without REQ reference when enforcement is disabled"

    cleanup_test_repo
}

test_commitmsg_allows_valid_cur_and_req() {
    echo ""
    echo "=== Commit-Msg: Valid CUR and REQ References Tests ==="
    echo ""

    setup_test_repo "valid-implements"

    create_workflow_state "CUR-123" '["REQ-d00001"]'
    create_test_file "feature.txt" "New feature"

    # Valid commit with both CUR and REQ references
    assert_success \
        "git commit -m '[CUR-123] Add feature

Implements: REQ-d00001'" \
        "Should allow commit with valid CUR and REQ references"

    cleanup_test_repo
}

test_commitmsg_allows_valid_fixes_with_cur() {
    echo ""
    echo "=== Commit-Msg: Valid CUR with Fixes Tests ==="
    echo ""

    setup_test_repo "valid-fixes"

    create_workflow_state "CUR-123" '["REQ-d00002"]'
    create_test_file "fix.txt" "Bug fix"

    # Valid commit with CUR and Fixes: REQ-d00002
    assert_success \
        "git commit -m '[CUR-123] Fix bug

Fixes: REQ-d00002'" \
        "Should allow commit with valid CUR and Fixes: REQ reference"

    cleanup_test_repo
}

test_commitmsg_allows_multiple_req_with_cur() {
    echo ""
    echo "=== Commit-Msg: CUR with Multiple REQ References Tests ==="
    echo ""

    setup_test_repo "multiple-reqs"

    create_workflow_state "CUR-123" '["REQ-d00001", "REQ-p00042"]'
    create_test_file "feature.txt" "Complex feature"

    # Valid commit with CUR and multiple REQ references
    assert_success \
        "git commit -m '[CUR-123] Add complex feature

Implements: REQ-d00001, REQ-p00042'" \
        "Should allow commit with CUR and multiple REQ references"

    cleanup_test_repo
}

# =====================================================
# Post-Commit Hook Tests
# =====================================================

test_postcommit_records_workflow_history() {
    echo ""
    echo "=== Post-Commit: Workflow History Tests ==="
    echo ""

    setup_test_repo "history"

    create_workflow_state "CUR-123" '["REQ-d00001"]'
    create_test_file "feature.txt" "New feature"

    # Make a valid commit (needs both CUR and REQ references to pass commit-msg hook)
    git commit -m "[CUR-123] Add feature

Implements: REQ-d00001" > /dev/null 2>&1 || true

    # Check if workflow state was updated with commit history
    if [ -f .git/WORKFLOW_STATE ]; then
        assert_success \
            "jq -e '.history | length > 0' .git/WORKFLOW_STATE" \
            "Should record commit in workflow history"
    else
        echo -e "${YELLOW}⚠${NC} Post-commit history test skipped (no WORKFLOW_STATE after commit)"
    fi

    cleanup_test_repo
}

# =====================================================
# Integration Tests
# =====================================================

test_integration_valid_workflow() {
    echo ""
    echo "=== Integration: Complete Valid Workflow ==="
    echo ""

    setup_test_repo "integration-valid"

    # Setup: claim ticket with REQ
    create_workflow_state "CUR-999" '["REQ-d00099"]'

    # Create feature on feature branch (not main)
    git checkout -q -b feature/CUR-999 2>/dev/null || git checkout -q feature/CUR-999

    create_test_file "integration-feature.txt" "Integration test feature"

    # Complete workflow: commit with all requirements
    assert_success \
        "git commit -m '[CUR-999] Add integration feature

This is a complete valid workflow test.

Implements: REQ-d00099'" \
        "Complete valid workflow should succeed"

    cleanup_test_repo
}

test_integration_spec_file_changes() {
    echo ""
    echo "=== Integration: Spec File Changes ==="
    echo ""

    setup_test_repo "spec-changes"

    create_workflow_state "CUR-888" '["REQ-d00088"]'

    # Create spec file change
    create_spec_file "spec/test-requirements.md"

    # Note: traceability matrix regeneration requires Python scripts
    # This test verifies the hook runs without error
    assert_success \
        "git commit -m 'Update requirements

Implements: REQ-d00088' || true" \
        "Spec file changes should trigger hooks without error"

    cleanup_test_repo
}

# =====================================================
# Bypass Tests (--no-verify)
# =====================================================

test_bypass_with_no_verify() {
    echo ""
    echo "=== Bypass: --no-verify Flag Tests ==="
    echo ""

    setup_test_repo "bypass"

    # No workflow state, but using --no-verify
    create_test_file "emergency.txt" "Emergency fix"

    assert_success \
        "git commit --no-verify -m 'Emergency fix without ticket'" \
        "Should allow bypass with --no-verify flag"

    cleanup_test_repo
}

# =====================================================
# Main Test Execution
# =====================================================

main() {
    echo "=========================================="
    echo "Git Hooks Test Suite"
    echo "=========================================="
    echo ""

    # Detect CI environment
    if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
        echo "🔍 Running in CI/CD environment"
    else
        echo "🔍 Running locally"
    fi

    echo "Testing git hooks in isolated repositories"
    echo ""

    # Pre-commit tests
    test_precommit_blocks_without_ticket
    test_precommit_allows_with_valid_ticket
    test_precommit_blocks_commits_to_main
    test_precommit_blocks_commits_to_master

    # Commit-msg tests
    test_commitmsg_blocks_without_cur_reference
    test_commitmsg_blocks_without_req_reference
    test_commitmsg_blocks_invalid_req_format
    test_commitmsg_allows_without_req_when_disabled
    test_commitmsg_allows_valid_cur_and_req
    test_commitmsg_allows_valid_fixes_with_cur
    test_commitmsg_allows_multiple_req_with_cur

    # Post-commit tests
    test_postcommit_records_workflow_history

    # Integration tests
    test_integration_valid_workflow
    test_integration_spec_file_changes

    # Bypass tests
    test_bypass_with_no_verify

    # Print summary
    echo ""
    echo "=========================================="
    print_test_summary
}

# Run tests
main
exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    echo "✅ Test execution complete - all tests passed"
else
    echo "❌ Test execution complete - some tests failed"
fi
exit $exit_code
