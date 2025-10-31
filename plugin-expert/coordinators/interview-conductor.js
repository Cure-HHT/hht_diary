/**
 * Interview Conductor for Plugin-Expert
 * Guide users through plugin creation questions
 * Layer 3: Process Coordinator (depends on Layers 1 & 2)
 */

const readline = require('readline');
const { toKebabCase, toPascalCase, capitalize } = require('../utilities/string-helpers');
const { isValidPluginName, isValidVersion, isValidEmail } = require('../utilities/validation');

/**
 * Interview questions organized by section
 */
const INTERVIEW_SECTIONS = {
  'basic-info': {
    title: 'Basic Information',
    questions: [
      {
        key: 'name',
        prompt: 'What is the name of your plugin?',
        validate: (input) => {
          const kebab = toKebabCase(input);
          if (!isValidPluginName(kebab)) {
            return 'Plugin name must be kebab-case (lowercase with dashes)';
          }
          return true;
        },
        transform: toKebabCase,
        default: 'my-plugin'
      },
      {
        key: 'description',
        prompt: 'Brief description of your plugin (max 500 chars):',
        validate: (input) => input.length > 0 && input.length <= 500,
        default: 'A Claude Code plugin'
      },
      {
        key: 'version',
        prompt: 'Initial version:',
        validate: isValidVersion,
        default: '1.0.0'
      },
      {
        key: 'author.name',
        prompt: 'Author name:',
        validate: (input) => input.trim().length > 0,
        required: true
      },
      {
        key: 'author.email',
        prompt: 'Author email (optional):',
        validate: (input) => !input || isValidEmail(input),
        required: false
      }
    ]
  },

  'capabilities': {
    title: 'Plugin Capabilities',
    questions: [
      {
        key: 'purpose',
        prompt: 'What is the main purpose of this plugin?',
        type: 'text',
        required: true
      },
      {
        key: 'features',
        prompt: 'List the main features (comma-separated):',
        type: 'list',
        transform: (input) => input.split(',').map(s => s.trim()).filter(s => s)
      },
      {
        key: 'target_users',
        prompt: 'Who will use this plugin? (developers, data scientists, etc.):',
        type: 'text'
      }
    ]
  },

  'components': {
    title: 'Plugin Components',
    questions: [
      {
        key: 'has_commands',
        prompt: 'Will your plugin have slash commands? (y/n)',
        type: 'boolean',
        default: 'y'
      },
      {
        key: 'commands',
        prompt: 'List command names (comma-separated, e.g., build, deploy):',
        condition: (answers) => answers.has_commands,
        type: 'list',
        transform: (input) => input.split(',').map(s => toKebabCase(s.trim())).filter(s => s)
      },
      {
        key: 'has_agents',
        prompt: 'Will your plugin have sub-agents? (y/n)',
        type: 'boolean',
        default: 'n'
      },
      {
        key: 'agents',
        prompt: 'List agent names (comma-separated, e.g., CodeReviewer, DataAnalyzer):',
        condition: (answers) => answers.has_agents,
        type: 'list',
        transform: (input) => input.split(',').map(s => toPascalCase(s.trim())).filter(s => s)
      },
      {
        key: 'has_skills',
        prompt: 'Will your plugin have skills? (y/n)',
        type: 'boolean',
        default: 'n'
      },
      {
        key: 'skills',
        prompt: 'List skill names (comma-separated):',
        condition: (answers) => answers.has_skills,
        type: 'list',
        transform: (input) => input.split(',').map(s => toPascalCase(s.trim())).filter(s => s)
      },
      {
        key: 'has_hooks',
        prompt: 'Will your plugin use event hooks? (y/n)',
        type: 'boolean',
        default: 'n'
      },
      {
        key: 'hooks',
        prompt: 'Which events? (comma-separated: before-tool-use, after-tool-use, etc.):',
        condition: (answers) => answers.has_hooks,
        type: 'list',
        transform: (input) => input.split(',').map(s => s.trim().toLowerCase().replace(/_/g, '-')).filter(s => s)
      }
    ]
  },

  'advanced': {
    title: 'Advanced Options',
    questions: [
      {
        key: 'license',
        prompt: 'License (MIT, Apache-2.0, GPL-3.0, etc.):',
        default: 'MIT'
      },
      {
        key: 'repository',
        prompt: 'Repository URL (optional):',
        required: false
      },
      {
        key: 'homepage',
        prompt: 'Homepage URL (optional):',
        required: false
      },
      {
        key: 'keywords',
        prompt: 'Keywords for discovery (comma-separated):',
        type: 'list',
        transform: (input) => input.split(',').map(s => s.trim()).filter(s => s),
        required: false
      }
    ]
  }
};

/**
 * Conduct interview to gather plugin specifications
 * @param {object} options - Interview options
 * @returns {Promise<object>} Plugin specification from answers
 */
async function conductInterview(options = {}) {
  const {
    sections = ['basic-info', 'capabilities', 'components'],
    interactive = true,
    defaults = {}
  } = options;

  const answers = { ...defaults };

  if (interactive) {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    try {
      for (const sectionKey of sections) {
        const section = INTERVIEW_SECTIONS[sectionKey];
        if (!section) continue;

        console.log(`\n=== ${section.title} ===\n`);

        for (const question of section.questions) {
          // Check condition
          if (question.condition && !question.condition(answers)) {
            continue;
          }

          const answer = await askQuestion(rl, question, answers);
          setNestedValue(answers, question.key, answer);
        }
      }
    } finally {
      rl.close();
    }
  } else {
    // Non-interactive mode: use defaults
    for (const sectionKey of sections) {
      const section = INTERVIEW_SECTIONS[sectionKey];
      if (!section) continue;

      for (const question of section.questions) {
        if (question.condition && !question.condition(answers)) {
          continue;
        }

        const existing = getNestedValue(answers, question.key);
        if (existing === undefined && question.default !== undefined) {
          setNestedValue(answers, question.key, question.default);
        }
      }
    }
  }

  return buildSpecification(answers);
}

/**
 * Ask a single question
 * @param {readline.Interface} rl - Readline interface
 * @param {object} question - Question configuration
 * @param {object} currentAnswers - Current answers
 * @returns {Promise<any>} Answer value
 */
function askQuestion(rl, question, currentAnswers) {
  return new Promise((resolve) => {
    const promptText = buildPrompt(question);

    rl.question(promptText, (input) => {
      // Handle empty input
      if (!input.trim()) {
        if (question.default !== undefined) {
          resolve(question.default);
          return;
        }
        if (!question.required) {
          resolve(null);
          return;
        }
        // Re-ask if required
        console.log('This field is required.');
        askQuestion(rl, question, currentAnswers).then(resolve);
        return;
      }

      // Validate input
      if (question.validate) {
        const validation = question.validate(input);
        if (validation !== true) {
          console.log(validation);
          askQuestion(rl, question, currentAnswers).then(resolve);
          return;
        }
      }

      // Transform input
      let value = input;
      if (question.type === 'boolean') {
        value = input.toLowerCase().startsWith('y');
      } else if (question.transform) {
        value = question.transform(input);
      }

      resolve(value);
    });
  });
}

/**
 * Build prompt string for question
 * @param {object} question - Question configuration
 * @returns {string} Prompt text
 */
function buildPrompt(question) {
  let prompt = question.prompt;

  if (question.default !== undefined) {
    prompt += ` [${question.default}]`;
  }

  if (!question.required) {
    prompt += ' (optional)';
  }

  prompt += ': ';
  return prompt;
}

/**
 * Set nested value in object using dot notation
 * @param {object} obj - Object to modify
 * @param {string} path - Dot notation path
 * @param {any} value - Value to set
 */
function setNestedValue(obj, path, value) {
  const parts = path.split('.');
  const last = parts.pop();
  let current = obj;

  for (const part of parts) {
    if (!current[part]) {
      current[part] = {};
    }
    current = current[part];
  }

  current[last] = value;
}

/**
 * Get nested value from object using dot notation
 * @param {object} obj - Object to query
 * @param {string} path - Dot notation path
 * @returns {any} Value at path
 */
function getNestedValue(obj, path) {
  const parts = path.split('.');
  let current = obj;

  for (const part of parts) {
    if (current && typeof current === 'object') {
      current = current[part];
    } else {
      return undefined;
    }
  }

  return current;
}

/**
 * Build complete plugin specification from answers
 * @param {object} answers - Interview answers
 * @returns {object} Plugin specification
 */
function buildSpecification(answers) {
  const spec = {
    // Basic info
    name: answers.name || 'my-plugin',
    version: answers.version || '1.0.0',
    description: answers.description || 'A Claude Code plugin',
    author: answers.author || { name: 'Unknown' },

    // Capabilities
    purpose: answers.purpose,
    features: answers.features || [],
    targetUsers: answers.target_users,

    // Components
    commands: answers.commands || [],
    agents: answers.agents || [],
    skills: answers.skills || [],
    hooks: answers.hooks ? answers.hooks.map(event => ({
      event,
      description: `Handle ${event} event`,
      script: `${event}.sh`
    })) : [],

    // Advanced
    license: answers.license,
    repository: answers.repository,
    homepage: answers.homepage,
    keywords: answers.keywords || []
  };

  // Clean up undefined values
  return JSON.parse(JSON.stringify(spec));
}

/**
 * Create interview presets for common plugin types
 * @param {string} pluginType - Type of plugin
 * @returns {object} Preset answers
 */
function getInterviewPreset(pluginType) {
  const presets = {
    'data-analysis': {
      name: 'data-analyzer',
      description: 'Advanced data analysis and visualization plugin',
      purpose: 'Provide comprehensive data analysis capabilities',
      features: ['Data parsing', 'Statistical analysis', 'Visualization', 'Report generation'],
      target_users: 'data scientists, analysts',
      has_commands: true,
      commands: ['analyze', 'visualize', 'report'],
      has_skills: true,
      skills: ['DataAnalysis', 'Visualization'],
      keywords: ['data', 'analysis', 'statistics', 'visualization']
    },

    'code-quality': {
      name: 'code-quality',
      description: 'Code quality analysis and improvement plugin',
      purpose: 'Analyze and improve code quality',
      features: ['Code review', 'Style checking', 'Security scanning', 'Performance analysis'],
      target_users: 'developers',
      has_commands: true,
      commands: ['review', 'lint', 'security-scan'],
      has_agents: true,
      agents: ['CodeReviewer', 'SecurityAnalyzer'],
      has_hooks: true,
      hooks: ['before-tool-use', 'after-tool-use'],
      keywords: ['code', 'quality', 'review', 'security']
    },

    'deployment': {
      name: 'deployment-helper',
      description: 'Automated deployment and CI/CD plugin',
      purpose: 'Streamline deployment processes',
      features: ['Build automation', 'Deploy to cloud', 'Rollback support', 'Environment management'],
      target_users: 'devops engineers, developers',
      has_commands: true,
      commands: ['deploy', 'rollback', 'build', 'status'],
      has_hooks: true,
      hooks: ['before-tool-use', 'after-message'],
      keywords: ['deploy', 'ci', 'cd', 'automation']
    },

    'documentation': {
      name: 'doc-generator',
      description: 'Documentation generation and management plugin',
      purpose: 'Generate and maintain project documentation',
      features: ['API docs', 'README generation', 'Changelog updates', 'Wiki creation'],
      target_users: 'developers, technical writers',
      has_commands: true,
      commands: ['generate-docs', 'update-readme', 'changelog'],
      has_agents: true,
      agents: ['DocumentationWriter'],
      keywords: ['documentation', 'docs', 'readme', 'api']
    }
  };

  return presets[pluginType] || {};
}

/**
 * Validate interview answers
 * @param {object} answers - Interview answers
 * @returns {object} Validation result
 */
function validateAnswers(answers) {
  const errors = [];
  const warnings = [];

  // Required fields
  if (!answers.name) {
    errors.push('Plugin name is required');
  }
  if (!answers.description) {
    errors.push('Plugin description is required');
  }
  if (!answers.author || !answers.author.name) {
    errors.push('Author name is required');
  }

  // Component validation
  const hasComponents = (answers.commands && answers.commands.length > 0) ||
                       (answers.agents && answers.agents.length > 0) ||
                       (answers.skills && answers.skills.length > 0) ||
                       (answers.hooks && answers.hooks.length > 0);

  if (!hasComponents) {
    warnings.push('Plugin has no components (commands, agents, skills, or hooks)');
  }

  // Name conflicts
  if (answers.commands && answers.agents) {
    const commandNames = new Set(answers.commands.map(c => c.toLowerCase()));
    const agentNames = new Set(answers.agents.map(a => a.toLowerCase()));
    const conflicts = [...commandNames].filter(x => agentNames.has(x));
    if (conflicts.length > 0) {
      warnings.push(`Name conflicts between commands and agents: ${conflicts.join(', ')}`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings
  };
}

module.exports = {
  INTERVIEW_SECTIONS,
  conductInterview,
  askQuestion,
  buildPrompt,
  setNestedValue,
  getNestedValue,
  buildSpecification,
  getInterviewPreset,
  validateAnswers
};