/**
 * Comprehensive Validator for Plugin-Expert
 * Validate all aspects of a plugin
 * Layer 3: Process Coordinator (depends on Layers 1 & 2)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Utilities
const { PathManager } = require('../utilities/path-manager');
const { validatePluginConfig } = require('../utilities/validation');

// Builders
const { parsePlugin } = require('../builders/parser');
const { validateOrganization } = require('../builders/organization');
const { validateHooksConfig } = require('../builders/hook-builder');

/**
 * Comprehensive plugin validation
 * @param {string} pluginPath - Path to plugin to validate
 * @param {object} options - Validation options
 * @returns {Promise<object>} Validation result
 */
async function validatePlugin(pluginPath, options = {}) {
  const {
    runTests = false,
    checkSecurity = true,
    checkPerformance = false,
    strict = false
  } = options;

  const pathManager = new PathManager(pluginPath);
  const result = {
    valid: false,
    score: 0,
    errors: [],
    warnings: [],
    suggestions: [],
    details: {}
  };

  // Step 1: Structure validation
  console.log('Validating plugin structure...');
  const structureResult = await validateStructure(pathManager);
  result.details.structure = structureResult;
  result.errors.push(...structureResult.errors);
  result.warnings.push(...structureResult.warnings);
  result.suggestions.push(...structureResult.suggestions);

  // Step 2: Metadata validation
  console.log('Validating metadata...');
  const metadataResult = await validateMetadata(pathManager);
  result.details.metadata = metadataResult;
  result.errors.push(...metadataResult.errors);
  result.warnings.push(...metadataResult.warnings);

  // Step 3: Component validation
  console.log('Validating components...');
  const componentsResult = await validateComponents(pathManager);
  result.details.components = componentsResult;
  result.errors.push(...componentsResult.errors);
  result.warnings.push(...componentsResult.warnings);

  // Step 4: Syntax validation
  console.log('Validating syntax...');
  const syntaxResult = await validateSyntax(pathManager);
  result.details.syntax = syntaxResult;
  result.errors.push(...syntaxResult.errors);
  result.warnings.push(...syntaxResult.warnings);

  // Step 5: Security validation (if requested)
  if (checkSecurity) {
    console.log('Checking security...');
    const securityResult = await validateSecurity(pathManager);
    result.details.security = securityResult;
    result.warnings.push(...securityResult.warnings);
    if (strict && securityResult.errors.length > 0) {
      result.errors.push(...securityResult.errors);
    }
  }

  // Step 6: Performance validation (if requested)
  if (checkPerformance) {
    console.log('Checking performance...');
    const performanceResult = await validatePerformance(pathManager);
    result.details.performance = performanceResult;
    result.suggestions.push(...performanceResult.suggestions);
  }

  // Step 7: Run tests (if requested)
  if (runTests) {
    console.log('Running tests...');
    const testResult = await runValidationTests(pathManager);
    result.details.tests = testResult;
    if (!testResult.passed) {
      result.warnings.push('Some tests failed');
    }
  }

  // Calculate score
  result.score = calculateValidationScore(result);
  result.valid = result.errors.length === 0 && (!strict || result.warnings.length === 0);

  return result;
}

/**
 * Validate plugin structure
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Structure validation result
 */
async function validateStructure(pathManager) {
  const result = {
    errors: [],
    warnings: [],
    suggestions: []
  };

  // Check required directories and files
  if (!pathManager.exists('.claude-plugin')) {
    result.errors.push('Missing .claude-plugin directory');
  }

  if (!pathManager.exists('.claude-plugin', 'plugin.json')) {
    result.errors.push('Missing plugin.json');
  }

  // Check for at least one component
  const hasComponent = ['commands', 'agents', 'skills', 'hooks'].some(dir => {
    if (pathManager.exists(dir)) {
      const items = pathManager.listComponentItems(dir === 'hooks' ? 'commands' : dir);
      return items.length > 0;
    }
    return false;
  });

  if (!hasComponent) {
    result.errors.push('Plugin must have at least one component (command, agent, skill, or hook)');
  }

  // Check organization
  const orgValidation = validateOrganization(pathManager.getBasePath());
  result.warnings.push(...orgValidation.issues);
  result.suggestions.push(...orgValidation.suggestions);

  // Check for documentation
  if (!pathManager.exists('README.md')) {
    result.warnings.push('Missing README.md');
  }

  // Check for unnecessary files
  const unnecessaryFiles = ['.DS_Store', 'Thumbs.db', 'desktop.ini'];
  for (const file of unnecessaryFiles) {
    if (pathManager.exists(file)) {
      result.suggestions.push(`Remove unnecessary file: ${file}`);
    }
  }

  return result;
}

/**
 * Validate plugin metadata
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Metadata validation result
 */
async function validateMetadata(pathManager) {
  const result = {
    errors: [],
    warnings: []
  };

  const pluginJsonPath = pathManager.getConfigFilePath('plugin.json');

  if (!fs.existsSync(pluginJsonPath)) {
    result.errors.push('plugin.json not found');
    return result;
  }

  try {
    const content = fs.readFileSync(pluginJsonPath, 'utf8');
    const data = JSON.parse(content);

    // Validate using utility function
    const validationErrors = validatePluginConfig(data);
    result.errors.push(...validationErrors);

    // Additional checks
    if (data.keywords && data.keywords.length > 10) {
      result.warnings.push('Too many keywords (max 10 recommended)');
    }

    if (data.description && data.description.length < 10) {
      result.warnings.push('Description is too short (at least 10 characters recommended)');
    }

    // Check for semantic version
    if (data.version && !data.version.match(/^\d+\.\d+\.\d+/)) {
      result.warnings.push('Version should follow semantic versioning (e.g., 1.0.0)');
    }

  } catch (error) {
    result.errors.push(`Invalid plugin.json: ${error.message}`);
  }

  return result;
}

/**
 * Validate plugin components
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Components validation result
 */
async function validateComponents(pathManager) {
  const result = {
    errors: [],
    warnings: []
  };

  // Validate commands
  if (pathManager.exists('commands')) {
    const commands = pathManager.listComponentItems('commands');
    for (const cmd of commands) {
      const filePath = pathManager.getComponentItemPath('commands', cmd, '.md');
      const validation = validateCommandFile(filePath);
      result.errors.push(...validation.errors.map(e => `commands/${cmd}: ${e}`));
      result.warnings.push(...validation.warnings.map(w => `commands/${cmd}: ${w}`));
    }
  }

  // Validate agents
  if (pathManager.exists('agents')) {
    const agents = pathManager.listComponentItems('agents');
    for (const agent of agents) {
      const filePath = pathManager.getComponentItemPath('agents', agent, '.md');
      const validation = validateAgentFile(filePath);
      result.errors.push(...validation.errors.map(e => `agents/${agent}: ${e}`));
      result.warnings.push(...validation.warnings.map(w => `agents/${agent}: ${w}`));
    }
  }

  // Validate skills
  if (pathManager.exists('skills')) {
    const skills = pathManager.listComponentItems('skills');
    for (const skill of skills) {
      const skillPath = pathManager.resolve('skills', skill, 'SKILL.md');
      if (!fs.existsSync(skillPath)) {
        result.errors.push(`skills/${skill}: Missing SKILL.md`);
      } else {
        const validation = validateSkillFile(skillPath);
        result.errors.push(...validation.errors.map(e => `skills/${skill}: ${e}`));
        result.warnings.push(...validation.warnings.map(w => `skills/${skill}: ${w}`));
      }
    }
  }

  // Validate hooks
  if (pathManager.exists('hooks', 'hooks.json')) {
    try {
      const content = fs.readFileSync(pathManager.resolve('hooks', 'hooks.json'), 'utf8');
      const hooksConfig = JSON.parse(content);
      const hookErrors = validateHooksConfig(hooksConfig);
      result.errors.push(...hookErrors.map(e => `hooks: ${e}`));
    } catch (error) {
      result.errors.push(`hooks.json: ${error.message}`);
    }
  }

  return result;
}

/**
 * Validate command file
 * @param {string} filePath - Path to command file
 * @returns {object} Validation result
 */
function validateCommandFile(filePath) {
  const result = {
    errors: [],
    warnings: []
  };

  try {
    const content = fs.readFileSync(filePath, 'utf8');

    // Check for frontmatter
    if (!content.startsWith('---\n')) {
      result.errors.push('Missing frontmatter');
      return result;
    }

    // Parse frontmatter
    const endIndex = content.indexOf('\n---\n', 4);
    if (endIndex === -1) {
      result.errors.push('Unclosed frontmatter');
      return result;
    }

    // Check required frontmatter fields
    const frontmatter = content.substring(4, endIndex);
    if (!frontmatter.includes('name:')) {
      result.errors.push('Missing name in frontmatter');
    }
    if (!frontmatter.includes('description:')) {
      result.warnings.push('Missing description in frontmatter');
    }

    // Check content
    const body = content.substring(endIndex + 5);
    if (body.trim().length < 10) {
      result.warnings.push('Command body is too short');
    }

  } catch (error) {
    result.errors.push(error.message);
  }

  return result;
}

/**
 * Validate agent file
 * @param {string} filePath - Path to agent file
 * @returns {object} Validation result
 */
function validateAgentFile(filePath) {
  const result = {
    errors: [],
    warnings: []
  };

  try {
    const content = fs.readFileSync(filePath, 'utf8');

    // Similar validation to command file
    if (!content.startsWith('---\n')) {
      result.errors.push('Missing frontmatter');
      return result;
    }

    const endIndex = content.indexOf('\n---\n', 4);
    if (endIndex === -1) {
      result.errors.push('Unclosed frontmatter');
      return result;
    }

    const frontmatter = content.substring(4, endIndex);
    if (!frontmatter.includes('name:')) {
      result.errors.push('Missing name in frontmatter');
    }

    const body = content.substring(endIndex + 5);
    if (!body.includes('# ')) {
      result.warnings.push('Agent should have section headers');
    }

  } catch (error) {
    result.errors.push(error.message);
  }

  return result;
}

/**
 * Validate skill file
 * @param {string} filePath - Path to SKILL.md
 * @returns {object} Validation result
 */
function validateSkillFile(filePath) {
  const result = {
    errors: [],
    warnings: []
  };

  try {
    const content = fs.readFileSync(filePath, 'utf8');

    if (content.trim().length < 50) {
      result.warnings.push('Skill description is too short');
    }

    if (!content.includes('## ')) {
      result.warnings.push('Skill should have section headers');
    }

  } catch (error) {
    result.errors.push(error.message);
  }

  return result;
}

/**
 * Validate syntax across all files
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Syntax validation result
 */
async function validateSyntax(pathManager) {
  const { parsePlugin } = require('../builders/parser');

  const result = {
    errors: [],
    warnings: []
  };

  // Parse the entire plugin
  const parsed = parsePlugin(pathManager.getBasePath());

  if (!parsed.valid) {
    result.errors.push(...parsed.errors);
  }
  result.warnings.push(...parsed.warnings);

  return result;
}

/**
 * Validate security aspects
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Security validation result
 */
async function validateSecurity(pathManager) {
  const result = {
    errors: [],
    warnings: []
  };

  // Check for sensitive data in plugin.json
  const pluginJsonPath = pathManager.getConfigFilePath('plugin.json');
  if (fs.existsSync(pluginJsonPath)) {
    const content = fs.readFileSync(pluginJsonPath, 'utf8');

    // Check for potential secrets
    const secretPatterns = [
      /api[_-]?key/i,
      /secret/i,
      /password/i,
      /token/i,
      /private[_-]?key/i
    ];

    for (const pattern of secretPatterns) {
      if (pattern.test(content)) {
        result.warnings.push('Potential sensitive data found in plugin.json');
        break;
      }
    }
  }

  // Check hook scripts for dangerous commands
  if (pathManager.exists('hooks')) {
    const hookFiles = fs.readdirSync(pathManager.resolve('hooks'))
      .filter(f => f.endsWith('.sh') || f.endsWith('.js') || f.endsWith('.py'));

    for (const file of hookFiles) {
      const filePath = pathManager.resolve('hooks', file);
      const content = fs.readFileSync(filePath, 'utf8');

      // Check for dangerous patterns
      const dangerousPatterns = [
        /rm\s+-rf\s+\//,
        /curl.*\|.*bash/,
        /eval\(/,
        /exec\(/
      ];

      for (const pattern of dangerousPatterns) {
        if (pattern.test(content)) {
          result.warnings.push(`Potentially dangerous code in hooks/${file}`);
          break;
        }
      }
    }
  }

  // Check file permissions
  if (process.platform !== 'win32') {
    const checkPermissions = (dir) => {
      if (pathManager.exists(dir)) {
        const files = fs.readdirSync(pathManager.resolve(dir));
        for (const file of files) {
          const filePath = pathManager.resolve(dir, file);
          const stats = fs.statSync(filePath);
          const mode = (stats.mode & parseInt('777', 8)).toString(8);
          if (mode === '777') {
            result.warnings.push(`Overly permissive file permissions: ${dir}/${file}`);
          }
        }
      }
    };

    ['hooks', 'commands', 'agents', 'skills'].forEach(checkPermissions);
  }

  return result;
}

/**
 * Validate performance aspects
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Performance validation result
 */
async function validatePerformance(pathManager) {
  const result = {
    suggestions: []
  };

  // Check file sizes
  const checkFileSize = (filePath, maxSize, type) => {
    if (fs.existsSync(filePath)) {
      const stats = fs.statSync(filePath);
      if (stats.size > maxSize) {
        result.suggestions.push(
          `${type} file is large (${Math.round(stats.size / 1024)}KB). Consider optimizing.`
        );
      }
    }
  };

  // Check plugin.json size
  checkFileSize(pathManager.getConfigFilePath('plugin.json'), 10 * 1024, 'plugin.json');

  // Check for large command/agent files
  if (pathManager.exists('commands')) {
    const commands = pathManager.listComponentItems('commands');
    for (const cmd of commands) {
      const filePath = pathManager.getComponentItemPath('commands', cmd, '.md');
      checkFileSize(filePath, 50 * 1024, `Command ${cmd}`);
    }
  }

  // Check for too many components
  const componentCounts = {
    commands: pathManager.listComponentItems('commands').length,
    agents: pathManager.listComponentItems('agents').length,
    skills: pathManager.listComponentItems('skills').length
  };

  if (componentCounts.commands > 20) {
    result.suggestions.push(`Many commands (${componentCounts.commands}). Consider grouping or splitting into multiple plugins.`);
  }

  if (componentCounts.agents > 10) {
    result.suggestions.push(`Many agents (${componentCounts.agents}). Consider consolidating functionality.`);
  }

  return result;
}

/**
 * Run validation tests
 * @param {PathManager} pathManager - Path manager
 * @returns {Promise<object>} Test result
 */
async function runValidationTests(pathManager) {
  const result = {
    passed: false,
    tests: 0,
    failures: 0,
    output: ''
  };

  // Look for test runner
  const testRunners = ['tests/test.sh', 'tests/test.js', 'tests/test.py'];
  let testRunner = null;

  for (const runner of testRunners) {
    if (pathManager.exists(...runner.split('/'))) {
      testRunner = pathManager.resolve(...runner.split('/'));
      break;
    }
  }

  if (!testRunner) {
    result.output = 'No test runner found';
    return result;
  }

  try {
    // Run tests with timeout
    const output = execSync(testRunner, {
      cwd: pathManager.getBasePath(),
      timeout: 30000,
      encoding: 'utf8'
    });

    result.output = output;
    result.passed = true;

    // Try to parse test count from output
    const passMatch = output.match(/(\d+)\s+passed/i);
    const failMatch = output.match(/(\d+)\s+failed/i);

    if (passMatch) {
      result.tests += parseInt(passMatch[1]);
    }
    if (failMatch) {
      result.failures = parseInt(failMatch[1]);
      result.passed = result.failures === 0;
    }

  } catch (error) {
    result.output = error.message;
    result.passed = false;
  }

  return result;
}

/**
 * Calculate validation score
 * @param {object} result - Validation result
 * @returns {number} Score from 0-100
 */
function calculateValidationScore(result) {
  let score = 100;

  // Deduct for errors (10 points each)
  score -= result.errors.length * 10;

  // Deduct for warnings (3 points each)
  score -= result.warnings.length * 3;

  // Deduct for suggestions (1 point each)
  score -= result.suggestions.length;

  // Bonus for passing tests
  if (result.details.tests && result.details.tests.passed) {
    score += 5;
  }

  // Bonus for good security
  if (result.details.security && result.details.security.warnings.length === 0) {
    score += 5;
  }

  return Math.max(0, Math.min(100, score));
}

module.exports = {
  validatePlugin,
  validateStructure,
  validateMetadata,
  validateComponents,
  validateCommandFile,
  validateAgentFile,
  validateSkillFile,
  validateSyntax,
  validateSecurity,
  validatePerformance,
  runValidationTests,
  calculateValidationScore
};