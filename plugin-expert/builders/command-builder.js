/**
 * Command Builder for Plugin-Expert
 * Builds slash command configurations
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const { isValidCommandName } = require('../utilities/validation');
const { toKebabCase } = require('../utilities/string-helpers');
const { escapePromptForMarkdown } = require('../utilities/escape-helpers');
const { PathManager } = require('../utilities/path-manager');

/**
 * Build command files from specifications
 * @param {array} specs - Array of command specifications
 * @param {string} basePath - Base path for the plugin
 * @returns {array} Array of command file configurations
 */
function buildCommands(specs, basePath = null) {
  const pathManager = new PathManager(basePath);
  const commands = [];

  if (!Array.isArray(specs)) {
    throw new Error('Command specifications must be an array');
  }

  for (const spec of specs) {
    commands.push(buildSingleCommand(spec, pathManager));
  }

  return commands;
}

/**
 * Build a single command configuration
 * @param {object} spec - Command specification
 * @param {PathManager} pathManager - Path manager instance
 * @returns {object} Command configuration with file content
 */
function buildSingleCommand(spec, pathManager) {
  // Normalize command name
  let commandName = spec.name || 'unnamed-command';
  if (!commandName.startsWith('/')) {
    commandName = '/' + toKebabCase(commandName);
  }

  if (!isValidCommandName(commandName)) {
    throw new Error(`Invalid command name: ${commandName}. Must start with / and contain only lowercase letters, numbers, and dashes`);
  }

  // Build frontmatter
  const frontmatter = buildCommandFrontmatter(spec);

  // Build command body
  const body = buildCommandBody(spec);

  // Combine frontmatter and body
  const content = `${frontmatter}\n${escapePromptForMarkdown(body)}`;

  // Determine file path
  const fileName = commandName.substring(1) + '.md'; // Remove leading slash for filename
  const filePath = pathManager.getComponentItemPath('commands', fileName, '');

  return {
    name: commandName,
    fileName: fileName,
    filePath: filePath,
    content: content,
    spec: spec
  };
}

/**
 * Build command frontmatter
 * @param {object} spec - Command specification
 * @returns {string} YAML frontmatter
 */
function buildCommandFrontmatter(spec) {
  const lines = ['---'];

  // Name (without leading slash for frontmatter)
  const name = spec.name?.startsWith('/') ? spec.name.substring(1) : toKebabCase(spec.name || 'unnamed');
  lines.push(`name: ${name}`);

  // Description
  const description = spec.description || `${name} command for Claude Code`;
  lines.push(`description: ${description}`);

  // Arguments
  if (spec.arguments) {
    if (typeof spec.arguments === 'string') {
      lines.push(`arguments: ${spec.arguments}`);
    } else if (Array.isArray(spec.arguments)) {
      if (spec.arguments.length === 0) {
        lines.push('arguments: none');
      } else {
        lines.push('arguments:');
        for (const arg of spec.arguments) {
          if (typeof arg === 'string') {
            lines.push(`  - ${arg}`);
          } else {
            lines.push(`  - name: ${arg.name}`);
            if (arg.type) lines.push(`    type: ${arg.type}`);
            if (arg.required) lines.push(`    required: true`);
            if (arg.description) lines.push(`    description: ${arg.description}`);
          }
        }
      }
    }
  } else {
    lines.push('arguments: none');
  }

  // Optional metadata
  if (spec.category) {
    lines.push(`category: ${spec.category}`);
  }

  if (spec.aliases && Array.isArray(spec.aliases)) {
    lines.push('aliases:');
    for (const alias of spec.aliases) {
      lines.push(`  - ${alias}`);
    }
  }

  if (spec.permissions && Array.isArray(spec.permissions)) {
    lines.push('permissions:');
    for (const perm of spec.permissions) {
      lines.push(`  - ${perm}`);
    }
  }

  lines.push('---');
  return lines.join('\n');
}

/**
 * Build command body content
 * @param {object} spec - Command specification
 * @returns {string} Markdown body content
 */
function buildCommandBody(spec) {
  const sections = [];

  // Command title
  const commandName = spec.name?.startsWith('/') ? spec.name : '/' + toKebabCase(spec.name || 'unnamed');
  sections.push(`# ${commandName} Command\n`);

  // Long description
  if (spec.longDescription) {
    sections.push(spec.longDescription);
    sections.push('');
  } else if (spec.description) {
    sections.push(spec.description);
    sections.push('');
  }

  // Purpose
  if (spec.purpose) {
    sections.push('## Purpose\n');
    sections.push(spec.purpose);
    sections.push('');
  }

  // Usage
  if (spec.usage || spec.arguments) {
    sections.push('## Usage\n');
    if (spec.usage) {
      sections.push('```bash');
      sections.push(spec.usage);
      sections.push('```\n');
    } else {
      sections.push('```bash');
      sections.push(`${commandName} [arguments]`);
      sections.push('```\n');
    }
  }

  // Arguments detail
  if (spec.argumentDetails && spec.argumentDetails.length > 0) {
    sections.push('## Arguments\n');
    for (const arg of spec.argumentDetails) {
      const required = arg.required ? ' *(required)*' : ' *(optional)*';
      sections.push(`### \`${arg.name}\`${required}\n`);
      sections.push(arg.description || 'No description provided');
      sections.push('');

      if (arg.type) {
        sections.push(`- **Type**: ${arg.type}`);
      }
      if (arg.default !== undefined) {
        sections.push(`- **Default**: \`${arg.default}\``);
      }
      if (arg.values && Array.isArray(arg.values)) {
        sections.push(`- **Possible values**: ${arg.values.map(v => `\`${v}\``).join(', ')}`);
      }
      if (arg.example) {
        sections.push(`- **Example**: \`${arg.example}\``);
      }
      sections.push('');
    }
  }

  // Behavior/Implementation
  if (spec.implementation) {
    sections.push('## Implementation\n');
    sections.push(spec.implementation);
    sections.push('');
  } else if (spec.steps && spec.steps.length > 0) {
    sections.push('## Execution Steps\n');
    spec.steps.forEach((step, index) => {
      sections.push(`${index + 1}. ${step}`);
    });
    sections.push('');
  }

  // Options/Flags
  if (spec.options && spec.options.length > 0) {
    sections.push('## Options\n');
    for (const option of spec.options) {
      sections.push(`- \`${option.flag}\`: ${option.description}`);
      if (option.default !== undefined) {
        sections.push(`  - Default: \`${option.default}\``);
      }
    }
    sections.push('');
  }

  // Examples
  if (spec.examples && spec.examples.length > 0) {
    sections.push('## Examples\n');
    for (const example of spec.examples) {
      if (example.title) {
        sections.push(`### ${example.title}\n`);
      }
      sections.push('```bash');
      sections.push(example.command || `${commandName} ${example.args || ''}`);
      sections.push('```\n');
      if (example.description) {
        sections.push(example.description);
        sections.push('');
      }
      if (example.output) {
        sections.push('**Output:**');
        sections.push('```');
        sections.push(example.output);
        sections.push('```\n');
      }
    }
  }

  // Error handling
  if (spec.errorHandling) {
    sections.push('## Error Handling\n');
    sections.push(spec.errorHandling);
    sections.push('');
  }

  // Notes
  if (spec.notes) {
    sections.push('## Notes\n');
    sections.push(spec.notes);
    sections.push('');
  }

  // Related commands
  if (spec.related && spec.related.length > 0) {
    sections.push('## Related Commands\n');
    for (const related of spec.related) {
      const relName = related.name?.startsWith('/') ? related.name : '/' + related.name;
      sections.push(`- **${relName}**: ${related.description}`);
    }
    sections.push('');
  }

  return sections.join('\n').trim();
}

/**
 * Generate a command template
 * @param {string} name - Command name
 * @returns {object} Command template
 */
function generateCommandTemplate(name) {
  const commandName = name.startsWith('/') ? name : '/' + toKebabCase(name);
  const displayName = commandName.substring(1).replace(/-/g, ' ');

  return {
    name: commandName,
    description: `${displayName} command`,
    arguments: 'none',
    longDescription: `The ${commandName} command performs...`,
    purpose: 'Describe the main purpose of this command',
    usage: `${commandName}`,
    implementation: `When invoked, this command will:

1. First, validate any arguments
2. Then, perform the main operation
3. Finally, return the results to the user`,
    examples: [
      {
        title: 'Basic usage',
        command: commandName,
        description: 'Run the command with default settings'
      }
    ],
    errorHandling: 'If an error occurs, the command will display a helpful error message and suggest corrective actions.',
    notes: 'Additional information or caveats about using this command.'
  };
}

/**
 * Validate command specification
 * @param {object} spec - Command specification
 * @returns {array} Array of validation errors (empty if valid)
 */
function validateCommandSpec(spec) {
  const errors = [];

  if (!spec.name) {
    errors.push('Command name is required');
  } else {
    const commandName = spec.name.startsWith('/') ? spec.name : '/' + toKebabCase(spec.name);
    if (!isValidCommandName(commandName)) {
      errors.push(`Invalid command name: ${commandName}`);
    }
  }

  if (!spec.description) {
    errors.push('Command description is required');
  }

  if (spec.arguments && typeof spec.arguments === 'object' && !Array.isArray(spec.arguments)) {
    errors.push('Arguments must be a string or array');
  }

  if (spec.argumentDetails && !Array.isArray(spec.argumentDetails)) {
    errors.push('Argument details must be an array');
  }

  if (spec.examples && !Array.isArray(spec.examples)) {
    errors.push('Examples must be an array');
  }

  if (spec.options && !Array.isArray(spec.options)) {
    errors.push('Options must be an array');
  }

  if (spec.related && !Array.isArray(spec.related)) {
    errors.push('Related commands must be an array');
  }

  return errors;
}

module.exports = {
  buildCommands,
  buildSingleCommand,
  buildCommandFrontmatter,
  buildCommandBody,
  generateCommandTemplate,
  validateCommandSpec
};