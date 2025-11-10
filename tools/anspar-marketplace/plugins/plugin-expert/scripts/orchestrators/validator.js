/**
 * Comprehensive Validator for Plugin-Expert
 * Validate all aspects of a plugin
 * Layer 3: Process Coordinator (depends on Layers 1 & 2)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Utilities
const { PathManager } = require('../utils/path-manager');
const { validatePluginConfig } = require('../utils/validation');

// Builders
const { parsePlugin } = require('../generators/parser');
const { validateOrganization } = require('../generators/organization');
const { validateHooksConfig } = require('../generators/hook-builder');

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
 * Validate agent file with comprehensive structure and emphasis checks
 * @param {string} filePath - Path to agent file
 * @returns {object} Validation result
 */
function validateAgentFile(filePath) {
  const result = {
    errors: [],
    warnings: [],
    suggestions: [],
    metrics: {
      emphasisCount: 0,
      sectionCount: 0,
      hasIdentity: false,
      hasOperationalApproach: false,
      hasAvailableTools: false,
      hasExamples: false
    }
  };

  try {
    const content = fs.readFileSync(filePath, 'utf8');

    // 1. YAML Frontmatter Validation
    if (!content.startsWith('---\n')) {
      result.errors.push('Missing YAML frontmatter (must start with "---\\n")');
      return result;
    }

    const endIndex = content.indexOf('\n---\n', 4);
    if (endIndex === -1) {
      result.errors.push('Unclosed YAML frontmatter (missing closing "---")');
      return result;
    }

    const frontmatter = content.substring(4, endIndex);
    const body = content.substring(endIndex + 5);

    // Required frontmatter fields
    if (!frontmatter.includes('name:')) {
      result.errors.push('Missing "name:" field in frontmatter');
    }
    if (!frontmatter.includes('description:')) {
      result.errors.push('Missing "description:" field in frontmatter');
    }

    // 2. Section Structure Validation (Option A)
    const sections = extractSections(body);
    result.metrics.sectionCount = sections.length;

    if (sections.length === 0) {
      result.errors.push('Agent has no section headers (use # or ## for sections)');
      return result;
    }

    // Check for required sections (flexible matching)
    const sectionNames = sections.map(s => s.title.toLowerCase());

    // Identity: role, purpose, what the agent is
    const identityPatterns = ['role', 'purpose', 'identity', 'overview', 'who you are'];
    result.metrics.hasIdentity = sectionNames.some(name =>
      identityPatterns.some(pattern => name.includes(pattern))
    );

    // Operational approach: capabilities, workflow, what it does
    const operationalPatterns = ['capabilities', 'core capabilities', 'workflow', 'operational', 'what you can do', 'how to use'];
    result.metrics.hasOperationalApproach = sectionNames.some(name =>
      operationalPatterns.some(pattern => name.includes(pattern))
    );

    // Available tools/skills: how to invoke them
    const toolsPatterns = ['available tools', 'available skills', 'tools', 'skills', 'how to invoke'];
    result.metrics.hasAvailableTools = sectionNames.some(name =>
      toolsPatterns.some(pattern => name.includes(pattern))
    );

    // Examples (optional but recommended)
    const examplePatterns = ['example', 'usage', 'how to use'];
    result.metrics.hasExamples = sectionNames.some(name =>
      examplePatterns.some(pattern => name.includes(pattern))
    );

    // Report missing critical sections
    if (!result.metrics.hasIdentity) {
      result.warnings.push('Missing Identity section (recommended: "# Role" or "## Purpose")');
    }
    if (!result.metrics.hasOperationalApproach) {
      result.warnings.push('Missing Operational section (recommended: "## Capabilities" or "## Workflow")');
    }
    if (!result.metrics.hasAvailableTools) {
      result.warnings.push('Missing Tools section (recommended: "## Available Tools" or "## Available Skills")');
    }
    if (!result.metrics.hasExamples) {
      result.suggestions.push('Consider adding "## Examples" section to demonstrate usage');
    }

    // 3. Emphasis Balance Validation (Option B enhancement)
    const emphasisMarkers = [
      'CRITICAL',
      'IMPORTANT',
      'MUST',
      'NEVER',
      'ALWAYS',
      'MANDATORY',
      'WARNING',
      'REQUIRED'
    ];

    result.metrics.emphasisCount = countEmphasisMarkers(body, emphasisMarkers);

    // Check emphasis balance
    const wordCount = body.split(/\s+/).length;
    const emphasisRatio = result.metrics.emphasisCount / wordCount;

    if (result.metrics.emphasisCount === 0) {
      result.suggestions.push('Consider using emphasis markers (CRITICAL, IMPORTANT, MUST) for key points');
    } else if (result.metrics.emphasisCount > 20) {
      result.warnings.push(`Too many emphasis markers (${result.metrics.emphasisCount} found). When everything is emphasized, nothing is. Limit to 5-15 critical points.`);
    } else if (result.metrics.emphasisCount > 15) {
      result.suggestions.push(`High emphasis count (${result.metrics.emphasisCount}). Consider if all are truly critical.`);
    } else if (emphasisRatio > 0.05) {
      result.warnings.push(`Emphasis overuse detected (${(emphasisRatio * 100).toFixed(1)}% of words). Keep critical emphasis under 3% of content.`);
    }

    // 4. Content Quality Checks (Option B)

    // Check for thin delegator pattern in tools section
    if (result.metrics.hasAvailableTools) {
      const toolsSection = sections.find(s =>
        ['available tools', 'available skills'].some(p => s.title.toLowerCase().includes(p))
      );

      if (toolsSection) {
        const hasInvocationExamples =
          toolsSection.content.includes('${CLAUDE_PLUGIN_ROOT}') ||
          toolsSection.content.includes('bash') ||
          toolsSection.content.includes('```') ||
          toolsSection.content.includes('node ') ||
          toolsSection.content.includes('python ');

        if (!hasInvocationExamples) {
          result.warnings.push('Available Tools section should show HOW to invoke tools (using Bash tool, with examples)');
        }
      }
    }

    // Check for auto-invocation triggers if applicable
    const hasAutoInvoke = body.toLowerCase().includes('auto-invoke') ||
                          body.toLowerCase().includes('when to invoke') ||
                          body.toLowerCase().includes('when to use');
    if (!hasAutoInvoke) {
      result.suggestions.push('Consider adding auto-invocation triggers or "When to Use" section');
    }

    // Check minimum length
    if (body.trim().length < 200) {
      result.warnings.push('Agent body seems too short (< 200 chars). Add more detail about capabilities and usage.');
    }

    // 5. Structural Issues

    // Check for proper heading hierarchy
    const headingLevels = extractHeadingLevels(body);
    if (headingLevels.length > 0 && headingLevels[0] !== 1) {
      result.warnings.push('First heading should be level 1 (# Title)');
    }

    // Check for orphaned emphasis (CRITICAL: without context)
    const emphasisLines = body.split('\n').filter(line =>
      emphasisMarkers.some(marker => line.includes(marker))
    );

    const orphanedEmphasis = emphasisLines.filter(line => {
      const trimmed = line.trim();
      // Check if it's a standalone word without explanation
      return emphasisMarkers.some(marker =>
        trimmed === `**${marker}**` ||
        trimmed === marker ||
        (trimmed.includes(marker) && trimmed.length < marker.length + 20)
      );
    });

    if (orphanedEmphasis.length > 0) {
      result.warnings.push('Found emphasis markers without context. Always explain WHY something is critical.');
    }

  } catch (error) {
    result.errors.push(`Validation error: ${error.message}`);
  }

  return result;
}

/**
 * Extract sections from markdown content
 * @param {string} content - Markdown content
 * @returns {Array} Array of {title, level, content}
 */
function extractSections(content) {
  const sections = [];
  const lines = content.split('\n');
  let currentSection = null;

  for (const line of lines) {
    const match = line.match(/^(#{1,6})\s+(.+)$/);
    if (match) {
      if (currentSection) {
        sections.push(currentSection);
      }
      currentSection = {
        title: match[2].trim(),
        level: match[1].length,
        content: ''
      };
    } else if (currentSection) {
      currentSection.content += line + '\n';
    }
  }

  if (currentSection) {
    sections.push(currentSection);
  }

  return sections;
}

/**
 * Extract heading levels from content
 * @param {string} content - Markdown content
 * @returns {Array} Array of heading levels
 */
function extractHeadingLevels(content) {
  const levels = [];
  const lines = content.split('\n');

  for (const line of lines) {
    const match = line.match(/^(#{1,6})\s+/);
    if (match) {
      levels.push(match[1].length);
    }
  }

  return levels;
}

/**
 * Count emphasis markers in content
 * @param {string} content - Text content
 * @param {Array} markers - Emphasis markers to count
 * @returns {number} Total count
 */
function countEmphasisMarkers(content, markers) {
  let count = 0;
  for (const marker of markers) {
    const regex = new RegExp(marker, 'gi');
    const matches = content.match(regex);
    if (matches) {
      count += matches.length;
    }
  }
  return count;
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
  const { parsePlugin } = require('../generators/parser');

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

  // Patterns that trigger marketplace security scanners
  // Even in example/documentation code, these will cause issues
  const marketplaceScannerPatterns = [
    { pattern: /\bAPI_KEY\b/g, name: 'API_KEY', severity: 'error' },
    { pattern: /\bSECRET_KEY\b/g, name: 'SECRET_KEY', severity: 'error' },
    { pattern: /\bPRIVATE_KEY\b/g, name: 'PRIVATE_KEY', severity: 'error' },
    { pattern: /\bTOKEN\b(?!_)/g, name: 'TOKEN', severity: 'error' },
    { pattern: /\bPASSWORD\b/g, name: 'PASSWORD', severity: 'error' },
    { pattern: /\bACCESS_KEY\b/g, name: 'ACCESS_KEY', severity: 'error' },
    { pattern: /\bAUTH_TOKEN\b/g, name: 'AUTH_TOKEN', severity: 'error' }
  ];

  // Patterns for actual secrets (looser matching)
  const secretPatterns = [
    { pattern: /api[_-]?key\s*[=:]\s*['"][^'"]+['"]/i, name: 'API key value', severity: 'error' },
    { pattern: /secret\s*[=:]\s*['"][^'"]+['"]/i, name: 'Secret value', severity: 'error' },
    { pattern: /password\s*[=:]\s*['"][^'"]+['"]/i, name: 'Password value', severity: 'error' },
    { pattern: /token\s*[=:]\s*['"][^'"]+['"]/i, name: 'Token value', severity: 'error' },
    { pattern: /Bearer\s+[A-Za-z0-9_-]{20,}/i, name: 'Bearer token', severity: 'error' }
  ];

  // Check all plugin files, not just plugin.json
  const filesToCheck = [];

  // Check plugin.json
  const pluginJsonPath = pathManager.getConfigFilePath('plugin.json');
  if (fs.existsSync(pluginJsonPath)) {
    filesToCheck.push({ path: pluginJsonPath, type: 'plugin.json' });
  }

  // Check commands
  if (pathManager.exists('commands')) {
    const commands = pathManager.listComponentItems('commands');
    for (const cmd of commands) {
      const filePath = pathManager.getComponentItemPath('commands', cmd, '.md');
      if (fs.existsSync(filePath)) {
        filesToCheck.push({ path: filePath, type: `commands/${cmd}.md` });
      }
    }
  }

  // Check agents
  if (pathManager.exists('agents')) {
    const agents = pathManager.listComponentItems('agents');
    for (const agent of agents) {
      const filePath = pathManager.getComponentItemPath('agents', agent, '.md');
      if (fs.existsSync(filePath)) {
        filesToCheck.push({ path: filePath, type: `agents/${agent}.md` });
      }
    }
  }

  // Check skills
  if (pathManager.exists('skills')) {
    const skills = pathManager.listComponentItems('skills');
    for (const skill of skills) {
      const skillPath = pathManager.resolve('skills', skill, 'SKILL.md');
      if (fs.existsSync(skillPath)) {
        filesToCheck.push({ path: skillPath, type: `skills/${skill}/SKILL.md` });
      }
    }
  }

  // Check examples directory
  if (pathManager.exists('examples')) {
    const examples = fs.readdirSync(pathManager.resolve('examples'));
    for (const file of examples) {
      if (file.endsWith('.md') || file.endsWith('.js') || file.endsWith('.sh')) {
        const filePath = pathManager.resolve('examples', file);
        filesToCheck.push({ path: filePath, type: `examples/${file}` });
      }
    }
  }

  // Check README and other docs
  ['README.md', 'docs/USAGE.md', 'docs/INSTALLATION.md'].forEach(docPath => {
    const parts = docPath.split('/');
    if (pathManager.exists(...parts)) {
      const fullPath = pathManager.resolve(...parts);
      filesToCheck.push({ path: fullPath, type: docPath });
    }
  });

  // Scan all files
  for (const file of filesToCheck) {
    const content = fs.readFileSync(file.path, 'utf8');

    // Check for marketplace scanner triggers
    for (const { pattern, name, severity } of marketplaceScannerPatterns) {
      const matches = content.match(pattern);
      if (matches) {
        const message = `${file.type}: Contains "${name}" which triggers marketplace security scanners. Use generic names like "PLUGIN_CONFIG" or "SETTING" instead.`;
        if (severity === 'error') {
          result.errors.push(message);
        } else {
          result.warnings.push(message);
        }
      }
    }

    // Check for actual secret values
    for (const { pattern, name, severity } of secretPatterns) {
      if (pattern.test(content)) {
        const message = `${file.type}: Contains actual ${name} - never commit real credentials!`;
        if (severity === 'error') {
          result.errors.push(message);
        } else {
          result.warnings.push(message);
        }
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