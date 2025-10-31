/**
 * Hook Builder for Plugin-Expert
 * Builds hook configurations for event handling
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const { isValidHookEvent } = require('../utilities/validation');
const { escapeForShell, escapeForJSON } = require('../utilities/escape-helpers');
const { PathManager } = require('../utilities/path-manager');

/**
 * Build hooks configuration from specifications
 * @param {array} specs - Array of hook specifications
 * @param {string} basePath - Base path for the plugin
 * @returns {object} Hooks configuration object
 */
function buildHooksConfig(specs, basePath = null) {
  const pathManager = new PathManager(basePath);
  const config = {
    hooks: []
  };

  if (!Array.isArray(specs)) {
    throw new Error('Hook specifications must be an array');
  }

  for (const spec of specs) {
    config.hooks.push(buildSingleHook(spec, pathManager));
  }

  return config;
}

/**
 * Build a single hook configuration
 * @param {object} spec - Hook specification
 * @param {PathManager} pathManager - Path manager instance
 * @returns {object} Hook configuration
 */
function buildSingleHook(spec, pathManager) {
  const hook = {
    event: '',
    command: '',
    ...spec
  };

  // Validate event
  if (!spec.event) {
    throw new Error('Hook event is required');
  }

  if (!isValidHookEvent(spec.event)) {
    throw new Error(`Invalid hook event: ${spec.event}. Valid events: before-tool-use, after-tool-use, before-message, after-message, on-error, on-session-start, on-session-end`);
  }

  // Build command based on type
  if (spec.script) {
    // Reference to a script file
    const scriptPath = pathManager.resolve('hooks', spec.script);
    hook.command = escapeForShell(scriptPath);
  } else if (spec.inline) {
    // Inline command
    hook.command = spec.inline;
  } else if (spec.function) {
    // JavaScript function (for advanced hooks)
    hook.command = `node -e "${escapeForJSON(spec.function)}"`;
  } else {
    throw new Error('Hook must have either script, inline, or function property');
  }

  // Add optional properties
  if (spec.description) {
    hook.description = spec.description;
  }

  if (spec.condition) {
    hook.condition = spec.condition;
  }

  if (spec.timeout) {
    hook.timeout = spec.timeout;
  }

  if (spec.retries) {
    hook.retries = spec.retries;
  }

  // Add environment variables if specified
  if (spec.env) {
    hook.env = spec.env;
  }

  // Add working directory if specified
  if (spec.cwd) {
    hook.cwd = pathManager.resolve(spec.cwd);
  }

  return hook;
}

/**
 * Generate hook script templates
 * @param {string} event - Hook event type
 * @param {string} language - Script language (bash, python, node)
 * @returns {string} Script template
 */
function generateHookScript(event, language = 'bash') {
  const templates = {
    bash: {
      'before-tool-use': `#!/bin/bash
# Hook: Before Tool Use
# This hook runs before a tool is executed

# Access environment variables
TOOL_NAME="\${CLAUDE_TOOL_NAME}"
TOOL_PARAMS="\${CLAUDE_TOOL_PARAMS}"

# Your logic here
echo "About to use tool: \$TOOL_NAME"

# Return 0 to continue, non-zero to abort
exit 0`,

      'after-tool-use': `#!/bin/bash
# Hook: After Tool Use
# This hook runs after a tool has been executed

TOOL_NAME="\${CLAUDE_TOOL_NAME}"
TOOL_RESULT="\${CLAUDE_TOOL_RESULT}"

echo "Tool \$TOOL_NAME completed"
exit 0`,

      'before-message': `#!/bin/bash
# Hook: Before Message
# This hook runs before Claude sends a message

MESSAGE_CONTENT="\${CLAUDE_MESSAGE_CONTENT}"

echo "Processing message..."
exit 0`,

      'after-message': `#!/bin/bash
# Hook: After Message
# This hook runs after Claude sends a message

MESSAGE_CONTENT="\${CLAUDE_MESSAGE_CONTENT}"

echo "Message sent"
exit 0`,

      'on-error': `#!/bin/bash
# Hook: On Error
# This hook runs when an error occurs

ERROR_MESSAGE="\${CLAUDE_ERROR_MESSAGE}"
ERROR_CONTEXT="\${CLAUDE_ERROR_CONTEXT}"

echo "Error occurred: \$ERROR_MESSAGE"
# Log error or send notification
exit 0`,

      'on-session-start': `#!/bin/bash
# Hook: On Session Start
# This hook runs when a new session begins

SESSION_ID="\${CLAUDE_SESSION_ID}"

echo "Session started: \$SESSION_ID"
# Initialize resources
exit 0`,

      'on-session-end': `#!/bin/bash
# Hook: On Session End
# This hook runs when a session ends

SESSION_ID="\${CLAUDE_SESSION_ID}"

echo "Session ended: \$SESSION_ID"
# Clean up resources
exit 0`
    },

    python: {
      'before-tool-use': `#!/usr/bin/env python3
# Hook: Before Tool Use

import os
import sys
import json

def main():
    tool_name = os.environ.get('CLAUDE_TOOL_NAME', '')
    tool_params = os.environ.get('CLAUDE_TOOL_PARAMS', '{}')

    params = json.loads(tool_params)
    print(f"About to use tool: {tool_name}")

    # Your logic here

    # Return 0 to continue, non-zero to abort
    return 0

if __name__ == '__main__':
    sys.exit(main())`,

      'after-tool-use': `#!/usr/bin/env python3
# Hook: After Tool Use

import os
import sys
import json

def main():
    tool_name = os.environ.get('CLAUDE_TOOL_NAME', '')
    tool_result = os.environ.get('CLAUDE_TOOL_RESULT', '{}')

    result = json.loads(tool_result)
    print(f"Tool {tool_name} completed")

    return 0

if __name__ == '__main__':
    sys.exit(main())`,

      // ... other events similar pattern
    },

    node: {
      'before-tool-use': `#!/usr/bin/env node
// Hook: Before Tool Use

const toolName = process.env.CLAUDE_TOOL_NAME || '';
const toolParams = JSON.parse(process.env.CLAUDE_TOOL_PARAMS || '{}');

console.log(\`About to use tool: \${toolName}\`);

// Your logic here

// Exit with 0 to continue, non-zero to abort
process.exit(0);`,

      'after-tool-use': `#!/usr/bin/env node
// Hook: After Tool Use

const toolName = process.env.CLAUDE_TOOL_NAME || '';
const toolResult = JSON.parse(process.env.CLAUDE_TOOL_RESULT || '{}');

console.log(\`Tool \${toolName} completed\`);

process.exit(0);`,

      // ... other events similar pattern
    }
  };

  // Return template if it exists
  if (templates[language] && templates[language][event]) {
    return templates[language][event];
  }

  // Return generic template if specific one doesn't exist
  return templates[language]?.['before-tool-use'] || templates.bash['before-tool-use'];
}

/**
 * Validate hooks configuration
 * @param {object} config - Hooks configuration
 * @returns {array} Array of validation errors (empty if valid)
 */
function validateHooksConfig(config) {
  const errors = [];

  if (!config.hooks || !Array.isArray(config.hooks)) {
    errors.push('Hooks configuration must have a "hooks" array');
    return errors;
  }

  config.hooks.forEach((hook, index) => {
    if (!hook.event) {
      errors.push(`Hook ${index}: missing event`);
    } else if (!isValidHookEvent(hook.event)) {
      errors.push(`Hook ${index}: invalid event "${hook.event}"`);
    }

    if (!hook.command) {
      errors.push(`Hook ${index}: missing command`);
    }

    if (hook.timeout && (typeof hook.timeout !== 'number' || hook.timeout <= 0)) {
      errors.push(`Hook ${index}: timeout must be a positive number`);
    }

    if (hook.retries && (typeof hook.retries !== 'number' || hook.retries < 0)) {
      errors.push(`Hook ${index}: retries must be a non-negative number`);
    }
  });

  return errors;
}

/**
 * Generate a hook template
 * @param {string} event - Hook event
 * @returns {object} Hook template
 */
function generateHookTemplate(event) {
  return {
    event: event || 'before-tool-use',
    description: `Hook for ${event} event`,
    script: `${event}.sh`,
    timeout: 5000,
    retries: 0
  };
}

/**
 * Create hook script file
 * @param {string} event - Hook event
 * @param {string} scriptPath - Path to create script
 * @param {string} language - Script language
 * @returns {boolean} Success status
 */
function createHookScript(event, scriptPath, language = 'bash') {
  const fs = require('fs');
  const script = generateHookScript(event, language);

  try {
    fs.writeFileSync(scriptPath, script);

    // Make script executable (Unix-like systems)
    if (process.platform !== 'win32') {
      fs.chmodSync(scriptPath, '755');
    }

    return true;
  } catch {
    return false;
  }
}

/**
 * Build hook command with proper escaping
 * @param {string} scriptPath - Path to script
 * @param {object} args - Arguments to pass
 * @returns {string} Properly escaped command
 */
function buildHookCommand(scriptPath, args = {}) {
  let command = escapeForShell(scriptPath);

  // Add arguments if provided
  for (const [key, value] of Object.entries(args)) {
    command += ` ${escapeForShell(`--${key}=${value}`)}`;
  }

  return command;
}

module.exports = {
  buildHooksConfig,
  buildSingleHook,
  generateHookScript,
  validateHooksConfig,
  generateHookTemplate,
  createHookScript,
  buildHookCommand
};