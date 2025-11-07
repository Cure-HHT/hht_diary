#!/usr/bin/env node
/**
 * Generate test suite for plugin-expert using its own test-builder
 * This is a meta-test: the test builder tests itself!
 */

const path = require('path');
const fs = require('fs');
const testBuilder = require('../builders/test-builder');

// Define the plugin-expert specification
const pluginExpertSpec = {
  name: 'plugin-expert',
  version: '1.0.0',
  description: 'Expert guidance and automation for creating Claude Code plugins with best practices',
  author: {
    name: 'Claude Code Plugin Expert Team'
  }
};

// Define the plugin-expert components
const pluginExpertComponents = {
  commands: [
    {
      name: 'create-plugin',
      filePath: 'commands/create-plugin.md',
      spec: {
        description: 'Expert guidance for creating Claude Code plugins',
        testArgs: ['--help'],
        testOutput: 'should show help information'
      }
    }
  ],
  agents: [
    {
      name: 'PluginExpert',
      testInput: 'Create a simple data analysis plugin',
      testBehavior: 'Provides expert guidance and generates plugin structure'
    }
  ],
  skills: [],
  hooks: []
};

console.log('🔨 Generating test suite for plugin-expert...');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');

// Build the test suite using the test-builder
const pluginRoot = path.join(__dirname, '..');
const tests = testBuilder.buildTestSuite(pluginExpertSpec, pluginExpertComponents, pluginRoot);

console.log('✅ Test suite structure generated:');
console.log(`   - Metadata tests: ${tests.metadata.tests.length} tests`);
console.log(`   - Command tests: ${tests.commands.length} command suites`);
console.log(`   - Agent tests: ${tests.agents.length} agent suites`);
console.log(`   - Integration tests: ${tests.integration.length} tests`);
console.log('');

// Create test files
console.log('📝 Creating test files...');
const result = testBuilder.createTestFiles(tests, pluginRoot);

if (result.created.length > 0) {
  console.log('✅ Created files:');
  result.created.forEach(file => console.log(`   - ${file}`));
  console.log('');
}

if (result.errors.length > 0) {
  console.log('⚠️  Errors encountered:');
  result.errors.forEach(error => console.log(`   - ${error}`));
  console.log('');
}

// Add custom tests specific to plugin-expert
console.log('📋 Adding custom tests for plugin-expert utilities...');

const customTests = `
# Custom Tests for Plugin-Expert Utilities

## Builders Tests
run_test "command-builder.js exists" "test -f builders/command-builder.js"
run_test "docs-builder.js exists" "test -f builders/docs-builder.js"
run_test "hook-builder.js exists" "test -f builders/hook-builder.js"
run_test "metadata-builder.js exists" "test -f builders/metadata-builder.js"
run_test "test-builder.js exists" "test -f builders/test-builder.js"

## Coordinators Tests
run_test "interview-conductor.js exists" "test -f coordinators/interview-conductor.js"
run_test "plugin-assembler.js exists" "test -f coordinators/plugin-assembler.js"
run_test "validator.js exists" "test -f coordinators/validator.js"

## Utilities Tests
run_test "path-manager.js exists" "test -f utilities/path-manager.js"
run_test "string-helpers.js exists" "test -f utilities/string-helpers.js"
run_test "validation.js exists" "test -f utilities/validation.js"
run_test "escape-helpers.js exists" "test -f utilities/escape-helpers.js"

## Node.js Module Load Tests
if command -v node &>/dev/null; then
    echo ""
    echo "=== Node.js Module Tests ==="

    run_test "test-builder loads" "node -e 'require(\"./builders/test-builder\")'"
    run_test "command-builder loads" "node -e 'require(\"./builders/command-builder\")'"
    run_test "path-manager loads" "node -e 'require(\"./utilities/path-manager\")'"
    run_test "string-helpers loads" "node -e 'require(\"./utilities/string-helpers\")'"
fi
`;

// Append custom tests to the bash test runner
const testShPath = path.join(pluginRoot, 'tests', 'test.sh');
if (fs.existsSync(testShPath)) {
  let testContent = fs.readFileSync(testShPath, 'utf8');

  // Insert custom tests before the summary section
  const summaryIndex = testContent.indexOf('# Summary');
  if (summaryIndex > 0) {
    testContent =
      testContent.slice(0, summaryIndex) +
      customTests +
      '\n\n' +
      testContent.slice(summaryIndex);

    fs.writeFileSync(testShPath, testContent);
    console.log('✅ Added custom tests to test.sh');
  }
}

console.log('');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('✅ Test suite generation complete!');
console.log('');
console.log('To run the tests:');
console.log('  bash tests/test.sh       # Run bash tests');
console.log('  node tests/test.js       # Run Node.js tests');
console.log('  python3 tests/test.py    # Run Python tests');
console.log('');
