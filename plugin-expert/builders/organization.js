/**
 * Organization Utilities for Plugin-Expert
 * Handle file organization, naming conventions, and documentation references
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const fs = require('fs');
const path = require('path');
const { toKebabCase, toPascalCase } = require('../utilities/string-helpers');
const { PathManager } = require('../utilities/path-manager');

/**
 * Plugin organization standards and conventions
 */
const PLUGIN_STANDARDS = {
  // Directory structure
  directories: {
    config: '.claude-plugin',
    commands: 'commands',
    agents: 'agents',
    skills: 'skills',
    hooks: 'hooks',
    tests: 'tests',
    docs: 'docs',
    examples: 'examples'
  },

  // File naming conventions
  fileNames: {
    pluginConfig: 'plugin.json',
    marketplaceConfig: 'marketplace.json',
    hooksConfig: 'hooks.json',
    readme: 'README.md',
    changelog: 'CHANGELOG.md',
    contributing: 'CONTRIBUTING.md',
    license: 'LICENSE'
  },

  // Naming conventions
  conventions: {
    plugin: 'kebab-case',       // my-plugin
    command: 'kebab-case',      // my-command
    agent: 'PascalCase',        // MyAgent
    skill: 'PascalCase',        // MySkill
    hook: 'kebab-case'          // before-tool-use
  },

  // Documentation URLs
  documentation: {
    main: 'https://docs.claude.com/en/docs/claude-code/plugins',
    subAgents: 'https://docs.claude.com/en/docs/claude-code/sub-agents',
    commands: 'https://docs.claude.com/en/docs/claude-code/plugins#commands',
    skills: 'https://docs.claude.com/en/docs/claude-code/plugins#skills',
    hooks: 'https://docs.claude.com/en/docs/claude-code/plugins#hooks',
    examples: 'https://github.com/jeremylongshore/claude-code-plugins-plus/tree/main/plugins',
    marketplace: 'https://docs.claude.com/en/docs/claude-code/plugins#marketplace'
  }
};

/**
 * Create the standard plugin directory structure
 * @param {string} pluginPath - Path to plugin directory
 * @param {object} options - Creation options
 * @returns {object} Creation result
 */
function createPluginStructure(pluginPath, options = {}) {
  const pathManager = new PathManager(pluginPath);
  const result = {
    created: [],
    existing: [],
    errors: []
  };

  // Create base directory if needed
  if (!pathManager.exists()) {
    try {
      pathManager.ensureDir();
      result.created.push(pluginPath);
    } catch (error) {
      result.errors.push(`Failed to create plugin directory: ${error.message}`);
      return result;
    }
  } else {
    result.existing.push(pluginPath);
  }

  // Create standard directories
  for (const [key, dir] of Object.entries(PLUGIN_STANDARDS.directories)) {
    const dirPath = pathManager.resolve(dir);
    if (!pathManager.exists(dir)) {
      try {
        pathManager.ensureDir(dir);
        result.created.push(dir);
      } catch (error) {
        result.errors.push(`Failed to create ${dir}: ${error.message}`);
      }
    } else {
      result.existing.push(dir);
    }
  }

  // Create initial files if requested
  if (options.createFiles) {
    // Create plugin.json
    if (!pathManager.exists('.claude-plugin', 'plugin.json')) {
      const pluginJson = createInitialPluginJson(options.pluginName || 'my-plugin');
      const configPath = pathManager.getConfigFilePath('plugin.json');
      try {
        fs.writeFileSync(configPath, JSON.stringify(pluginJson, null, 2));
        result.created.push('.claude-plugin/plugin.json');
      } catch (error) {
        result.errors.push(`Failed to create plugin.json: ${error.message}`);
      }
    }

    // Create README.md
    if (!pathManager.exists('README.md')) {
      const readme = createInitialReadme(options.pluginName || 'my-plugin');
      try {
        fs.writeFileSync(pathManager.resolve('README.md'), readme);
        result.created.push('README.md');
      } catch (error) {
        result.errors.push(`Failed to create README.md: ${error.message}`);
      }
    }
  }

  return result;
}

/**
 * Create initial plugin.json content
 * @param {string} pluginName - Plugin name
 * @returns {object} Plugin configuration
 */
function createInitialPluginJson(pluginName) {
  return {
    name: toKebabCase(pluginName),
    version: '1.0.0',
    description: `${pluginName} plugin for Claude Code`,
    author: {
      name: 'Your Name'
    }
  };
}

/**
 * Create initial README content
 * @param {string} pluginName - Plugin name
 * @returns {string} README content
 */
function createInitialReadme(pluginName) {
  return `# ${pluginName}

A Claude Code plugin

## Installation

\`\`\`bash
claude-code plugin install ${toKebabCase(pluginName)}
\`\`\`

## Usage

[Describe how to use your plugin]

## Features

- Feature 1
- Feature 2
- Feature 3

## Documentation

For more information about Claude Code plugins, see:
- [Plugin Documentation](${PLUGIN_STANDARDS.documentation.main})
- [Example Plugins](${PLUGIN_STANDARDS.documentation.examples})

## License

MIT
`;
}

/**
 * Validate plugin organization
 * @param {string} pluginPath - Path to plugin directory
 * @returns {object} Validation result
 */
function validateOrganization(pluginPath) {
  const pathManager = new PathManager(pluginPath);
  const result = {
    valid: true,
    issues: [],
    suggestions: []
  };

  // Check required directories
  if (!pathManager.exists('.claude-plugin')) {
    result.valid = false;
    result.issues.push('Missing .claude-plugin directory');
  }

  if (!pathManager.exists('.claude-plugin', 'plugin.json')) {
    result.valid = false;
    result.issues.push('Missing plugin.json');
  }

  // Check component directories
  const hasComponents = ['commands', 'agents', 'skills', 'hooks'].some(dir =>
    pathManager.exists(dir)
  );
  if (!hasComponents) {
    result.valid = false;
    result.issues.push('No component directories found (commands, agents, skills, or hooks)');
  }

  // Check naming conventions
  if (pathManager.exists('commands')) {
    const commands = fs.readdirSync(pathManager.getComponentPath('commands'));
    for (const file of commands) {
      if (file.endsWith('.md')) {
        const name = file.replace('.md', '');
        if (!isKebabCase(name)) {
          result.suggestions.push(`Command file '${file}' should use kebab-case naming`);
        }
      }
    }
  }

  if (pathManager.exists('agents')) {
    const agents = fs.readdirSync(pathManager.getComponentPath('agents'));
    for (const file of agents) {
      if (file.endsWith('.md')) {
        const name = file.replace('.md', '');
        if (!isPascalCase(name)) {
          result.suggestions.push(`Agent file '${file}' should use PascalCase naming`);
        }
      }
    }
  }

  if (pathManager.exists('skills')) {
    const skills = fs.readdirSync(pathManager.getComponentPath('skills'));
    for (const dir of skills) {
      if (!isPascalCase(dir)) {
        result.suggestions.push(`Skill directory '${dir}' should use PascalCase naming`);
      }
      // Check for SKILL.md
      const skillFile = pathManager.resolve('skills', dir, 'SKILL.md');
      if (!fs.existsSync(skillFile)) {
        result.issues.push(`Skill '${dir}' missing SKILL.md file`);
      }
    }
  }

  // Check documentation
  if (!pathManager.exists('README.md')) {
    result.suggestions.push('Consider adding a README.md file');
  }

  return result;
}

/**
 * Check if string is kebab-case
 * @param {string} str - String to check
 * @returns {boolean} True if kebab-case
 */
function isKebabCase(str) {
  return /^[a-z][a-z0-9-]*$/.test(str) && !str.endsWith('-');
}

/**
 * Check if string is PascalCase
 * @param {string} str - String to check
 * @returns {boolean} True if PascalCase
 */
function isPascalCase(str) {
  return /^[A-Z][a-zA-Z0-9]*$/.test(str);
}

/**
 * Get documentation reference for a component type
 * @param {string} componentType - Type of component
 * @returns {object} Documentation info
 */
function getDocumentation(componentType) {
  const docs = PLUGIN_STANDARDS.documentation;

  switch (componentType.toLowerCase()) {
    case 'plugin':
      return {
        url: docs.main,
        description: 'Complete plugin documentation'
      };
    case 'command':
    case 'commands':
      return {
        url: docs.commands,
        description: 'How to create custom slash commands'
      };
    case 'agent':
    case 'agents':
    case 'subagent':
    case 'sub-agent':
      return {
        url: docs.subAgents,
        description: 'How to create sub-agents'
      };
    case 'skill':
    case 'skills':
      return {
        url: docs.skills,
        description: 'How to create agent skills'
      };
    case 'hook':
    case 'hooks':
      return {
        url: docs.hooks,
        description: 'How to use event hooks'
      };
    case 'marketplace':
      return {
        url: docs.marketplace,
        description: 'How to publish to the marketplace'
      };
    case 'examples':
      return {
        url: docs.examples,
        description: 'Example plugins repository'
      };
    default:
      return {
        url: docs.main,
        description: 'Plugin documentation'
      };
  }
}

/**
 * Reorganize plugin files to match conventions
 * @param {string} pluginPath - Path to plugin directory
 * @param {object} options - Reorganization options
 * @returns {object} Reorganization result
 */
function reorganizePlugin(pluginPath, options = {}) {
  const pathManager = new PathManager(pluginPath);
  const result = {
    moved: [],
    renamed: [],
    errors: []
  };

  // Fix directory names
  const dirMapping = {
    'command': 'commands',
    'agent': 'agents',
    'skill': 'skills',
    'hook': 'hooks'
  };

  for (const [wrong, correct] of Object.entries(dirMapping)) {
    if (pathManager.exists(wrong) && !pathManager.exists(correct)) {
      try {
        fs.renameSync(
          pathManager.resolve(wrong),
          pathManager.resolve(correct)
        );
        result.moved.push(`${wrong} -> ${correct}`);
      } catch (error) {
        result.errors.push(`Failed to rename ${wrong}: ${error.message}`);
      }
    }
  }

  // Fix file names in commands directory
  if (pathManager.exists('commands')) {
    const commands = fs.readdirSync(pathManager.getComponentPath('commands'));
    for (const file of commands) {
      if (file.endsWith('.md')) {
        const name = file.replace('.md', '');
        const fixedName = toKebabCase(name);
        if (name !== fixedName) {
          try {
            fs.renameSync(
              pathManager.resolve('commands', file),
              pathManager.resolve('commands', `${fixedName}.md`)
            );
            result.renamed.push(`commands/${file} -> commands/${fixedName}.md`);
          } catch (error) {
            result.errors.push(`Failed to rename ${file}: ${error.message}`);
          }
        }
      }
    }
  }

  // Fix skill directory names
  if (pathManager.exists('skills')) {
    const skills = fs.readdirSync(pathManager.getComponentPath('skills'));
    for (const dir of skills) {
      const fixedName = toPascalCase(dir);
      if (dir !== fixedName) {
        try {
          fs.renameSync(
            pathManager.resolve('skills', dir),
            pathManager.resolve('skills', fixedName)
          );
          result.renamed.push(`skills/${dir} -> skills/${fixedName}`);
        } catch (error) {
          result.errors.push(`Failed to rename ${dir}: ${error.message}`);
        }
      }
    }
  }

  // Move misplaced config files
  if (pathManager.exists('plugin.json') && !pathManager.exists('.claude-plugin', 'plugin.json')) {
    try {
      pathManager.ensureDir('.claude-plugin');
      fs.renameSync(
        pathManager.resolve('plugin.json'),
        pathManager.getConfigFilePath('plugin.json')
      );
      result.moved.push('plugin.json -> .claude-plugin/plugin.json');
    } catch (error) {
      result.errors.push(`Failed to move plugin.json: ${error.message}`);
    }
  }

  return result;
}

/**
 * Get example code for a component type
 * @param {string} componentType - Type of component
 * @returns {string} Example code or reference
 */
function getExample(componentType) {
  const examples = {
    command: `---
name: hello
description: Greet the user
arguments: none
---

# /hello Command

This command greets the user with a friendly message.

## Usage

\`\`\`bash
/hello
\`\`\`

## Implementation

When invoked, this command will:
1. Generate a greeting
2. Display it to the user`,

    agent: `---
name: CodeReviewer
description: Reviews code for best practices
---

# CodeReviewer Agent

You are a code review specialist.

## Capabilities

- Analyze code quality
- Suggest improvements
- Check for security issues

## Workflow

1. Parse the provided code
2. Check against best practices
3. Generate review comments
4. Provide improvement suggestions`,

    skill: `# DataAnalysis Skill

This skill enables advanced data analysis capabilities.

## Purpose

Provide comprehensive data analysis tools and workflows.

## Capabilities

- Parse various data formats
- Generate statistical summaries
- Create visualizations
- Identify patterns and anomalies

## Usage Guidelines

- Always validate data before analysis
- Handle missing values appropriately
- Provide clear explanations of results`,

    hook: `{
  "hooks": [
    {
      "event": "before-tool-use",
      "command": "./hooks/validate-tool.sh",
      "description": "Validate tool parameters before execution"
    }
  ]
}`
  };

  return examples[componentType.toLowerCase()] || 'See documentation for examples';
}

/**
 * Generate a component file with proper structure
 * @param {string} componentType - Type of component
 * @param {string} name - Component name
 * @param {string} outputPath - Where to save the file
 * @returns {object} Generation result
 */
function generateComponent(componentType, name, outputPath) {
  const pathManager = new PathManager(path.dirname(outputPath));
  const result = {
    created: false,
    path: outputPath,
    error: null
  };

  try {
    let content = '';
    let fileName = '';

    switch (componentType.toLowerCase()) {
      case 'command':
        fileName = `${toKebabCase(name)}.md`;
        content = getExample('command').replace('hello', toKebabCase(name));
        break;

      case 'agent':
        fileName = `${toPascalCase(name)}.md`;
        content = getExample('agent').replace('CodeReviewer', toPascalCase(name));
        break;

      case 'skill':
        // Skills are directories with SKILL.md
        const skillDir = path.join(outputPath, toPascalCase(name));
        pathManager.ensureDir(toPascalCase(name));
        fileName = path.join(toPascalCase(name), 'SKILL.md');
        content = getExample('skill').replace('DataAnalysis', toPascalCase(name));
        break;

      case 'hook':
        fileName = 'hooks.json';
        content = getExample('hook');
        break;

      default:
        result.error = `Unknown component type: ${componentType}`;
        return result;
    }

    const fullPath = path.join(outputPath, fileName);
    fs.writeFileSync(fullPath, content);
    result.created = true;
    result.path = fullPath;

  } catch (error) {
    result.error = error.message;
  }

  return result;
}

module.exports = {
  PLUGIN_STANDARDS,
  createPluginStructure,
  createInitialPluginJson,
  createInitialReadme,
  validateOrganization,
  isKebabCase,
  isPascalCase,
  getDocumentation,
  reorganizePlugin,
  getExample,
  generateComponent
};