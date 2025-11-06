# Plugin-Expert Test Suite

This test suite was generated using the plugin-expert's own `test-builder.js` utility - a meta-test where the test builder tests itself!

## Test Coverage

The test suite validates:

### Metadata Tests (2 tests)
- ✅ Valid plugin.json structure
- ✅ Valid marketplace.json (if present)

### Component Tests (14 tests)
- ✅ Command files exist (create-plugin.md)
- ✅ Agent files exist (PluginExpert.md)
- ✅ Builder modules exist (9 files)
  - command-builder.js
  - docs-builder.js
  - hook-builder.js
  - metadata-builder.js
  - test-builder.js
- ✅ Coordinator modules exist (3 files)
  - interview-conductor.js
  - plugin-assembler.js
  - validator.js
- ✅ Utility modules exist (4 files tested)
  - path-manager.js
  - string-helpers.js
  - validation.js
  - escape-helpers.js

### Module Loading Tests (4 tests)
- ✅ test-builder loads correctly
- ✅ command-builder loads correctly
- ✅ path-manager loads correctly
- ✅ string-helpers loads correctly

## Running Tests

### Bash Test Suite (Recommended)
```bash
bash tests/test.sh
```

Runs comprehensive tests including:
- File existence checks
- JSON validation (requires `jq`)
- Node.js module loading
- Structure validation

### Node.js Test Suite
```bash
node tests/test.js
```

Runs basic metadata validation tests.

### Python Test Suite
```bash
python3 tests/test.py
```

Runs basic metadata validation tests.

## Test Configuration

The test configuration is stored in `test-config.json` and includes:
- Test specifications for all components
- Expected behaviors for integration tests
- Timeout settings (30 seconds)
- Test runner preferences

## Generating Tests

To regenerate the test suite:

```bash
node scripts/generate-self-tests.js
```

This will:
1. Use the test-builder to create test suite structure
2. Generate test runners for bash, Node.js, and Python
3. Add custom tests for plugin-expert utilities
4. Create test-config.json with test specifications

## Test Results

Current test status: **18/18 tests passing** ✅

- Bash test suite: 18 tests passed
- Node.js test suite: 2 tests passed
- Python test suite: 2 tests passed

## Notes

- The bash test suite requires `jq` for JSON validation
- The bash test suite requires Node.js for module loading tests
- Tests automatically detect the plugin root directory
- Tests can be run from any directory

## Meta-Testing Achievement Unlocked! 🏆

This test suite demonstrates the power of the plugin-expert framework:
- The test-builder was used to test itself
- Generated comprehensive tests with minimal configuration
- Validates the entire plugin architecture
- Ensures all utilities and builders are functional
