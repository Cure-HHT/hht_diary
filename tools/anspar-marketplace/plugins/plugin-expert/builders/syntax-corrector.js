/**
 * Syntax Corrector for Plugin-Expert
 * Fix common syntax issues in plugin files
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const fs = require('fs');
const { toKebabCase, toPascalCase } = require('../utilities/string-helpers');
const { isValidPluginName, isValidVersion, isValidCommandName } = require('../utilities/validation');
const { safeJSONStringify } = require('../utilities/escape-helpers');
const { PathManager } = require('../utilities/path-manager');

/**
 * Correct syntax issues in a complete plugin
 * @param {string} pluginPath - Path to plugin directory
 * @param {object} options - Correction options
 * @returns {object} Correction result
 */
function correctPluginSyntax(pluginPath, options = {}) {
  const pathManager = new PathManager(pluginPath);
  const result = {
    fixed: [],
    errors: [],
    backups: []
  };

  // Correct plugin.json
  if (pathManager.exists('.claude-plugin', 'plugin.json')) {
    const pluginJsonResult = correctPluginJson(
      pathManager.getConfigFilePath('plugin.json'),
      options
    );
    if (pluginJsonResult.fixed) {
      result.fixed.push('plugin.json');
      if (pluginJsonResult.backup) {
        result.backups.push(pluginJsonResult.backup);
      }
    }
    if (pluginJsonResult.error) {
      result.errors.push(`plugin.json: ${pluginJsonResult.error}`);
    }
  }

  // Correct marketplace.json
  if (pathManager.exists('.claude-plugin', 'marketplace.json')) {
    const marketplaceResult = correctMarketplaceJson(
      pathManager.getConfigFilePath('marketplace.json'),
      options
    );
    if (marketplaceResult.fixed) {
      result.fixed.push('marketplace.json');
      if (marketplaceResult.backup) {
        result.backups.push(marketplaceResult.backup);
      }
    }
    if (marketplaceResult.error) {
      result.errors.push(`marketplace.json: ${marketplaceResult.error}`);
    }
  }

  // Correct hooks.json
  if (pathManager.exists('hooks', 'hooks.json')) {
    const hooksResult = correctHooksJson(
      pathManager.resolve('hooks', 'hooks.json'),
      options
    );
    if (hooksResult.fixed) {
      result.fixed.push('hooks.json');
      if (hooksResult.backup) {
        result.backups.push(hooksResult.backup);
      }
    }
    if (hooksResult.error) {
      result.errors.push(`hooks.json: ${hooksResult.error}`);
    }
  }

  // Correct command files
  if (pathManager.exists('commands')) {
    const commands = pathManager.listComponentItems('commands');
    for (const cmd of commands) {
      const cmdPath = pathManager.getComponentItemPath('commands', cmd, '.md');
      const cmdResult = correctCommandFile(cmdPath, options);
      if (cmdResult.fixed) {
        result.fixed.push(`commands/${cmd}.md`);
        if (cmdResult.backup) {
          result.backups.push(cmdResult.backup);
        }
      }
      if (cmdResult.error) {
        result.errors.push(`commands/${cmd}.md: ${cmdResult.error}`);
      }
    }
  }

  // Correct agent files
  if (pathManager.exists('agents')) {
    const agents = pathManager.listComponentItems('agents');
    for (const agent of agents) {
      const agentPath = pathManager.getComponentItemPath('agents', agent, '.md');
      const agentResult = correctAgentFile(agentPath, options);
      if (agentResult.fixed) {
        result.fixed.push(`agents/${agent}.md`);
        if (agentResult.backup) {
          result.backups.push(agentResult.backup);
        }
      }
      if (agentResult.error) {
        result.errors.push(`agents/${agent}.md: ${agentResult.error}`);
      }
    }
  }

  return result;
}

/**
 * Correct plugin.json syntax
 * @param {string} filePath - Path to plugin.json
 * @param {object} options - Correction options
 * @returns {object} Correction result
 */
function correctPluginJson(filePath, options = {}) {
  const { backup = true, autoFix = true } = options;

  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let data;
    let needsFix = false;
    let backupPath = null;

    // Try to parse JSON
    try {
      data = JSON.parse(content);
    } catch (error) {
      // Attempt to fix common JSON errors
      if (autoFix) {
        content = fixCommonJsonErrors(content);
        try {
          data = JSON.parse(content);
          needsFix = true;
        } catch {
          return { fixed: false, error: `Invalid JSON: ${error.message}` };
        }
      } else {
        return { fixed: false, error: `Invalid JSON: ${error.message}` };
      }
    }

    // Fix invalid plugin name
    if (data.name && !isValidPluginName(data.name)) {
      data.name = toKebabCase(data.name);
      needsFix = true;
    }

    // Fix invalid version
    if (data.version && !isValidVersion(data.version)) {
      // Try to extract version numbers
      const match = data.version.match(/(\d+)\.?(\d+)?\.?(\d+)?/);
      if (match) {
        data.version = `${match[1] || 0}.${match[2] || 0}.${match[3] || 0}`;
      } else {
        data.version = '1.0.0';
      }
      needsFix = true;
    }

    // Add missing required fields
    if (!data.name) {
      data.name = 'unnamed-plugin';
      needsFix = true;
    }
    if (!data.version) {
      data.version = '1.0.0';
      needsFix = true;
    }
    if (!data.description) {
      data.description = 'A Claude Code plugin';
      needsFix = true;
    }
    if (!data.author) {
      data.author = { name: 'Unknown' };
      needsFix = true;
    } else if (typeof data.author === 'string') {
      // Convert string author to object
      data.author = { name: data.author };
      needsFix = true;
    }

    // Write fixed content if needed
    if (needsFix) {
      if (backup) {
        backupPath = filePath + '.bak';
        fs.copyFileSync(filePath, backupPath);
      }
      fs.writeFileSync(filePath, safeJSONStringify(data, 2));
      return { fixed: true, backup: backupPath };
    }

    return { fixed: false };
  } catch (error) {
    return { fixed: false, error: error.message };
  }
}

/**
 * Correct marketplace.json syntax
 * @param {string} filePath - Path to marketplace.json
 * @param {object} options - Correction options
 * @returns {object} Correction result
 */
function correctMarketplaceJson(filePath, options = {}) {
  const { backup = true, autoFix = true } = options;

  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let data;
    let needsFix = false;
    let backupPath = null;

    // Try to parse JSON
    try {
      data = JSON.parse(content);
    } catch (error) {
      if (autoFix) {
        content = fixCommonJsonErrors(content);
        try {
          data = JSON.parse(content);
          needsFix = true;
        } catch {
          return { fixed: false, error: `Invalid JSON: ${error.message}` };
        }
      } else {
        return { fixed: false, error: `Invalid JSON: ${error.message}` };
      }
    }

    // Ensure plugins array exists
    if (!data.plugins) {
      data.plugins = [];
      needsFix = true;
    } else if (!Array.isArray(data.plugins)) {
      data.plugins = [data.plugins];
      needsFix = true;
    }

    // Fix plugin entries
    for (let i = 0; i < data.plugins.length; i++) {
      const plugin = data.plugins[i];
      if (typeof plugin === 'string') {
        // Convert string to object
        data.plugins[i] = {
          name: toKebabCase(plugin),
          source: `./${toKebabCase(plugin)}`
        };
        needsFix = true;
      } else if (plugin && typeof plugin === 'object') {
        // Fix plugin name
        if (plugin.name && !isValidPluginName(plugin.name)) {
          plugin.name = toKebabCase(plugin.name);
          needsFix = true;
        }
        // Add missing source
        if (!plugin.source) {
          plugin.source = `./${plugin.name}`;
          needsFix = true;
        }
      }
    }

    // Add missing fields
    if (!data.name) {
      data.name = 'plugin-marketplace';
      needsFix = true;
    }
    if (!data.owner) {
      data.owner = { name: 'Unknown' };
      needsFix = true;
    } else if (typeof data.owner === 'string') {
      data.owner = { name: data.owner };
      needsFix = true;
    }

    // Write fixed content if needed
    if (needsFix) {
      if (backup) {
        backupPath = filePath + '.bak';
        fs.copyFileSync(filePath, backupPath);
      }
      fs.writeFileSync(filePath, safeJSONStringify(data, 2));
      return { fixed: true, backup: backupPath };
    }

    return { fixed: false };
  } catch (error) {
    return { fixed: false, error: error.message };
  }
}

/**
 * Correct hooks.json syntax
 * @param {string} filePath - Path to hooks.json
 * @param {object} options - Correction options
 * @returns {object} Correction result
 */
function correctHooksJson(filePath, options = {}) {
  const { backup = true, autoFix = true } = options;

  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let data;
    let needsFix = false;
    let backupPath = null;

    // Try to parse JSON
    try {
      data = JSON.parse(content);
    } catch (error) {
      if (autoFix) {
        content = fixCommonJsonErrors(content);
        try {
          data = JSON.parse(content);
          needsFix = true;
        } catch {
          return { fixed: false, error: `Invalid JSON: ${error.message}` };
        }
      } else {
        return { fixed: false, error: `Invalid JSON: ${error.message}` };
      }
    }

    // Ensure hooks array exists
    if (!data.hooks) {
      data.hooks = [];
      needsFix = true;
    } else if (!Array.isArray(data.hooks)) {
      data.hooks = [data.hooks];
      needsFix = true;
    }

    // Fix hook event names
    const validEvents = ['before-tool-use', 'after-tool-use', 'before-message',
                        'after-message', 'on-error', 'on-session-start', 'on-session-end'];

    for (const hook of data.hooks) {
      if (hook.event) {
        // Fix common event name mistakes
        const lowerEvent = hook.event.toLowerCase().replace(/_/g, '-');
        if (validEvents.includes(lowerEvent) && hook.event !== lowerEvent) {
          hook.event = lowerEvent;
          needsFix = true;
        }
      }
    }

    // Write fixed content if needed
    if (needsFix) {
      if (backup) {
        backupPath = filePath + '.bak';
        fs.copyFileSync(filePath, backupPath);
      }
      fs.writeFileSync(filePath, safeJSONStringify(data, 2));
      return { fixed: true, backup: backupPath };
    }

    return { fixed: false };
  } catch (error) {
    return { fixed: false, error: error.message };
  }
}

/**
 * Correct command file syntax
 * @param {string} filePath - Path to command file
 * @param {object} options - Correction options
 * @returns {object} Correction result
 */
function correctCommandFile(filePath, options = {}) {
  const { backup = true } = options;

  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let needsFix = false;
    let backupPath = null;

    // Fix frontmatter formatting
    if (!content.startsWith('---\n')) {
      // Try to detect frontmatter without proper delimiters
      if (content.includes('name:') && content.includes('description:')) {
        const lines = content.split('\n');
        const frontmatterEnd = lines.findIndex(line =>
          !line.trim() || (!line.includes(':') && !line.startsWith(' '))
        );
        if (frontmatterEnd > 0) {
          const frontmatter = lines.slice(0, frontmatterEnd).join('\n');
          const body = lines.slice(frontmatterEnd).join('\n');
          content = `---\n${frontmatter}\n---\n${body}`;
          needsFix = true;
        }
      } else {
        // Add minimal frontmatter
        const fileName = filePath.split('/').pop().replace('.md', '');
        const name = toKebabCase(fileName);
        content = `---\nname: ${name}\ndescription: ${name} command\narguments: none\n---\n\n${content}`;
        needsFix = true;
      }
    }

    // Fix unclosed frontmatter
    if (content.startsWith('---\n') && !content.includes('\n---\n', 4)) {
      const lines = content.split('\n');
      const bodyStart = lines.findIndex((line, idx) =>
        idx > 0 && !line.includes(':') && !line.startsWith(' ')
      );
      if (bodyStart > 0) {
        lines.splice(bodyStart, 0, '---');
        content = lines.join('\n');
        needsFix = true;
      }
    }

    // Fix command name in frontmatter
    if (content.startsWith('---\n')) {
      const endIndex = content.indexOf('\n---\n', 4);
      if (endIndex !== -1) {
        let frontmatter = content.substring(4, endIndex);
        const body = content.substring(endIndex + 5);

        // Fix name format
        const nameMatch = frontmatter.match(/^name:\s*(.+)$/m);
        if (nameMatch) {
          const name = nameMatch[1].trim();
          if (name.startsWith('/')) {
            // Remove slash from frontmatter name
            frontmatter = frontmatter.replace(
              /^name:\s*.+$/m,
              `name: ${name.substring(1)}`
            );
            needsFix = true;
          } else if (!isValidCommandName('/' + name)) {
            // Fix invalid name
            const fixedName = toKebabCase(name);
            frontmatter = frontmatter.replace(
              /^name:\s*.+$/m,
              `name: ${fixedName}`
            );
            needsFix = true;
          }
        }

        if (needsFix) {
          content = `---\n${frontmatter}\n---\n${body}`;
        }
      }
    }

    // Write fixed content if needed
    if (needsFix) {
      if (backup) {
        backupPath = filePath + '.bak';
        fs.copyFileSync(filePath, backupPath);
      }
      fs.writeFileSync(filePath, content);
      return { fixed: true, backup: backupPath };
    }

    return { fixed: false };
  } catch (error) {
    return { fixed: false, error: error.message };
  }
}

/**
 * Correct agent file syntax
 * @param {string} filePath - Path to agent file
 * @param {object} options - Correction options
 * @returns {object} Correction result
 */
function correctAgentFile(filePath, options = {}) {
  const { backup = true } = options;

  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let needsFix = false;
    let backupPath = null;

    // Similar to command file correction
    if (!content.startsWith('---\n')) {
      if (content.includes('name:') && content.includes('description:')) {
        const lines = content.split('\n');
        const frontmatterEnd = lines.findIndex(line =>
          !line.trim() || (!line.includes(':') && !line.startsWith(' '))
        );
        if (frontmatterEnd > 0) {
          const frontmatter = lines.slice(0, frontmatterEnd).join('\n');
          const body = lines.slice(frontmatterEnd).join('\n');
          content = `---\n${frontmatter}\n---\n${body}`;
          needsFix = true;
        }
      } else {
        const fileName = filePath.split('/').pop().replace('.md', '');
        const name = toPascalCase(fileName);
        content = `---\nname: ${name}\ndescription: ${name} agent for Claude Code\n---\n\n${content}`;
        needsFix = true;
      }
    }

    // Write fixed content if needed
    if (needsFix) {
      if (backup) {
        backupPath = filePath + '.bak';
        fs.copyFileSync(filePath, backupPath);
      }
      fs.writeFileSync(filePath, content);
      return { fixed: true, backup: backupPath };
    }

    return { fixed: false };
  } catch (error) {
    return { fixed: false, error: error.message };
  }
}

/**
 * Fix common JSON syntax errors
 * @param {string} content - JSON string with errors
 * @returns {string} Fixed JSON string
 */
function fixCommonJsonErrors(content) {
  // Remove trailing commas
  content = content.replace(/,(\s*[}\]])/g, '$1');

  // Fix single quotes to double quotes
  content = content.replace(/'/g, '"');

  // Add missing commas between properties
  content = content.replace(/"\s*\n\s*"/g, '",\n"');

  // Fix unquoted keys
  content = content.replace(/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/g, '$1"$2":');

  // Remove comments
  content = content.replace(/\/\/.*/g, '');
  content = content.replace(/\/\*[\s\S]*?\*\//g, '');

  return content;
}

module.exports = {
  correctPluginSyntax,
  correctPluginJson,
  correctMarketplaceJson,
  correctHooksJson,
  correctCommandFile,
  correctAgentFile,
  fixCommonJsonErrors
};