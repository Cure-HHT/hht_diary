#!/bin/bash
# =====================================================
# test-helpers.sh
# =====================================================
#
# Shared test utilities for git hook testing
#
# Provides functions for:
# - Setting up isolated test git repositories
# - Creating test fixtures (files, commits, state)
# - Assertion helpers
# - Cleanup utilities
#
# Usage:
#   source test-helpers.sh
#   setup_test_repo
#   # ... run tests ...
#   cleanup_test_repo
#
# =====================================================

# Color codes for output
export GREEN="\033[0;32m"
export RED="\033[0;31m"
export YELLOW="\033[1;33m"
export BLUE="\033[0;34m"
export NC="\033[0m"

# Test counters
export TESTS_PASSED=0
export TESTS_FAILED=0
export CURRENT_TEST=""

# Test repository paths
export TEST_REPO_DIR=""
export ORIGINAL_DIR="$(pwd)"
export PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$(cd "$PLUGIN_ROOT/../../../.." && pwd)"

# =====================================================
# Test Repository Setup
# =====================================================

setup_test_repo() {
    local test_name="${1:-test-repo}"

    # Create temp directory for test repository
    TEST_REPO_DIR=$(mktemp -d -t "git-hooks-test-${test_name}-XXXXXX")

    # Initialize git repo
    cd "$TEST_REPO_DIR" || exit 1
    git init -q --initial-branch=main
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Copy hooks from project
    mkdir -p .githooks
    cp -r "$PROJECT_ROOT/.githooks/"* .githooks/ 2>/dev/null || true

    # Copy plugin directories needed by hooks
    mkdir -p tools/anspar-marketplace/plugins
    cp -r "$PROJECT_ROOT/tools/anspar-marketplace/plugins/"* tools/anspar-marketplace/plugins/ 2>/dev/null || true

    # Copy tools/requirements for validation scripts
    mkdir -p tools/requirements
    cp -r "$PROJECT_ROOT/tools/requirements/"* tools/requirements/ 2>/dev/null || true

    # Configure git to use our hooks
    git config core.hooksPath .githooks

    # Create initial commit so we have a commit history
    echo "# Test Repository" > README.md
    git add README.md
    git commit -q -m "Initial commit" --no-verify

    # Create a feature branch for testing
    git checkout -q -b feature/test-branch

    echo -e "${BLUE}📦 Test repo created: $TEST_REPO_DIR${NC}" >&2
}

cleanup_test_repo() {
    if [ -n "$TEST_REPO_DIR" ] && [ -d "$TEST_REPO_DIR" ]; then
        cd "$ORIGINAL_DIR" || exit 1
        rm -rf "$TEST_REPO_DIR"
        echo -e "${BLUE}🧹 Test repo cleaned up${NC}" >&2
    fi
    TEST_REPO_DIR=""
}

# =====================================================
# Workflow State Management
# =====================================================

create_workflow_state() {
    local ticket_id="${1:-CUR-TEST}"
    local requirements="${2:-[]}"

    mkdir -p .git
    cat > .git/WORKFLOW_STATE <<EOF
{
  "version": "1.0.0",
  "worktree": {
    "path": "$TEST_REPO_DIR",
    "branch": "feature/test-branch"
  },
  "sponsor": null,
  "activeTicket": {
    "id": "$ticket_id",
    "requirements": $requirements,
    "claimedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "claimedBy": "test",
    "trackerMetadata": {
      "trackerType": "linear"
    }
  },
  "history": []
}
EOF
    echo -e "${BLUE}📋 Workflow state created for $ticket_id${NC}" >&2
}

clear_workflow_state() {
    rm -f .git/WORKFLOW_STATE
    echo -e "${BLUE}🗑️  Workflow state cleared${NC}" >&2
}

# =====================================================
# Test Assertions
# =====================================================

assert_success() {
    local command="$1"
    local description="${2:-Command should succeed}"

    CURRENT_TEST="$description"

    if eval "$command" > /tmp/test-output.log 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo -e "${RED}  Failed command: $command${NC}"
        echo -e "${YELLOW}  Output:${NC}"
        cat /tmp/test-output.log | sed 's/^/    /'
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_failure() {
    local command="$1"
    local description="${2:-Command should fail}"
    local expected_pattern="${3:-}"

    CURRENT_TEST="$description"

    if eval "$command" > /tmp/test-output.log 2>&1; then
        echo -e "${RED}✗${NC} $description (expected failure but succeeded)"
        ((TESTS_FAILED++))
        return 1
    else
        # Check if output matches expected pattern
        if [ -n "$expected_pattern" ]; then
            if grep -q "$expected_pattern" /tmp/test-output.log; then
                echo -e "${GREEN}✓${NC} $description"
                ((TESTS_PASSED++))
                return 0
            else
                echo -e "${RED}✗${NC} $description (failed but wrong error message)"
                echo -e "${YELLOW}  Expected pattern: $expected_pattern${NC}"
                echo -e "${YELLOW}  Actual output:${NC}"
                cat /tmp/test-output.log | sed 's/^/    /'
                ((TESTS_FAILED++))
                return 1
            fi
        fi

        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
        return 0
    fi
}

assert_file_exists() {
    local file_path="$1"
    local description="${2:-File $file_path should exist}"

    CURRENT_TEST="$description"

    if [ -f "$file_path" ]; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_contains() {
    local file_path="$1"
    local pattern="$2"
    local description="${3:-File $file_path should contain '$pattern'}"

    CURRENT_TEST="$description"

    if [ -f "$file_path" ] && grep -q "$pattern" "$file_path"; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        ((TESTS_FAILED++))
        return 1
    fi
}

# =====================================================
# Test File Creation Helpers
# =====================================================

create_test_file() {
    local filename="${1:-test-file.txt}"
    local content="${2:-Test content}"

    echo "$content" > "$filename"
    git add "$filename"
}

create_spec_file() {
    local filename="${1:-spec/test-spec.md}"

    mkdir -p spec
    cat > "$filename" <<'EOF'
# Test Specification

## Requirements

### REQ-d00001: Test Requirement One
This is a test requirement.

### REQ-d00002: Test Requirement Two
Another test requirement.
EOF
    git add "$filename"
}

create_dockerfile() {
    local filename="${1:-Dockerfile}"

    cat > "$filename" <<'EOF'
FROM ubuntu:22.04
RUN apt-get update
WORKDIR /app
COPY . .
EOF
    git add "$filename"
}

# =====================================================
# Test Summary
# =====================================================

print_test_summary() {
    echo ""
    echo "================================"
    echo "Test Summary"
    echo "================================"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo "================================"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

# =====================================================
# Trap to ensure cleanup on exit
# =====================================================

trap cleanup_test_repo EXIT
