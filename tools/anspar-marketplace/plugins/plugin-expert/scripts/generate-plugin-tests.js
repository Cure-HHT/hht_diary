#!/usr/bin/env node
/**
 * Generate test suite for any plugin using the test-builder
 * Usage: node generate-plugin-tests.js <plugin-path>
 */

const path = require('path');
const fs = require('fs');
const testBuilder = require('../builders/test-builder');

// Get plugin path from command line argument
const pluginPath = process.argv[2];

if (!pluginPath) {
  console.error('Usage: node generate-plugin-tests.js <plugin-path>');
  console.error('Example: node generate-plugin-tests.js ../../linear-integration');
  process.exit(1);
}

const pluginRoot = path.resolve(pluginPath);

if (!fs.existsSync(pluginRoot)) {
  console.error(`Error: Plugin path does not exist: ${pluginRoot}`);
  process.exit(1);
}

const pluginJsonPath = path.join(pluginRoot, '.claude-plugin', 'plugin.json');
if (!fs.existsSync(pluginJsonPath)) {
  console.error(`Error: plugin.json not found at: ${pluginJsonPath}`);
  process.exit(1);
}

// Read plugin.json
const pluginJson = JSON.parse(fs.readFileSync(pluginJsonPath, 'utf8'));

console.log(`🔨 Generating test suite for ${pluginJson.name}...`);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');

// Discover plugin components
const components = {
  commands: [],
  agents: [],
  skills: [],
  hooks: []
};

// Find commands
const commandsDir = path.join(pluginRoot, 'commands');
if (fs.existsSync(commandsDir)) {
  const commandFiles = fs.readdirSync(commandsDir).filter(f => f.endsWith('.md'));
  commandFiles.forEach(file => {
    const commandName = file.replace('.md', '');
    components.commands.push({
      name: commandName,
      filePath: `commands/${file}`,
      spec: {
        testArgs: ['--help'],
        testOutput: 'should provide help information'
      }
    });
  });
}

// Find agents
const agentsDir = path.join(pluginRoot, 'agents');
if (fs.existsSync(agentsDir)) {
  const agentFiles = fs.readdirSync(agentsDir).filter(f => f.endsWith('.md'));
  agentFiles.forEach(file => {
    const agentName = file.replace('.md', '');
    components.agents.push({
      name: agentName,
      testInput: 'Test input for agent',
      testBehavior: 'Agent responds appropriately'
    });
  });
}

// Find skills
const skillsDir = path.join(pluginRoot, 'skills');
if (fs.existsSync(skillsDir)) {
  const skillDirs = fs.readdirSync(skillsDir).filter(f => {
    const fullPath = path.join(skillsDir, f);
    return fs.statSync(fullPath).isDirectory();
  });
  skillDirs.forEach(skillDir => {
    components.skills.push({
      name: skillDir
    });
  });
}

// Find hooks
const hooksJsonPath = path.join(pluginRoot, 'hooks', 'hooks.json');
if (fs.existsSync(hooksJsonPath)) {
  try {
    const hooksJson = JSON.parse(fs.readFileSync(hooksJsonPath, 'utf8'));
    if (hooksJson.hooks) {
      Object.entries(hooksJson.hooks).forEach(([event, hook]) => {
        components.hooks.push({
          event: event,
          command: hook.command || hook,
          script: hook.script
        });
      });
    }
  } catch (e) {
    console.warn(`Warning: Could not parse hooks.json: ${e.message}`);
  }
}

console.log('📋 Discovered components:');
console.log(`   - Commands: ${components.commands.length}`);
console.log(`   - Agents: ${components.agents.length}`);
console.log(`   - Skills: ${components.skills.length}`);
console.log(`   - Hooks: ${components.hooks.length}`);
console.log('');

// Build the test suite
const tests = testBuilder.buildTestSuite(pluginJson, components, pluginRoot);

console.log('✅ Test suite structure generated:');
console.log(`   - Metadata tests: ${tests.metadata.tests.length} tests`);
console.log(`   - Command tests: ${tests.commands.length} command suites`);
console.log(`   - Agent tests: ${tests.agents.length} agent suites`);
console.log(`   - Skill tests: ${tests.skills.length} skill suites`);
console.log(`   - Hook tests: ${tests.hooks.length} hook suites`);
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

// Add custom tests for scripts directory
const scriptsDir = path.join(pluginRoot, 'scripts');
if (fs.existsSync(scriptsDir)) {
  const scriptFiles = fs.readdirSync(scriptsDir).filter(f =>
    f.endsWith('.sh') || f.endsWith('.js') || f.endsWith('.py')
  );

  if (scriptFiles.length > 0) {
    console.log('📋 Adding custom tests for scripts...');

    let customTests = '\n# Scripts Tests\necho ""\necho "=== Scripts Tests ==="\n';
    scriptFiles.forEach(file => {
      const ext = path.extname(file);
      const testName = `${file} exists`;
      customTests += `run_test "${testName}" "test -f scripts/${file}"\n`;

      // Add executability test for shell scripts
      if (ext === '.sh') {
        customTests += `run_test "${file} is executable" "test -x scripts/${file}"\n`;
      }
    });

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
          '\n' +
          testContent.slice(summaryIndex);

        fs.writeFileSync(testShPath, testContent);
        console.log(`✅ Added tests for ${scriptFiles.length} scripts`);
      }
    }
  }
}

// Create README
const readmePath = path.join(pluginRoot, 'tests', 'README.md');
if (!fs.existsSync(readmePath)) {
  const readme = `# ${pluginJson.name} Test Suite

${pluginJson.description}

## Test Coverage

This test suite was auto-generated using the plugin-expert test-builder.

### Components Tested
- Commands: ${components.commands.length}
- Agents: ${components.agents.length}
- Skills: ${components.skills.length}
- Hooks: ${components.hooks.length}

## Running Tests

### Bash Test Suite (Recommended)
\`\`\`bash
bash tests/test.sh
\`\`\`

### Node.js Test Suite
\`\`\`bash
node tests/test.js
\`\`\`

### Python Test Suite
\`\`\`bash
python3 tests/test.py
\`\`\`

## Test Configuration

Test configuration is stored in \`test-config.json\`.

## Regenerating Tests

To regenerate this test suite:

\`\`\`bash
node path/to/plugin-expert/scripts/generate-plugin-tests.js .
\`\`\`
`;
  fs.writeFileSync(readmePath, readme);
  console.log('✅ Created tests/README.md');
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
