/**
 * Validation Utilities for Plugin-Expert
 * Validates plugin names, versions, and other inputs
 * Layer 1: Atomic Utility (no dependencies on other helpers)
 */

/**
 * Validate semantic version string
 * @param {string} version - Version string to validate
 * @returns {boolean} True if valid semver
 */
function isValidVersion(version) {
  const semverRegex = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/;
  return typeof version === 'string' && semverRegex.test(version);
}

/**
 * Validate plugin name (kebab-case, alphanumeric with dashes)
 * @param {string} name - Plugin name to validate
 * @returns {boolean} True if valid plugin name
 */
function isValidPluginName(name) {
  const nameRegex = /^[a-z][a-z0-9-]*[a-z0-9]$/;
  return typeof name === 'string' &&
         name.length >= 2 &&
         name.length <= 50 &&
         nameRegex.test(name);
}

/**
 * Validate command name (starts with slash)
 * @param {string} name - Command name to validate
 * @returns {boolean} True if valid command name
 */
function isValidCommandName(name) {
  const commandRegex = /^\/[a-z][a-z0-9-]*$/;
  return typeof name === 'string' && commandRegex.test(name);
}

/**
 * Validate URL
 * @param {string} url - URL to validate
 * @returns {boolean} True if valid URL
 */
function isValidURL(url) {
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

/**
 * Validate email address
 * @param {string} email - Email to validate
 * @returns {boolean} True if valid email
 */
function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return typeof email === 'string' && emailRegex.test(email);
}

/**
 * Validate hook event name
 * @param {string} event - Event name to validate
 * @returns {boolean} True if valid event name
 */
function isValidHookEvent(event) {
  const validEvents = [
    'before-tool-use',
    'after-tool-use',
    'before-message',
    'after-message',
    'on-error',
    'on-session-start',
    'on-session-end'
  ];
  return validEvents.includes(event);
}

/**
 * Validate agent name (alphanumeric with dashes, underscores)
 * @param {string} name - Agent name to validate
 * @returns {boolean} True if valid agent name
 */
function isValidAgentName(name) {
  const nameRegex = /^[a-zA-Z][a-zA-Z0-9-_]*$/;
  return typeof name === 'string' &&
         name.length >= 2 &&
         name.length <= 50 &&
         nameRegex.test(name);
}

/**
 * Validate skill name (alphanumeric with dashes, underscores)
 * @param {string} name - Skill name to validate
 * @returns {boolean} True if valid skill name
 */
function isValidSkillName(name) {
  const nameRegex = /^[a-zA-Z][a-zA-Z0-9-_]*$/;
  return typeof name === 'string' &&
         name.length >= 2 &&
         name.length <= 50 &&
         nameRegex.test(name);
}

/**
 * Validate file path (no parent directory traversal)
 * @param {string} path - File path to validate
 * @returns {boolean} True if valid and safe path
 */
function isValidFilePath(path) {
  // Check for parent directory traversal
  if (path.includes('..')) return false;

  // Check for absolute paths (we want relative paths within plugin)
  if (path.startsWith('/') || path.match(/^[A-Z]:\\/)) return false;

  // Check for invalid characters
  const invalidChars = /[<>:"|?*\x00-\x1F]/;
  if (invalidChars.test(path)) return false;

  return true;
}

/**
 * Validate description length and content
 * @param {string} description - Description to validate
 * @param {number} maxLength - Maximum allowed length
 * @returns {boolean} True if valid description
 */
function isValidDescription(description, maxLength = 500) {
  return typeof description === 'string' &&
         description.length > 0 &&
         description.length <= maxLength &&
         description.trim().length > 0;
}

/**
 * Sanitize a string for use as a filename
 * @param {string} str - String to sanitize
 * @returns {string} Sanitized string
 */
function sanitizeFilename(str) {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9-_]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

/**
 * Get validation error messages for a plugin configuration
 * @param {object} config - Plugin configuration to validate
 * @returns {array} Array of error messages (empty if valid)
 */
function validatePluginConfig(config) {
  const errors = [];

  if (!config.name) {
    errors.push('Plugin name is required');
  } else if (!isValidPluginName(config.name)) {
    errors.push(`Invalid plugin name: ${config.name}. Must be kebab-case (lowercase with dashes)`);
  }

  if (!config.version) {
    errors.push('Plugin version is required');
  } else if (!isValidVersion(config.version)) {
    errors.push(`Invalid version: ${config.version}. Must be semantic version (e.g., 1.0.0)`);
  }

  if (!config.description) {
    errors.push('Plugin description is required');
  } else if (!isValidDescription(config.description)) {
    errors.push('Invalid description: must be non-empty and under 500 characters');
  }

  if (!config.author) {
    errors.push('Plugin author is required');
  } else if (!config.author.name || config.author.name.trim().length === 0) {
    errors.push('Author name is required');
  } else if (config.author.email && !isValidEmail(config.author.email)) {
    errors.push(`Invalid author email: ${config.author.email}`);
  }

  return errors;
}

module.exports = {
  isValidVersion,
  isValidPluginName,
  isValidCommandName,
  isValidURL,
  isValidEmail,
  isValidHookEvent,
  isValidAgentName,
  isValidSkillName,
  isValidFilePath,
  isValidDescription,
  sanitizeFilename,
  validatePluginConfig
};