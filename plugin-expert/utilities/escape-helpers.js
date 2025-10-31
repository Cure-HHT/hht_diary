/**
 * Escape Helpers for Plugin-Expert
 * Handle escaping for JSON, markdown, and multi-line strings
 * Layer 1: Atomic Utility (no dependencies on other helpers)
 */

/**
 * Escape a string for safe inclusion in JSON
 * Handles multi-line strings and special characters
 * @param {string} str - String to escape
 * @returns {string} Escaped string safe for JSON
 */
function escapeForJSON(str) {
  if (typeof str !== 'string') {
    return str;
  }

  return str
    .replace(/\\/g, '\\\\')     // Backslash
    .replace(/"/g, '\\"')        // Double quotes
    .replace(/\n/g, '\\n')       // Newlines
    .replace(/\r/g, '\\r')       // Carriage returns
    .replace(/\t/g, '\\t')       // Tabs
    .replace(/\f/g, '\\f')       // Form feeds
    .replace(/\b/g, '\\b')       // Backspaces
    .replace(/\v/g, '\\v')       // Vertical tabs
    .replace(/\u0000/g, '\\u0000') // Null characters
    .replace(/\u2028/g, '\\u2028') // Line separator
    .replace(/\u2029/g, '\\u2029'); // Paragraph separator
}

/**
 * Unescape a JSON-escaped string
 * @param {string} str - Escaped string
 * @returns {string} Unescaped string
 */
function unescapeFromJSON(str) {
  if (typeof str !== 'string') {
    return str;
  }

  return str
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\f/g, '\f')
    .replace(/\\b/g, '\b')
    .replace(/\\v/g, '\v')
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\')
    .replace(/\\u0000/g, '\u0000')
    .replace(/\\u2028/g, '\u2028')
    .replace(/\\u2029/g, '\u2029');
}

/**
 * Escape a string for safe inclusion in a shell command
 * @param {string} str - String to escape
 * @returns {string} Shell-escaped string
 */
function escapeForShell(str) {
  if (typeof str !== 'string') {
    return str;
  }

  // If string contains special characters, wrap in single quotes
  // and escape any existing single quotes
  if (/[^a-zA-Z0-9_\-./]/.test(str)) {
    return "'" + str.replace(/'/g, "'\\''") + "'";
  }

  return str;
}

/**
 * Escape backticks in template literals
 * @param {string} str - String to escape
 * @returns {string} Escaped string
 */
function escapeBackticks(str) {
  if (typeof str !== 'string') {
    return str;
  }

  return str.replace(/`/g, '\\`');
}

/**
 * Escape a string for use in a regular expression
 * @param {string} str - String to escape
 * @returns {string} Regex-escaped string
 */
function escapeForRegex(str) {
  if (typeof str !== 'string') {
    return str;
  }

  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Convert a multi-line string to a JSON-compatible format
 * @param {string} str - Multi-line string
 * @param {object} options - Formatting options
 * @returns {string} JSON-compatible string
 */
function multilineToJSON(str, options = {}) {
  const {
    indent = 2,
    arrayFormat = false  // If true, returns as array of lines
  } = options;

  if (!str) return '""';

  if (arrayFormat) {
    // Split into lines and return as JSON array
    const lines = str.split('\n').map(line => escapeForJSON(line));
    const indentStr = ' '.repeat(indent);
    return '[\n' +
      lines.map(line => `${indentStr}"${line}"`).join(',\n') +
      '\n]';
  } else {
    // Return as single escaped string
    return '"' + escapeForJSON(str) + '"';
  }
}

/**
 * Convert a JSON string array back to multi-line text
 * @param {array} lines - Array of strings
 * @returns {string} Multi-line string
 */
function jsonArrayToMultiline(lines) {
  if (!Array.isArray(lines)) {
    return '';
  }

  return lines.join('\n');
}

/**
 * Escape HTML entities
 * @param {string} str - String to escape
 * @returns {string} HTML-escaped string
 */
function escapeHTML(str) {
  if (typeof str !== 'string') {
    return str;
  }

  const escapeMap = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  };

  return str.replace(/[&<>"']/g, char => escapeMap[char]);
}

/**
 * Escape YAML special characters
 * @param {string} str - String to escape
 * @returns {string} YAML-safe string
 */
function escapeForYAML(str) {
  if (typeof str !== 'string') {
    return str;
  }

  // Check if string needs quoting
  const needsQuoting = /^[>|]|^[*&]|^[@`]|[:#]|^\s|\s$|\n/.test(str) ||
                      /^(true|false|null|undefined|yes|no|on|off)$/i.test(str) ||
                      /^[+-]?\d+(\.\d+)?([eE][+-]?\d+)?$/.test(str);

  if (needsQuoting) {
    // Use double quotes and escape necessary characters
    return '"' + str
      .replace(/\\/g, '\\\\')
      .replace(/"/g, '\\"')
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t') + '"';
  }

  return str;
}

/**
 * Prepare a prompt string for safe inclusion in a markdown file
 * Handles frontmatter, code blocks, and special characters
 * @param {string} prompt - Prompt string
 * @returns {string} Markdown-safe prompt
 */
function escapePromptForMarkdown(prompt) {
  if (typeof prompt !== 'string') {
    return prompt;
  }

  // Check if prompt contains triple backticks that might break markdown
  if (prompt.includes('```')) {
    // Escape code blocks by adding zero-width spaces
    prompt = prompt.replace(/```/g, '``\u200B`');
  }

  // Ensure frontmatter delimiters don't break
  if (prompt.includes('---') && prompt.indexOf('---') < 50) {
    // Add zero-width space to prevent frontmatter parsing issues
    prompt = prompt.replace(/^---/gm, '-\u200B--');
  }

  return prompt;
}

/**
 * Safely format a string for inclusion in different contexts
 * @param {string} str - String to format
 * @param {string} context - Context: 'json', 'shell', 'markdown', 'yaml', 'html'
 * @returns {string} Safely formatted string
 */
function safeFormat(str, context) {
  switch (context.toLowerCase()) {
    case 'json':
      return escapeForJSON(str);
    case 'shell':
      return escapeForShell(str);
    case 'markdown':
      return escapePromptForMarkdown(str);
    case 'yaml':
      return escapeForYAML(str);
    case 'html':
      return escapeHTML(str);
    case 'regex':
      return escapeForRegex(str);
    default:
      return str;
  }
}

/**
 * Create a safe JSON string with proper escaping
 * Handles multi-line values and special characters
 * @param {object} obj - Object to stringify
 * @param {number} indent - Indentation level
 * @returns {string} Safe JSON string
 */
function safeJSONStringify(obj, indent = 2) {
  // Custom replacer that handles multi-line strings
  function replacer(key, value) {
    if (typeof value === 'string' && value.includes('\n')) {
      // Already escaped by JSON.stringify
      return value;
    }
    return value;
  }

  return JSON.stringify(obj, replacer, indent);
}

module.exports = {
  escapeForJSON,
  unescapeFromJSON,
  escapeForShell,
  escapeBackticks,
  escapeForRegex,
  multilineToJSON,
  jsonArrayToMultiline,
  escapeHTML,
  escapeForYAML,
  escapePromptForMarkdown,
  safeFormat,
  safeJSONStringify
};