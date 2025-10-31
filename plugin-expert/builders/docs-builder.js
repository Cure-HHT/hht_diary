/**
 * Documentation Builder for Plugin-Expert
 * Builds README and documentation files
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const { mdHeader, mdLink, codeBlock, capitalize } = require('../utilities/string-helpers');
const { PathManager } = require('../utilities/path-manager');

/**
 * Build complete documentation for a plugin
 * @param {object} spec - Plugin specification
 * @param {object} components - Built components (metadata, commands, etc.)
 * @param {string} basePath - Base path for the plugin
 * @returns {object} Documentation files
 */
function buildDocumentation(spec, components, basePath = null) {
  const pathManager = new PathManager(basePath);

  return {
    readme: buildReadme(spec, components),
    installation: buildInstallationGuide(spec),
    usage: buildUsageGuide(spec, components),
    contributing: buildContributingGuide(spec),
    changelog: buildChangelog(spec)
  };
}

/**
 * Build README.md content
 * @param {object} spec - Plugin specification
 * @param {object} components - Built components
 * @returns {string} README content
 */
function buildReadme(spec, components) {
  const sections = [];

  // Title and description
  sections.push(mdHeader(spec.name || 'Unnamed Plugin', 1));
  sections.push('');
  sections.push(spec.description || 'A Claude Code plugin');
  sections.push('');

  // Badges (if applicable)
  if (spec.version) {
    sections.push(`![Version](https://img.shields.io/badge/version-${spec.version}-blue)`);
  }
  if (spec.license) {
    sections.push(`![License](https://img.shields.io/badge/license-${spec.license}-green)`);
  }
  sections.push('');

  // Table of Contents
  sections.push(mdHeader('Table of Contents', 2));
  sections.push('');
  sections.push('- [Features](#features)');
  sections.push('- [Installation](#installation)');
  sections.push('- [Usage](#usage)');
  if (components.commands?.length > 0) {
    sections.push('- [Commands](#commands)');
  }
  if (components.agents?.length > 0) {
    sections.push('- [Agents](#agents)');
  }
  if (components.skills?.length > 0) {
    sections.push('- [Skills](#skills)');
  }
  if (components.hooks?.length > 0) {
    sections.push('- [Hooks](#hooks)');
  }
  sections.push('- [Configuration](#configuration)');
  sections.push('- [Contributing](#contributing)');
  sections.push('- [License](#license)');
  sections.push('');

  // Features
  if (spec.features && spec.features.length > 0) {
    sections.push(mdHeader('Features', 2));
    sections.push('');
    for (const feature of spec.features) {
      sections.push(`- ${feature}`);
    }
    sections.push('');
  }

  // Installation
  sections.push(mdHeader('Installation', 2));
  sections.push('');
  sections.push('### From Marketplace');
  sections.push('');
  sections.push('```bash');
  sections.push(`claude-code plugin install ${spec.name}`);
  sections.push('```');
  sections.push('');
  sections.push('### Manual Installation');
  sections.push('');
  sections.push('1. Clone this repository or download the plugin files');
  sections.push('2. Copy the plugin directory to your Claude Code plugins folder');
  sections.push('3. Restart Claude Code or reload plugins');
  sections.push('');

  // Usage
  sections.push(mdHeader('Usage', 2));
  sections.push('');
  if (spec.quickStart) {
    sections.push(spec.quickStart);
  } else {
    sections.push('After installation, the plugin features are available immediately.');
  }
  sections.push('');

  // Commands
  if (components.commands && components.commands.length > 0) {
    sections.push(mdHeader('Commands', 2));
    sections.push('');
    sections.push('This plugin provides the following commands:');
    sections.push('');
    for (const cmd of components.commands) {
      const cmdName = cmd.spec.name?.startsWith('/') ? cmd.spec.name : '/' + cmd.spec.name;
      sections.push(`### ${cmdName}`);
      sections.push('');
      sections.push(cmd.spec.description || 'No description provided');
      sections.push('');
      if (cmd.spec.usage) {
        sections.push('**Usage:**');
        sections.push('```bash');
        sections.push(cmd.spec.usage);
        sections.push('```');
        sections.push('');
      }
    }
  }

  // Agents
  if (components.agents && components.agents.length > 0) {
    sections.push(mdHeader('Agents', 2));
    sections.push('');
    sections.push('This plugin includes the following agents:');
    sections.push('');
    for (const agent of components.agents) {
      sections.push(`### ${agent.name}`);
      sections.push('');
      sections.push(agent.description || 'No description provided');
      sections.push('');
    }
  }

  // Skills
  if (components.skills && components.skills.length > 0) {
    sections.push(mdHeader('Skills', 2));
    sections.push('');
    sections.push('This plugin provides the following skills:');
    sections.push('');
    for (const skill of components.skills) {
      sections.push(`### ${skill.name}`);
      sections.push('');
      sections.push(skill.description || 'No description provided');
      sections.push('');
    }
  }

  // Hooks
  if (components.hooks && components.hooks.length > 0) {
    sections.push(mdHeader('Hooks', 2));
    sections.push('');
    sections.push('This plugin uses the following event hooks:');
    sections.push('');
    for (const hook of components.hooks) {
      sections.push(`- **${hook.event}**: ${hook.description || 'No description'}`);
    }
    sections.push('');
  }

  // Configuration
  sections.push(mdHeader('Configuration', 2));
  sections.push('');
  if (spec.configuration) {
    sections.push(spec.configuration);
  } else {
    sections.push('The plugin can be configured by editing the `plugin.json` file:');
    sections.push('');
    sections.push('```json');
    sections.push(JSON.stringify({
      name: spec.name,
      version: spec.version || '1.0.0',
      // Add other config options
    }, null, 2));
    sections.push('```');
  }
  sections.push('');

  // Contributing
  sections.push(mdHeader('Contributing', 2));
  sections.push('');
  sections.push('Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.');
  sections.push('');

  // License
  sections.push(mdHeader('License', 2));
  sections.push('');
  sections.push(spec.license ? `This project is licensed under the ${spec.license} License.` : 'This project is licensed under the MIT License.');
  sections.push('');

  // Author
  if (spec.author) {
    sections.push(mdHeader('Author', 2));
    sections.push('');
    if (typeof spec.author === 'string') {
      sections.push(spec.author);
    } else {
      sections.push(spec.author.name || 'Unknown');
      if (spec.author.email) {
        sections.push(` - ${spec.author.email}`);
      }
      if (spec.author.url) {
        sections.push(` - ${mdLink('Website', spec.author.url)}`);
      }
    }
    sections.push('');
  }

  return sections.join('\n');
}

/**
 * Build installation guide
 * @param {object} spec - Plugin specification
 * @returns {string} Installation guide content
 */
function buildInstallationGuide(spec) {
  const sections = [];

  sections.push(mdHeader('Installation Guide', 1));
  sections.push('');

  sections.push(mdHeader('Prerequisites', 2));
  sections.push('');
  sections.push('- Claude Code version 1.0.0 or higher');
  if (spec.prerequisites) {
    for (const prereq of spec.prerequisites) {
      sections.push(`- ${prereq}`);
    }
  }
  sections.push('');

  sections.push(mdHeader('Installation Methods', 2));
  sections.push('');

  sections.push(mdHeader('Method 1: Marketplace Installation (Recommended)', 3));
  sections.push('');
  sections.push('```bash');
  sections.push(`claude-code plugin install ${spec.name}`);
  sections.push('```');
  sections.push('');

  sections.push(mdHeader('Method 2: Git Installation', 3));
  sections.push('');
  sections.push('```bash');
  sections.push('cd ~/.claude-code/plugins');
  sections.push(`git clone ${spec.repository || 'https://github.com/user/plugin.git'} ${spec.name}`);
  sections.push('```');
  sections.push('');

  sections.push(mdHeader('Method 3: Manual Installation', 3));
  sections.push('');
  sections.push('1. Download the plugin files');
  sections.push('2. Extract to `~/.claude-code/plugins/' + spec.name + '`');
  sections.push('3. Ensure the plugin.json file is present');
  sections.push('4. Restart Claude Code');
  sections.push('');

  sections.push(mdHeader('Verification', 2));
  sections.push('');
  sections.push('To verify the installation:');
  sections.push('');
  sections.push('```bash');
  sections.push('claude-code plugin list');
  sections.push('```');
  sections.push('');
  sections.push(`You should see "${spec.name}" in the list of installed plugins.`);
  sections.push('');

  sections.push(mdHeader('Troubleshooting', 2));
  sections.push('');
  sections.push('If the plugin doesn\'t appear:');
  sections.push('');
  sections.push('1. Check that the plugin directory structure is correct');
  sections.push('2. Verify plugin.json is valid JSON');
  sections.push('3. Check Claude Code logs for error messages');
  sections.push('4. Ensure you have the required permissions');
  sections.push('');

  return sections.join('\n');
}

/**
 * Build usage guide
 * @param {object} spec - Plugin specification
 * @param {object} components - Built components
 * @returns {string} Usage guide content
 */
function buildUsageGuide(spec, components) {
  const sections = [];

  sections.push(mdHeader('Usage Guide', 1));
  sections.push('');

  sections.push(mdHeader('Getting Started', 2));
  sections.push('');
  sections.push(spec.gettingStarted || 'Follow these steps to start using the plugin:');
  sections.push('');

  // Command usage
  if (components.commands && components.commands.length > 0) {
    sections.push(mdHeader('Using Commands', 2));
    sections.push('');
    for (const cmd of components.commands) {
      sections.push(mdHeader(cmd.name, 3));
      sections.push('');
      sections.push(cmd.spec.longDescription || cmd.spec.description);
      sections.push('');
      if (cmd.spec.examples && cmd.spec.examples.length > 0) {
        sections.push('**Examples:**');
        sections.push('');
        for (const example of cmd.spec.examples) {
          sections.push(codeBlock(example.command, 'bash'));
          if (example.description) {
            sections.push(example.description);
          }
          sections.push('');
        }
      }
    }
  }

  // Best practices
  if (spec.bestPractices) {
    sections.push(mdHeader('Best Practices', 2));
    sections.push('');
    for (const practice of spec.bestPractices) {
      sections.push(`- ${practice}`);
    }
    sections.push('');
  }

  // Common workflows
  if (spec.workflows) {
    sections.push(mdHeader('Common Workflows', 2));
    sections.push('');
    for (const workflow of spec.workflows) {
      sections.push(mdHeader(workflow.name, 3));
      sections.push('');
      sections.push(workflow.description);
      sections.push('');
      if (workflow.steps) {
        workflow.steps.forEach((step, index) => {
          sections.push(`${index + 1}. ${step}`);
        });
        sections.push('');
      }
    }
  }

  return sections.join('\n');
}

/**
 * Build contributing guide
 * @param {object} spec - Plugin specification
 * @returns {string} Contributing guide content
 */
function buildContributingGuide(spec) {
  const sections = [];

  sections.push(mdHeader('Contributing', 1));
  sections.push('');
  sections.push('Thank you for your interest in contributing to this plugin!');
  sections.push('');

  sections.push(mdHeader('How to Contribute', 2));
  sections.push('');
  sections.push('1. Fork the repository');
  sections.push('2. Create a feature branch (`git checkout -b feature/amazing-feature`)');
  sections.push('3. Commit your changes (`git commit -m "Add amazing feature"`)');
  sections.push('4. Push to the branch (`git push origin feature/amazing-feature`)');
  sections.push('5. Open a Pull Request');
  sections.push('');

  sections.push(mdHeader('Development Setup', 2));
  sections.push('');
  sections.push('```bash');
  sections.push('# Clone your fork');
  sections.push(`git clone https://github.com/yourusername/${spec.name}.git`);
  sections.push(`cd ${spec.name}`);
  sections.push('');
  sections.push('# Install dependencies (if any)');
  sections.push('npm install');
  sections.push('```');
  sections.push('');

  sections.push(mdHeader('Testing', 2));
  sections.push('');
  sections.push('Before submitting a PR, ensure:');
  sections.push('');
  sections.push('- [ ] All existing tests pass');
  sections.push('- [ ] New features have tests');
  sections.push('- [ ] Documentation is updated');
  sections.push('- [ ] Code follows the style guidelines');
  sections.push('');

  sections.push(mdHeader('Code Style', 2));
  sections.push('');
  sections.push('- Use clear, descriptive variable names');
  sections.push('- Add comments for complex logic');
  sections.push('- Follow existing code patterns');
  sections.push('');

  return sections.join('\n');
}

/**
 * Build changelog
 * @param {object} spec - Plugin specification
 * @returns {string} Changelog content
 */
function buildChangelog(spec) {
  const sections = [];

  sections.push(mdHeader('Changelog', 1));
  sections.push('');
  sections.push('All notable changes to this project will be documented in this file.');
  sections.push('');
  sections.push('The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),');
  sections.push('and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).');
  sections.push('');

  // Current version
  sections.push(mdHeader(`[${spec.version || '1.0.0'}] - ${new Date().toISOString().split('T')[0]}`, 2));
  sections.push('');

  sections.push(mdHeader('Added', 3));
  sections.push('- Initial release');
  if (spec.features) {
    for (const feature of spec.features) {
      sections.push(`- ${feature}`);
    }
  }
  sections.push('');

  return sections.join('\n');
}

module.exports = {
  buildDocumentation,
  buildReadme,
  buildInstallationGuide,
  buildUsageGuide,
  buildContributingGuide,
  buildChangelog
};