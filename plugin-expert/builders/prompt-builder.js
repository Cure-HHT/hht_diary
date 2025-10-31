/**
 * Prompt Builder for Plugin-Expert
 * Builds prompts for skills, agents, and commands
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const { toKebabCase, toPascalCase, capitalize, indent, wordWrap, mdHeader, mdLink, codeBlock } = require('../utilities/string-helpers');
const { isValidAgentName, isValidSkillName, isValidCommandName } = require('../utilities/validation');

/**
 * Build a skill prompt from specifications
 * @param {object} spec - Skill specifications
 * @returns {object} Skill configuration with prompt
 */
function buildSkillPrompt(spec) {
  const skill = {
    name: '',
    description: '',
    prompt: '',
    ...spec
  };

  // Validate and normalize name
  if (spec.name) {
    const normalizedName = toPascalCase(spec.name);
    if (!isValidSkillName(normalizedName)) {
      throw new Error(`Invalid skill name: ${normalizedName}`);
    }
    skill.name = normalizedName;
  } else {
    throw new Error('Skill name is required');
  }

  // Build the skill prompt
  const sections = [];

  // Header
  sections.push(mdHeader(skill.name, 1));
  sections.push('');

  // Description
  if (skill.description) {
    sections.push(`**Description**: ${skill.description}`);
    sections.push('');
  }

  // Purpose section
  if (skill.purpose) {
    sections.push(mdHeader('Purpose', 2));
    sections.push(wordWrap(skill.purpose));
    sections.push('');
  }

  // Capabilities section
  if (skill.capabilities && skill.capabilities.length > 0) {
    sections.push(mdHeader('Capabilities', 2));
    sections.push('This skill enables you to:');
    for (const capability of skill.capabilities) {
      sections.push(`- ${capability}`);
    }
    sections.push('');
  }

  // Usage guidelines
  if (skill.guidelines && skill.guidelines.length > 0) {
    sections.push(mdHeader('Usage Guidelines', 2));
    for (const guideline of skill.guidelines) {
      sections.push(`- ${guideline}`);
    }
    sections.push('');
  }

  // Examples
  if (skill.examples && skill.examples.length > 0) {
    sections.push(mdHeader('Examples', 2));
    for (const example of skill.examples) {
      sections.push(mdHeader(example.title || 'Example', 3));
      if (example.context) {
        sections.push(`**Context**: ${example.context}`);
      }
      if (example.input) {
        sections.push(`**User Input**: ${example.input}`);
      }
      if (example.action) {
        sections.push(`**Action**: ${example.action}`);
      }
      if (example.output) {
        sections.push(`**Expected Output**: ${example.output}`);
      }
      sections.push('');
    }
  }

  // Tools available
  if (skill.tools && skill.tools.length > 0) {
    sections.push(mdHeader('Available Tools', 2));
    sections.push('You have access to these tools for this skill:');
    for (const tool of skill.tools) {
      sections.push(`- **${tool.name}**: ${tool.description || ''}`);
    }
    sections.push('');
  }

  // Custom instructions
  if (skill.instructions) {
    sections.push(mdHeader('Instructions', 2));
    sections.push(skill.instructions);
    sections.push('');
  }

  skill.prompt = sections.join('\n').trim();

  return skill;
}

/**
 * Build an agent prompt from specifications
 * @param {object} spec - Agent specifications
 * @returns {object} Agent configuration with prompt
 */
function buildAgentPrompt(spec) {
  const agent = {
    name: '',
    description: '',
    prompt: '',
    ...spec
  };

  // Validate and normalize name
  if (spec.name) {
    if (!isValidAgentName(spec.name)) {
      throw new Error(`Invalid agent name: ${spec.name}`);
    }
    agent.name = spec.name;
  } else {
    throw new Error('Agent name is required');
  }

  // Build the agent prompt
  const sections = [];

  // Header with description
  sections.push(`---
name: ${agent.name}
description: ${agent.description || `${agent.name} agent for Claude Code`}
---
`);

  // Role definition
  sections.push(mdHeader('Role', 1));
  sections.push(agent.role || `You are the ${agent.name} agent, a specialized assistant for Claude Code.`);
  sections.push('');

  // Primary objectives
  if (agent.objectives && agent.objectives.length > 0) {
    sections.push(mdHeader('Primary Objectives', 2));
    for (const objective of agent.objectives) {
      sections.push(`1. ${objective}`);
    }
    sections.push('');
  }

  // Capabilities
  if (agent.capabilities && agent.capabilities.length > 0) {
    sections.push(mdHeader('Capabilities', 2));
    sections.push('You are equipped to:');
    for (const capability of agent.capabilities) {
      sections.push(`- ${capability}`);
    }
    sections.push('');
  }

  // Workflow
  if (agent.workflow && agent.workflow.length > 0) {
    sections.push(mdHeader('Workflow', 2));
    sections.push('Follow these steps when activated:');
    let stepNum = 1;
    for (const step of agent.workflow) {
      sections.push(`${stepNum}. ${step}`);
      stepNum++;
    }
    sections.push('');
  }

  // Context awareness
  if (agent.context) {
    sections.push(mdHeader('Context Awareness', 2));
    sections.push(agent.context);
    sections.push('');
  }

  // Best practices
  if (agent.bestPractices && agent.bestPractices.length > 0) {
    sections.push(mdHeader('Best Practices', 2));
    for (const practice of agent.bestPractices) {
      sections.push(`- ${practice}`);
    }
    sections.push('');
  }

  // Error handling
  if (agent.errorHandling) {
    sections.push(mdHeader('Error Handling', 2));
    sections.push(agent.errorHandling);
    sections.push('');
  }

  // Output format
  if (agent.outputFormat) {
    sections.push(mdHeader('Output Format', 2));
    sections.push(agent.outputFormat);
    sections.push('');
  }

  // Examples
  if (agent.examples && agent.examples.length > 0) {
    sections.push(mdHeader('Examples', 2));
    for (const example of agent.examples) {
      sections.push(mdHeader(example.scenario || 'Example', 3));
      if (example.input) {
        sections.push('**Input:**');
        sections.push(codeBlock(example.input, example.inputLang || ''));
      }
      if (example.process) {
        sections.push('**Process:**');
        sections.push(example.process);
      }
      if (example.output) {
        sections.push('**Output:**');
        sections.push(codeBlock(example.output, example.outputLang || ''));
      }
      sections.push('');
    }
  }

  // Notes
  if (agent.notes) {
    sections.push(mdHeader('Notes', 2));
    sections.push(agent.notes);
    sections.push('');
  }

  agent.prompt = sections.join('\n').trim();

  return agent;
}

/**
 * Build a command prompt from specifications
 * @param {object} spec - Command specifications
 * @returns {object} Command configuration with prompt
 */
function buildCommandPrompt(spec) {
  const command = {
    name: '',
    description: '',
    prompt: '',
    ...spec
  };

  // Validate and normalize name
  if (spec.name) {
    const normalizedName = spec.name.startsWith('/') ? spec.name : `/${toKebabCase(spec.name)}`;
    if (!isValidCommandName(normalizedName)) {
      throw new Error(`Invalid command name: ${normalizedName}`);
    }
    command.name = normalizedName;
  } else {
    throw new Error('Command name is required');
  }

  // Build the command prompt
  const sections = [];

  // Frontmatter
  sections.push(`---
name: ${command.name}
description: ${command.description || `${command.name} command for Claude Code`}
arguments: ${command.arguments || 'none'}
---
`);

  // Command header
  sections.push(mdHeader(`Command: ${command.name}`, 1));
  sections.push('');

  // Description
  if (command.longDescription) {
    sections.push(command.longDescription);
    sections.push('');
  }

  // Arguments
  if (command.argumentDetails && command.argumentDetails.length > 0) {
    sections.push(mdHeader('Arguments', 2));
    for (const arg of command.argumentDetails) {
      sections.push(`- **${arg.name}** ${arg.required ? '(required)' : '(optional)'}: ${arg.description}`);
      if (arg.default) {
        sections.push(`  - Default: ${arg.default}`);
      }
      if (arg.values) {
        sections.push(`  - Possible values: ${arg.values.join(', ')}`);
      }
    }
    sections.push('');
  }

  // Usage
  if (command.usage) {
    sections.push(mdHeader('Usage', 2));
    sections.push('```');
    sections.push(command.usage);
    sections.push('```');
    sections.push('');
  }

  // Behavior
  if (command.behavior) {
    sections.push(mdHeader('Behavior', 2));
    sections.push(command.behavior);
    sections.push('');
  }

  // Steps
  if (command.steps && command.steps.length > 0) {
    sections.push(mdHeader('Execution Steps', 2));
    let stepNum = 1;
    for (const step of command.steps) {
      sections.push(`${stepNum}. ${step}`);
      stepNum++;
    }
    sections.push('');
  }

  // Options
  if (command.options && command.options.length > 0) {
    sections.push(mdHeader('Options', 2));
    for (const option of command.options) {
      sections.push(`- **${option.flag}**: ${option.description}`);
    }
    sections.push('');
  }

  // Examples
  if (command.examples && command.examples.length > 0) {
    sections.push(mdHeader('Examples', 2));
    for (const example of command.examples) {
      if (example.title) {
        sections.push(mdHeader(example.title, 3));
      }
      sections.push('```bash');
      sections.push(example.command);
      sections.push('```');
      if (example.description) {
        sections.push(example.description);
      }
      sections.push('');
    }
  }

  // Related commands
  if (command.related && command.related.length > 0) {
    sections.push(mdHeader('Related Commands', 2));
    for (const related of command.related) {
      sections.push(`- **${related.name}**: ${related.description}`);
    }
    sections.push('');
  }

  // Notes
  if (command.notes) {
    sections.push(mdHeader('Notes', 2));
    sections.push(command.notes);
    sections.push('');
  }

  command.prompt = sections.join('\n').trim();

  return command;
}

/**
 * Generate a template for a new skill
 * @param {string} name - Skill name
 * @returns {object} Skill template
 */
function generateSkillTemplate(name) {
  return {
    name: toPascalCase(name),
    description: `${capitalize(name)} skill for Claude Code`,
    purpose: 'Describe the main purpose of this skill',
    capabilities: [
      'First capability',
      'Second capability'
    ],
    guidelines: [
      'Always follow this guideline',
      'Remember to check this'
    ],
    tools: [],
    instructions: 'Detailed instructions for using this skill effectively.'
  };
}

/**
 * Generate a template for a new agent
 * @param {string} name - Agent name
 * @returns {object} Agent template
 */
function generateAgentTemplate(name) {
  return {
    name: name,
    description: `${capitalize(name)} agent for specialized tasks`,
    role: `You are the ${name} agent, specialized in...`,
    objectives: [
      'Primary objective',
      'Secondary objective'
    ],
    capabilities: [
      'Can do this',
      'Can do that'
    ],
    workflow: [
      'First, analyze the request',
      'Then, perform the action',
      'Finally, validate and report'
    ],
    bestPractices: [
      'Always validate input',
      'Handle errors gracefully'
    ]
  };
}

/**
 * Generate a template for a new command
 * @param {string} name - Command name
 * @returns {object} Command template
 */
function generateCommandTemplate(name) {
  const cmdName = name.startsWith('/') ? name : `/${toKebabCase(name)}`;
  return {
    name: cmdName,
    description: `${capitalize(name.replace('/', ''))} command`,
    arguments: 'none',
    longDescription: `The ${cmdName} command performs...`,
    behavior: 'When invoked, this command will...',
    steps: [
      'Parse arguments',
      'Execute main logic',
      'Return results'
    ],
    examples: [
      {
        title: 'Basic usage',
        command: cmdName,
        description: 'Runs the command with default settings'
      }
    ]
  };
}

module.exports = {
  buildSkillPrompt,
  buildAgentPrompt,
  buildCommandPrompt,
  generateSkillTemplate,
  generateAgentTemplate,
  generateCommandTemplate
};