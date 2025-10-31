/**
 * Parser for Plugin-Expert
 * Parse and validate existing plugin files
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const fs = require('fs');
const path = require('path');
const { parseJSON } = require('../utilities/json-yaml');
const { PathManager } = require('../utilities/path-manager');

/**
 * Parse a complete plugin directory
 * @param {string} pluginPath - Path to plugin directory
 * @returns {object} Parsed plugin structure
 */
function parsePlugin(pluginPath) {
  const pathManager = new PathManager(pluginPath);
  const result = {
    valid: false,
    path: pluginPath,
    metadata: null,
    commands: [],
    agents: [],
    skills: [],
    hooks: null,
    marketplace: null,
    errors: [],
    warnings: []
  };

  // Parse plugin.json
  const pluginJsonPath = pathManager.getConfigFilePath('plugin.json');
  if (pathManager.exists('.claude-plugin', 'plugin.json')) {
    const metadata = parsePluginJson(pluginJsonPath);
    result.metadata = metadata.data;
    if (!metadata.success) {
      result.errors.push(`plugin.json: ${metadata.error}`);
    }
  } else {
    result.errors.push('Missing .claude-plugin/plugin.json');
  }

  // Parse marketplace.json if exists
  const marketplacePath = pathManager.getConfigFilePath('marketplace.json');
  if (pathManager.exists('.claude-plugin', 'marketplace.json')) {
    const marketplace = parseMarketplaceJson(marketplacePath);
    result.marketplace = marketplace.data;
    if (!marketplace.success) {
      result.warnings.push(`marketplace.json: ${marketplace.error}`);
    }
  }

  // Parse commands
  if (pathManager.exists('commands')) {
    const commands = parseCommands(pathManager);
    result.commands = commands.items;
    result.errors.push(...commands.errors);
    result.warnings.push(...commands.warnings);
  }

  // Parse agents
  if (pathManager.exists('agents')) {
    const agents = parseAgents(pathManager);
    result.agents = agents.items;
    result.errors.push(...agents.errors);
    result.warnings.push(...agents.warnings);
  }

  // Parse skills
  if (pathManager.exists('skills')) {
    const skills = parseSkills(pathManager);
    result.skills = skills.items;
    result.errors.push(...skills.errors);
    result.warnings.push(...skills.warnings);
  }

  // Parse hooks
  if (pathManager.exists('hooks', 'hooks.json')) {
    const hooks = parseHooksJson(pathManager.resolve('hooks', 'hooks.json'));
    result.hooks = hooks.data;
    if (!hooks.success) {
      result.errors.push(`hooks.json: ${hooks.error}`);
    }
  }

  result.valid = result.errors.length === 0;
  return result;
}

/**
 * Parse plugin.json file
 * @param {string} filePath - Path to plugin.json
 * @returns {object} Parse result
 */
function parsePluginJson(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const parsed = parseJSON(content, 'plugin.json');

    if (!parsed.success) {
      return parsed;
    }

    // Validate required fields
    const required = ['name', 'version', 'description', 'author'];
    const missing = required.filter(field => !parsed.data[field]);

    if (missing.length > 0) {
      return {
        success: false,
        data: parsed.data,
        error: `Missing required fields: ${missing.join(', ')}`
      };
    }

    return parsed;
  } catch (error) {
    return {
      success: false,
      data: null,
      error: error.message
    };
  }
}

/**
 * Parse marketplace.json file
 * @param {string} filePath - Path to marketplace.json
 * @returns {object} Parse result
 */
function parseMarketplaceJson(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const parsed = parseJSON(content, 'marketplace.json');

    if (!parsed.success) {
      return parsed;
    }

    // Validate structure
    if (!parsed.data.plugins || !Array.isArray(parsed.data.plugins)) {
      return {
        success: false,
        data: parsed.data,
        error: 'marketplace.json must have a "plugins" array'
      };
    }

    return parsed;
  } catch (error) {
    return {
      success: false,
      data: null,
      error: error.message
    };
  }
}

/**
 * Parse hooks.json file
 * @param {string} filePath - Path to hooks.json
 * @returns {object} Parse result
 */
function parseHooksJson(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const parsed = parseJSON(content, 'hooks.json');

    if (!parsed.success) {
      return parsed;
    }

    // Validate structure
    if (!parsed.data.hooks || !Array.isArray(parsed.data.hooks)) {
      return {
        success: false,
        data: parsed.data,
        error: 'hooks.json must have a "hooks" array'
      };
    }

    return parsed;
  } catch (error) {
    return {
      success: false,
      data: null,
      error: error.message
    };
  }
}

/**
 * Parse all command files
 * @param {PathManager} pathManager - Path manager instance
 * @returns {object} Parse result with items, errors, warnings
 */
function parseCommands(pathManager) {
  const result = {
    items: [],
    errors: [],
    warnings: []
  };

  const commandFiles = pathManager.listComponentItems('commands');

  for (const cmdFile of commandFiles) {
    const filePath = pathManager.getComponentItemPath('commands', cmdFile, '.md');
    const parsed = parseCommandFile(filePath);

    if (parsed.success) {
      result.items.push(parsed.data);
    } else {
      result.errors.push(`Command ${cmdFile}: ${parsed.error}`);
    }

    if (parsed.warnings) {
      result.warnings.push(...parsed.warnings.map(w => `Command ${cmdFile}: ${w}`));
    }
  }

  return result;
}

/**
 * Parse a single command file
 * @param {string} filePath - Path to command file
 * @returns {object} Parse result
 */
function parseCommandFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const result = parseMarkdownWithFrontmatter(content);

    if (!result.frontmatter.name) {
      return {
        success: false,
        data: null,
        error: 'Command file missing "name" in frontmatter'
      };
    }

    return {
      success: true,
      data: {
        name: result.frontmatter.name,
        description: result.frontmatter.description,
        arguments: result.frontmatter.arguments,
        content: result.body,
        frontmatter: result.frontmatter,
        filePath: filePath
      },
      warnings: result.warnings
    };
  } catch (error) {
    return {
      success: false,
      data: null,
      error: error.message
    };
  }
}

/**
 * Parse all agent files
 * @param {PathManager} pathManager - Path manager instance
 * @returns {object} Parse result
 */
function parseAgents(pathManager) {
  const result = {
    items: [],
    errors: [],
    warnings: []
  };

  const agentFiles = pathManager.listComponentItems('agents');

  for (const agentFile of agentFiles) {
    const filePath = pathManager.getComponentItemPath('agents', agentFile, '.md');
    const parsed = parseAgentFile(filePath);

    if (parsed.success) {
      result.items.push(parsed.data);
    } else {
      result.errors.push(`Agent ${agentFile}: ${parsed.error}`);
    }

    if (parsed.warnings) {
      result.warnings.push(...parsed.warnings.map(w => `Agent ${agentFile}: ${w}`));
    }
  }

  return result;
}

/**
 * Parse a single agent file
 * @param {string} filePath - Path to agent file
 * @returns {object} Parse result
 */
function parseAgentFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const result = parseMarkdownWithFrontmatter(content);

    if (!result.frontmatter.name) {
      return {
        success: false,
        data: null,
        error: 'Agent file missing "name" in frontmatter'
      };
    }

    return {
      success: true,
      data: {
        name: result.frontmatter.name,
        description: result.frontmatter.description,
        content: result.body,
        frontmatter: result.frontmatter,
        filePath: filePath
      },
      warnings: result.warnings
    };
  } catch (error) {
    return {
      success: false,
      data: null,
      error: error.message
    };
  }
}

/**
 * Parse all skill directories
 * @param {PathManager} pathManager - Path manager instance
 * @returns {object} Parse result
 */
function parseSkills(pathManager) {
  const result = {
    items: [],
    errors: [],
    warnings: []
  };

  const skillDirs = pathManager.listComponentItems('skills');

  for (const skillDir of skillDirs) {
    const skillFile = pathManager.resolve('skills', skillDir, 'SKILL.md');
    const parsed = parseSkillFile(skillFile, skillDir);

    if (parsed.success) {
      result.items.push(parsed.data);
    } else {
      result.errors.push(`Skill ${skillDir}: ${parsed.error}`);
    }

    if (parsed.warnings) {
      result.warnings.push(...parsed.warnings.map(w => `Skill ${skillDir}: ${w}`));
    }
  }

  return result;
}

/**
 * Parse a single skill file
 * @param {string} filePath - Path to SKILL.md
 * @param {string} skillName - Skill directory name
 * @returns {object} Parse result
 */
function parseSkillFile(filePath, skillName) {
  try {
    if (!fs.existsSync(filePath)) {
      return {
        success: false,
        data: null,
        error: 'SKILL.md not found'
      };
    }

    const content = fs.readFileSync(filePath, 'utf8');

    return {
      success: true,
      data: {
        name: skillName,
        content: content,
        filePath: filePath
      },
      warnings: []
    };
  } catch (error) {
    return {
      success: false,
      data: null,
      error: error.message
    };
  }
}

/**
 * Parse markdown file with YAML frontmatter
 * @param {string} content - File content
 * @returns {object} Parsed frontmatter and body
 */
function parseMarkdownWithFrontmatter(content) {
  const result = {
    frontmatter: {},
    body: content,
    warnings: []
  };

  // Check for frontmatter
  if (content.startsWith('---\n')) {
    const endIndex = content.indexOf('\n---\n', 4);
    if (endIndex !== -1) {
      const frontmatterText = content.substring(4, endIndex);
      result.body = content.substring(endIndex + 5);

      // Parse YAML frontmatter
      try {
        result.frontmatter = parseYamlFrontmatter(frontmatterText);
      } catch (error) {
        result.warnings.push(`Invalid frontmatter: ${error.message}`);
      }
    } else {
      result.warnings.push('Unclosed frontmatter block');
    }
  } else {
    result.warnings.push('No frontmatter found');
  }

  return result;
}

/**
 * Parse YAML frontmatter (simple parser for common cases)
 * @param {string} yamlText - YAML content
 * @returns {object} Parsed object
 */
function parseYamlFrontmatter(yamlText) {
  const result = {};
  const lines = yamlText.split('\n');
  let currentKey = null;
  let inArray = false;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    if (inArray && trimmed.startsWith('- ')) {
      // Array item
      if (!Array.isArray(result[currentKey])) {
        result[currentKey] = [];
      }
      result[currentKey].push(trimmed.substring(2).trim());
    } else if (line[0] !== ' ' && line.includes(':')) {
      // Top-level key
      const colonIndex = line.indexOf(':');
      currentKey = line.substring(0, colonIndex).trim();
      const value = line.substring(colonIndex + 1).trim();

      if (value) {
        // Inline value
        result[currentKey] = parseYamlValue(value);
        inArray = false;
      } else {
        // Value on next line(s)
        inArray = false;
      }
    } else if (currentKey && trimmed.startsWith('- ')) {
      // Start of array
      inArray = true;
      result[currentKey] = [trimmed.substring(2).trim()];
    }
  }

  return result;
}

/**
 * Parse a YAML value (handle strings, numbers, booleans)
 * @param {string} value - Value string
 * @returns {any} Parsed value
 */
function parseYamlValue(value) {
  // Remove quotes if present
  if ((value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }

  // Boolean
  if (value === 'true') return true;
  if (value === 'false') return false;

  // Null
  if (value === 'null' || value === 'none') return null;

  // Number
  if (/^-?\d+(\.\d+)?$/.test(value)) {
    return parseFloat(value);
  }

  // String
  return value;
}

/**
 * Detect plugin type from directory structure
 * @param {string} pluginPath - Path to analyze
 * @returns {object} Detection result
 */
function detectPluginStructure(pluginPath) {
  const pathManager = new PathManager(pluginPath);
  const structure = {
    hasPluginJson: false,
    hasMarketplace: false,
    hasCommands: false,
    hasAgents: false,
    hasSkills: false,
    hasHooks: false,
    components: [],
    isValid: false
  };

  // Check for plugin.json
  structure.hasPluginJson = pathManager.exists('.claude-plugin', 'plugin.json');
  if (structure.hasPluginJson) structure.components.push('metadata');

  // Check for marketplace.json
  structure.hasMarketplace = pathManager.exists('.claude-plugin', 'marketplace.json');
  if (structure.hasMarketplace) structure.components.push('marketplace');

  // Check for commands
  if (pathManager.exists('commands')) {
    const commands = pathManager.listComponentItems('commands');
    if (commands.length > 0) {
      structure.hasCommands = true;
      structure.components.push('commands');
    }
  }

  // Check for agents
  if (pathManager.exists('agents')) {
    const agents = pathManager.listComponentItems('agents');
    if (agents.length > 0) {
      structure.hasAgents = true;
      structure.components.push('agents');
    }
  }

  // Check for skills
  if (pathManager.exists('skills')) {
    const skills = pathManager.listComponentItems('skills');
    if (skills.length > 0) {
      structure.hasSkills = true;
      structure.components.push('skills');
    }
  }

  // Check for hooks
  structure.hasHooks = pathManager.exists('hooks', 'hooks.json');
  if (structure.hasHooks) structure.components.push('hooks');

  // A valid plugin must have plugin.json and at least one component
  structure.isValid = structure.hasPluginJson &&
                     (structure.hasCommands || structure.hasAgents ||
                      structure.hasSkills || structure.hasHooks);

  return structure;
}

module.exports = {
  parsePlugin,
  parsePluginJson,
  parseMarketplaceJson,
  parseHooksJson,
  parseCommands,
  parseCommandFile,
  parseAgents,
  parseAgentFile,
  parseSkills,
  parseSkillFile,
  parseMarkdownWithFrontmatter,
  parseYamlFrontmatter,
  parseYamlValue,
  detectPluginStructure
};