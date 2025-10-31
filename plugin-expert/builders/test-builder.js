/**
 * Test Builder for Plugin-Expert
 * Build test structures and validation for plugins
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const { toKebabCase, toPascalCase, codeBlock } = require('../utilities/string-helpers');
const { PathManager } = require('../utilities/path-manager');

/**
 * Build test suite for a plugin
 * @param {object} spec - Plugin specification
 * @param {object} components - Plugin components
 * @param {string} basePath - Base path for the plugin
 * @returns {object} Test suite configuration
 */
function buildTestSuite(spec, components, basePath = null) {
  const pathManager = new PathManager(basePath);
  const tests = {
    metadata: buildMetadataTests(spec),
    commands: [],
    agents: [],
    skills: [],
    hooks: [],
    integration: []
  };

  // Build command tests
  if (components.commands && components.commands.length > 0) {
    for (const cmd of components.commands) {
      tests.commands.push(buildCommandTest(cmd));
    }
  }

  // Build agent tests
  if (components.agents && components.agents.length > 0) {
    for (const agent of components.agents) {
      tests.agents.push(buildAgentTest(agent));
    }
  }

  // Build skill tests
  if (components.skills && components.skills.length > 0) {
    for (const skill of components.skills) {
      tests.skills.push(buildSkillTest(skill));
    }
  }

  // Build hook tests
  if (components.hooks && components.hooks.length > 0) {
    for (const hook of components.hooks) {
      tests.hooks.push(buildHookTest(hook));
    }
  }

  // Build integration tests
  tests.integration = buildIntegrationTests(spec, components);

  return tests;
}

/**
 * Build metadata validation tests
 * @param {object} spec - Plugin specification
 * @returns {object} Metadata test configuration
 */
function buildMetadataTests(spec) {
  return {
    name: 'Plugin Metadata Tests',
    tests: [
      {
        name: 'Valid plugin.json structure',
        type: 'validation',
        target: '.claude-plugin/plugin.json',
        checks: [
          { field: 'name', required: true, pattern: /^[a-z][a-z0-9-]*$/ },
          { field: 'version', required: true, pattern: /^\d+\.\d+\.\d+/ },
          { field: 'description', required: true, minLength: 1, maxLength: 500 },
          { field: 'author', required: true, type: 'object' },
          { field: 'author.name', required: true, minLength: 1 }
        ]
      },
      {
        name: 'Valid marketplace.json if present',
        type: 'validation',
        target: '.claude-plugin/marketplace.json',
        optional: true,
        checks: [
          { field: 'plugins', required: true, type: 'array' },
          { field: 'owner', required: true, type: 'object' }
        ]
      }
    ]
  };
}

/**
 * Build test for a command
 * @param {object} command - Command configuration
 * @returns {object} Command test configuration
 */
function buildCommandTest(command) {
  return {
    name: `Command: ${command.name}`,
    tests: [
      {
        name: 'Command file exists',
        type: 'file-exists',
        target: command.filePath
      },
      {
        name: 'Valid frontmatter',
        type: 'frontmatter-validation',
        target: command.filePath,
        checks: [
          { field: 'name', required: true },
          { field: 'description', required: true },
          { field: 'arguments', required: true }
        ]
      },
      {
        name: 'Command execution test',
        type: 'execution',
        command: command.name,
        args: command.spec.testArgs || [],
        expectedOutput: command.spec.testOutput,
        expectedError: false
      }
    ]
  };
}

/**
 * Build test for an agent
 * @param {object} agent - Agent configuration
 * @returns {object} Agent test configuration
 */
function buildAgentTest(agent) {
  return {
    name: `Agent: ${agent.name}`,
    tests: [
      {
        name: 'Agent file exists',
        type: 'file-exists',
        target: `agents/${agent.name}.md`
      },
      {
        name: 'Valid agent structure',
        type: 'content-validation',
        target: `agents/${agent.name}.md`,
        checks: [
          { contains: '# Role' },
          { contains: agent.name }
        ]
      },
      {
        name: 'Agent invocation test',
        type: 'agent-invocation',
        agent: agent.name,
        input: agent.testInput || 'Test input',
        expectedBehavior: agent.testBehavior || 'Responds appropriately'
      }
    ]
  };
}

/**
 * Build test for a skill
 * @param {object} skill - Skill configuration
 * @returns {object} Skill test configuration
 */
function buildSkillTest(skill) {
  return {
    name: `Skill: ${skill.name}`,
    tests: [
      {
        name: 'Skill directory exists',
        type: 'directory-exists',
        target: `skills/${skill.name}`
      },
      {
        name: 'SKILL.md file exists',
        type: 'file-exists',
        target: `skills/${skill.name}/SKILL.md`
      },
      {
        name: 'Skill content validation',
        type: 'content-validation',
        target: `skills/${skill.name}/SKILL.md`,
        checks: [
          { contains: skill.name },
          { contains: '## Purpose' }
        ]
      }
    ]
  };
}

/**
 * Build test for a hook
 * @param {object} hook - Hook configuration
 * @returns {object} Hook test configuration
 */
function buildHookTest(hook) {
  return {
    name: `Hook: ${hook.event}`,
    tests: [
      {
        name: 'Hook configuration valid',
        type: 'hook-validation',
        event: hook.event,
        command: hook.command
      },
      {
        name: 'Hook script exists if referenced',
        type: 'conditional-file-exists',
        condition: hook.script !== undefined,
        target: `hooks/${hook.script}`
      },
      {
        name: 'Hook execution test',
        type: 'hook-execution',
        event: hook.event,
        testEnv: {
          CLAUDE_TOOL_NAME: 'test-tool',
          CLAUDE_TOOL_PARAMS: '{}'
        },
        expectedExitCode: 0
      }
    ]
  };
}

/**
 * Build integration tests
 * @param {object} spec - Plugin specification
 * @param {object} components - Plugin components
 * @returns {array} Integration test configurations
 */
function buildIntegrationTests(spec, components) {
  const tests = [];

  // Test plugin loading
  tests.push({
    name: 'Plugin loads successfully',
    type: 'plugin-load',
    pluginPath: '.',
    expectedComponents: Object.keys(components).filter(k =>
      components[k] && components[k].length > 0
    )
  });

  // Test component interactions
  if (components.commands && components.agents) {
    tests.push({
      name: 'Commands and agents interact correctly',
      type: 'component-interaction',
      scenario: 'Command invokes agent',
      steps: [
        { action: 'invoke-command', target: components.commands[0]?.name },
        { verify: 'agent-activated', target: components.agents[0]?.name }
      ]
    });
  }

  // Test error handling
  tests.push({
    name: 'Error handling works correctly',
    type: 'error-handling',
    scenarios: [
      {
        name: 'Invalid command arguments',
        action: 'invoke-command',
        args: ['--invalid-arg'],
        expectedError: true
      },
      {
        name: 'Hook timeout handling',
        action: 'trigger-hook',
        event: 'before-tool-use',
        simulateTimeout: true,
        expectedBehavior: 'graceful-failure'
      }
    ]
  });

  return tests;
}

/**
 * Generate test runner script
 * @param {object} tests - Test suite configuration
 * @param {string} language - Script language (bash, node, python)
 * @returns {string} Test runner script
 */
function generateTestRunner(tests, language = 'bash') {
  const runners = {
    bash: generateBashTestRunner,
    node: generateNodeTestRunner,
    python: generatePythonTestRunner
  };

  const runner = runners[language] || runners.bash;
  return runner(tests);
}

/**
 * Generate bash test runner
 * @param {object} tests - Test suite configuration
 * @returns {string} Bash script
 */
function generateBashTestRunner(tests) {
  const lines = [
    '#!/bin/bash',
    '# Plugin Test Runner',
    '',
    'TESTS_PASSED=0',
    'TESTS_FAILED=0',
    '',
    '# Color codes',
    'GREEN="\\033[0;32m"',
    'RED="\\033[0;31m"',
    'NC="\\033[0m"',
    '',
    '# Test function',
    'run_test() {',
    '    local test_name="$1"',
    '    local test_command="$2"',
    '    ',
    '    echo -n "Running: $test_name... "',
    '    if eval "$test_command" > /dev/null 2>&1; then',
    '        echo -e "${GREEN}PASSED${NC}"',
    '        ((TESTS_PASSED++))',
    '    else',
    '        echo -e "${RED}FAILED${NC}"',
    '        ((TESTS_FAILED++))',
    '    fi',
    '}',
    '',
    '# Metadata Tests',
    'echo "=== Metadata Tests ==="'
  ];

  // Add metadata tests
  if (tests.metadata) {
    for (const test of tests.metadata.tests) {
      if (test.type === 'validation' && test.target === '.claude-plugin/plugin.json') {
        lines.push(`run_test "${test.name}" "test -f .claude-plugin/plugin.json && jq '.' .claude-plugin/plugin.json > /dev/null"`);
      }
    }
  }

  // Add command tests
  if (tests.commands && tests.commands.length > 0) {
    lines.push('', '# Command Tests', 'echo "=== Command Tests ==="');
    for (const cmdTest of tests.commands) {
      for (const test of cmdTest.tests) {
        if (test.type === 'file-exists') {
          lines.push(`run_test "${test.name}" "test -f ${test.target}"`);
        }
      }
    }
  }

  // Add summary
  lines.push(
    '',
    '# Summary',
    'echo ""',
    'echo "=== Test Summary ==="',
    'echo "Tests Passed: $TESTS_PASSED"',
    'echo "Tests Failed: $TESTS_FAILED"',
    '',
    'if [ $TESTS_FAILED -eq 0 ]; then',
    '    echo -e "${GREEN}All tests passed!${NC}"',
    '    exit 0',
    'else',
    '    echo -e "${RED}Some tests failed.${NC}"',
    '    exit 1',
    'fi'
  );

  return lines.join('\n');
}

/**
 * Generate Node.js test runner
 * @param {object} tests - Test suite configuration
 * @returns {string} Node.js script
 */
function generateNodeTestRunner(tests) {
  return `#!/usr/bin/env node
// Plugin Test Runner

const fs = require('fs');
const path = require('path');

let testsPassed = 0;
let testsFailed = 0;

function runTest(name, testFn) {
    process.stdout.write(\`Running: \${name}... \`);
    try {
        if (testFn()) {
            console.log('\\x1b[32mPASSED\\x1b[0m');
            testsPassed++;
        } else {
            console.log('\\x1b[31mFAILED\\x1b[0m');
            testsFailed++;
        }
    } catch (error) {
        console.log('\\x1b[31mFAILED\\x1b[0m', error.message);
        testsFailed++;
    }
}

// Metadata Tests
console.log('=== Metadata Tests ===');
runTest('Plugin.json exists', () => {
    return fs.existsSync('.claude-plugin/plugin.json');
});

runTest('Valid plugin.json', () => {
    const content = fs.readFileSync('.claude-plugin/plugin.json', 'utf8');
    const data = JSON.parse(content);
    return data.name && data.version && data.description && data.author;
});

// Summary
console.log('\\n=== Test Summary ===');
console.log(\`Tests Passed: \${testsPassed}\`);
console.log(\`Tests Failed: \${testsFailed}\`);

if (testsFailed === 0) {
    console.log('\\x1b[32mAll tests passed!\\x1b[0m');
    process.exit(0);
} else {
    console.log('\\x1b[31mSome tests failed.\\x1b[0m');
    process.exit(1);
}`;
}

/**
 * Generate Python test runner
 * @param {object} tests - Test suite configuration
 * @returns {string} Python script
 */
function generatePythonTestRunner(tests) {
  return `#!/usr/bin/env python3
# Plugin Test Runner

import os
import json
import sys

tests_passed = 0
tests_failed = 0

def run_test(name, test_fn):
    global tests_passed, tests_failed
    print(f"Running: {name}... ", end="")
    try:
        if test_fn():
            print("\\033[32mPASSED\\033[0m")
            tests_passed += 1
        else:
            print("\\033[31mFAILED\\033[0m")
            tests_failed += 1
    except Exception as e:
        print(f"\\033[31mFAILED\\033[0m {str(e)}")
        tests_failed += 1

# Metadata Tests
print("=== Metadata Tests ===")
run_test("Plugin.json exists", lambda: os.path.exists(".claude-plugin/plugin.json"))

def validate_plugin_json():
    with open(".claude-plugin/plugin.json", "r") as f:
        data = json.load(f)
    return all([
        data.get("name"),
        data.get("version"),
        data.get("description"),
        data.get("author")
    ])

run_test("Valid plugin.json", validate_plugin_json)

# Summary
print("\\n=== Test Summary ===")
print(f"Tests Passed: {tests_passed}")
print(f"Tests Failed: {tests_failed}")

if tests_failed == 0:
    print("\\033[32mAll tests passed!\\033[0m")
    sys.exit(0)
else:
    print("\\033[31mSome tests failed.\\033[0m")
    sys.exit(1)`;
}

/**
 * Create test files in the plugin
 * @param {object} tests - Test suite configuration
 * @param {string} pluginPath - Plugin path
 * @returns {object} Creation result
 */
function createTestFiles(tests, pluginPath) {
  const pathManager = new PathManager(pluginPath);
  const result = {
    created: [],
    errors: []
  };

  // Ensure tests directory exists
  pathManager.ensureDir('tests');

  // Create test runner scripts
  const runners = [
    { name: 'test.sh', content: generateTestRunner(tests, 'bash') },
    { name: 'test.js', content: generateTestRunner(tests, 'node') },
    { name: 'test.py', content: generateTestRunner(tests, 'python') }
  ];

  for (const runner of runners) {
    const filePath = pathManager.resolve('tests', runner.name);
    try {
      require('fs').writeFileSync(filePath, runner.content);

      // Make executable
      if (process.platform !== 'win32' && runner.name.endsWith('.sh')) {
        require('fs').chmodSync(filePath, '755');
      }

      result.created.push(`tests/${runner.name}`);
    } catch (error) {
      result.errors.push(`Failed to create ${runner.name}: ${error.message}`);
    }
  }

  // Create test configuration
  const testConfig = {
    tests: tests,
    runner: 'bash',
    timeout: 30000
  };

  try {
    const configPath = pathManager.resolve('tests', 'test-config.json');
    require('fs').writeFileSync(configPath, JSON.stringify(testConfig, null, 2));
    result.created.push('tests/test-config.json');
  } catch (error) {
    result.errors.push(`Failed to create test config: ${error.message}`);
  }

  return result;
}

module.exports = {
  buildTestSuite,
  buildMetadataTests,
  buildCommandTest,
  buildAgentTest,
  buildSkillTest,
  buildHookTest,
  buildIntegrationTests,
  generateTestRunner,
  generateBashTestRunner,
  generateNodeTestRunner,
  generatePythonTestRunner,
  createTestFiles
};