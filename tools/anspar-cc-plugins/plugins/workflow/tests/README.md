# Workflow Plugin Tests

Automated test suite for git hooks and workflow plugin functionality.

## Test Files

### `test-hooks.sh`
Comprehensive integration tests for all git hooks:
- Pre-commit hook behavior (ticket validation, branch protection)
- Commit-msg hook validation (REQ reference checking)
- Post-commit hook functionality (workflow history)
- Complete workflow integration tests
- Bypass mechanism (`--no-verify`) tests

### `test-helpers.sh`
Shared test utilities providing:
- Isolated test repository setup/teardown
- Workflow state management helpers
- Assertion functions (`assert_success`, `assert_failure`, etc.)
- Test file creation helpers
- Colored output and test summary reporting

### `test-plugin.sh`
Basic plugin structure validation:
- Plugin metadata validation
- Script executability checks
- Hook file presence verification

## Running Tests

### Run All Hook Tests

```bash
./test-hooks.sh
```

### Run With Verbose Output

```bash
./test-hooks.sh --verbose
```

### Run Plugin Structure Tests

```bash
./test-plugin.sh
```

### Run All Tests

```bash
./test-plugin.sh && ./test-hooks.sh
```

## Test Coverage

### Pre-Commit Hook Tests

| Test Case | Description |
|-----------|-------------|
| `test_precommit_blocks_without_ticket` | Verifies commits are blocked when no ticket is claimed |
| `test_precommit_allows_with_valid_ticket` | Verifies commits succeed with active ticket |
| `test_precommit_blocks_commits_to_main` | Verifies main branch protection |
| `test_precommit_blocks_commits_to_master` | Verifies master branch protection |

### Commit-Msg Hook Tests

| Test Case | Description |
|-----------|-------------|
| `test_commitmsg_blocks_without_req_reference` | Blocks commits without `Implements:`/`Fixes:` |
| `test_commitmsg_blocks_invalid_req_format` | Blocks invalid REQ formats (e.g., `REQ-123`) |
| `test_commitmsg_allows_valid_req_implements` | Allows `Implements: REQ-d00001` |
| `test_commitmsg_allows_valid_req_fixes` | Allows `Fixes: REQ-d00002` |
| `test_commitmsg_allows_multiple_req_references` | Allows multiple REQ references |

### Post-Commit Hook Tests

| Test Case | Description |
|-----------|-------------|
| `test_postcommit_records_workflow_history` | Verifies commits are recorded in workflow history |

### Integration Tests

| Test Case | Description |
|-----------|-------------|
| `test_integration_valid_workflow` | Complete workflow from ticket claim to commit |
| `test_integration_spec_file_changes` | Spec file modifications trigger matrix regeneration |

### Bypass Tests

| Test Case | Description |
|-----------|-------------|
| `test_bypass_with_no_verify` | Verifies `--no-verify` flag bypasses all hooks |

## Test Architecture

### Isolation Strategy

Each test runs in a completely isolated temporary git repository:

1. **Setup** (`setup_test_repo`):
   - Creates temp directory with unique name
   - Initializes fresh git repository
   - Copies all hooks and plugin code
   - Configures git to use local hooks
   - Creates initial commit and feature branch

2. **Test Execution**:
   - Test creates necessary fixtures (files, workflow state)
   - Executes git commands
   - Asserts expected behavior

3. **Cleanup** (`cleanup_test_repo`):
   - Removes temp directory
   - Triggered automatically via trap on exit

### Assertion Helpers

**`assert_success`**
```bash
assert_success \
    "git commit -m 'Valid commit'" \
    "Description of what should succeed"
```

**`assert_failure`**
```bash
assert_failure \
    "git commit -m 'Invalid commit'" \
    "Description of what should fail" \
    "Expected error pattern"
```

**`assert_file_exists`**
```bash
assert_file_exists \
    ".git/WORKFLOW_STATE" \
    "Workflow state should exist"
```

**`assert_file_contains`**
```bash
assert_file_contains \
    ".git/WORKFLOW_STATE" \
    "CUR-123" \
    "Workflow state should contain ticket ID"
```

### Test Output

Tests produce colored output:
- ✅ **Green**: Test passed
- ❌ **Red**: Test failed (with details)
- ⚠️ **Yellow**: Warning or skip
- 📦 **Blue**: Info messages

Example:
```
=== Pre-Commit: Ticket Validation Tests ===

📦 Test repo created: /tmp/git-hooks-test-no-ticket-ABC123
✅ Should block commit without active ticket
🧹 Test repo cleaned up
```

## Test Summary

At the end of each run, a summary is displayed:

```
================================
Test Summary
================================
Passed: 12
Failed: 0
================================
✅ All tests passed!
```

## Exit Codes

- `0`: All tests passed
- `1`: One or more tests failed

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# .github/workflows/pr-validation.yml
- name: Run git hook tests
  run: |
    cd tools/anspar-cc-plugins/plugins/workflow/tests
    ./test-hooks.sh
```

## Requirements Coverage

These tests validate **REQ-d00018** (Git Hook Implementation):

| Requirement | Test Coverage |
|-------------|---------------|
| Pre-commit hook validates requirements | ✅ `test_commitmsg_*` tests |
| Auto-regenerates traceability matrices | ✅ `test_integration_spec_file_changes` |
| Blocks commits with validation errors | ✅ All `assert_failure` tests |
| Clear error messages | ✅ Pattern matching in assertions |
| Auto-staging of matrices | ✅ Integration tests |
| Bypass mechanism (`--no-verify`) | ✅ `test_bypass_with_no_verify` |

## Troubleshooting

### Tests Fail with "jq: command not found"

Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq
```

### Tests Fail with "Python script not found"

Ensure you're running from the project root or that `tools/requirements/` exists.

### Permission Denied Errors

Make scripts executable:
```bash
chmod +x test-*.sh
```

### Tests Hang or Timeout

Check for:
- Infinite loops in hooks
- Missing `set -e` in scripts
- Background processes not cleaned up

## Adding New Tests

To add a new test case:

1. **Create test function** in `test-hooks.sh`:
   ```bash
   test_my_new_feature() {
       echo ""
       echo "=== My New Feature Tests ==="
       echo ""

       setup_test_repo "my-feature"

       # Setup test conditions
       create_workflow_state "CUR-123"
       create_test_file "feature.txt"

       # Run test assertion
       assert_success \
           "git commit -m 'Test commit'" \
           "My feature should work"

       cleanup_test_repo
   }
   ```

2. **Call test function** in `main()`:
   ```bash
   main() {
       # ... existing tests ...
       test_my_new_feature
       # ...
   }
   ```

3. **Run tests** to verify:
   ```bash
   ./test-hooks.sh
   ```

## Best Practices

1. **One assertion per test function** - Makes failures easier to diagnose
2. **Descriptive test names** - Use `test_<hook>_<behavior>` pattern
3. **Clean setup/teardown** - Always use `setup_test_repo` / `cleanup_test_repo`
4. **Test both success and failure** - Verify hooks block AND allow correctly
5. **Test error messages** - Use pattern matching in `assert_failure`

## Related Documentation

- [Main Workflow Plugin README](../README.md)
- [Git Hooks Documentation](../../../../.githooks/README.md)
- [REQ-d00018: Git Hook Implementation](../../../../spec/dev-requirements-management.md)
